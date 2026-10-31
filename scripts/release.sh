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
#   scripts/release.sh --build 03       a new build of the last released version (odd, 03-99),
#                                       e.g. 26.11.01 - 26110103; with --version, of that version
#
# Version  YY.MM.NN  (NN: release number within the month, from 01)
# Code     YYMMNNBB  (BB: build of that version; odd for Release builds, 01 for a new
#                    version; even for Debug builds from Xcode, the release code + 1)
#          A release is one build: Software Update and the release page order by code.
# Tag      the build code, YYMMNNBB (26110103). Older tags vYY.MM.NN and vYY.MM.NN-bBB still count.
#          Tags are annotated, their message holding the release notes.
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
requested_build=""
while [ $# -gt 0 ]; do
  case $1 in
    --dry-run) dry_run=1 ;;
    --allow-branch) allow_branch=1 ;;
    --version) requested=${2:?--version needs a value such as 26.11.01}; shift ;;
    --build) requested_build=${2:?--build needs an odd number such as 03}; shift ;;
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

# Release tags are build codes (26110103). Older ones read as codes too: v26.11.01 is 26110101,
# v26.11.01-b03 is 26110103.
code_pattern='[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]'
tag_code() {
  case $1 in
    v*)
      local tag=${1#v} build=01
      case $tag in *-b*) build=${tag##*-b}; tag=${tag%-b*} ;; esac
      printf '%s%s' "$(printf '%s' "$tag" | tr -d '.')" "$build"
      ;;
    *) printf '%s' "$1" ;;
  esac
}
# 26110103 -> 26.11.01
code_version() { printf '%s.%s.%s' "${1:0:2}" "${1:2:2}" "${1:4:2}"; }
previous=""
previous_code=0
release_codes=()
for tag in $(git tag --list "$code_pattern" 'v[0-9][0-9].[0-9][0-9].[0-9][0-9]' 'v[0-9][0-9].[0-9][0-9].[0-9][0-9]-b[0-9][0-9]'); do
  tag_value=$(tag_code "$tag")
  release_codes+=("$tag_value")
  if [ "$((10#$tag_value))" -gt "$previous_code" ]; then
    previous=$tag
    previous_code=$((10#$tag_value))
  fi
done

if [ -n "$requested" ]; then
  printf '%s' "$requested" | grep -Eq '^[0-9]{2}\.(0[1-9]|1[0-2])\.(0[1-9]|[1-9][0-9])$' \
    || fail "--version $requested: expected YY.MM.NN, such as 26.11.01"
  version=$requested
elif [ -n "$requested_build" ]; then
  [ -n "$previous" ] || fail "--build needs a released version to build again; pass --version too"
  version=$(code_version "$(printf '%08d' "$previous_code")")
else
  # The next version number this month: one past the highest released this month.
  month=$(date +%y%m)
  number=0
  for released in ${release_codes[@]+"${release_codes[@]}"}; do
    if [ "${released:0:4}" = "$month" ] && [ $((10#${released:4:2})) -gt "$number" ]; then
      number=$((10#${released:4:2}))
    fi
  done
  version=$(code_version "$month$(printf '%02d' $((number + 1)))01")
fi
build=01
if [ -n "$requested_build" ]; then
  printf '%s' "$requested_build" | grep -Eq '^[0-9]{1,2}$' && [ $((10#$requested_build % 2)) -eq 1 ] \
    && [ $((10#$requested_build)) -ge 3 ] \
    || fail "--build $requested_build: a later Release build is odd, 03 to 99 (01 is the version itself)"
  build=$(printf '%02d' $((10#$requested_build)))
fi
code="$(printf '%s' "$version" | tr -d '.')$build"
tag=$code
title="$version - $code"
[ -z "$(git tag --list "$tag")" ] || fail "$tag already exists"
[ "$((10#$code))" -gt "$previous_code" ] || fail "$title is not newer than the last release, $previous ($previous_code); pass --version or --build"
debug_code=$(printf '%08d' $((10#$code + 1)))
today=$(date +%Y-%m-%d)
range=${previous:+$previous..}HEAD
files=(App/Sources/Changelog.json Config/Base.xcconfig site/releases.html)
push=(git push --follow-tags origin "${branch:-main}")

step "$title, changes since ${previous:-the first commit}"
if [ $dry_run -eq 1 ]; then
  scratch=$(mktemp -d)
  trap 'rm -rf "${scratch:?}"' EXIT
  mkdir -p "$scratch/App/Sources" "$scratch/site"
  cp App/Sources/Changelog.json "$scratch/App/Sources/"
  git log --no-merges --format=%s "$range" \
    | (cd "$scratch" && swift "$root/scripts/changelog.swift" "$version" "$code" "$today")
  (cd "$scratch" && swift "$root/scripts/render-releases.swift")
  echo "dry run: would set Config/Base.xcconfig to $version ($code; Debug $debug_code), commit \"chore: release $title\","
  echo "         tag $tag, and offer: ${push[*]}"
  exit 0
fi

git log --no-merges --format=%s "$range" | swift scripts/changelog.swift "$version" "$code" "$today" >/dev/null
undo() { git checkout -- "${files[@]}"; }
sed -i '' -E "s/^MARKETING_VERSION = .*/MARKETING_VERSION = $version/" Config/Base.xcconfig
sed -i '' -E "s/^CURRENT_PROJECT_VERSION = .*/CURRENT_PROJECT_VERSION = $code/" Config/Base.xcconfig
# Debug builds from Xcode carry the even code right after it.
sed -i '' -E "s/^CURRENT_PROJECT_VERSION\[config=Debug\] = .*/CURRENT_PROJECT_VERSION[config=Debug] = $debug_code/" Config/Base.xcconfig

echo
swift scripts/changelog.swift --print "$code"
echo "Commit subjects are the notes as written. Reword them for users in"
echo "App/Sources/Changelog.json now if needed (entry $code), then press Return."
read -r _ || true
notes=$(swift scripts/changelog.swift --print "$code") || { undo; fail "App/Sources/Changelog.json no longer reads; nothing changed"; }
echo "$notes"
echo
swift scripts/render-releases.swift || { undo; fail "site/releases.html did not render; nothing changed"; }

scripts/verify.sh || { undo; fail "scripts/verify.sh"; }

answer=""
read -r -p "Commit and tag $tag? [y/N] " answer || true
if [ "$answer" != "y" ] && [ "$answer" != "Y" ]; then
  undo
  echo "stopped; nothing changed"
  exit 1
fi
git add -- "${files[@]}"
git commit -q -m "chore: release $title" || { git reset -q -- "${files[@]}"; undo; fail "git commit; nothing changed"; }
git tag -a "$tag" -F - <<EOF
$title

$notes
EOF
echo "done  $tag committed and tagged"

answer=""
read -r -p "Push $branch and $tag to origin? This deploys the release page. [y/N] " answer || true
if [ "$answer" = "y" ] || [ "$answer" = "Y" ]; then
  "${push[@]}" || fail "push failed; $tag is committed and tagged locally, retry with: ${push[*]}"
  echo "done  pushed; https://lklong1551019.github.io/Tenure/releases.html updates when the Pages workflow finishes"
else
  echo "note  not pushed; when ready: ${push[*]}"
fi
echo "next  scripts/install-app.sh"
