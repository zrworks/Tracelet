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

echo "✅ Android build complete. Libraries placed in $OUT_DIR"
