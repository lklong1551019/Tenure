#!/usr/bin/env bash
# Backstop for the dependency rule declared in Packages/Package.swift.
# SPM can let a module import a sibling it does not declare; this greps the imports.
#
#   Domain            -> Foundation only
#   Data/*            -> no SwiftUI, no DesignSystem, no *Feature, no other Data module
#   DesignSystem      -> no Domain, no Data module, no *Feature
#   Features/*        -> no Data module, no other *Feature
set -u

root=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
cd "$root/Packages" || exit 1

data_modules='Persistence|DriveSync'
fail=0

report() {
  echo "ERROR: $1" >&2
  printf '%s\n' "$2" | sed 's/^/  /' >&2
  fail=1
}

imports() {
  # $1 = module directory; prints "file:line:import X" for every import in its Sources/.
  # Tests are exempt: they import Testing and use @testable imports.
  grep -rnE '^[[:space:]]*(@[A-Za-z_]+[[:space:]]+)*import[[:space:]]+' --include='*.swift' "${1%/}/Sources" 2>/dev/null
}

hits=$(imports Domain | grep -vE 'import[[:space:]]+Foundation[[:space:]]*$' || true)
[ -n "$hits" ] && report "Domain may import Foundation only." "$hits"

for dir in Data/*/; do
  self=$(basename "$dir")
  others=$(printf '%s' "$data_modules" | tr '|' '\n' | grep -vx "$self" | paste -sd'|' -)
  hits=$(imports "$dir" | grep -E "import[[:space:]]+(SwiftUI|DesignSystem|[A-Za-z]+Feature|$others)\b" || true)
  [ -n "$hits" ] && report "$dir must not import UI, features, or another Data module." "$hits"
done

hits=$(imports Presentation/DesignSystem | grep -E "import[[:space:]]+(Domain|$data_modules|[A-Za-z]+Feature)\b" || true)
[ -n "$hits" ] && report "DesignSystem must not import Domain, Data, or features." "$hits"

for dir in Presentation/Features/*/; do
  self="$(basename "$dir")Feature"
  hits=$(imports "$dir" | grep -E "import[[:space:]]+($data_modules)\b" || true)
  [ -n "$hits" ] && report "$dir must not import a Data module." "$hits"
  hits=$(imports "$dir" | grep -E 'import[[:space:]]+[A-Za-z]+Feature\b' | grep -vE "import[[:space:]]+$self\b" || true)
  [ -n "$hits" ] && report "$dir must not import another feature." "$hits"
done

# Every module directory (one holding Sources/) carries a README.md.
while IFS= read -r src; do
  mod=$(dirname "$src")
  [ -f "$mod/README.md" ] || report "Module without README.md." "$mod"
done < <(find . -type d -name Sources -not -path './.build/*')

[ "$fail" -eq 0 ] && echo "check-deps: ok"
exit $fail
