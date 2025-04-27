#!/bin/bash

# 服务器资源监控脚本
# 每分钟记录 CPU、内存、内存占用前三的进程
# 配合 systemd 可实现开机自启
# update: 2025-04-27

export LC_ALL=C

LOG_DIR="/var/log/resource_monitor"
mkdir -p "$LOG_DIR"

if [ ! -w "$LOG_DIR" ]; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') Log directory not writable!" >> /tmp/resource_monitor_error.log
    exit 1
fi

while sleep 60; do
    {
        echo "==== $(date '+%Y-%m-%d %H:%M:%S') ===="
        
        echo "CPU Summary:"
        top -bn1 | grep "Cpu(s)"
        
        echo ""
        echo "Memory Summary:"
        top -bn1 | grep "KiB Mem"
        
        echo ""
        echo "Top 3 memory-consuming processes (from top):"
        # 这条命令是从 top 命令中获取内存占用前三的进程
        # 可能需要根据 top 的输出行数不同进行调整（可手动执行这条命令看看结果)
        top -b -o %MEM -n 1 | head -n 10 | tail -n 4
        # ps -eo pid,comm,%mem --sort=-%mem | head -n 4
        
        echo ""
    } >> "$LOG_DIR/monitor.log"

    # 每小时清理一次日志大小，避免磁盘压力
    if [ "$(date +%M)" == "00" ]; then
        tail -n 10000 "$LOG_DIR/monitor.log" > "$LOG_DIR/monitor.log.tmp" && mv "$LOG_DIR/monitor.log.tmp" "$LOG_DIR/monitor.log"
    fi
done
