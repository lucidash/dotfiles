#!/bin/bash
#
# Lock / Logout / Restart / Shutdown / Sleep 5종 앱을 유니버설(arm64 + x86_64)로 빌드한다.
#
# 산출물: build/*.app
#
set -euo pipefail

cd "$(dirname "$0")"

VERSION="2.0"
BUILD_NUMBER="1"
MIN_MACOS="11.0"
BUNDLE_PREFIX="local.sysaction"
COPYRIGHT="Intel 전용 com.siong1987 5종 세트의 유니버설 대체 구현"

BUILD_DIR="build"
WORK_DIR="$BUILD_DIR/.work"

# 앱 이름 : SAAction : SF Symbol : 아이콘 색상
APPS=(
  "Lock:lock:lock.fill:2C6FD8"
  "Sleep:sleep:moon.fill:5A4FCF"
  "Logout:logout:rectangle.portrait.and.arrow.right:0F9B8E"
  "Restart:restart:arrow.clockwise:E08A1E"
  "Shutdown:shutdown:power:D0342C"
)

rm -rf "$BUILD_DIR"
mkdir -p "$WORK_DIR"

# ── 1. 유니버설 바이너리 ────────────────────────────────────────────────
echo "==> SystemAction 컴파일 (arm64 + x86_64)"
for arch in arm64 x86_64; do
  swiftc -O -whole-module-optimization \
         -target "${arch}-apple-macos${MIN_MACOS}" \
         -o "$WORK_DIR/SystemAction-$arch" \
         Sources/main.swift
done
lipo -create -output "$WORK_DIR/SystemAction" \
     "$WORK_DIR/SystemAction-arm64" "$WORK_DIR/SystemAction-x86_64"
strip -x "$WORK_DIR/SystemAction"
echo "    $(lipo -archs "$WORK_DIR/SystemAction") / $(stat -f%z "$WORK_DIR/SystemAction") bytes"

# ── 2. 아이콘 ──────────────────────────────────────────────────────────
echo "==> 아이콘 생성"
swiftc -O -o "$WORK_DIR/make-icons" Tools/make-icons.swift

icon_specs=()
for entry in "${APPS[@]}"; do
  IFS=: read -r name _ symbol color <<< "$entry"
  icon_specs+=("$name:$symbol:$color")
done
mkdir -p "$WORK_DIR/png"
"$WORK_DIR/make-icons" "$WORK_DIR/png" "${icon_specs[@]}"

for entry in "${APPS[@]}"; do
  IFS=: read -r name _ _ _ <<< "$entry"
  iconset="$WORK_DIR/$name.iconset"
  mkdir -p "$iconset"
  for pair in "16 16x16" "32 16x16@2x" "32 32x32" "64 32x32@2x" \
              "128 128x128" "256 128x128@2x" "256 256x256" "512 256x256@2x" \
              "512 512x512" "1024 512x512@2x"; do
    read -r px label <<< "$pair"
    sips -z "$px" "$px" "$WORK_DIR/png/$name.png" \
         --out "$iconset/icon_$label.png" >/dev/null
  done
  iconutil -c icns "$iconset" -o "$WORK_DIR/$name.icns"
done

# ── 3. 번들 조립 ───────────────────────────────────────────────────────
echo "==> 앱 번들 조립"
for entry in "${APPS[@]}"; do
  IFS=: read -r name action _ _ <<< "$entry"
  app="$BUILD_DIR/$name.app"

  mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
  cp "$WORK_DIR/SystemAction" "$app/Contents/MacOS/SystemAction"
  cp "$WORK_DIR/$name.icns"   "$app/Contents/Resources/AppIcon.icns"
  printf 'APPL????' > "$app/Contents/PkgInfo"

  cat > "$app/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleName</key>                  <string>$name</string>
	<key>CFBundleDisplayName</key>           <string>$name</string>
	<key>CFBundleExecutable</key>            <string>SystemAction</string>
	<key>CFBundleIdentifier</key>            <string>$BUNDLE_PREFIX.$name</string>
	<key>CFBundleIconFile</key>              <string>AppIcon</string>
	<key>CFBundlePackageType</key>           <string>APPL</string>
	<key>CFBundleShortVersionString</key>    <string>$VERSION</string>
	<key>CFBundleVersion</key>               <string>$BUILD_NUMBER</string>
	<key>CFBundleInfoDictionaryVersion</key> <string>6.0</string>
	<key>CFBundleDevelopmentRegion</key>     <string>en</string>
	<key>LSMinimumSystemVersion</key>        <string>$MIN_MACOS</string>
	<key>LSApplicationCategoryType</key>     <string>public.app-category.utilities</string>
	<key>LSUIElement</key>                   <true/>
	<key>NSAppleEventsUsageDescription</key> <string>시스템에 $name 동작을 요청합니다.</string>
	<key>NSHumanReadableCopyright</key>      <string>$COPYRIGHT</string>
	<key>SAAction</key>                      <string>$action</string>
</dict>
</plist>
PLIST

  codesign --force --sign - --timestamp=none "$app" >/dev/null 2>&1
  printf "    %-12s %-9s %s\n" "$name.app" "$action" "$(lipo -archs "$app/Contents/MacOS/SystemAction")"
done

rm -rf "$WORK_DIR"
echo
echo "완료: $(pwd)/$BUILD_DIR"
