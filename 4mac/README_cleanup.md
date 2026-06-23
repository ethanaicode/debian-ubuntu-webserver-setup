# cleanup.sh LaunchAgent

这个目录提供 macOS 上运行 `cleanup.sh` 的 `launchd` 配置模板。

## 文件说明

- `cleanup.sh`：实际执行清理动作的脚本。
- `com.user.cleanup.plist`：LaunchAgent 配置文件模板。

## 先准备脚本

请把脚本放到：

```bash
~/.config/cleanup.sh
```

然后把 plist 里的 `YOUR_USERNAME` 替换成你的 macOS 用户名。

## 日志位置

该 LaunchAgent 会把输出写到你的用户目录下，便于追踪执行记录：

- 标准输出：`~/Library/Logs/cleanup/cleanup.out.log`
- 标准错误：`~/Library/Logs/cleanup/cleanup.err.log`

请先确保日志目录存在：

```bash
mkdir -p ~/Library/Logs/cleanup
```

## 安装与运行

1. 确保脚本可执行并已经放到 `~/.config/cleanup.sh`：

```bash
chmod +x ~/.config/cleanup.sh
```

2. 将 `com.user.cleanup.plist` 放到 `~/Library/LaunchAgents/`。

3. 把 plist 里的 `YOUR_USERNAME` 替换成你的用户名，然后加载配置：

```bash
launchctl bootstrap gui/$UID ~/Library/LaunchAgents/com.user.cleanup.plist
```

4. 如果想立刻验证，可以手动触发一次：

```bash
launchctl kickstart -k gui/$UID/com.user.cleanup
```

## 卸载

```bash
launchctl bootout gui/$UID ~/Library/LaunchAgents/com.user.cleanup.plist
```

## 说明

- 这个配置是 LaunchAgent，放到 `~/Library/LaunchAgents/` 并设置 `RunAtLoad` 后，会在用户登录时自动运行。
- 如果你要的是登录前的真正系统级开机执行，需要改成 LaunchDaemon，脚本也要改成 root 可访问的方式。
