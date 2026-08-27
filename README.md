# Cloudflare DDNS

Automatically updates a Cloudflare DNS A/AAAA record with your current public IP, with optional Telegram notifications after successful changes.

## Requirements

- `curl`, `jq`, `cron`
- Root access for installation

The installer detects missing dependencies and installs them automatically on systems using `apt-get`, `dnf`, `yum`, or `apk`. It also attempts to enable and start the cron service.

## Installation

```bash
curl -fsSL https://raw.githubusercontent.com/agjvrkgj/ddns/main/setup.sh | sudo bash
```

The installer first installs any missing tools, then prompts for your Cloudflare credentials, update interval, and optional Telegram settings before scheduling the updater automatically.

## Telegram Notifications

When enabled, the bot sends a message after Cloudflare successfully changes a DNS record. The notification includes the domain, record type, old IP, and new IP. Runs where the IP has not changed do not send a message.

1. Create a bot with [@BotFather](https://t.me/BotFather) and copy its Bot Token.
2. Open the new bot and send it a message.
3. Open `https://api.telegram.org/bot<BOT_TOKEN>/getUpdates` and find `message.chat.id` in the response.
4. Enter the Bot Token and Chat ID when the installer asks whether to enable Telegram notifications.

To enable notifications on an existing installation, edit `/usr/local/bin/cloudflare-ddns.sh` and set:

```bash
TELEGRAM_BOT_TOKEN="123456789:your_bot_token"
TELEGRAM_CHAT_ID="123456789"
```

## Manual Usage

1. Edit `ddns.sh` and fill in the configuration section.
2. Run `bash ddns.sh`.

## File Locations (after install)

| Path | Description |
|---|---|
| `/usr/local/bin/cloudflare-ddns.sh` | Main updater script |
| `/etc/cron.d/cloudflare-ddns` | Scheduled cron job |
| `/var/log/cloudflare-ddns.log` | Runtime log |

## Mainland China

`icanhazip.com` (default) may be unreliable from mainland China. Edit the installed script and change the two IP service URLs:

```bash
# /usr/local/bin/cloudflare-ddns.sh
IP_SERVICE_V4="https://4.ipw.cn"   # IPv4 (operated by IPIP.NET)
IP_SERVICE_V6="https://6.ipw.cn"   # IPv6
```

`api.cloudflare.com` is generally accessible from mainland China without additional configuration. Telegram API connectivity may require a reachable network route.

## Uninstall

```bash
sudo rm /usr/local/bin/cloudflare-ddns.sh /etc/cron.d/cloudflare-ddns
```

## License

MIT
