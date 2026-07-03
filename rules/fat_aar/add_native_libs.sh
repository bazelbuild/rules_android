#!/bin/bash
# Adds native libraries to AAR in the correct jni/ARCH/*.so format.
#
# Why this script is needed:
# - Android native libraries are distributed in ZIP files with lib/ARCH/*.so structure
#   (e.g., lib/arm64-v8a/libnative.so, lib/armeabi-v7a/libnative.so)
# - The AAR format requires native libraries in jni/ARCH/*.so structure
#   (e.g., jni/arm64-v8a/libnative.so, jni/armeabi-v7a/libnative.so)
# - This script extracts native libs from ZIP files and converts them to the correct format
#
# The conversion is necessary for aar_import to properly recognize and use the native
# libraries when the fat AAR is consumed by other projects.
#
# Usage: add_native_libs.sh BASE_AAR FINAL_AAR TEMP_DIR NATIVE_ZIP1 [NATIVE_ZIP2 ...]

set -e

BASE_AAR="$(cd "$(dirname "$1")"; pwd)/$(basename "$1")"
FINAL_AAR="$(cd "$(dirname "$2")"; pwd)/$(basename "$2")"
TEMP_DIR="$3"
shift 3

ORIG_DIR="$(pwd)"

mkdir -p "$TEMP_DIR"
unzip -q "$BASE_AAR" -d "$TEMP_DIR"

cd "$TEMP_DIR"
mkdir -p jni

for native_zip in "$@"; do
    if [ -f "$ORIG_DIR/$native_zip" ] && [ -s "$ORIG_DIR/$native_zip" ]; then
        TEMP_EXTRACT=$(mktemp -d)
        unzip -q -o "$ORIG_DIR/$native_zip" -d "$TEMP_EXTRACT" 2>/dev/null || true
        # Convert lib/ARCH/*.so to jni/ARCH/*.so
        if [ -d "$TEMP_EXTRACT/lib" ]; then
            cp -r "$TEMP_EXTRACT/lib/"* jni/ 2>/dev/null || true
        fi
        rm -rf "$TEMP_EXTRACT"
    fi
done

zip -q -r "$FINAL_AAR" .
