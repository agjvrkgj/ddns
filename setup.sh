#!/usr/bin/env bash
# One-click Cloudflare DDNS installer
# Usage: sudo bash setup.sh
#   or : curl -fsSL https://raw.githubusercontent.com/agjvrkgj/ddns/main/setup.sh | sudo bash

set -euo pipefail

RAW_URL="https://raw.githubusercontent.com/agjvrkgj/ddns/main/ddns.sh"
SCRIPT_PATH="/usr/local/bin/cloudflare-ddns.sh"
LOG_FILE="/var/log/cloudflare-ddns.log"
CRON_FILE="/etc/cron.d/cloudflare-ddns"

if [[ $EUID -ne 0 ]]; then
    echo "Error: Please run as root  ->  sudo bash $0" >&2
    exit 1
fi

install_dependencies() {
    local -a missing=() packages=()
    local item package_manager=""

    command -v curl &>/dev/null || missing+=(curl)
    command -v jq &>/dev/null || missing+=(jq)
    if { ! command -v cron &>/dev/null && ! command -v crond &>/dev/null; } || [[ ! -d /etc/cron.d ]]; then
        missing+=(cron)
    fi

    if (( ${#missing[@]} == 0 )); then
        echo "Dependencies already installed: curl, jq, cron"
        return 0
    fi

    echo "Missing dependencies: ${missing[*]}"

    if command -v apt-get &>/dev/null; then
        package_manager="apt-get"
        for item in "${missing[@]}"; do
            packages+=("$item")
        done
        apt-get update
        DEBIAN_FRONTEND=noninteractive apt-get install -y "${packages[@]}"
    elif command -v dnf &>/dev/null; then
        package_manager="dnf"
        for item in "${missing[@]}"; do
            [[ "$item" == "cron" ]] && packages+=(cronie) || packages+=("$item")
        done
        dnf install -y "${packages[@]}"
    elif command -v yum &>/dev/null; then
        package_manager="yum"
        for item in "${missing[@]}"; do
            [[ "$item" == "cron" ]] && packages+=(cronie) || packages+=("$item")
        done
        yum install -y "${packages[@]}"
    elif command -v apk &>/dev/null; then
        package_manager="apk"
        for item in "${missing[@]}"; do
            [[ "$item" == "cron" ]] && packages+=(cronie) || packages+=("$item")
        done
        apk add --no-cache "${packages[@]}"
    else
        echo "Error: No supported package manager found (apt-get, dnf, yum, or apk)." >&2
        echo "Install curl, jq, and cron manually, then run this installer again." >&2
        exit 1
    fi

    echo "Dependencies installed with $package_manager."

    for item in curl jq; do
        if ! command -v "$item" &>/dev/null; then
            echo "Error: Dependency installation finished, but '$item' is still unavailable." >&2
            exit 1
        fi
    done

    if ! command -v cron &>/dev/null && ! command -v crond &>/dev/null; then
        echo "Error: Dependency installation finished, but cron is still unavailable." >&2
        exit 1
    fi

    mkdir -p /etc/cron.d
    chmod 755 /etc/cron.d
}

start_cron_service() {
    if command -v systemctl &>/dev/null; then
        if systemctl enable --now cron.service &>/dev/null || systemctl enable --now crond.service &>/dev/null; then
            echo "Cron service enabled and started."
            return 0
        fi
    fi

    if command -v rc-update &>/dev/null && command -v rc-service &>/dev/null; then
        rc-update add crond default &>/dev/null || true
        if rc-service crond start &>/dev/null; then
            echo "Cron service enabled and started."
            return 0
        fi
    fi

    if command -v service &>/dev/null; then
        if service cron start &>/dev/null || service crond start &>/dev/null; then
            echo "Cron service started."
            return 0
        fi
    fi

    echo "Warning: Could not start cron automatically. Verify that the cron service is running." >&2
}

install_dependencies
start_cron_service

# Reads from /dev/tty so interactive prompts work even when piped via curl | bash
prompt() {
    local _var="$1" _text="$2" _default="${3:-}" _input
    if [[ -n "$_default" ]]; then
        read -rp "$_text [$_default]: " _input </dev/tty || true
        printf -v "$_var" '%s' "${_input:-$_default}"
    else
        while true; do
            read -rp "$_text: " _input </dev/tty || true
            [[ -n "$_input" ]] && { printf -v "$_var" '%s' "$_input"; break; }
            echo "  (required)" >&2
        done
    fi
}

prompt API_KEY       "Global API Key"
prompt EMAIL         "Cloudflare Email"
prompt ZONE_ID       "Zone ID"
prompt RECORD_NAME   "Record Name (FQDN)"
prompt RECORD_TYPE   "Record Type (A / AAAA)" "A"
prompt CRON_INTERVAL "Update interval (minutes)" "5"
prompt TELEGRAM_ENABLED "Enable Telegram notifications? (y/N)" "N"

case "$TELEGRAM_ENABLED" in
    y|Y|yes|YES|Yes)
        prompt TELEGRAM_BOT_TOKEN "Telegram Bot Token"
        prompt TELEGRAM_CHAT_ID   "Telegram Chat ID"
        ;;
    *)
        TELEGRAM_BOT_TOKEN=""
        TELEGRAM_CHAT_ID=""
        ;;
esac

if ! [[ "$CRON_INTERVAL" =~ ^[1-9][0-9]*$ ]]; then
    echo "Error: Update interval must be a positive integer." >&2
    exit 1
fi

case "$RECORD_TYPE" in
    A|AAAA) ;;
    *)
        echo "Error: Record Type must be A or AAAA." >&2
        exit 1
        ;;
esac

echo "Downloading ddns.sh..."
curl -fsSL "$RAW_URL" -o "$SCRIPT_PATH"
chmod 700 "$SCRIPT_PATH"

sed -i "s|^GLOBAL_API_KEY=.*|GLOBAL_API_KEY=\"${API_KEY}\"|"                 "$SCRIPT_PATH"
sed -i "s|^EMAIL=.*|EMAIL=\"${EMAIL}\"|"                                    "$SCRIPT_PATH"
sed -i "s|^ZONE_ID=.*|ZONE_ID=\"${ZONE_ID}\"|"                              "$SCRIPT_PATH"
sed -i "s|^RECORD_NAME=.*|RECORD_NAME=\"${RECORD_NAME}\"|"                  "$SCRIPT_PATH"
sed -i "s|^RECORD_TYPE=.*|RECORD_TYPE=\"${RECORD_TYPE}\"|"                  "$SCRIPT_PATH"
sed -i "s|^TELEGRAM_BOT_TOKEN=.*|TELEGRAM_BOT_TOKEN=\"${TELEGRAM_BOT_TOKEN}\"|" "$SCRIPT_PATH"
sed -i "s|^TELEGRAM_CHAT_ID=.*|TELEGRAM_CHAT_ID=\"${TELEGRAM_CHAT_ID}\"|"       "$SCRIPT_PATH"

cat > "$CRON_FILE" <<EOF
# Cloudflare DDNS - runs every ${CRON_INTERVAL} minute(s)
*/${CRON_INTERVAL} * * * * root ${SCRIPT_PATH} >> ${LOG_FILE} 2>&1
EOF
chmod 644 "$CRON_FILE"

echo "Running initial update..."
"$SCRIPT_PATH"
echo "Done. Cron: every ${CRON_INTERVAL} min | Logs: tail -f ${LOG_FILE}"
