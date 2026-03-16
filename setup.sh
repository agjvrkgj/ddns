#!/usr/bin/env bash
# One-click Cloudflare DDNS installer
# Usage: sudo bash setup.sh
#   or : curl -fsSL https://raw.githubusercontent.com/xhhcn/ddns/main/setup.sh | sudo bash

set -euo pipefail

RAW_URL="https://raw.githubusercontent.com/xhhcn/ddns/main/ddns.sh"
SCRIPT_PATH="/usr/local/bin/cloudflare-ddns.sh"
LOG_FILE="/var/log/cloudflare-ddns.log"
CRON_FILE="/etc/cron.d/cloudflare-ddns"

if [[ $EUID -ne 0 ]]; then
    echo "Error: Please run as root  ->  sudo bash $0" >&2
    exit 1
fi

for cmd in curl jq; do
    if ! command -v "$cmd" &>/dev/null; then
        echo "Error: '$cmd' is not installed. Install it and retry." >&2
        exit 1
    fi
done

if [[ ! -d /etc/cron.d ]]; then
    echo "Error: /etc/cron.d not found. Please install cron (e.g. apt/yum/dnf install cron) and retry." >&2
    exit 1
fi

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

if ! [[ "$CRON_INTERVAL" =~ ^[1-9][0-9]*$ ]]; then
    echo "Error: Update interval must be a positive integer." >&2
    exit 1
fi

echo "Downloading ddns.sh..."
curl -fsSL "$RAW_URL" -o "$SCRIPT_PATH"
chmod +x "$SCRIPT_PATH"

sed -i "s|^GLOBAL_API_KEY=.*|GLOBAL_API_KEY=\"${API_KEY}\"|"   "$SCRIPT_PATH"
sed -i "s|^EMAIL=.*|EMAIL=\"${EMAIL}\"|"                        "$SCRIPT_PATH"
sed -i "s|^ZONE_ID=.*|ZONE_ID=\"${ZONE_ID}\"|"                 "$SCRIPT_PATH"
sed -i "s|^RECORD_NAME=.*|RECORD_NAME=\"${RECORD_NAME}\"|"     "$SCRIPT_PATH"
sed -i "s|^RECORD_TYPE=.*|RECORD_TYPE=\"${RECORD_TYPE}\"|"     "$SCRIPT_PATH"

cat > "$CRON_FILE" <<EOF
# Cloudflare DDNS - runs every ${CRON_INTERVAL} minute(s)
*/${CRON_INTERVAL} * * * * root ${SCRIPT_PATH} >> ${LOG_FILE} 2>&1
EOF
chmod 644 "$CRON_FILE"

echo "Running initial update..."
"$SCRIPT_PATH"
echo "Done. Cron: every ${CRON_INTERVAL} min | Logs: tail -f ${LOG_FILE}"
