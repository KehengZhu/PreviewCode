#!/bin/zsh
# Quicklook Anything installer: installs the latest release, or upgrades an
# existing installation in place (settings are kept). The same command does both:
#
#   curl -fsSL https://raw.githubusercontent.com/KehengZhu/QuicklookAnything/main/install.sh | zsh
#
# Uninstall:
#
#   curl -fsSL https://raw.githubusercontent.com/KehengZhu/QuicklookAnything/main/install.sh | zsh -s -- --uninstall
#
# What it changes: it copies the app to /Applications (or ~/Applications when
# /Applications is not writable), registers its Quick Look extensions, and
# turns off other Quick Look extensions for Markdown and Jupyter notebooks (and
# the App Store PreviewCode's), noting which so --uninstall can turn them back
# on. It never changes which app opens a file type.
#
# Uses only tools that ship with macOS, so it works without Xcode, the command
# line tools or Homebrew.

# Everything runs from main(), called on the last line, so a download cut short
# by `curl | zsh` runs nothing.
main() {
    set -euo pipefail

    local name="Quicklook Anything"
    local bundle_id="io.github.kehengzhu.QuicklookAnything"
    local team="BTT85F79L9"
    local url="https://github.com/KehengZhu/QuicklookAnything/releases/latest/download/QuicklookAnything.zip"
    local state_dir="$HOME/Library/Application Support/$bundle_id"
    local state_file="$state_dir/disabled-extensions.txt"
    local lsregister=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister
    local extensions=(Code-Previewer Code-Thumbnailer Markdown-Previewer)

    local mode=install zip=""
    while (( $# )); do
        case $1 in
            --uninstall) mode=uninstall ;;
            --zip) zip=${2:?--zip needs a path}; shift ;;
            *) echo "Unknown option: $1" >&2; return 1 ;;
        esac
        shift
    done

    if [[ $EUID -eq 0 ]]; then
        echo "Run this as yourself, not with sudo: Quick Look extensions are registered per user." >&2
        return 1
    fi

    # Where an existing copy lives, if any
    local existing="" dir
    for dir in /Applications "$HOME/Applications"; do
        [[ -d "$dir/$name.app" ]] && { existing="$dir/$name.app"; break; }
    done

    if [[ $mode == uninstall ]]; then
        uninstall
        return
    fi

    local macos_major=${$(sw_vers -productVersion)%%.*}
    if (( macos_major < 13 )); then
        echo "$name needs macOS 13 (Ventura) or later; this Mac runs $(sw_vers -productVersion)." >&2
        return 1
    fi

    local tmp
    tmp=$(mktemp -d -t quicklook-anything)
    trap "rm -rf '$tmp'" EXIT

    if [[ -z $zip ]]; then
        echo "Downloading $name..."
        curl -fL --progress-bar -o "$tmp/app.zip" "$url"
        zip="$tmp/app.zip"
    fi

    # Check the download before touching the installed copy
    ditto -x -k "$zip" "$tmp/check"
    local new_app="$tmp/check/$name.app"
    [[ -d $new_app ]] || { echo "The download does not contain $name.app." >&2; return 1; }
    codesign --verify --deep --strict "$new_app" 2>/dev/null \
        || { echo "The download's code signature is not valid; nothing was installed." >&2; return 1; }
    [[ $(codesign -dv "$new_app" 2>&1 | sed -n 's/^TeamIdentifier=//p') == "$team" ]] \
        || { echo "The download is not signed by the expected developer; nothing was installed." >&2; return 1; }
    [[ $(plutil -extract CFBundleIdentifier raw "$new_app/Contents/Info.plist") == "$bundle_id" ]] \
        || { echo "The download is not $name; nothing was installed." >&2; return 1; }
    local new_version
    new_version=$(plutil -extract CFBundleShortVersionString raw "$new_app/Contents/Info.plist")
    rm -rf "$tmp/check"

    local dest
    if [[ -n $existing ]]; then
        dest=$existing
        local old_version
        old_version=$(plutil -extract CFBundleShortVersionString raw "$dest/Contents/Info.plist" 2>/dev/null || echo "?")
        if [[ $old_version == "$new_version" ]]; then
            echo "Reinstalling $name $new_version in ${dest:h}..."
        else
            echo "Upgrading $name $old_version -> $new_version in ${dest:h}..."
        fi
    else
        if [[ -w /Applications ]]; then dest="/Applications/$name.app"
        else mkdir -p "$HOME/Applications"; dest="$HOME/Applications/$name.app"; fi
        echo "Installing $name $new_version in ${dest:h}..."
    fi

    # Quit the app and its extensions so Quick Look loads the new build
    pkill -x "$name" 2>/dev/null || true
    pkill -f "$name.app/Contents/PlugIns" 2>/dev/null || true

    remove_legacy_build

    rm -rf "$dest"
    ditto -x -k "$zip" "${dest:h}"

    # Register the installed copy. When another copy of the app was just removed
    # (an upgrade, or build.sh's build output), the system drops that copy's
    # extensions a moment later by identifier, which can take these with them;
    # so register again until all of them stick.
    local attempt found ext
    for attempt in 1 2 3 4 5; do
        "$lsregister" -f -R "$dest"
        for ext in "$dest"/Contents/PlugIns/*.appex; do pluginkit -a "$ext"; done
        sleep 2
        found=0
        for ext in $extensions; do
            pluginkit -m -v -i "$bundle_id.$ext" 2>/dev/null | grep -qF "$dest/" && (( found += 1 ))
        done
        (( found == ${#extensions} )) && break
    done
    if (( found < ${#extensions} )); then
        echo "Warning: the Quick Look extensions did not register; run the install command again." >&2
    fi

    # A first install turns the extensions on; an upgrade keeps the user's choice
    if [[ -z $existing ]]; then
        for ext in $extensions; do pluginkit -e use -i "$bundle_id.$ext" 2>/dev/null || true; done
    fi

    disable_competitors

    qlmanage -r >/dev/null 2>&1 || true
    qlmanage -r cache >/dev/null 2>&1 || true

    echo
    echo "Done: $name $new_version is installed in ${dest:h}."
    echo "Select a code file, Markdown note or notebook in Finder and press Space."
    echo "Settings: open $name from Applications. To upgrade later, run the same command again."
}


# Turn off other Quick Look extensions that would compete with ours: any that
# preview Markdown or Jupyter notebooks, and the App Store PreviewCode's. Each one
# turned off is noted in the state file, for --uninstall.
disable_competitors() {
    local point line flag id appex types
    mkdir -p "$state_dir"
    touch "$state_file"
    for point in com.apple.quicklook.preview com.apple.quicklook.thumbnail; do
        pluginkit -m -A -D -v -p "$point" 2>/dev/null | while IFS=$'\t' read -r line _ _ appex; do
            flag=${line[1]}
            id=${${line[2,-1]//[[:space:]]/}%%\(*}
            [[ -z $id || $id == "$bundle_id".* || $flag == "-" ]] && continue
            if [[ $id == com.bps.PreviewCode.* ]]; then
                :
            else
                types=$(/usr/libexec/PlistBuddy -c "Print :NSExtension:NSExtensionAttributes:QLSupportedContentTypes" \
                        "$appex/Contents/Info.plist" 2>/dev/null || true)
                print -r -- "$types" | grep -qiE "markdown|ipynb" || continue
            fi
            if pluginkit -e ignore -i "$id" 2>/dev/null; then
                grep -qxF "$id" "$state_file" || print -r -- "$id" >> "$state_file"
                echo "Turned off a competing Quick Look extension: $id"
            fi
        done
    done
}


# Remove an old build of this app made under its former name (PreviewCode built
# from source by this project's author); the App Store PreviewCode is left alone.
remove_legacy_build() {
    local old
    for old in /Applications/PreviewCode.app "$HOME/Applications/PreviewCode.app"; do
        [[ -d $old && ! -e $old/Contents/_MASReceipt ]] || continue
        [[ $(codesign -dv "$old" 2>&1 | sed -n 's/^TeamIdentifier=//p') == "$team" ]] || continue
        local ext
        pkill -f "PreviewCode.app/Contents/PlugIns" 2>/dev/null || true
        for ext in "$old"/Contents/PlugIns/*.appex; do pluginkit -r "$ext" 2>/dev/null || true; done
        "$lsregister" -u "$old" 2>/dev/null || true
        rm -rf "$old"
        echo "Removed the old build $old (now $name)."
    done
}


uninstall() {
    if [[ -z $existing ]]; then
        echo "$name is not installed."
    else
        local ext
        pkill -x "$name" 2>/dev/null || true
        pkill -f "$name.app/Contents/PlugIns" 2>/dev/null || true
        for ext in "$existing"/Contents/PlugIns/*.appex; do pluginkit -r "$ext" 2>/dev/null || true; done
        "$lsregister" -u "$existing" 2>/dev/null || true
        rm -rf "$existing"
        echo "Removed $existing."
    fi

    if [[ -s $state_file ]]; then
        local id
        while read -r id; do
            [[ -n $id ]] && pluginkit -e use -i "$id" 2>/dev/null && echo "Turned back on: $id"
        done < "$state_file"
    fi
    rm -rf "$state_dir"
    qlmanage -r >/dev/null 2>&1 || true
    qlmanage -r cache >/dev/null 2>&1 || true
    echo "Your preview settings stay in ~/Library/Group Containers/$team.suite.preview-code; delete that folder to remove them too."
}


main "$@"
