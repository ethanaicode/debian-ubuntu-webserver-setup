#!/bin/zsh

# 定义源目录（当前脚本所在目录下的 .ssh）
# "${0:A:h}" 是 Zsh 的写法，表示获取当前脚本所在的绝对路径
SOURCE_DIR="${0:A:h}/.ssh"
TARGET_DIR="$HOME/.ssh"

echo "=== 开始恢复 SSH 密钥 ==="

# 复制密钥文件
cp -v "$SOURCE_DIR"/id_ed25519* "$TARGET_DIR/"

# 提前自动写入 GitHub 的服务器指纹（免去手动输入 yes 的烦恼）
ssh-keyscan -t ed25519 github.com >> ~/.ssh/known_hosts 2>/dev/null

echo "✨ SSH 密钥恢复完成！"
