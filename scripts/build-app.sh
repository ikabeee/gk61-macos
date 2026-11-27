#!/usr/bin/env bash
# Builds GK61 in release mode and packages it as build/GK61.app, signed with the local identity.
# Set SCRATCH_PATH to use a SwiftPM build directory other than .build.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
app="$repo_root/build/GK61.app"
swift_build=(swift build --package-path "$repo_root" -c release --product GK61)
if [[ -n "${SCRATCH_PATH:-}" ]]; then
    swift_build+=(--scratch-path "$SCRATCH_PATH")
fi

main() {
    build_release
    assemble_bundle "$("${swift_build[@]}" --show-bin-path)"
    codesign --force --deep --sign "$(signing_identity)" "$app"
    echo "Built $app"
}

# A stable identity keeps the Input Monitoring grant across rebuilds; ad-hoc ("-") loses it every build.
signing_identity() {
    local identity="GK61 Local Signing"
    if security find-certificate -c "$identity" >/dev/null 2>&1; then
        echo "$identity"
    else
        echo "warning: \"$identity\" not found; signing ad-hoc. Run scripts/create-signing-identity.sh." >&2
        echo "-"
    fi
}

build_release() {
    "${swift_build[@]}"
}

assemble_bundle() {
    local bin_path="$1"
    rm -rf "$app"
    mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
    cp "$bin_path/GK61" "$app/Contents/MacOS/GK61"
    # SwiftPM's Bundle.module looks in Bundle.main.resourceURL (Contents/Resources) inside an app.
    local bundle
    for bundle in "$bin_path"/*.bundle; do
        [[ -e "$bundle" ]] && cp -R "$bundle" "$app/Contents/Resources/"
    done
    write_info_plist "$app/Contents/Info.plist"
}

write_info_plist() {
    cat >"$1" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>GK61</string>
    <key>CFBundleIdentifier</key>
    <string>local.gk61.config</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>GK61</string>
    <key>CFBundleDisplayName</key>
    <string>GK61</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>0.1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.utilities</string>
    <key>LSMinimumSystemVersion</key>
    <string>15.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
PLIST
}

main "$@"
