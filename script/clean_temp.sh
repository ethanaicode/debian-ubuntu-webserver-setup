#!/bin/bash

# 脚本作用: 清理指定目录下超过X天的临时文件和空目录

# 设置要清理的目录
TARGET_DIR="/path/to/your/temp/dir"

# 设置要清理超过几天的文件和目录
DAYS=7

# 日志文件
LOG_FILE="/var/log/clean_temp.log"

# 检查日志文件是否存在，如果不存在则创建
if [ ! -f "$LOG_FILE" ]; then
    # 尝试创建文件并设置读写权限为666
    touch "$LOG_FILE"
    if [ $? -ne 0 ]; then
        echo "[$(date "+%Y-%m-%d %H:%M:%S")] Failed to create log file $LOG_FILE." >&2
        exit 1
    fi
    chmod 666 "$LOG_FILE"
    if [ $? -ne 0 ]; then
        echo "[$(date "+%Y-%m-%d %H:%M:%S")] Failed to set permissions for log file $LOG_FILE." >&2
        exit 1
    fi
    echo "[$(date "+%Y-%m-%d %H:%M:%S")] Log file $LOG_FILE created." >> "$LOG_FILE"
fi

# 检查目标目录是否存在
if [ ! -d "$TARGET_DIR" ]; then
    echo "[$(date "+%Y-%m-%d %H:%M:%S")] Target directory $TARGET_DIR does not exist." >> "$LOG_FILE"
    exit 1
fi

# 当前时间
NOW=$(date "+%Y-%m-%d %H:%M:%S")

# 记录开始清理的时间和目标目录信息到日志文件
echo "-----------------------------" >> "$LOG_FILE"
echo "[$NOW] Cleaning started" >> "$LOG_FILE"
echo "Target: $TARGET_DIR | Days: $DAYS" >> "$LOG_FILE"
echo "-----------------------------" >> "$LOG_FILE"

# 删除超过X天的文件并记录到日志
find "$TARGET_DIR" -type f -mtime +"$DAYS" -print -delete >> "$LOG_FILE" 2>&1

# 删除超过X天的空目录并记录到日志
find "$TARGET_DIR" -type d -empty -mtime +"$DAYS" -print -delete >> "$LOG_FILE" 2>&1

# 因为删除目录下的文件后，目录的更新日期会变成最近，从而会影响删除空目录的目标
# 可以考虑用下面的命令来删除空目录，但这个会删除所有空目录，不管它们的修改时间，请根据需求选择采用哪种方式

# 如果需要删除所有空目录（不考虑修改时间），可以使用下面的命令
# find "$TARGET_DIR" -type d -empty -print -delete >> "$LOG_FILE" 2>&1

# 记录清理完成的时间到日志文件
echo "-----------------------------" >> "$LOG_FILE"
echo "[$(date "+%Y-%m-%d %H:%M:%S")] Cleaning completed." >> "$LOG_FILE"
echo "" >> "$LOG_FILE"
