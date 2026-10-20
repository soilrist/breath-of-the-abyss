#!/bin/sh
# 웹 빌드를 로컬에서 띄운다. 스레드를 끈 빌드라 특별한 헤더 없이도 돈다.
set -eu
PROJECT_DIR=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
PORT=${PORT:-8060}
cd "$PROJECT_DIR/build/web"
echo "http://localhost:$PORT/index.html"
exec python3 -m http.server "$PORT"
