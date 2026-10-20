#!/bin/sh
# 웹으로 내보낸다. 브라우저에서 바로 확인할 수 있어 모바일 조작 검증에 편하다.
set -eu

PROJECT_DIR=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
GODOT_BIN=${GODOT_BIN:-/Applications/Godot.app/Contents/MacOS/Godot}
OUT_DIR="$PROJECT_DIR/build/web"

mkdir -p "$OUT_DIR"
"$GODOT_BIN" --headless --path "$PROJECT_DIR" --export-release "Web" "$OUT_DIR/index.html"
test -f "$OUT_DIR/index.html"
test -s "$OUT_DIR/index.pck"
test -s "$OUT_DIR/index.wasm"
test -s "$OUT_DIR/index.js"
if grep -q 'canvas' "$OUT_DIR/index.html" && grep -q 'engine.startGame' "$OUT_DIR/index.html"; then
	echo "WEB_RUNTIME_OK"
else
	echo "WEB_RUNTIME_FAIL: index.html missing canvas/engine.startGame markers" >&2
	exit 1
fi
echo "WEB_BUILD_OK: $OUT_DIR/index.html"
echo "확인: cd $OUT_DIR && python3 -m http.server 8060"
