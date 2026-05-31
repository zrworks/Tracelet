#!/bin/bash
set -e

echo "Building iOS Rust Core and Sync (Tracelet)..."

# Ensure we are in the correct directory
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
cd "$DIR"

# Target architectures
TARGETS=("aarch64-apple-ios" "aarch64-apple-ios-sim")

# Add rust targets
for target in "${TARGETS[@]}"; do
    rustup target add "$target"
done

echo "Compiling for iOS targets..."
cargo build --release --target aarch64-apple-ios
cargo build --release --target aarch64-apple-ios-sim

echo "Creating XCFrameworks..."
OUT_DIR="out"
mkdir -p "$OUT_DIR"

# --- CORE FRAMEWORK ---
mkdir -p "$OUT_DIR/core/ios" "$OUT_DIR/core/sim"
cp target/aarch64-apple-ios-sim/release/libtracelet_core.a "$OUT_DIR/core/sim/libtracelet_core.a"
cp target/aarch64-apple-ios/release/libtracelet_core.a "$OUT_DIR/core/ios/libtracelet_core.a"

cargo run -p tracelet_core --features=uniffi/cli --bin uniffi-bindgen generate --library target/aarch64-apple-ios/release/libtracelet_core.a --language swift --out-dir "$OUT_DIR/core"

mkdir -p "$OUT_DIR/core/Headers"
cp "$OUT_DIR/core/tracelet_coreFFI.h" "$OUT_DIR/core/Headers/"
cp "$OUT_DIR/core/tracelet_coreFFI.modulemap" "$OUT_DIR/core/Headers/module.modulemap"

sed -i '' 's/module tracelet_coreFFI/module TraceletCore/g' "$OUT_DIR/core/Headers/module.modulemap"
sed -i '' 's/canImport(tracelet_coreFFI)/SWIFT_PACKAGE/g' "$OUT_DIR/core/tracelet_core.swift"
sed -i '' 's/import tracelet_coreFFI/import TraceletCore/g' "$OUT_DIR/core/tracelet_core.swift"

cp "$OUT_DIR/core/tracelet_core.swift" "../../sdk/ios/Sources/TraceletSDK/"
cp "$OUT_DIR/core/tracelet_coreFFI.h" "../../sdk/ios/Sources/TraceletSDK/"

DUMMY_SWIFT="$OUT_DIR/core/TraceletIosPlugin+FRBDummy.swift"
NM_OUTPUT=$(nm -g target/aarch64-apple-ios/release/libtracelet_core.a 2>/dev/null | grep -E " T _frb| T _store_dart" | awk '{print $3}' | sed 's/^_//' | sort | uniq)

echo "import Foundation" > "$DUMMY_SWIFT"
echo "" >> "$DUMMY_SWIFT"
for symbol in $NM_OUTPUT; do
    echo "@_silgen_name(\"$symbol\") func dummy_$symbol()" >> "$DUMMY_SWIFT"
done
echo "" >> "$DUMMY_SWIFT"
echo "public extension TraceletIosPlugin {" >> "$DUMMY_SWIFT"
echo "    func dummyMethodToEnforceBundling() {" >> "$DUMMY_SWIFT"
for symbol in $NM_OUTPUT; do
    echo "        dummy_$symbol()" >> "$DUMMY_SWIFT"
done
echo "    }" >> "$DUMMY_SWIFT"
echo "}" >> "$DUMMY_SWIFT"

cp "$DUMMY_SWIFT" "../../packages/tracelet_ios/ios/tracelet_ios/Sources/tracelet_ios/"

rm -rf "$OUT_DIR/TraceletCore.xcframework"
xcodebuild -create-xcframework \
    -library "$OUT_DIR/core/ios/libtracelet_core.a" -headers "$OUT_DIR/core/Headers" \
    -library "$OUT_DIR/core/sim/libtracelet_core.a" -headers "$OUT_DIR/core/Headers" \
    -output "$OUT_DIR/TraceletCore.xcframework"


# --- SYNC FRAMEWORK ---
mkdir -p "$OUT_DIR/sync/ios" "$OUT_DIR/sync/sim"
cp target/aarch64-apple-ios-sim/release/libtracelet_sync.a "$OUT_DIR/sync/sim/libtracelet_sync.a"
cp target/aarch64-apple-ios/release/libtracelet_sync.a "$OUT_DIR/sync/ios/libtracelet_sync.a"

cargo run -p tracelet_sync --features=uniffi/cli --bin uniffi-bindgen generate --library target/aarch64-apple-ios/release/libtracelet_sync.a --language swift --out-dir "$OUT_DIR/sync"

mkdir -p "$OUT_DIR/sync/Headers"
cp "$OUT_DIR/sync/tracelet_syncFFI.h" "$OUT_DIR/sync/Headers/"
cp "$OUT_DIR/sync/tracelet_syncFFI.modulemap" "$OUT_DIR/sync/Headers/module.modulemap"

sed -i '' 's/module tracelet_syncFFI/module TraceletSync/g' "$OUT_DIR/sync/Headers/module.modulemap"
sed -i '' 's/canImport(tracelet_syncFFI)/SWIFT_PACKAGE/g' "$OUT_DIR/sync/tracelet_sync.swift"
sed -i '' 's/import tracelet_syncFFI/import TraceletSync/g' "$OUT_DIR/sync/tracelet_sync.swift"

# (Sync framework files will be copied to their final destination by another script or during tracelet_sync setup)

rm -rf "$OUT_DIR/TraceletSync.xcframework"
xcodebuild -create-xcframework \
    -library "$OUT_DIR/sync/ios/libtracelet_sync.a" -headers "$OUT_DIR/sync/Headers" \
    -library "$OUT_DIR/sync/sim/libtracelet_sync.a" -headers "$OUT_DIR/sync/Headers" \
    -output "$OUT_DIR/TraceletSync.xcframework"


# --- SYMBOL VERIFICATION ---
echo "Verifying symbols for TraceletCore..."
if nm -gU "$OUT_DIR/TraceletCore.xcframework/ios-arm64/libtracelet_core.a" | grep -i 'reqwest'; then
    echo "❌ ERROR: Heavy dependencies leaked into TraceletCore!"
    exit 1
fi
echo "✅ TraceletCore symbol verification passed. No heavy dependencies found."

echo "✅ iOS build complete."
