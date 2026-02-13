#!/bin/bash

# 脚本作用: 自动从Git仓库拉取最新代码并构建项目
# 适用于公开的git仓库，私有仓库请确保已配置SSH密钥或凭据
# 使用方法: ./auto_build_node_project.sh [--debug]
#     定时任务: 0 3 * * * /path/to/auto_build_node_project.sh

####################################
# 基本配置
####################################
# 本地仓库目录
REPO_DIR="/path/to/your/local/node_project"
# 目标分支名
BRANCH="target-branch"
# 构建命令，可以根据需要进行修改
BUILD_COMMAND="npm run docs:build"
# 日志目录      
LOG_DIR="/path/to/your/logs"
# 日志文件路径            
LOG_FILE="$LOG_DIR/build-node.log"
# Debug 模式，0=关闭，1=开启          
DEBUG_MODE=0

####################################
# 参数解析
####################################
while [[ $# -gt 0 ]]; do
    case $1 in
        --debug|-d)
            DEBUG_MODE=1
            shift
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 [--debug|-d]"
            exit 1
            ;;
    esac
done

####################################
# 日志目录不存在就创建
####################################
mkdir -p "$LOG_DIR"

####################################
# 日志函数
####################################
log() {
  local message="[$(date '+%Y-%m-%d %H:%M:%S')] $1"
  # 写入日志文件
  echo "$message" >> "$LOG_FILE"
  # 如果开启 debug 模式，同时输出到控制台
  if [ "$DEBUG_MODE" -eq 1 ]; then
    echo "$message"
  fi
}

####################################
# 开始记录日志
####################################
if [ "$DEBUG_MODE" -eq 1 ]; then
  echo "Debug mode enabled - logs will be displayed in console"
fi

log "======== Task Started ========="
log "Repository Directory: $REPO_DIR"
log "Target Branch: $BRANCH"
log "Build Command: $BUILD_COMMAND"

####################################
# 检查 Git 是否可用
####################################
if ! command -v git &> /dev/null; then
    log "Error: Git is not installed."
    exit 1
fi

####################################
# 进入仓库目录并更新代码
####################################
# 进入本地仓库目录
if ! cd "$REPO_DIR"; then
    log "Error: Directory $REPO_DIR does not exist."
    exit 1
fi

# 检查目标分支是否存在
if ! git rev-parse --verify "$BRANCH" &> /dev/null; then
    log "Error: Branch $BRANCH does not exist."
    exit 1
fi

# 切换到目标分支
if ! git checkout "$BRANCH"; then
    log "Error: Failed to checkout branch $BRANCH."
    exit 1
fi

# 记录拉取前的 commit hash
BEFORE_PULL=$(git rev-parse HEAD)
log "Current commit: $BEFORE_PULL"

# 拉取最新代码
if ! git pull origin "$BRANCH"; then
    log "Error: Failed to pull branch $BRANCH."
    exit 1
fi

# 获取拉取后的 commit hash
AFTER_PULL=$(git rev-parse HEAD)
log "After pull commit: $AFTER_PULL"

# 比较拉取前后的 commit hash
if [ "$BEFORE_PULL" = "$AFTER_PULL" ]; then
    log "No new changes detected. Skipping build."
    log "======== Task Completed (No Build Required) ========"
    log ""
    exit 0
fi

log "New changes detected. Starting build..."

# 执行构建命令
if ! $BUILD_COMMAND; then
    log "Error: Build command '$BUILD_COMMAND' failed."
    exit 1
fi

####################################
# 任务完成
####################################
log "======== Task Completed Successfully ========"
log ""
