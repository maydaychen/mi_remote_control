#!/bin/bash
# setup-signing.sh — 检查 RemoKey 所需的 Apple 官方代码签名身份。
#
# 开发包使用 Apple Development；面向用户的站外分发包必须使用
# Developer ID Application。此脚本不创建自签名证书，也不会静默回退 ad-hoc。

set -euo pipefail

TEAM_ID="${REMOKEY_TEAM_ID:-3YT2ZK3Z94}"
REQUIRE_DISTRIBUTION=0
[ "${1:-}" = "--distribution" ] && REQUIRE_DISTRIBUTION=1

if [ "$#" -gt 1 ] || { [ "$#" -eq 1 ] && [ "${1:-}" != "--distribution" ]; }; then
    echo "用法：$0 [--distribution]" >&2
    exit 2
fi

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

DEVELOPMENT_IDENTITY="$(find_identity "Apple Development:" || true)"
DISTRIBUTION_IDENTITY="$(find_identity "Developer ID Application:" || true)"

echo "== RemoKey Apple 签名检查 =="
echo "团队：$TEAM_ID"

if [ -n "$DEVELOPMENT_IDENTITY" ]; then
    echo "✅ 开发签名：$DEVELOPMENT_IDENTITY"
else
    echo "❌ 找不到团队 $TEAM_ID 的 Apple Development 身份。" >&2
    echo "   请在 Xcode → Settings → Accounts → Manage Certificates 中创建或下载。" >&2
    exit 1
fi

if [ -n "$DISTRIBUTION_IDENTITY" ]; then
    echo "✅ 站外分发：$DISTRIBUTION_IDENTITY"
    echo "✅ 可运行 ./scripts/package.sh --distribution"
    exit 0
fi

echo "⚠️  找不到团队 $TEAM_ID 的 Developer ID Application 身份。"
echo "   正式分发前，请由 Account Holder 在 Apple Developer 后台或 Xcode 中创建："
echo "   https://developer.apple.com/account/resources/certificates/add"
echo "   类型选择 Developer ID Application，安装证书及对应私钥后重跑："
echo "     ./scripts/setup-signing.sh --distribution"

if [ "$REQUIRE_DISTRIBUTION" = "1" ]; then
    exit 1
fi
