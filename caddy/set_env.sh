#!/usr/bin/env bash
set -euo pipefail

ENV_FILE="${ENV_FILE:-./caddy.env}"
HMAC_SECRET_KEY=""

XHTTP_PREFIXES=(assets static public cdn content resources site media uploads dist build)
WS_PREFIXES=(ws socket wss live realtime api/socket socket.io chat stream)

hmac_hex() {
    local key="$1"
    local msg="$2"
    local len=${3:-12}
    openssl dgst -sha256 -hmac "$key" <<<"$msg" | awk '{print $2}' | cut -c1-"$len"
}

gen_xhttp_path() {
    local context="$1"
    local prefix="${XHTTP_PREFIXES[$RANDOM % ${#XHTTP_PREFIXES[@]}]}"
    local ver="v$((RANDOM % 9 + 1))"
    local token path
    token="$(hmac_hex "$HMAC_SECRET_KEY" "$context")"
    if (( RANDOM % 2 )); then
        path="/$prefix/$ver/$token"
    else
        local ext=(js css png jpg gz svg)
        path="/$prefix/$ver/$token.${ext[$RANDOM % ${#ext[@]}]}"
    fi
    echo "$path"
}

gen_ws_path() {
    local context="$1"
    local prefix="${WS_PREFIXES[$RANDOM % ${#WS_PREFIXES[@]}]}"
    local token="$(hmac_hex "$HMAC_SECRET_KEY" "$context" 8)"
    if (( RANDOM % 2 )); then
        echo "/$prefix/$token"
    else
        echo "/$prefix/$token/handshake"
    fi
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
    set_env "PROXY_XHTTP_PATH" "$(gen_xhttp_path "xhttp")"
    set_env "PROXY_XHTTP_WARP_PATH" "$(gen_xhttp_path "xhttp-warp")"
    set_env "PROXY_WEBSOCKET_PATH" "$(gen_ws_path "ws")"
    set_env "PROXY_WEBSOCKET_WARP_PATH" "$(gen_ws_path "ws-warp")"
    set_env "CDN_AUTH_TOKEN" "$(hmac_hex "$HMAC_SECRET_KEY" "cdn-auth-token" 32)"
    echo "[+] done"
}

main "$@"
