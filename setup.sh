#!/usr/bin/env bash
set -eEuo pipefail
trap 'echo "error: $BASH_COMMAND on line $LINENO" >&2' ERR

BASE_DIR="$(dirname "$(realpath "$0")")"

declare -A VARS
declare -A DEFAULTS

VARS[domain]=""
VARS[panel]=""
VARS[panel_path]=""
VARS[caddy_env]="$BASE_DIR/caddy/caddy.env"
VARS[sui_port]="2095"
DEFAULTS[panel]="3x-ui"

is_root() {
    [ "$(id -u)" -eq 0 ]
}

is_sui() {
    [ "${VARS[panel]}" = "s-ui" ]
}

install_docker() {
    if command -v docker >/dev/null 2>&1; then
        echo "[*] docker already installed"
        return 0
    fi
    echo "[*] installing docker..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
    rm -f ./get-docker.sh
    sudo groupadd -f docker
    sudo usermod -aG docker "$(whoami)"
    echo "[+] docker installed"
}

configure_sysctl() {
    local target="/etc/sysctl.d/99-proxy.conf"
    [[ -f "$BASE_DIR/$target" ]] || { echo "error: missing $target, exit" >&2; exit 1; }
    echo "[*] configuring sysctl..."
    sudo install -m 644 -o root -g root "$BASE_DIR/$target" "$target"
    echo "[+] sysctl config deployed to $target"
}

ask_domain() {
    local domain
    read -rp "enter your domain: " domain
    [[ -z "$domain" ]] && { echo "error: domain cannot be empty, exit" >&2; exit 1; }
    VARS[domain]="$domain"
}

set_domain() {
    local env_file="${VARS[caddy_env]}"
    [[ -f "$env_file" ]] || { echo "error: $env_file not found, exit" >&2; exit 1; }
    sed -i "s/^DOMAIN=.*/DOMAIN=${VARS[domain]}/" "$env_file"
    echo "[*] updated $env_file with domain ${VARS[domain]}"
}

set_caddy_env() {
    local set_env_script="$BASE_DIR/caddy/set_env.sh"
    local env_file="${VARS[caddy_env]}"
    [[ -f "$set_env_script" ]] || { echo "error: $set_env_script not found, exit" >&2; exit 1; }
    ENV_FILE="$env_file" bash "$set_env_script"
    echo "[*] executed $set_env_script with ENV_FILE=$env_file"
}

copy_compose_file () {
    local src_file="$BASE_DIR/compose/${VARS[panel]}.yml"
    local dst_file="$BASE_DIR/compose.yml"
    [[ -f "$src_file" ]] || { echo "error: $src_file not found, exit" >&2; exit 1; }
    cp "$src_file" "$dst_file"
    echo "[*] copied $src_file to $dst_file"
}

init_panel_db() {
    local compose_file="$BASE_DIR/compose.yml"
    echo "[*] starting docker compose to initialize database..."
    docker compose -f "$compose_file" up -d
    echo "[*] waiting for n seconds for database initialization..."
    for i in {1..10}; do
        if compgen -G "$BASE_DIR/panel/${VARS[panel]}/db/*.db" > /dev/null; then
            echo "[*] database initialized"
            break
        fi
        sleep 1
    done
    docker compose -f "$compose_file" down
    echo "[*] docker compose stopped"
}

set_panel_path() {
    local env_file="${VARS[caddy_env]}"
    local panel_path="$(grep -E '^PANEL_PATH=' "$env_file" | cut -d'=' -f2-)"
    [[ -z "$panel_path" ]] && { echo "error: PANEL_PATH is empty in $env_file, exit" >&2; exit 1; }
    local compose_file="$BASE_DIR/compose.yml"
    echo "[*] starting docker compose to initialize database..."
    docker compose -f "$compose_file" up -d
    local panel="${VARS[panel]}"
    if [ "$panel" = "3x-ui" ] || [ "$panel" = "x-ui" ]; then
        docker exec -it $panel sh -c "/app/x-ui setting -webBasePath '$panel_path'"
    elif [ "$panel" = "s-ui" ]; then
        docker exec -it $panel sh -c "/app/sui setting -path '$panel_path'"
    fi
    docker compose -f "$compose_file" down
    echo "[*] docker compose stopped"
    VARS[panel_path]="$panel_path"
}

ask_panel() {
    local panel
    while true; do
        read -rp "choose panel [3x-ui/x-ui/s-ui] (default: ${DEFAULTS[panel]}): " panel
        panel="${panel:-${DEFAULTS[panel]}}"
        case "$panel" in
            3x-ui|x-ui|s-ui)
                VARS[panel]="$panel"
                echo "[*] panel set to: ${VARS[panel]}"
                break
                ;;
            *)
                echo "error: invalid choice, please choose 3x-ui, x-ui, or s-ui"
                ;;
        esac
    done
}

set_panel() {
    local env_file="${VARS[caddy_env]}"
    [[ -f "$env_file" ]] || { echo "error: $env_file not found, exit" >&2; exit 1; }
    sed -i "s/^PANEL=.*/PANEL=${VARS[panel]}/" "$env_file"
    echo "[*] updated $env_file with panel ${VARS[panel]}"
    if is_sui; then
        sed -i "s/^PANEL_PORT=.*/PANEL_PORT=${VARS[sui_port]}/" "$env_file"
        echo "[*] updated $env_file with panel port ${VARS[sui_port]}"
    fi
}

handle_domain() {
    ask_domain
    set_domain
}

handle_panel() {
    ask_panel
    set_panel
}

configure_ufw() {
    if ! command -v ufw >/dev/null 2>&1; then
        return 0
    fi
    echo "[*] configuring UFW rules..."
    sudo ufw allow http
    sudo ufw allow https
    echo "[+] UFW configured"
}

main() {
    is_root && { echo "error: run as root is forbidden, exit" >&2; exit 1; }
    install_docker
    configure_sysctl
    configure_ufw
    handle_domain
    handle_panel
    set_caddy_env
    copy_compose_file
    set_panel_path
    echo "[*] panel is available at: https://${VARS[domain]}${VARS[panel_path]}/"
    echo "[*] panel params file: ${VARS[caddy_env]}"
    echo "[+] done, reboot"
}

main "$@"
