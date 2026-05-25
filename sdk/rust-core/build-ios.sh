#!/bin/bash
set -e

echo "Building iOS Rust Core (Tracelet)..."

# Ensure we are in the correct directory
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
cd "$DIR"

# Target architectures
TARGETS=("aarch64-apple-ios" "aarch64-apple-ios-sim" "x86_64-apple-ios")

# Add rust targets
for target in "${TARGETS[@]}"; do
    rustup target add "$target"
done

echo "Compiling for iOS targets..."
cargo build --release --target aarch64-apple-ios
cargo build --release --target aarch64-apple-ios-sim
cargo build --release --target x86_64-apple-ios

echo "Creating XCFramework..."
OUT_DIR="out"
mkdir -p "$OUT_DIR"

# Lipo the simulator architectures together
mkdir -p "$OUT_DIR/ios" "$OUT_DIR/sim"
lipo -create \
    target/aarch64-apple-ios-sim/release/libtracelet_core.a \
    target/x86_64-apple-ios/release/libtracelet_core.a \
    -output "$OUT_DIR/sim/libtracelet_core.a"

cp target/aarch64-apple-ios/release/libtracelet_core.a "$OUT_DIR/ios/libtracelet_core.a"

# Generate Swift bindings if they don't exist
cargo run --features=uniffi/cli --bin uniffi-bindgen generate --library target/aarch64-apple-ios/release/libtracelet_core.a --language swift --out-dir "$OUT_DIR"

# Move headers to a clean directory
mkdir -p "$OUT_DIR/Headers"
cp "$OUT_DIR/tracelet_coreFFI.h" "$OUT_DIR/Headers/"
cp "$OUT_DIR/tracelet_coreFFI.modulemap" "$OUT_DIR/Headers/module.modulemap"

# Remove old XCFramework
rm -rf "$OUT_DIR/TraceletCore.xcframework"

# Build new XCFramework
xcodebuild -create-xcframework \
    -library "$OUT_DIR/ios/libtracelet_core.a" -headers "$OUT_DIR/Headers" \
    -library "$OUT_DIR/sim/libtracelet_core.a" -headers "$OUT_DIR/Headers" \
    -output "$OUT_DIR/TraceletCore.xcframework"

echo "✅ iOS build complete. XCFramework placed in $OUT_DIR/TraceletCore.xcframework"
