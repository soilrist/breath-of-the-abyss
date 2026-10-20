#!/bin/sh
set -eu

PROJECT_DIR=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
GODOT_BIN=${GODOT_BIN:-/Applications/Godot.app/Contents/MacOS/Godot}
TEMPLATE="$HOME/Library/Application Support/Godot/export_templates/4.7.2.stable/macos.zip"
DESTINATION=${1:-<저장소>.app}
TEMP_DIR=$(mktemp -d /tmp/zero-study-rpg-build.XXXXXX)
trap 'rm -rf "$TEMP_DIR"' EXIT

test -f "$TEMPLATE"
unzip -q "$TEMPLATE" -d "$TEMP_DIR"
rm -rf "$DESTINATION.new"
mv "$TEMP_DIR/macos_template.app" "$DESTINATION.new"
DESTINATION="$DESTINATION.new"
rm -f "$DESTINATION/Contents/MacOS/godot_macos_debug.universal"
mv "$DESTINATION/Contents/MacOS/godot_macos_release.universal" "$DESTINATION/Contents/MacOS/ZeroStudyRPG"

sed -i '' '/\$liquid_glass_icon/d; /\$usage_descriptions/d; /\$additional_plist_content/d' "$DESTINATION/Contents/Info.plist"
sed -i '' 's/\$binary/ZeroStudyRPG/g; s/\$name/Zero Study RPG/g; s/\$bundle_identifier/com.example.zerostudyrpg/g; s/\$short_version/1.0/g; s/\$signature/ZSRP/g; s/\$version/1.0/g; s/\$platfbuild//g; s/\$platform/macosx/g; s/\$sdkver//g; s/\$sdkbuild//g; s/\$sdkname/macosx/g; s/\$xcodever//g; s/\$xcodebuild//g; s/\$copyright/Personal study project/g; s/\$min_version_arm64/11.0/g; s/\$min_version_x86_64/10.13/g; s/\$highres/<true\/>/g; s/\$app_category/games/g' "$DESTINATION/Contents/Info.plist"
plutil -lint "$DESTINATION/Contents/Info.plist"

"$GODOT_BIN" --headless --path "$PROJECT_DIR" --export-pack Mac "$DESTINATION/Contents/Resources/ZeroStudyRPG.pck" >/tmp/zero-study-rpg-pack.log 2>&1
codesign --force --deep --sign - "$DESTINATION"
codesign --verify --deep --strict "$DESTINATION"

test -x "$DESTINATION/Contents/MacOS/ZeroStudyRPG"
test -s "$DESTINATION/Contents/Resources/ZeroStudyRPG.pck"
FINAL_DESTINATION=${DESTINATION%.new}
rm -rf "$FINAL_DESTINATION"
mv "$DESTINATION" "$FINAL_DESTINATION"
echo "MACOS_BUILD_OK: $FINAL_DESTINATION"

"$FINAL_DESTINATION/Contents/MacOS/ZeroStudyRPG" >/tmp/zero-study-rpg-runtime.log 2>&1 &
RUNTIME_PID=$!
sleep 3
if kill -0 "$RUNTIME_PID" 2>/dev/null; then
	kill "$RUNTIME_PID"
	wait "$RUNTIME_PID" 2>/dev/null || true
	echo "MACOS_RUNTIME_OK"
else
	echo "MACOS_RUNTIME_FAIL: process exited early, see /tmp/zero-study-rpg-runtime.log" >&2
	exit 1
fi
