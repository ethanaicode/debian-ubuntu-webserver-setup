# nginx-error-client-ban

根据 Nginx 错误日志中 `client: IP` 的出现频率自动封禁客户端 IP。
脚本默认每分钟运行一次，在最近 120 秒内统计所有匹配的 `*.error.log` 文件；达到阈值的 IP 会加入 **ipset**，并通过 **iptables** 丢弃后续连接。

## 重要风险

> **这是一个有风险的自动封禁操作。启用前请务必先使用 `--dry-run` 检查结果。**

本脚本不像 `nginx-ratelimit-ban` 那样只处理 `limiting requests`，而是统计错误日志中所有带有 `client:` 的记录。因此以下情况可能造成误封：

- 普通客户端请求触发了大量正常错误，例如 404、400 或上游错误。
- 多个用户经过同一个 NAT、公司出口或校园网访问，共用一个公网 IP。
- Nginx 位于 CDN、反向代理或负载均衡器之后，日志中的 `client` 可能是代理 IP，而不是访客真实 IP。
- 管理员、监控服务或搜索引擎爬虫触发了大量错误。
- 错误日志格式或时间不正确，导致统计结果不准确。

封禁发生在服务器的 `iptables INPUT` 链，可能影响 SSH、面板、API 和其他所有入站服务。请先确认 SSH 管理来源不会被误封，并准备好通过控制台或带外管理解除封禁。

建议流程：

1. 使用 `--dry-run` 运行并观察至少一段时间。
2. 检查候选 IP 是否属于可信代理、办公网络、监控或管理员来源。
3. 初次启用时使用较高阈值和较短封禁时间。
4. 确认没有误封后，再交给 systemd 定时运行。

## 工作方式

```text
nginx error.log
    -> 查找带有 client: IP 的记录
    -> 只统计最近 N 秒
    -> 按 IP 计数
    -> 达到阈值
    -> 加入 nginx_error_client_ban
    -> iptables DROP
```

封禁由 ipset 的 TTL 自动过期，默认封禁 24 小时。脚本使用独立的 `nginx_error_client_ban` ipset，不会修改原 `nginx_ratelimit_ban` 集合。

## 安装

```bash
# 1. 安装依赖
sudo apt install -y gawk ipset iptables

# 2. 安装脚本
sudo cp auto_ban_error_client.sh /usr/local/bin/
sudo chmod +x /usr/local/bin/auto_ban_error_client.sh

# 3. 安装 systemd units
sudo cp nginx-error-client-ban.service /etc/systemd/system/
sudo cp nginx-error-client-ban.timer /etc/systemd/system/

# 4. 重载 systemd
sudo systemctl daemon-reload
```

## 启用前测试

只查看候选 IP，不会创建 ipset，也不会修改防火墙：

```bash
sudo /usr/local/bin/auto_ban_error_client.sh --dry-run
```

提高阈值并扩大观察窗口：

```bash
sudo /usr/local/bin/auto_ban_error_client.sh \
  --dry-run \
  --window 300 \
  --threshold 50
```

确认输出合理后，再启用定时器：

```bash
sudo systemctl enable --now nginx-error-client-ban.timer
sudo systemctl start nginx-error-client-ban.service
```

查看执行结果：

```bash
systemctl status nginx-error-client-ban.timer
journalctl -u nginx-error-client-ban.service -n 50 --no-pager
```

## 参数

| 参数 | 默认值 | 说明 |
|---|---:|---|
| `--log-dir` | `/www/wwwlogs` | Nginx 错误日志目录 |
| `--log-pattern` | `*.error.log` | 错误日志文件匹配模式 |
| `--window` | `120` | 回溯时间窗口，单位为秒 |
| `--threshold` | `30` | 窗口内同一 IP 出现次数达到该值时封禁 |
| `--ban-seconds` | `86400` | 封禁时间，单位为秒，默认 24 小时 |
| `--set-name` | `nginx_error_client_ban` | ipset 名称 |
| `--dry-run` | - | 只输出候选 IP，不修改防火墙 |

systemd 默认配置位于 `nginx-error-client-ban.service`：

```ini
ExecStart=/usr/local/bin/auto_ban_error_client.sh --window 120 --threshold 30 --ban-seconds 86400
```

修改 `/etc/systemd/system/nginx-error-client-ban.service` 后，需要执行：

```bash
sudo systemctl daemon-reload
sudo systemctl restart nginx-error-client-ban.timer
```

## 排查和解除封禁

确认 Nginx 日志中确实存在可识别的客户端记录：

```bash
grep 'client:' /www/wwwlogs/*.error.log | tail
```

查看当前封禁：

```bash
sudo ipset list nginx_error_client_ban
```

解除单个 IP：

```bash
sudo ipset del nginx_error_client_ban 1.2.3.4
```

清空该脚本创建的全部封禁：

```bash
sudo ipset flush nginx_error_client_ban
```

停用定时器：

```bash
sudo systemctl disable --now nginx-error-client-ban.timer
```

如果需要立即移除 iptables 规则，请先确认规则内容，再执行：

```bash
sudo iptables -C INPUT -m set --match-set nginx_error_client_ban src -j DROP
sudo iptables -D INPUT -m set --match-set nginx_error_client_ban src -j DROP
```

## 与 nginx-ratelimit-ban 的区别

两个服务使用相同的 `ipset + iptables` 封禁机制，但使用不同的集合：

| 服务 | ipset | 日志来源 | 触发条件 |
|---|---|---|---|
| `nginx-ratelimit-ban` | `nginx_ratelimit_ban` | error.log | 出现 `limiting requests` |
| `nginx-error-client-ban` | `nginx_error_client_ban` | error.log | `client: IP` 在窗口内出现次数达到阈值 |

不建议在没有充分观察和调试的情况下同时启用两个服务，因为它们可能对同一个来源执行两次独立封禁。

当前脚本主要按 IPv4 地址设计。若服务器需要稳定处理 IPv6，需额外配置 IPv6 ipset 和 `ip6tables` 规则后再启用。
