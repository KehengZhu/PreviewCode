#!/bin/zsh
# Build a universal (Apple silicon + Intel) Release of Quicklook Anything and zip
# it to build/dist/QuicklookAnything.zip, the file install.sh downloads.
#
# Signs with the local "Apple Development" certificate (team BTT85F79L9) and no
# provisioning profile, so the build never expires weekly; only the certificate
# (valid until 2027-11-15) needs renewing, by reopening Xcode > Settings > Accounts.
#
# Usage: Scripts/build.sh
set -euo pipefail

cd "${0:A:h}/.."
derived=build/DerivedData
dist=build/dist
log=$(mktemp -t quicklook-anything-build)

# A failed codesign can leave *.cstemp files that break every later signing run.
rm -rf "$derived/Build/Products"

echo "Building (log: $log)..."
if ! xcodebuild -scheme "Quicklook Anything" -configuration Release -derivedDataPath "$derived" \
    ONLY_ACTIVE_ARCH=NO \
    DEVELOPMENT_TEAM=BTT85F79L9 CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY="Apple Development" \
    PROVISIONING_PROFILE_SPECIFIER="" PROVISIONING_PROFILE="" \
    build > "$log" 2>&1; then
    grep -E "error:|\*\* BUILD" "$log" | sort -u
    exit 1
fi

app="$derived/Build/Products/Release/Quicklook Anything.app"
codesign --verify --deep --strict "$app"
lipo -archs "$app/Contents/MacOS/Quicklook Anything"

mkdir -p "$dist"
rm -f "$dist/QuicklookAnything.zip"
ditto -c -k --keepParent "$app" "$dist/QuicklookAnything.zip"

# macOS registers the build output as soon as it appears, and with two
# registered copies of an extension Quick Look may pick the wrong one (or none).
# So unregister and delete the build; install.sh registers the installed copy.
lsregister=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister
for appex in "$app"/Contents/PlugIns/*.appex; do pluginkit -r "$appex" 2>/dev/null || true; done
"$lsregister" -u "$app" 2>/dev/null || true
rm -rf "$derived/Build/Products"

echo "Built $dist/QuicklookAnything.zip ($(unzip -p "$dist/QuicklookAnything.zip" "Quicklook Anything.app/Contents/Info.plist" | plutil -extract CFBundleShortVersionString raw -))"
