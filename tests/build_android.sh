#!/bin/sh
# Android APK 로 내보낸다.
# 릴리스 서명용 keystore가 없으므로 디버그 APK로 검증한다(디버그 서명은
# Godot 에디터 설정(export/android/debug_keystore)의 debug.keystore로 자동 서명됨).
# JAVA_HOME/ANDROID_HOME이 비어 있으면 로컬 설치본(~/android-toolchain)을 기본값으로 쓴다.
set -eu

PROJECT_DIR=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
GODOT_BIN=${GODOT_BIN:-/Applications/Godot.app/Contents/MacOS/Godot}
export JAVA_HOME=${JAVA_HOME:-$HOME/android-toolchain/jdk-17.0.20.1+1/Contents/Home}
export ANDROID_HOME=${ANDROID_HOME:-$HOME/android-toolchain/sdk}
export PATH="$JAVA_HOME/bin:$ANDROID_HOME/platform-tools:$PATH"
OUT="$PROJECT_DIR/build/ZeroStudyRPG_debug.apk"

test -d "$JAVA_HOME"
test -d "$ANDROID_HOME"
mkdir -p "$PROJECT_DIR/build"
rm -f "$OUT"

"$GODOT_BIN" --headless --path "$PROJECT_DIR" --export-debug "Android" "$OUT"
test -f "$OUT"
unzip -l "$OUT" | grep -q "classes.dex"
unzip -l "$OUT" | grep -q "AndroidManifest.xml"
echo "ANDROID_BUILD_OK: $OUT"
