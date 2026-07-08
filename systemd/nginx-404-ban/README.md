# HOW TO

脚本用来检测 Nginx 日志中 404 错误的请求，并根据请求频率自动封禁 IP 地址。它使用 `ipset` 和 `iptables` 来管理封禁列表。

```bash
# 1) Install dependencies
sudo apt update
sudo apt install -y ipset iptables gawk

# 2) Install script
sudo cp /path/to/debian-ubuntu-webserver-setup/script/auto_ban_404_scanners.sh /usr/local/bin/auto_ban_404_scanners.sh
sudo chmod +x /usr/local/bin/auto_ban_404_scanners.sh

# 3) Install systemd unit files
sudo cp /path/to/debian-ubuntu-webserver-setup/systemd/nginx-404-ban/nginx-404-ban.service /etc/systemd/system/nginx-404-ban.service
sudo cp /path/to/debian-ubuntu-webserver-setup/systemd/nginx-404-ban/nginx-404-ban.timer /etc/systemd/system/nginx-404-ban.timer

# 4) Reload systemd and enable timer
sudo systemctl daemon-reload
sudo systemctl enable --now nginx-404-ban.timer

# 5) Verify
systemctl list-timers | grep nginx-404-ban
sudo systemctl status nginx-404-ban.timer

# 6) Run once manually for testing
sudo systemctl start nginx-404-ban.service
sudo journalctl -u nginx-404-ban.service -n 100 --no-pager

# 7) Optional: dry run check
sudo /usr/local/bin/auto_ban_404_scanners.sh --dry-run --window 180 --threshold 10
```

## Notes

- Timer runs once per minute.
- Default script arguments in service:
  - `--window 120`
  - `--threshold 12`
  - `--ban-seconds 86400`
- Modify `ExecStart` in `nginx-404-ban.service` if you want stricter or looser behavior.