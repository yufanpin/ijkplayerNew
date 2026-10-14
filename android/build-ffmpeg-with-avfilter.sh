#! /usr/bin/env bash
#
# Build ijkffmpeg from source WITH avfilter filters enabled, then let the normal
# gradle step package the AAR.
#
# Two things block the stock pipeline on this fork:
#   1) the toolchain's prebuilt ijkffmpeg was configured with `--disable-filters`,
#      so no avfilter filter (volume / alimiter / dynaudnorm / ...) exists at
#      runtime -> we recompile ijkffmpeg from source with filters enabled.
#   2) the pinned soundtouch android release (soundtouch-2.3.3-250428092710) was
#      deleted upstream -> we repoint the tag at a release that still exists.

set -e

THIS_DIR=$(cd "$(dirname "$0")" && pwd)
cd "$THIS_DIR"

FFTC=../FFToolChain

# portable in-place sed: patch_file <file> <sed-expr>
patch_file() {
    if [ "$(uname)" = "Darwin" ]; then
        sed -i '' -e "$2" "$1"
    else
        sed -i -e "$2" "$1"
    fi
}

echo "=== fix deps: soundtouch android prebuilt tag was deleted upstream ==="
STCFG="$FFTC/configs/libs/soundtouch.sh"
patch_file "$STCFG" 's|^export PRE_COMPILE_TAG_ANDROID=.*|export PRE_COMPILE_TAG_ANDROID=soundtouch-2.4.1-260824190319|'
grep -n 'PRE_COMPILE_TAG_ANDROID' "$STCFG"

echo "=== install prebuilt deps (soundtouch + yuv) ==="
"$FFTC/main.sh" install -l 'soundtouch yuv' -p android

echo "=== enable avfilter filters in ijk ffmpeg config ==="
FFCFG="$FFTC/configs/ijk-ffmpeg-config/module-lite.sh"
patch_file "$FFCFG" '/--disable-filters/d'
if grep -q -- '--disable-filters' "$FFCFG"; then
    echo "!! failed to remove --disable-filters" >&2
    exit 1
fi
echo "[ok] --disable-filters removed -> all avfilter filters enabled"

echo "=== clone ffmpeg source ==="
"$FFTC/main.sh" init -p android -l ijkffmpeg

echo "=== compile ijkffmpeg from source with filters ==="
"$FFTC/main.sh" compile -p android -c build -l ijkffmpeg
