#!/bin/bash
# 生成可立即实机验收的 ad-hoc 测试包。
# 正式分发仍必须使用 package.sh + 固定 RemoKey Dev 证书；本包换版本后可能需要重新授予 TCC 权限。

set -euo pipefail
cd "$(dirname "$0")/.."

DIST="dist"
APP="$DIST/RemoKey-Test.app"
BUNDLE_ID="com.remokey.controller"
SHORT_VERSION="$(git describe --tags --always --dirty 2>/dev/null || echo test)"
BUILD_VERSION="$(git rev-list --count HEAD 2>/dev/null || echo 1)"

echo "-- 构建 release 测试二进制"
RELEASE=1 ./build.sh
.build/miremote --self-test >/dev/null

echo "-- 组装 $APP"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
sed -e "s/@SHORT_VERSION@/$SHORT_VERSION-test/" \
    -e "s/@BUILD_VERSION@/$BUILD_VERSION/" \
    Resources/Info-app.plist > "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleDisplayName RemoKey Test" "$APP/Contents/Info.plist"
plutil -lint "$APP/Contents/Info.plist" >/dev/null
cp .build/miremote "$APP/Contents/MacOS/miremote"
chmod +x "$APP/Contents/MacOS/miremote"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
cp -R Resources/en.lproj Resources/zh-Hans.lproj "$APP/Contents/Resources/"
plutil -replace CFBundleDisplayName -string "RemoKey Test" "$APP/Contents/Resources/en.lproj/InfoPlist.strings"
plutil -replace CFBundleDisplayName -string "遥键测试版" "$APP/Contents/Resources/zh-Hans.lproj/InfoPlist.strings"

echo "-- ad-hoc 签名（仅限本轮测试）"
codesign --force --identifier "$BUNDLE_ID" --sign - "$APP"
codesign --verify --strict "$APP"

ZIP="$DIST/RemoKey-Test-$SHORT_VERSION.zip"
rm -f "$ZIP"
ditto -c -k --keepParent "$APP" "$ZIP"

ROUNDTRIP="$(mktemp -d)"
trap 'rm -rf "$ROUNDTRIP"' EXIT
ditto -x -k "$ZIP" "$ROUNDTRIP"
codesign --verify --strict "$ROUNDTRIP/RemoKey-Test.app"

echo "✅ 测试 App: $APP"
echo "✅ 安装包: $ZIP"
echo "⚠️  此包为 ad-hoc 测试签名；更新测试包后可能需要重新授权。"
