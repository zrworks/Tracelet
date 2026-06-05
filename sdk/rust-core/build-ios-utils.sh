#!/bin/bash

# Generates a shallow iOS framework from a static library and its headers.
create_framework() {
    local NAME=$1
    local LIB=$2
    local HEADERS=$3
    local OUT=$4
    local PLATFORM=$5

    local FWK="$OUT/$NAME.framework"
    mkdir -p "$FWK/Headers"
    mkdir -p "$FWK/Modules"

    cp "$LIB" "$FWK/$NAME"
    cp "$HEADERS"/*.h "$FWK/Headers/"
    cp "$HEADERS"/module.modulemap "$FWK/Modules/module.modulemap"

    cat <<EOF > "$FWK/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>$NAME</string>
    <key>CFBundleIdentifier</key>
    <string>com.ikolvi.$NAME</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>$NAME</string>
    <key>CFBundlePackageType</key>
    <string>FMWK</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>MinimumOSVersion</key>
    <string>14.0</string>
</dict>
</plist>
EOF
}

# Generates dummy Swift methods for exported Rust symbols to prevent Dead Code Stripping in Xcode.
generate_dummy_symbols() {
    local LIB_PATH=$1
    local DUMMY_SWIFT_OUT=$2
    local EXTENSION_NAME=$3

    local NM_OUTPUT=""
    if [ "$EXTENSION_NAME" = "TraceletCore" ]; then
        NM_OUTPUT=$(nm -g "$LIB_PATH" 2>/dev/null | grep -E " T _frb| T _store_dart" | awk '{print $3}' | sed 's/^_//' | sort | uniq)
    fi

    echo "import Foundation" > "$DUMMY_SWIFT_OUT"
    echo "" >> "$DUMMY_SWIFT_OUT"
    for symbol in $NM_OUTPUT; do
        echo "@_silgen_name(\"$symbol\") func dummy_${EXTENSION_NAME}_$symbol()" >> "$DUMMY_SWIFT_OUT"
    done
    echo "" >> "$DUMMY_SWIFT_OUT"
    echo "public var _${EXTENSION_NAME}_dummy_sink: [Any] = []" >> "$DUMMY_SWIFT_OUT"
    echo "" >> "$DUMMY_SWIFT_OUT"
    echo "public struct ${EXTENSION_NAME}Dummy {" >> "$DUMMY_SWIFT_OUT"
    echo "    public static func enforceBundling() {" >> "$DUMMY_SWIFT_OUT"
    echo "        let dummyArray: [Any] = [" >> "$DUMMY_SWIFT_OUT"
    for symbol in $NM_OUTPUT; do
        echo "            dummy_${EXTENSION_NAME}_$symbol as Any," >> "$DUMMY_SWIFT_OUT"
    done
    echo "        ]" >> "$DUMMY_SWIFT_OUT"
    echo "        _${EXTENSION_NAME}_dummy_sink = dummyArray" >> "$DUMMY_SWIFT_OUT"
    echo "    }" >> "$DUMMY_SWIFT_OUT"
    echo "}" >> "$DUMMY_SWIFT_OUT"
}
