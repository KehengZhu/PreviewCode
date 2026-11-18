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

# Keep exactly one copy: macOS finds and registers the build output too, and
# with two registered copies of an extension Quick Look may pick the wrong one
# (or none) and fall back to plain text. So unregister and delete the build.
lsregister=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister
for appex in "$app"/Contents/PlugIns/*.appex; do pluginkit -r "$appex" 2>/dev/null || true; done
"$lsregister" -u "$app" 2>/dev/null || true
rm -rf "$derived/Build/Products"

# The system drops the removed copy's extensions a moment later, by identifier,
# which can take the installed copy's with them. So register the installed
# copy after that, and check it took.
installed="/Applications/PreviewCode.app/Contents/PlugIns"
for attempt in 1 2 3 4 5; do
    sleep 2
    "$lsregister" -f /Applications/PreviewCode.app
    for appex in "$installed"/*.appex; do pluginkit -a "$appex"; done
    sleep 1
    found=$(pluginkit -m -A -D -v -p com.apple.quicklook.preview 2>/dev/null | grep -c "$installed" || true)
    [[ $found -ge 2 ]] && break
done
if [[ $found -lt 2 ]]; then
    echo "Warning: the Quick Look extensions did not register; run this script again." >&2
fi
qlmanage -r >/dev/null 2>&1 || true

echo "Installed /Applications/PreviewCode.app ($(defaults read /Applications/PreviewCode.app/Contents/Info.plist CFBundleShortVersionString))"
