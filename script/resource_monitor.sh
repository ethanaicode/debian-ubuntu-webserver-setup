#!/bin/bash

# 脚本作用: 服务器资源监控脚本（重点监控 CPU 占用）
# 每分钟记录 CPU 使用率、内存使用率、占用最多 CPU/内存的进程
# 可结合 systemd 设置为开机启动
# update: 2025-04-30

export LC_ALL=C
LOG_DIR="/var/log/resource_monitor"
LOG_FILE="$LOG_DIR/monitor.log"
mkdir -p "$LOG_DIR"

if [ ! -w "$LOG_DIR" ]; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') Log directory not writable!" >> /tmp/resource_monitor_error.log
    exit 1
fi

while sleep 10; do
    {
        echo "==== $(date '+%Y-%m-%d %H:%M:%S') ===="

        echo "CPU Summary:"
        top -bn1 | grep "Cpu(s)"

        echo ""
        echo "Memory Summary:"
        free -h

        # # Old command to get memory usage
        # echo ""
        # echo "Top 3 memory-consuming processes (from top):"
        # # 这条命令是从 top 命令中获取内存占用前三的进程
        # # 可能需要根据 top 的输出行数不同进行调整（可手动执行这条命令看看结果)
        # top -b -o %MEM -n 1 | head -n 10 | tail -n 4

        echo ""
        echo "Top 5 CPU-consuming processes:"
        ps -eo pid,comm,%cpu,%mem --sort=-%cpu | head -n 6

        echo ""
        echo "Top 5 Memory-consuming processes:"
        ps -eo pid,comm,%cpu,%mem --sort=-%mem | head -n 6

        echo ""
    } >> "$LOG_FILE"

    # 每小时清理一次日志，保留最后 10000 行
    if [ "$(date +%M)" == "00" ]; then
        tail -n 10000 "$LOG_FILE" > "$LOG_FILE.tmp" && mv "$LOG_FILE.tmp" "$LOG_FILE"
    fi
done
