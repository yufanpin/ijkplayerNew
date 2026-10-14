#! /usr/bin/env bash
#
# Build ijkffmpeg from source WITH avfilter filters enabled.
#
# The toolchain "install" step downloads a prebuilt ijkffmpeg whose ffmpeg was
# configured with `--disable-filters`, so no avfilter filter (volume, alimiter,
# dynaudnorm, ...) exists at runtime. This script patches the toolchain ffmpeg
# config and recompiles ijkffmpeg from source so the `af` player option works.

set -e

THIS_DIR=$(cd "$(dirname "$0")" && pwd)
cd "$THIS_DIR"

FFTC=../FFToolChain

echo "=== install prebuilt deps (same set as install-ffmpeg.sh: soundtouch + yuv) ==="
"$FFTC/main.sh" install -l 'soundtouch yuv' -p android

echo "=== enable avfilter filters in ijk ffmpeg config ==="
FFCFG="$FFTC/configs/ijk-ffmpeg-config/module-lite.sh"
if [ "$(uname)" = "Darwin" ]; then
    sed -i '' -e '/--disable-filters/d' "$FFCFG"
else
    sed -i -e '/--disable-filters/d' "$FFCFG"
fi
if grep -q -- '--disable-filters' "$FFCFG"; then
    echo "!! failed to remove --disable-filters" >&2
    exit 1
fi
echo "[ok] --disable-filters removed -> all avfilter filters enabled"

echo "=== clone ffmpeg source ==="
"$FFTC/main.sh" init -p android -l ijkffmpeg

echo "=== compile ijkffmpeg from source with filters ==="
"$FFTC/main.sh" compile -p android -c build -l ijkffmpeg
