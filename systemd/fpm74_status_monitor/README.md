# PHP-FPM 7.4 Traffic Monitor

每分钟采集 PHP-FPM 7.4 的请求流量，记录类似 `systemctl status php7.4-fpm` 中的：

```text
Traffic: 2.70req/sec
```

本方案不解析 `systemctl status` 的显示文本，而是读取 PHP-FPM status 页面中的累计 `accepted conn`，通过两次采样的差值计算请求速率：

```text
Traffic (req/sec) = (本次 accepted conn - 上次 accepted conn) / 两次采样的实际间隔秒数
```

## 重要：必须配置 PHP-FPM status

脚本依赖 PHP-FPM status 页面。只安装脚本和 systemd 文件是不够的，必须确认 PHP-FPM 7.4 pool 配置中存在：

```ini
pm.status_path = /phpfpm_74_status
```

本仓库对应的 PHP-FPM 配置还使用以下 socket：

```ini
listen = /run/php/php7.4-fpm.sock;
```

通常配置文件为：

```text
/www/server/php/74/etc/php-fpm.conf
```

如果你的 PHP-FPM 配置路径或 socket 不同，需要同步修改 Nginx 配置和脚本中的 URL。

## 必须配置 Nginx status location

PHP-FPM 的 `pm.status_path` 只是注册 URI，仍然需要 Nginx 将这个 URI 转发到 PHP-FPM socket。请在 Nginx 的本机状态 server 中加入：

```nginx
server {
    listen 80;
    server_name 127.0.0.1;

    allow 127.0.0.1;
    deny all;

    location /phpfpm_74_status {
        include fastcgi.conf;
        fastcgi_pass unix:/run/php/php7.4-fpm.sock;
        fastcgi_param SCRIPT_FILENAME $fastcgi_script_name;
    }
}
```

本仓库提供的配置文件是：

```text
conf/nginx/vhost/phpfpm_status.conf
```

注意安全事项：

- 状态页只应允许 `127.0.0.1` 访问。
- 不要把 `/phpfpm_74_status` 暴露到公网。
- 如果服务器使用真实客户端 IP、代理或 CDN，仍应确保 status server 不被外部访问。

## 安装依赖

```bash
sudo apt install -y curl
```

PHP-FPM、Nginx 和 systemd 通常已经存在；脚本使用 `curl` 请求本机状态页。

## 安装文件

在仓库根目录执行：

```bash
sudo cp systemd/fpm74_status_monitor/php-fpm74_status_monitor.sh \
  /usr/local/bin/php-fpm74_status_monitor.sh
sudo chmod +x /usr/local/bin/php-fpm74_status_monitor.sh

sudo cp systemd/fpm74_status_monitor/php-fpm74-status-monitor.service \
  /etc/systemd/system/
sudo cp systemd/fpm74_status_monitor/php-fpm74-status-monitor.timer \
  /etc/systemd/system/
```

## 应用 PHP-FPM 和 Nginx 配置

确认 PHP-FPM 7.4 配置包含：

```ini
pm.status_path = /phpfpm_74_status
```

确认 Nginx location 中的 socket 与 PHP-FPM 的 `listen` 完全一致：

```text
PHP-FPM: listen = /run/php/php7.4-fpm.sock
Nginx:   fastcgi_pass unix:/run/php/php7.4-fpm.sock;
```

然后检查并重载配置：

```bash
sudo nginx -t
sudo systemctl reload nginx
sudo systemctl restart php-fpm74.service
```

如果你的服务名称不是 `php-fpm74.service`，请先查看：

```bash
systemctl list-units --type=service | grep -E 'php.*fpm|fpm.*php'
```

## 先手动测试 status 页面

在启用 timer 前，先确认本机状态页能返回 PHP-FPM 数据：

```bash
curl --fail http://127.0.0.1/phpfpm_74_status
```

正常输出应包含类似内容：

```text
pool:                 www
process manager:      dynamic
accepted conn:        27082
listen queue:         0
active processes:     0
idle processes:       20
total processes:      20
```

如果返回 `404`、`502` 或连接失败，先不要启用监控，依次检查：

```bash
sudo nginx -t
sudo systemctl status nginx --no-pager
sudo systemctl status php-fpm74.service --no-pager
ls -l /run/php/php7.4-fpm.sock
```

## 手动运行监控脚本

第一次运行只建立基线，因此会显示：

```text
status=baseline traffic=N/A req/sec
```

执行：

```bash
sudo /usr/local/bin/php-fpm74_status_monitor.sh
```

再次运行后会根据 `accepted conn` 的增量输出：

```text
status=ok traffic=2.70 req/sec accepted_conn=27082
```

如果 PHP-FPM 重启导致 `accepted conn` 归零，脚本会自动重新建立基线，不会计算出负数流量。

## 启用每分钟监控

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now php-fpm74-status-monitor.timer
```

检查 timer：

```bash
systemctl status php-fpm74-status-monitor.timer --no-pager
systemctl list-timers php-fpm74-status-monitor.timer
```

立即执行一次 service：

```bash
sudo systemctl start php-fpm74-status-monitor.service
```

查看 service 日志：

```bash
journalctl -u php-fpm74-status-monitor.service -n 50 --no-pager
```

## 日志和状态文件

监控日志：

```text
/var/log/php-fpm-monitor/php-fpm74-status.log
```

上一次采样的状态文件：

```text
/var/lib/php-fpm-monitor/php-fpm74.state
```

实时查看流量：

```bash
tail -f /var/log/php-fpm-monitor/php-fpm74-status.log
```

脚本每次执行都会记录：

- `traffic`：根据采样差值计算出的请求速率
- `accepted_conn`：PHP-FPM 自启动以来累计接受的连接数
- `status=baseline`：正在建立基线或需要重新建立基线
- `status=ok`：本次成功计算出请求速率
- `status=unavailable`：无法访问 status 页面
- `status=invalid`：status 页面缺少可解析的 `accepted conn`

## 自定义参数

脚本支持：

```bash
sudo /usr/local/bin/php-fpm74_status_monitor.sh --help
```

例如使用不同的 status URL 和日志路径：

```bash
sudo /usr/local/bin/php-fpm74_status_monitor.sh \
  --url http://127.0.0.1/phpfpm_74_status \
  --log-file /var/log/php-fpm-monitor/php-fpm74-status.log \
  --state-file /var/lib/php-fpm-monitor/php-fpm74.state
```

systemd service 默认执行：

```ini
ExecStart=/usr/local/bin/php-fpm74_status_monitor.sh
```

## 停止监控

```bash
sudo systemctl disable --now php-fpm74-status-monitor.timer
```

停止 timer 不会删除已经记录的日志和状态文件。
