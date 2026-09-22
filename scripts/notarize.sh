#!/bin/bash
# notarize.sh — 公证 Developer ID 签名的 RemoKey.app 与最终 DMG，并附加票据。
#
# 前置：先用 notarytool store-credentials 把凭据安全保存到钥匙串，然后设置
# NOTARY_PROFILE。脚本不接收或输出 Apple ID 密码、API 私钥内容。

set -euo pipefail
cd "$(dirname "$0")/.."

TEAM_ID="${REMOKEY_TEAM_ID:-3YT2ZK3Z94}"
NOTARY_PROFILE="${NOTARY_PROFILE:-}"
APP="dist/RemoKey.app"
SHORT_VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Resources/Info-app.plist)"
ZIP="dist/RemoKey-$SHORT_VERSION.zip"
DMG="dist/RemoKey-$SHORT_VERSION.dmg"

if [ -z "$NOTARY_PROFILE" ]; then
    echo "❌ 缺少 NOTARY_PROFILE。" >&2
    echo "   先用 xcrun notarytool store-credentials 将凭据保存到钥匙串，" >&2
    echo "   再运行 NOTARY_PROFILE=<配置名> ./scripts/notarize.sh" >&2
    exit 1
fi

[ -d "$APP" ] || { echo "❌ 找不到 $APP，请先运行 ./scripts/package.sh --distribution。" >&2; exit 1; }

codesign --verify --deep --strict --verbose=2 "$APP" >/dev/null
SIGNATURE_DETAILS="$(codesign -d --verbose=4 "$APP" 2>&1)"
echo "$SIGNATURE_DETAILS" | grep -q '^Authority=Developer ID Application:' \
    || { echo "❌ App 不是 Developer ID Application 签名。" >&2; exit 1; }
echo "$SIGNATURE_DETAILS" | grep -q "^TeamIdentifier=${TEAM_ID}$" \
    || { echo "❌ App 签名团队不是 $TEAM_ID。" >&2; exit 1; }
echo "$SIGNATURE_DETAILS" | grep -q '^Runtime Version=' \
    || { echo "❌ App 未启用 Hardened Runtime。" >&2; exit 1; }
echo "$SIGNATURE_DETAILS" | grep -q '^Timestamp=' \
    || { echo "❌ App 缺少安全时间戳。" >&2; exit 1; }

SUBMISSION_DIR="$(mktemp -d)"
trap 'rm -rf "$SUBMISSION_DIR"' EXIT
APP_SUBMISSION="$SUBMISSION_DIR/RemoKey-notarization.zip"
ditto -c -k --keepParent "$APP" "$APP_SUBMISSION"

echo "-- 提交 App 公证"
xcrun notarytool submit "$APP_SUBMISSION" --keychain-profile "$NOTARY_PROFILE" --wait
xcrun stapler staple "$APP"
xcrun stapler validate "$APP"

echo "-- 刷新已附票据的 ZIP"
rm -f "$ZIP"
ditto -c -k --keepParent "$APP" "$ZIP"

echo "-- 生成并提交 DMG 公证"
./scripts/make-dmg.sh
xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait
xcrun stapler staple "$DMG"
xcrun stapler validate "$DMG"

spctl --assess --type execute --verbose=2 "$APP"
spctl --assess --type open --context context:primary-signature --verbose=2 "$DMG"

echo "✅ App、ZIP 与 DMG 已完成 Developer ID 签名、公证和票据附加。"
echo "✅ ZIP: $ZIP"
echo "✅ DMG: $DMG"
