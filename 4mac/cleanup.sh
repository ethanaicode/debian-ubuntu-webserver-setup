#!/bin/bash

# Replace this sh to ~/.config/cleanup.sh and run it to clean up your local development environment on Mac.

# display datetime
echo "===== 任务开始 $(date '+%Y-%m-%d %H:%M:%S') ====="
echo "开始清理本地开发环境..."

# 1. 清理 SSH 密钥和 Keychain
echo "清理 SSH 和 Git 凭证..."

rm -rf ~/.ssh/id_* ~/.ssh/config ~/.ssh/known_hosts*
rm -f ~/.git-credentials
security delete-generic-password -l "git" ~/Library/Keychains/login.keychain-db 2>/dev/null || true

# 2. 清理 Zsh/Bash 历史
echo "清理命令历史..."

cat /dev/null > ~/.zsh_history
# cat /dev/null > ~/.bash_history
# cat /dev/null > ~/.history

# 3. 清理浏览器历史和 Cookies
echo "清理浏览器数据..."

pkill -9 "Google Chrome"
sleep 2
rm -rf ~/Library/Application\ Support/Google/Chrome
rm -rf ~/Library/Caches/Google/Chrome
rm -rf ~/Library/Caches/ChromeAppCache
rm -rf ~/Library/Saved\ Application\ State/com.google.Chrome.savedState

# rm -f ~/Library/Safari/History.db*
# rm -f ~/Library/Application\ Support/Firefox/Profiles/*.default-release/places.sqlite

# 4. 清理临时文件
echo "清理临时文件..."

rm -rf ~/tmp/*
# rm -rf ~/Library/Caches/*
# rm -rf /var/tmp/*
# rm -rf /tmp/*

# 5. 清理编辑器配置（可选）
# echo "清理编辑器配置..."

# rm -rf ~/.vscode/extensions/*
# rm -f ~/.vscode/settings.json

# 6. 清理 Homebrew 缓存
# echo "清理 Homebrew..."

# brew cleanup -s 2>/dev/null || true

# 7. 清理 npm/yarn 全局缓存
# echo "清理包管理器缓存..."

# npm cache clean --force 2>/dev/null || true
# yarn cache clean 2>/dev/null || true

echo "清理完成！设备已重置为新状态"
echo "===== 任务结束 $(date '+%Y-%m-%d %H:%M:%S') ====="