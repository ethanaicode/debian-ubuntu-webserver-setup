# nginx-ratelimit-ban

Auto-ban IPs that repeatedly trigger nginx `limit_req` rate limiting.  
Scans all `*.error.log` files under `/www/wwwlogs/` every minute, and uses **ipset + iptables** to block offending IPs at the kernel level.

---

## How it works

```
nginx error.log  →  script scans "limiting requests" entries
                 →  counts per-IP hits in last N seconds
                 →  IPs >= threshold  →  ipset add  →  iptables DROP
```

The ban automatically expires after `ban-seconds` (default: 24 h). No manual cleanup needed.

---

## Installation

```bash
# 1. Install dependencies (gawk is required for mktime support; mawk will NOT work)
apt install -y gawk ipset iptables

# 2. Copy script
cp auto_ban_ratelimit.sh /usr/local/bin/
chmod +x /usr/local/bin/auto_ban_ratelimit.sh

# 3. Copy systemd units
cp nginx-ratelimit-ban.service /etc/systemd/system/
cp nginx-ratelimit-ban.timer   /etc/systemd/system/

# 4. Enable and start
systemctl daemon-reload
systemctl enable --now nginx-ratelimit-ban.timer
```

---

## Test before enabling

```bash
# Dry-run: shows candidates without touching firewall
/usr/local/bin/auto_ban_ratelimit.sh --dry-run

# Adjust sensitivity
/usr/local/bin/auto_ban_ratelimit.sh --dry-run --window 300 --threshold 50
```

---

## Parameters (service defaults)

| Parameter | Default | Meaning |
|-----------|---------|---------|
| `--log-dir` | `/www/wwwlogs` | Directory containing error logs |
| `--log-pattern` | `*.error.log` | Glob for log file names |
| `--window` | `120` | Look back this many seconds 中文：回溯的时间窗口（秒） |
| `--threshold` | `30` | Ban if triggered >= N times in window 中文：达到阈值时封禁 |
| `--ban-seconds` | `86400` | Ban duration (24 h), auto-expires 中文：封禁持续时间（秒） |
| `--set-name` | `nginx_ratelimit_ban` | ipset name 中文：ipset 名称 |

Edit `/etc/systemd/system/nginx-ratelimit-ban.service` and run `systemctl daemon-reload` to change defaults.

---

## Useful commands

```bash
# Check timer status
systemctl status nginx-ratelimit-ban.timer

# View recent ban activity
journalctl -u nginx-ratelimit-ban.service -n 50

# List currently banned IPs
ipset list nginx_ratelimit_ban

# Manually unban an IP
ipset del nginx_ratelimit_ban 1.2.3.4

# Flush all bans
ipset flush nginx_ratelimit_ban
```

---

## Relationship with nginx-404-ban

Both services share the same mechanism (ipset + iptables) but use **separate ipsets**:

| Service | ipset name | Log source | Trigger |
|---------|-----------|------------|---------|
| nginx-404-ban | `nginx_404_scanners` | access.log | status=404 + suspicious URI |
| nginx-ratelimit-ban | `nginx_ratelimit_ban` | error.log | `limiting requests` |

They work independently and complement each other.
