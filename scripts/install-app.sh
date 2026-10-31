#!/usr/bin/env bash
# Builds the Release app, checks it, and installs it for daily use. The version comes from the
# latest release tag (scripts/release.sh tags the build code, 26110103; older tags v26.11.01); the
# build code YYMMNNBB is odd for Release builds (even codes are Debug builds from Xcode): the
# tag's build on the tagged commit, then 2 more per commit after it, so each commit has its
# own code and the same commit always gets the same one.
#
#   scripts/install-app.sh               verify, build, install to /Applications, launch
#   scripts/install-app.sh --skip-verify skip scripts/verify.sh
#   scripts/install-app.sh --build-only  build and check, install nothing
#   scripts/install-app.sh --dest DIR    install into DIR instead of /Applications
#   scripts/install-app.sh --build 03    this build number (odd, 01-99) instead of the default
#
# Release keeps the base bundle id, so the installed app opens the same data file, Keychain items,
# and Google client as the previous install. The data file lives in the app's sandbox container,
# not in the .app, so replacing the app never touches it. Signing uses the team in
# Config/Local.xcconfig; no Developer ID or notarization is involved, so build on each Mac
# that runs it.
set -euo pipefail

root=$(git rev-parse --show-toplevel)
cd "$root"

skip_verify=0
build_only=0
dest=/Applications
build=""
while [ $# -gt 0 ]; do
  case $1 in
    --skip-verify) skip_verify=1 ;;
    --build-only) build_only=1 ;;
    --dest) dest=${2:?--dest needs a directory}; shift ;;
    --build) build=${2:?--build needs an odd number such as 03}; shift ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
  shift
done

fail() { echo "FAIL  $*" >&2; exit 1; }
step() { echo "----  $*"; }

[ -f Config/Local.xcconfig ] || fail "no Config/Local.xcconfig: copy Config/Local.example.xcconfig and set DEVELOPMENT_TEAM"
[ -f Config/Secrets.xcconfig ] || echo "note  no Config/Secrets.xcconfig: the app installs with Google Drive sync off"
if [ -n "$(git status --porcelain)" ]; then
  echo "note  uncommitted changes are included in this build"
fi

if [ $skip_verify -eq 0 ]; then
  step "verify"
  scripts/verify.sh || fail "scripts/verify.sh (rerun with --skip-verify to install anyway)"
fi

derived="$root/.build/release"
mkdir -p "$derived"
log="$derived/build.log"
# Version code YYMMNNBB: the release tag gives YYMMNN and its build (the tag is the code, or the
# older vYY.MM.NN and vYY.MM.NN-bBB);
# BB stays odd (a Release build): the tag's build plus 2 per commit after it, or --build.
# Without a tag yet, Config/Base.xcconfig decides.
if [ -n "$build" ]; then
  printf '%s' "$build" | grep -Eq '^[0-9]{1,2}$' && [ $((10#$build % 2)) -eq 1 ] \
    || fail "--build $build: Release builds are odd, 01 to 99 (even codes are Debug builds)"
  build=$(printf '%02d' $((10#$build)))
fi
build_settings=()
if tag=$(git describe --tags --abbrev=0 --match '[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]' \
  --match 'v[0-9][0-9].[0-9][0-9].[0-9][0-9]*' 2>/dev/null); then
  since=$(git rev-list --count "$tag..HEAD")
  case $tag in
    v*)
      version=${tag#v}
      tag_build=01
      case $version in *-b*) tag_build=${version##*-b}; version=${version%-b*} ;; esac
      ;;
    *)
      version="${tag:0:2}.${tag:2:2}.${tag:4:2}"
      tag_build=${tag:6:2}
      ;;
  esac
  if [ -z "$build" ]; then
    next=$((10#$tag_build + 2 * since))
    [ "$next" -le 99 ] || fail "$since commits since $tag; cut a release with scripts/release.sh, or pass --build"
    build=$(printf '%02d' "$next")
  fi
  code="$(printf '%s' "$version" | tr -d '.')$build"
  build_settings=(MARKETING_VERSION="$version" CURRENT_PROJECT_VERSION="$code")
  [ "$since" -eq 0 ] || echo "note  $since commits after $tag: building $version as build $code"
elif [ -n "$build" ]; then
  version=$(sed -nE 's/^MARKETING_VERSION = (.*)/\1/p' Config/Base.xcconfig)
  build_settings=(CURRENT_PROJECT_VERSION="$(printf '%s' "$version" | tr -d '.')$build")
else
  echo "note  no release tag yet: version from Config/Base.xcconfig (scripts/release.sh tags one)"
fi
step "build Release ($(git rev-parse --short HEAD))"
if ! xcodebuild -project Tenure.xcodeproj -scheme Tenure \
  -configuration Release -derivedDataPath "$derived" -allowProvisioningUpdates \
  ${build_settings[@]+"${build_settings[@]}"} build >"$log" 2>&1; then
  grep -E "error:" "$log" | head -20 >&2 || true
  fail "xcodebuild (full log: $log)"
fi

app="$derived/Build/Products/Release/Tenure.app"
[ -d "$app" ] || fail "no app at $app"
plist="$app/Contents/Info.plist"
bundle_id=$(plutil -extract CFBundleIdentifier raw "$plist")
version=$(plutil -extract CFBundleShortVersionString raw "$plist")
build_number=$(plutil -extract CFBundleVersion raw "$plist")

step "check $bundle_id $version ($build_number)"
case $bundle_id in
  *.dev) fail "Release build carries the Debug bundle id $bundle_id" ;;
esac
codesign --verify --strict --deep "$app" 2>/dev/null || fail "code signature does not verify"
codesign -d --entitlements - --xml "$app" 2>/dev/null | grep -q "com.apple.security.app-sandbox" \
  || fail "App Sandbox entitlement missing"
if [ -z "$(plutil -extract GoogleClientID raw "$plist" 2>/dev/null || true)" ]; then
  echo "note  no Google client in this build: sync is off"
fi

if [ $build_only -eq 1 ]; then
  echo "done  built $app (not installed)"
  exit 0
fi

target="$dest/Tenure.app"
# Any running copy with this bundle id opens the same data file: quit it, wherever it was launched.
running() { [ -n "$(lsappinfo find bundleid="$bundle_id" 2>/dev/null)" ]; }
if running; then
  step "quit the running app"
  osascript -e "tell application id \"$bundle_id\" to quit" >/dev/null 2>&1 || true
  for _ in $(seq 1 20); do
    running || break
    sleep 0.5
  done
  running && fail "the app did not quit; quit it and run again"
fi

step "install to $target"
previous="$derived/previous.app"
staged="$dest/.Tenure.app.installing"
rm -rf "${staged:?}"
ditto "$app" "$staged"
if [ -d "$target" ]; then
  rm -rf "${previous:?}"
  mv "$target" "$previous"
fi
mv "$staged" "$target"

step "launch"
open "$target"
echo "done  installed $version ($build_number); previous copy, if any: $previous"
