#!/bin/bash
# package.sh — 组装并签名 RemoKey.app，产出 zip。
#
# 默认：Apple Development 开发签名，产物名带 -development，仅用于本机开发／真机验收。
# --distribution：Developer ID Application + Hardened Runtime + 安全时间戳，供公证与分发。
# --unsigned：ad-hoc 预览包，产物名带 -unsigned，不得对外分发。

set -euo pipefail
cd "$(dirname "$0")/.."

TEAM_ID="${REMOKEY_TEAM_ID:-3YT2ZK3Z94}"
BUNDLE_ID="com.remokey.controller"
DIST="dist"
APP="$DIST/RemoKey.app"
MODE="development"

case "${1:-}" in
    ""|--development) MODE="development" ;;
    --distribution) MODE="distribution" ;;
    --unsigned) MODE="unsigned" ;;
    *) echo "用法：$0 [--development|--distribution|--unsigned]" >&2; exit 2 ;;
esac
[ "$#" -le 1 ] || { echo "用法：$0 [--development|--distribution|--unsigned]" >&2; exit 2; }

find_identity() {
    local prefix="$1"
    local identity
    local subject

    while IFS= read -r identity; do
        case "$identity" in
            "$prefix"*)
                subject="$(security find-certificate -c "$identity" -p 2>/dev/null \
                    | openssl x509 -noout -subject -nameopt RFC2253 2>/dev/null || true)"
                if echo "$subject" | grep -q "OU=${TEAM_ID}"; then
                    echo "$identity"
                    return 0
                fi
                ;;
        esac
    done < <(security find-identity -v -p codesigning 2>/dev/null \
        | sed -nE 's/^[[:space:]]*[0-9]+\) [0-9A-F]+ "([^"]+)".*/\1/p')
    return 1
}

SIGNING_IDENTITY=""
if [ "$MODE" = "development" ]; then
    SIGNING_IDENTITY="${SIGNING_IDENTITY_OVERRIDE:-$(find_identity "Apple Development:" || true)}"
elif [ "$MODE" = "distribution" ]; then
    SIGNING_IDENTITY="${SIGNING_IDENTITY_OVERRIDE:-$(find_identity "Developer ID Application:" || true)}"
fi

if [ "$MODE" != "unsigned" ] && [ -z "$SIGNING_IDENTITY" ]; then
    if [ "$MODE" = "distribution" ]; then
        echo "❌ 找不到团队 $TEAM_ID 的 Developer ID Application 身份。" >&2
        echo "   正式分发绝不回退到 Apple Development、自签名或 ad-hoc。" >&2
        echo "   先运行 ./scripts/setup-signing.sh --distribution" >&2
    else
        echo "❌ 找不到团队 $TEAM_ID 的 Apple Development 身份。" >&2
        echo "   先运行 ./scripts/setup-signing.sh" >&2
    fi
    exit 1
fi

echo "-- 构建 release 二进制"
RELEASE=1 ./build.sh

SHORT_VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Resources/Info-app.plist)"
BUILD_VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' Resources/Info-app.plist)"
echo "-- 版本: $SHORT_VERSION (build $BUILD_VERSION)"

echo "-- 组装 $APP"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cp Resources/Info-app.plist "$APP/Contents/Info.plist"
plutil -lint "$APP/Contents/Info.plist" >/dev/null

cp .build/miremote "$APP/Contents/MacOS/miremote"
chmod +x "$APP/Contents/MacOS/miremote"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
cp -R Resources/en.lproj Resources/zh-Hans.lproj "$APP/Contents/Resources/"

if [ -f "Resources/default-config.json" ]; then
    cp Resources/default-config.json "$APP/Contents/Resources/"
fi

find "$APP" -name '._*' -delete 2>/dev/null || true

if [ "$MODE" = "unsigned" ]; then
    echo "⚠️  ad-hoc 签名：仅供 CI／预览，不得分发"
    codesign --force --identifier "$BUNDLE_ID" --sign - "$APP"
elif [ "$MODE" = "development" ]; then
    echo "-- Apple Development 签名：$SIGNING_IDENTITY"
    codesign --force \
        --identifier "$BUNDLE_ID" \
        --options runtime \
        --timestamp=none \
        --sign "$SIGNING_IDENTITY" \
        "$APP"
else
    echo "-- Developer ID Application 签名：$SIGNING_IDENTITY"
    codesign --force \
        --identifier "$BUNDLE_ID" \
        --options runtime \
        --timestamp \
        --sign "$SIGNING_IDENTITY" \
        "$APP"
fi

codesign --verify --deep --strict --verbose=2 "$APP"

SIGNATURE_DETAILS="$(codesign -d --verbose=4 "$APP" 2>&1)"
if [ "$MODE" = "development" ]; then
    echo "$SIGNATURE_DETAILS" | grep -q '^Authority=Apple Development:' \
        || { echo "❌ 签名身份不是 Apple Development。" >&2; exit 1; }
    echo "$SIGNATURE_DETAILS" | grep -q "^TeamIdentifier=${TEAM_ID}$" \
        || { echo "❌ 签名团队不是 $TEAM_ID。" >&2; exit 1; }
elif [ "$MODE" = "distribution" ]; then
    echo "$SIGNATURE_DETAILS" | grep -q '^Authority=Developer ID Application:' \
        || { echo "❌ 签名身份不是 Developer ID Application。" >&2; exit 1; }
    echo "$SIGNATURE_DETAILS" | grep -q "^TeamIdentifier=${TEAM_ID}$" \
        || { echo "❌ 签名团队不是 $TEAM_ID。" >&2; exit 1; }
    echo "$SIGNATURE_DETAILS" | grep -q '^Runtime Version=' \
        || { echo "❌ 正式包未启用 Hardened Runtime。" >&2; exit 1; }
    echo "$SIGNATURE_DETAILS" | grep -q '^Timestamp=' \
        || { echo "❌ 正式包缺少安全时间戳。" >&2; exit 1; }
fi

SUFFIX="-development"
[ "$MODE" = "distribution" ] && SUFFIX=""
[ "$MODE" = "unsigned" ] && SUFFIX="-unsigned"
ZIP="$DIST/RemoKey-$SHORT_VERSION$SUFFIX.zip"
rm -f "$ZIP"
ditto -c -k --keepParent "$APP" "$ZIP"

echo "✅ 完成: $APP"
echo "✅ 压缩包: $ZIP"
if [ "$MODE" = "distribution" ]; then
    echo "➡️  下一步：NOTARY_PROFILE=<钥匙串配置名> ./scripts/notarize.sh"
fi
