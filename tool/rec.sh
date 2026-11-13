#!/bin/bash
# Records the simulator and tiles the frames into one sheet, to judge motion.
#   tool/rec.sh OUT_DIR NAME SECONDS [FPS] [COLS] [SKIP_SECONDS]
D="${KEYSTONE_DEVICE:-44CDDB86-D61F-47C8-8C65-7C87828A38C5}"
OUT="$1"; NAME="$2"; SECS="${3:-4}"; FPS="${4:-10}"; COLS="${5:-10}"; SKIP="${6:-0}"
mkdir -p "$OUT"
xcrun simctl io "$D" recordVideo --codec h264 --force "$OUT/$NAME.mov" >/dev/null 2>&1 &
REC=$!
sleep "$SECS"
kill -INT $REC; wait $REC 2>/dev/null
ffmpeg -loglevel error -y -ss "$SKIP" -i "$OUT/$NAME.mov" \
  -vf "fps=$FPS,scale=150:-1,tile=${COLS}x4" -frames:v 1 "$OUT/$NAME.png"
