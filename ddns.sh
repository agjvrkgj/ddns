#!/usr/bin/env bash
# DDNS updater via Cloudflare API (Global API Key)

set -euo pipefail

# ================= Configuration =================
GLOBAL_API_KEY="your_new_global_api_key_here"
EMAIL="your_cf_email"
ZONE_ID="zone_id"
RECORD_NAME="xx.xxxxxx.xyz"
RECORD_TYPE="A"  # Use "A" for IPv4 or "AAAA" for IPv6

# ================= Dependency Check =================
for cmd in curl jq; do
    if ! command -v "$cmd" &>/dev/null; then
        echo "Error: Required command '$cmd' is not installed." >&2
        exit 1
    fi
done

# ================= Script Logic =================

# Fetch current public IP based on record type
case "$RECORD_TYPE" in
    A)    CURRENT_IP=$(curl -s -4 --fail --connect-timeout 10 https://icanhazip.com | tr -d '[:space:]') ;;
    AAAA) CURRENT_IP=$(curl -s -6 --fail --connect-timeout 10 https://icanhazip.com | tr -d '[:space:]') ;;
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
    "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/dns_records?name=${RECORD_NAME}&type=${RECORD_TYPE}")

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
    "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/dns_records/${RECORD_ID}")

if echo "$UPDATE_RESULT" | jq -e '.success == true' > /dev/null; then
    echo "Success: $RECORD_NAME ($RECORD_TYPE) updated to $CURRENT_IP"
else
    echo "Error: Update failed. Cloudflare API response:" >&2
    echo "$UPDATE_RESULT" | jq '.' >&2
    exit 1
fi
