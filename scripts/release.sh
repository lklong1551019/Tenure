#!/usr/bin/env bash
# Cuts a release: next version for this month, changelog from the commits since the last
# release tag, the release history page, a release commit, and an annotated tag. Then asks
# before pushing; the push deploys the page.
#
#   scripts/release.sh                  release from main
#   scripts/release.sh --dry-run        print the version and notes, change nothing
#   scripts/release.sh --allow-branch   release from a branch other than main
#   scripts/release.sh --version 26.11.01
#                                       this version instead of the next one for this month;
#                                       must be newer than the last release tag
#
# Version  YY.MM.NN  (NN: release number within the month, from 01)
# Code     YYMMNNBB  (BB: build of that version; 01 for the tagged commit itself)
# Tag      vYY.MM.NN, annotated, its message holding the release notes.
# Notes    from commit subjects (scripts/changelog.swift): feat -> New, fix -> Fixed,
#          ui and perf -> Improved. Kept in App/Sources/Changelog.json and rendered to
#          site/releases.html (scripts/render-releases.swift).
# Push     y pushes the branch and the tag; the Pages workflow then publishes
#          https://lklong1551019.github.io/Tenure/releases.html
# Then:    scripts/install-app.sh
set -euo pipefail

root=$(git rev-parse --show-toplevel)
cd "$root"

dry_run=0
allow_branch=0
requested=""
while [ $# -gt 0 ]; do
  case $1 in
    --dry-run) dry_run=1 ;;
    --allow-branch) allow_branch=1 ;;
    --version) requested=${2:?--version needs a value such as 26.11.01}; shift ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
  shift
done

fail() { echo "FAIL  $*" >&2; exit 1; }
step() { echo "----  $*"; }

branch=$(git branch --show-current)
if [ $dry_run -eq 0 ]; then
  [ -n "$branch" ] || fail "detached HEAD; check out main"
  if [ "$branch" != "main" ] && [ $allow_branch -eq 0 ]; then
    fail "on $branch; releases come from main (or pass --allow-branch)"
  fi
  [ -z "$(git status --porcelain)" ] || fail "uncommitted changes; commit or stash them first"
fi

previous=$(git tag --list 'v[0-9][0-9].[0-9][0-9].[0-9][0-9]' --sort=-v:refname | head -1)
if [ -n "$requested" ]; then
  printf '%s' "$requested" | grep -Eq '^[0-9]{2}\.(0[1-9]|1[0-2])\.(0[1-9]|[1-9][0-9])$' \
    || fail "--version $requested: expected YY.MM.NN, such as 26.11.01"
  [ -z "$(git tag --list "v$requested")" ] || fail "v$requested already exists"
  if [ -n "$previous" ]; then
    newest=$(printf '%s\n%s\n' "${previous#v}" "$requested" | sort -t. -k1,1n -k2,2n -k3,3n | tail -1)
    [ "$newest" = "$requested" ] || fail "--version $requested is not newer than $previous"
  fi
  version=$requested
else
  month=$(date +%y.%m)
  count=$(git tag --list "v$month.*" | wc -l | tr -d ' ')
  number=$(printf '%02d' $((10#$count + 1)))
  version="$month.$number"
fi
code="$(printf '%s' "$version" | tr -d '.')01"
today=$(date +%Y-%m-%d)
range=${previous:+$previous..}HEAD
files=(App/Sources/Changelog.json Config/Base.xcconfig site/releases.html)
push=(git push --follow-tags origin "${branch:-main}")

step "$version ($code), changes since ${previous:-the first commit}"
if [ $dry_run -eq 1 ]; then
  scratch=$(mktemp -d)
  trap 'rm -rf "${scratch:?}"' EXIT
  mkdir -p "$scratch/App/Sources" "$scratch/site"
  cp App/Sources/Changelog.json "$scratch/App/Sources/"
  git log --no-merges --format=%s "$range" \
    | (cd "$scratch" && swift "$root/scripts/changelog.swift" "$version" "$code" "$today")
  (cd "$scratch" && swift "$root/scripts/render-releases.swift")
  echo "dry run: would set Config/Base.xcconfig to $version ($code), commit \"chore: release $version\","
  echo "         tag v$version, and offer: ${push[*]}"
  exit 0
fi

git log --no-merges --format=%s "$range" | swift scripts/changelog.swift "$version" "$code" "$today" >/dev/null
undo() { git checkout -- "${files[@]}"; }
sed -i '' -E "s/^MARKETING_VERSION = .*/MARKETING_VERSION = $version/" Config/Base.xcconfig
sed -i '' -E "s/^CURRENT_PROJECT_VERSION = .*/CURRENT_PROJECT_VERSION = $code/" Config/Base.xcconfig

echo
swift scripts/changelog.swift --print "$version"
echo "Commit subjects are the notes as written. Reword them for users in"
echo "App/Sources/Changelog.json now if needed (entry $version), then press Return."
read -r _ || true
notes=$(swift scripts/changelog.swift --print "$version") || { undo; fail "App/Sources/Changelog.json no longer reads; nothing changed"; }
echo "$notes"
echo
swift scripts/render-releases.swift || { undo; fail "site/releases.html did not render; nothing changed"; }

scripts/verify.sh || { undo; fail "scripts/verify.sh"; }

answer=""
read -r -p "Commit and tag v$version? [y/N] " answer || true
if [ "$answer" != "y" ] && [ "$answer" != "Y" ]; then
  undo
  echo "stopped; nothing changed"
  exit 1
fi
git add -- "${files[@]}"
git commit -q -m "chore: release $version" || { git reset -q -- "${files[@]}"; undo; fail "git commit; nothing changed"; }
git tag -a "v$version" -F - <<EOF
$version ($code)

$notes
EOF
echo "done  v$version committed and tagged"

answer=""
read -r -p "Push $branch and v$version to origin? This deploys the release page. [y/N] " answer || true
if [ "$answer" = "y" ] || [ "$answer" = "Y" ]; then
  "${push[@]}" || fail "push failed; v$version is committed and tagged locally, retry with: ${push[*]}"
  echo "done  pushed; https://lklong1551019.github.io/Tenure/releases.html updates when the Pages workflow finishes"
else
  echo "note  not pushed; when ready: ${push[*]}"
fi
echo "next  scripts/install-app.sh"
