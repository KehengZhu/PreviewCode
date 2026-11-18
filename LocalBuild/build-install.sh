#!/bin/zsh
# Build PreviewCode from this checkout and install it to /Applications.
#
# Signs with the local "Apple Development" certificate (team BTT85F79L9) and no
# provisioning profile, so the build never expires weekly; only the certificate
# (valid until 2027-11-15) needs renewing, by reopening Xcode > Settings > Accounts.
#
# Usage: LocalBuild/build-install.sh
set -euo pipefail

cd "${0:A:h}/.."
derived=LocalBuild/DerivedData
log=$(mktemp -t previewcode-build)

# A failed codesign can leave *.cstemp files that break every later signing run.
rm -rf "$derived/Build/Products"

echo "Building (log: $log)..."
if ! xcodebuild -scheme PreviewCode -configuration Release -derivedDataPath "$derived" \
    ARCHS=arm64 ONLY_ACTIVE_ARCH=YES \
    DEVELOPMENT_TEAM=BTT85F79L9 CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY="Apple Development" \
    PROVISIONING_PROFILE_SPECIFIER="" PROVISIONING_PROFILE="" \
    build > "$log" 2>&1; then
    grep -E "error:|\*\* BUILD" "$log" | sort -u
    exit 1
fi

app="$derived/Build/Products/Release/PreviewCode.app"
codesign --verify --deep --strict "$app"

# Quit running extension processes so Quick Look loads the new build.
pkill -f "PreviewCode.app/Contents/PlugIns" 2>/dev/null || true
rm -rf /Applications/PreviewCode.app
ditto "$app" /Applications/PreviewCode.app
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f /Applications/PreviewCode.app
qlmanage -r >/dev/null 2>&1 || true

echo "Installed /Applications/PreviewCode.app ($(defaults read /Applications/PreviewCode.app/Contents/Info.plist CFBundleShortVersionString))"
