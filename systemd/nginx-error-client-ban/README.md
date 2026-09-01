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

> **教训**：曾经出现过 `127.0.0.1` 被脚本误封，导致本机回环通信中断、业务大范围异常。脚本现已内置白名单机制防止这种情况，但仍建议按下面的流程谨慎启用。

建议流程：

1. 使用 `--dry-run` 运行并观察至少一段时间。
2. 检查候选 IP 是否属于可信代理、办公网络、监控或管理员来源。
3. 将确认可信的 IP（包括服务器自身、内网互通地址、SSH 管理来源）加入白名单。
4. 初次启用时使用较高阈值和较短封禁时间。
5. 确认没有误封后，再交给 systemd 定时运行。

> **缩小误杀范围**：如果发现某类正常错误（如上游超时、404）频繁触发误封，可以编辑 `auto_ban_error_client.sh` 中 gawk 脚本的匹配行（形如 `/^[0-9]{4}\/.../ && /client:/ {`），追加更多 `&& /xxx/` 条件，只统计特定错误关键字（例如 `&& /limiting requests/` 或 `&& /upstream timed out/`），像 `nginx-ratelimit-ban` 那样缩小统计范围，降低误封概率。

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

## 白名单机制

脚本内置白名单，命中白名单的 IP 在统计阶段就会被跳过，既不会出现在候选列表中，也不会被封禁；封禁前还会二次核实白名单，双重保护。

- **内置白名单**：`127.0.0.1` 和 `::1` 始终受保护，无法通过任何参数移除。
- **`--whitelist`**：追加额外白名单 IP，支持逗号分隔，可重复使用：

  ```bash
  sudo /usr/local/bin/auto_ban_error_client.sh \
    --whitelist 10.0.0.5,203.0.113.9 \
    --dry-run
  ```

- **`--whitelist-file`**：从文件读取白名单，每行一个 IP，支持 `#` 注释：

  ```text
  # /etc/nginx-error-client-ban/whitelist.txt
  10.0.0.5
  203.0.113.9   # 监控探测节点
  ```

  ```bash
  sudo /usr/local/bin/auto_ban_error_client.sh \
    --whitelist-file /etc/nginx-error-client-ban/whitelist.txt \
    --dry-run
  ```

建议加入白名单的 IP：

- 服务器自身的内网 / 公网 IP
- SSH、面板等管理入口来源 IP
- 反向代理、CDN 回源、负载均衡器 IP
- 监控探测、健康检查来源 IP

每次运行都会在日志开头打印生效的白名单，便于确认配置是否正确：

```text
Whitelisted IPs (never banned): 127.0.0.1,::1,10.0.0.5,203.0.113.9
```

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

同时验证白名单是否生效（白名单 IP 不应出现在候选列表中）：

```bash
sudo /usr/local/bin/auto_ban_error_client.sh \
  --dry-run \
  --whitelist-file /etc/nginx-error-client-ban/whitelist.txt
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
| `--whitelist` | - | 额外白名单 IP，逗号分隔，可重复使用 |
| `--whitelist-file` | - | 白名单文件路径，每行一个 IP，支持 `#` 注释 |
| `--dry-run` | - | 只输出候选 IP，不修改防火墙 |

`127.0.0.1` 和 `::1` 始终位于白名单中，不受上述参数影响。

systemd 默认配置位于 `nginx-error-client-ban.service`：

```ini
ExecStart=/usr/local/bin/auto_ban_error_client.sh --window 120 --threshold 30 --ban-seconds 86400
```

修改 `/etc/systemd/system/nginx-error-client-ban.service` 后，需要执行：

```bash
sudo systemctl daemon-reload
sudo systemctl restart nginx-error-client-ban.timer
```

强烈建议在 `ExecStart` 中加上 `--whitelist-file`，避免每次修改 service 文件才能调整白名单：

```ini
ExecStart=/usr/local/bin/auto_ban_error_client.sh --window 120 --threshold 30 --ban-seconds 86400 --whitelist-file /etc/nginx-error-client-ban/whitelist.txt
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
