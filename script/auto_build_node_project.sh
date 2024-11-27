#!/bin/bash

# 仅适用于公开的git仓库，不适用于私有仓库（需要输入密码）
# 请确保在执行脚本时不需要输入密码

# 配置变量
REPO_DIR="/path/to/your/local/repo"  # 本地仓库目录
BRANCH="target-branch"               # 目标分支名
BUILD_COMMAND="npm run docs:dev"     # 构建命令，可以根据需要进行修改
LOG_FILE="/path/to/your/logfile.log" # 日志文件路径

# 记录任务开始
{
    echo "======== Task Started at $(date) ========"
    echo "Repository Directory: $REPO_DIR"
    echo "Target Branch: $BRANCH"
    echo "Build Command: $BUILD_COMMAND"
} >> "$LOG_FILE"

# 检查 Git 是否可用
if ! command -v git &> /dev/null; then
    echo "Error: Git is not installed." >> "$LOG_FILE"
    exit 1
fi

# 进入仓库目录
if ! cd "$REPO_DIR"; then
    echo "Error: Directory $REPO_DIR does not exist." >> "$LOG_FILE"
    exit 1
fi

# 检查目标分支是否存在
if ! git rev-parse --verify "$BRANCH" &> /dev/null; then
    echo "Error: Branch $BRANCH does not exist." >> "$LOG_FILE"
    exit 1
fi

# 切换到目标分支并拉取最新代码
if ! git checkout "$BRANCH" || ! git pull origin "$BRANCH"; then
    echo "Error: Failed to update $BRANCH." >> "$LOG_FILE"
    exit 1
fi

# 执行构建命令
if ! $BUILD_COMMAND; then
    echo "Error: Build command '$BUILD_COMMAND' failed." >> "$LOG_FILE"
    exit 1
fi

echo "======== Task Completed Successfully at $(date) ========" >> "$LOG_FILE"
