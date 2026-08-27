#!/usr/bin/env bash
# DDNS updater via Cloudflare API (Global API Key)

set -euo pipefail

# ================= Configuration =================
GLOBAL_API_KEY="your_new_global_api_key_here"
EMAIL="your_cf_email"
ZONE_ID="zone_id"
RECORD_NAME="xx.xxxxxx.xyz"
RECORD_TYPE="A"  # Use "A" for IPv4 or "AAAA" for IPv6

# Optional Telegram notification (sent only after a successful DNS update)
TELEGRAM_BOT_TOKEN=""
TELEGRAM_CHAT_ID=""

# IP detection service — for servers in mainland China, use: https://4.ipw.cn / https://6.ipw.cn
IP_SERVICE_V4="https://icanhazip.com"
IP_SERVICE_V6="https://icanhazip.com"

# ================= Dependency Check =================
for cmd in curl jq; do
    if ! command -v "$cmd" &>/dev/null; then
        echo "Error: Required command '$cmd' is not installed." >&2
        exit 1
    fi
done

# ================= Script Logic =================

send_telegram_notification() {
    local old_ip="$1"
    local new_ip="$2"
    local message response

    # Telegram notifications are optional. Both values are required to enable them.
    if [[ -z "$TELEGRAM_BOT_TOKEN" || -z "$TELEGRAM_CHAT_ID" ]]; then
        return 0
    fi

    printf -v message \
        '✅ Cloudflare DDNS 更新成功\n域名：%s\n记录类型：%s\nIP：%s → %s' \
        "$RECORD_NAME" "$RECORD_TYPE" "$old_ip" "$new_ip"

    if ! response=$(curl -sS --fail --connect-timeout 10 --max-time 20 \
        -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
        --data-urlencode "chat_id=${TELEGRAM_CHAT_ID}" \
        --data-urlencode "text=${message}" 2>&1); then
        echo "Warning: DDNS update succeeded, but Telegram notification failed: $response" >&2
    fi
}

# Fetch current public IP based on record type
case "$RECORD_TYPE" in
    A)    CURRENT_IP=$(curl -s -4 --fail --connect-timeout 10 "$IP_SERVICE_V4" | tr -d '[:space:]') || true ;;
    AAAA) CURRENT_IP=$(curl -s -6 --fail --connect-timeout 10 "$IP_SERVICE_V6" | tr -d '[:space:]') || true ;;
    *)
        echo "Error: Invalid RECORD_TYPE '$RECORD_TYPE'. Must be 'A' or 'AAAA'." >&2
        exit 1
        ;;
esac

if [[ -z "$CURRENT_IP" ]]; then
    echo "Error: Failed to fetch public IP. Check your network connection." >&2
    exit 1
fi

# Fetch the existing DNS record from Cloudflare
CF_RESPONSE=$(curl -s --connect-timeout 10 \
    -H "X-Auth-Email: $EMAIL" \
    -H "X-Auth-Key: $GLOBAL_API_KEY" \
    -H "Content-Type: application/json" \
    "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/dns_records?name=${RECORD_NAME}&type=${RECORD_TYPE}") || true

RECORD_ID=$(echo "$CF_RESPONSE"  | jq -r '.result[0].id      // empty')
DNS_IP=$(echo "$CF_RESPONSE"     | jq -r '.result[0].content // empty')

if [[ -z "$RECORD_ID" ]]; then
    echo "Error: Failed to fetch RECORD_ID. Check your API credentials, ZONE_ID, and RECORD_NAME." >&2
    exit 1
fi

# Skip update if IP has not changed
if [[ "$CURRENT_IP" == "$DNS_IP" ]]; then
    echo "No update needed: $RECORD_NAME is already set to $CURRENT_IP"
    exit 0
fi

echo "Updating $RECORD_NAME ($RECORD_TYPE): $DNS_IP -> $CURRENT_IP"

# Update the DNS record using jq to safely construct the JSON payload
UPDATE_RESULT=$(curl -s --connect-timeout 10 -X PUT \
    -H "X-Auth-Email: $EMAIL" \
    -H "X-Auth-Key: $GLOBAL_API_KEY" \
    -H "Content-Type: application/json" \
    --data "$(jq -n \
        --arg type    "$RECORD_TYPE" \
        --arg name    "$RECORD_NAME" \
        --arg content "$CURRENT_IP" \
        '{type: $type, name: $name, content: $content, proxied: false}')" \
    "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/dns_records/${RECORD_ID}") || true

if echo "$UPDATE_RESULT" | jq -e '.success == true' > /dev/null; then
    echo "Success: $RECORD_NAME ($RECORD_TYPE) updated to $CURRENT_IP"
    send_telegram_notification "$DNS_IP" "$CURRENT_IP"
else
    echo "Error: Update failed. Cloudflare API response:" >&2
    echo "$UPDATE_RESULT" | jq '.' >&2
    exit 1
fi
