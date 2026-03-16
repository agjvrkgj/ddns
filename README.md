# Cloudflare DDNS

Automatically updates a Cloudflare DNS A/AAAA record with your current public IP.

## Requirements

- `curl`, `jq`, `cron`

## Installation

```bash
curl -fsSL https://raw.githubusercontent.com/xhhcn/ddns/main/setup.sh | sudo bash
```

Prompts for your Cloudflare credentials and update interval, then installs and schedules the updater automatically.

## Manual Usage

1. Edit `ddns.sh` and fill in the configuration section
2. `bash ddns.sh`

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

`api.cloudflare.com` is generally accessible from mainland China without additional configuration.

## Uninstall

```bash
sudo rm /usr/local/bin/cloudflare-ddns.sh /etc/cron.d/cloudflare-ddns
```

## License

MIT
