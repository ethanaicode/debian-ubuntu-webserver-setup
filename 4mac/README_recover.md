# recover.sh

这个脚本用于在清理后，快速恢复常用 SSH 密钥和 known_hosts。

目标是保持足够简单，同时保留最小可扩展能力。

## 快速使用

1. 把 `recover.sh` 和同级 `.ssh/` 目录放到移动硬盘。
2. 插上硬盘后执行：

```bash
chmod +x ./recover.sh
./recover.sh
```

## 目录结构

默认读取脚本同级 `.ssh/`：

```text
4mac/
  recover.sh
  .ssh/
    id_ed25519
    id_ed25519.pub
    config
    known_hosts
    known_hosts_hosts.txt
```

也可以覆盖源目录：

```bash
RECOVER_SOURCE_DIR=/Volumes/YourDisk/my-ssh ./recover.sh
```

## 会恢复什么

- `id_ed25519` / `id_ed25519.pub`
- `id_rsa` / `id_rsa.pub`
- `config`
- `known_hosts`

脚本会自动设置权限：

- `~/.ssh` 目录：`700`（目录需要 `x` 才能进入）
- 私钥和 `config`：`600`
- `.pub` 和 `known_hosts`：`644`

注意：不要对目录执行 `chmod -R 600 ~/.ssh`，否则会丢失目录 `x` 权限，导致 SSH/agent 异常。

## 预写服务器指纹

默认预写：

- `github.com`

你也可以在 `.ssh/known_hosts_hosts.txt` 里每行写一个主机：

```text
github.com
gitlab.com
my-server.example.com
192.168.1.10
```

脚本会用 `ssh-keyscan -H -t ed25519` 追加到 `~/.ssh/known_hosts`，减少首次连接确认步骤。

## 未来扩展建议

- 想增加默认主机：改脚本顶部的 `DEFAULT_HOSTS`。
- 想恢复更多文件：在 `restore_ssh_files` 中增加 `copy_if_exists "文件名"`。