#!/bin/bash
set -e

echo "Building Android Rust Core (Tracelet)..."

# Ensure we are in the correct directory
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
cd "$DIR"

# Target architectures
TARGETS=("aarch64-linux-android" "armv7-linux-androideabi" "x86_64-linux-android")

# Output directory inside the Android project
OUT_DIR="../android/tracelet-sdk/src/main/jniLibs"

# Ensure cargo-ndk is installed
if ! command -v cargo-ndk &> /dev/null; then
    echo "Installing cargo-ndk..."
    cargo install cargo-ndk
fi

# Add rust targets
for target in "${TARGETS[@]}"; do
    rustup target add "$target"
done

# Build using cargo-ndk
echo "Compiling for Android targets..."
cargo ndk -t arm64-v8a -t armeabi-v7a -t x86_64 -o "$OUT_DIR" build --release

# Generate Kotlin bindings using uniffi-bindgen
echo "Generating Kotlin bindings..."
KOTLIN_OUT_DIR="../android/tracelet-sdk/src/main/kotlin/uniffi/tracelet_core"
TEMP_OUT="out"
mkdir -p "$TEMP_OUT"
cargo run --features=uniffi/cli --bin uniffi-bindgen generate --library target/aarch64-linux-android/release/libtracelet_core.so --language kotlin --out-dir "$TEMP_OUT"

# Copy generated Kotlin bindings to the Android SDK sources
mkdir -p "$KOTLIN_OUT_DIR"
cp "$TEMP_OUT/uniffi/tracelet_core/tracelet_core.kt" "$KOTLIN_OUT_DIR/"

echo "✅ Android build complete. Libraries placed in $OUT_DIR and Kotlin bindings placed in $KOTLIN_OUT_DIR"
