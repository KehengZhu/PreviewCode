#!/bin/zsh
# Build Quicklook Anything and publish it as a GitHub release, which the
# one-line installer (install.sh) downloads. Needs the GitHub CLI, logged in
# (`brew install gh && gh auth login`), and a clean, pushed checkout.
#
# Usage: Scripts/release.sh           (version comes from MARKETING_VERSION)
set -euo pipefail

cd "${0:A:h}/.."
repo=KehengZhu/QuicklookAnything

command -v gh >/dev/null || { echo "Install the GitHub CLI first: brew install gh && gh auth login" >&2; exit 1; }
[[ -z $(git status --porcelain) ]] || { echo "Commit your changes first." >&2; exit 1; }
git fetch -q origin
[[ $(git rev-parse HEAD) == $(git rev-parse origin/main) ]] || { echo "Push main to origin first." >&2; exit 1; }

Scripts/build.sh
zip=build/dist/QuicklookAnything.zip
version=$(unzip -p "$zip" "Quicklook Anything.app/Contents/Info.plist" | plutil -extract CFBundleShortVersionString raw -)

if gh release view "v$version" --repo "$repo" >/dev/null 2>&1; then
    echo "Release v$version exists; bump MARKETING_VERSION in the Xcode project first." >&2
    exit 1
fi
gh release create "v$version" "$zip" --repo "$repo" --target main \
    --title "Quicklook Anything $version" --generate-notes
echo "Released v$version. Friends get it by running the install command again."
