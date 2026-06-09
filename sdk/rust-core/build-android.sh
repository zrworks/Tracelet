#!/bin/bash
set -e

echo "Building Android Rust Core (Tracelet)..."

# Ensure we are in the correct directory
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
cd "$DIR"

# Target architectures
TARGETS=("aarch64-linux-android" "armv7-linux-androideabi" "x86_64-linux-android")

# Output directories inside the Android project
OUT_DIR_CORE="../android/tracelet-sdk/src/main/jniLibs"
OUT_DIR_SYNC="../android/tracelet-sync-sdk/src/main/jniLibs"

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
# Use a temporary directory for cargo-ndk output so we can split them
TEMP_JNI="target/jniLibs"
cargo ndk -t arm64-v8a -t armeabi-v7a -t x86_64 -o "$TEMP_JNI" build --release

# Distribute .so files to their respective modules
echo "Distributing libraries..."
mkdir -p "$OUT_DIR_CORE" "$OUT_DIR_SYNC"
for arch in arm64-v8a armeabi-v7a x86_64; do
    mkdir -p "$OUT_DIR_CORE/$arch" "$OUT_DIR_SYNC/$arch"
    cp "$TEMP_JNI/$arch/libtracelet_core.so" "$OUT_DIR_CORE/$arch/"
    cp "$TEMP_JNI/$arch/libtracelet_sync.so" "$OUT_DIR_SYNC/$arch/"
done

# Generate Kotlin bindings using uniffi-bindgen
echo "Generating Kotlin bindings for core..."
KOTLIN_OUT_DIR_CORE="../android/tracelet-sdk/src/main/kotlin/uniffi/tracelet_core"
TEMP_OUT="out"
mkdir -p "$TEMP_OUT"
cargo run -p tracelet_core --features=uniffi/cli --bin uniffi-bindgen generate --library target/aarch64-linux-android/release/libtracelet_core.so --language kotlin --out-dir "$TEMP_OUT"

# Copy generated Kotlin bindings to the Android SDK sources
mkdir -p "$KOTLIN_OUT_DIR_CORE"
cp "$TEMP_OUT/uniffi/tracelet_core/tracelet_core.kt" "$KOTLIN_OUT_DIR_CORE/"

echo "Generating Kotlin bindings for sync..."
KOTLIN_OUT_DIR_SYNC="../android/tracelet-sync-sdk/src/main/kotlin/uniffi/tracelet_sync"
cargo run -p tracelet_sync --features=uniffi/cli --bin sync-uniffi-bindgen generate --library target/aarch64-linux-android/release/libtracelet_sync.so --language kotlin --out-dir "$TEMP_OUT"

mkdir -p "$KOTLIN_OUT_DIR_SYNC"
cp "$TEMP_OUT/uniffi/tracelet_sync/tracelet_sync.kt" "$KOTLIN_OUT_DIR_SYNC/"

# Surface sccache effectiveness (compile requests / cache hits / misses). Guarded
# so local builds without sccache still succeed under `set -e`.
command -v sccache >/dev/null 2>&1 && sccache --show-stats || true

echo "✅ Android build complete. Libraries placed in $OUT_DIR_CORE and $OUT_DIR_SYNC, Kotlin bindings placed in main/kotlin/uniffi"
