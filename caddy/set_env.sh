#!/usr/bin/env bash
set -euo pipefail

ENV_FILE="${ENV_FILE:-./caddy.env}"
HMAC_SECRET_KEY=""

hmac_hex() {
    local key="$1"
    local msg="$2"
    local len=${3:-12}
    openssl dgst -sha256 -hmac "$key" <<<"$msg" | awk '{print $2}' | cut -c1-"$len"
}

set_env() {
    local key="$1"
    local value="$2"
    sed -i "s|^${key}=.*|${key}=${value}|" "$ENV_FILE"
}

main() {
    if [ -z "$HMAC_SECRET_KEY" ]; then
        HMAC_SECRET_KEY="$(openssl rand -hex 16)"
        echo "[*] empty hmac secret, using: $HMAC_SECRET_KEY"
    fi
    set_env "PANEL_PATH" "/pan/$(hmac_hex "$HMAC_SECRET_KEY" "panel")"
    set_env "SUBSCRIPTION_PATH" "/sub/$(hmac_hex "$HMAC_SECRET_KEY" "subscription")"
    echo "[+] done"
}

main "$@"
