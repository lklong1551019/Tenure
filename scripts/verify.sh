#!/usr/bin/env bash
# Every check a change must pass before commit: build, tests, dependency rule, format,
# the web app's checks, and a scan of uncommitted changes for secret-shaped values.
#   scripts/verify.sh
set -u

root=$(git rev-parse --show-toplevel)
cd "$root" || exit 1
fail=0

step() {
  local name=$1
  shift
  if "$@" >/dev/null 2>&1; then
    echo "pass  $name"
  else
    echo "FAIL  $name   (rerun: $*)"
    fail=1
  fi
}

step "build" swift build --package-path Packages --build-tests
step "test" swift test --package-path Packages
step "dependency rule" scripts/check-deps.sh
step "format" xcrun swift-format lint --strict --recursive Packages/Domain Packages/Data \
  Packages/Presentation Packages/IntegrationTests Packages/Package.swift App/Sources scripts
if [ -f Config/Local.xcconfig ]; then
  step "app build" xcodebuild -project Tenure.xcodeproj -scheme Tenure \
    -configuration Debug -derivedDataPath .build/xcode -allowProvisioningUpdates build
else
  echo "skip  app build   (no Config/Local.xcconfig; copy Config/Local.example.xcconfig)"
fi

if command -v npm >/dev/null 2>&1 && [ -d web/node_modules ]; then
  step "web check" npm --prefix web run check
elif [ -d web ]; then
  echo "skip  web check   (run: npm --prefix web ci)"
fi

# Same patterns as the pre-commit hook. Only file names and line numbers are printed,
# never the matched text.
value_patterns='(gh[pousr]_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{30,}|glpat-[A-Za-z0-9_-]{20,}|sk-[A-Za-z0-9_-]{24,}|AKIA[0-9A-Z]{16}|AIza[0-9A-Za-z_-]{35}|xox[abposr]-[A-Za-z0-9-]{10,}|-----BEGIN [A-Z ]*PRIVATE KEY-----)'
hits=$(git diff HEAD -U0 -- . ':(exclude)scripts/git-hooks/pre-commit' ':(exclude)scripts/verify.sh' \
  | awk '/^\+\+\+ /{file=substr($0,7)} /^@@/{split($3,a,/[+,]/); line=a[2]-1} /^\+[^+]/{line++; print file":"line"\t"$0}' \
  | grep -E "$value_patterns" | cut -f1 || true)
if [ -n "$hits" ]; then
  echo "FAIL  secret scan   (replace the values with 'temp'):"
  printf '      %s\n' $hits
  fail=1
else
  echo "pass  secret scan"
fi

exit $fail
