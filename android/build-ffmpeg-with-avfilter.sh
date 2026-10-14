#! /usr/bin/env bash
#
# Build a fresh, avfilter-enabled ijkffmpeg (plus the openssl it links against),
# then let the stock gradle step package the AAR.
#
# Why this script exists:
#   1) the toolchain's prebuilt ijkffmpeg was configured with `--disable-filters`,
#      so no avfilter filter (volume / alimiter / dynaudnorm / ...) exists at
#      runtime -> recompile ijkffmpeg from source with filters enabled.
#   2) the android prebuilt tags pinned by this toolchain revision were deleted
#      upstream (soundtouch-2.3.3-250428092710, yuv-stable-eb6e7bb-250310112252)
#      -> repoint them at releases that still exist.
#   3) ijkplayer's CMakeLists unconditionally links openssl (libcrypto.a/libssl.a)
#      and ijkffmpeg.sh auto-adds --enable-openssl when an openssl.pc is present
#      in the product dir, but install-ffmpeg.sh never installs openssl
#      -> build openssl from source so both the link and https survive.

set -e

THIS_DIR=$(cd "$(dirname "$0")" && pwd)
cd "$THIS_DIR"

FFTC=../FFToolChain
PRODUCT="$FFTC/build/product/android/universal"

patch_file() {
    if [ "$(uname)" = "Darwin" ]; then
        sed -i '' -e "$2" "$1"
    else
        sed -i -e "$2" "$1"
    fi
}

echo "=== 1/5 repoint upstream-deleted android prebuilt tags ==="
STCFG="$FFTC/configs/libs/soundtouch.sh"
patch_file "$STCFG" 's|^export PRE_COMPILE_TAG_ANDROID=.*|export PRE_COMPILE_TAG_ANDROID=soundtouch-2.4.1-260824190319|'
UVCFG="$FFTC/configs/libs/yuv.sh"
patch_file "$UVCFG" 's|^export PRE_COMPILE_TAG_ANDROID=.*|export PRE_COMPILE_TAG_ANDROID=yuv-main-f94b8cf7-260824190103|'
grep -n 'PRE_COMPILE_TAG_ANDROID' "$STCFG" "$UVCFG"

echo "=== 2/5 install prebuilt deps (soundtouch + yuv) ==="
"$FFTC/main.sh" install -l 'soundtouch yuv' -p android

echo "=== 3/5 build openssl from source (CMake links libcrypto.a/libssl.a) ==="
"$FFTC/main.sh" init    -p android -l openssl3
"$FFTC/main.sh" compile -p android -c build -l openssl3

echo "=== 4/5 enable avfilter filters in ijk ffmpeg config ==="
FFCFG="$FFTC/configs/ijk-ffmpeg-config/module-lite.sh"
patch_file "$FFCFG" '/--disable-filters/d'
if grep -q -- '--disable-filters' "$FFCFG"; then
    echo "!! failed to remove --disable-filters" >&2
    exit 1
fi
grep -n -- '--enable-avfilter' "$FFCFG" || echo "[warn] --enable-avfilter not found"
echo "[ok] --disable-filters removed -> avfilter filters enabled"

echo "=== 5/5 build ijkffmpeg from source (filters + openssl) ==="
"$FFTC/main.sh" init    -p android -l ijkffmpeg
"$FFTC/main.sh" compile -p android -c build -l ijkffmpeg

echo "=== product tree (what the CMake will find under third-libs) ==="
find "$PRODUCT" -maxdepth 3 -type d 2>/dev/null | sort || true
for lib in ijkffmpeg openssl yuv soundtouch; do
    echo "--- $lib ---"
    ls -la "$PRODUCT/$lib" 2>/dev/null || echo "!! missing $lib"
done
