#!/bin/bash

# 默认日志文件路径
DEFAULT_LOG_FILE="/var/log/nginx/access.log"
LOG_FILE="$DEFAULT_LOG_FILE"

# 获取今天的日期
TODAY=$(date +"%d/%b/%Y")

# 输出文件路径
OUTPUT_FILE="/var/log/nginx/analyze_$(date +%Y-%m-%d).txt"

# 清空输出文件内容
> "$OUTPUT_FILE"

# 检查日志文件是否存在
if [ ! -f "$LOG_FILE" ]; then
  echo "Error: Log file '$LOG_FILE' not found." | tee -a "$OUTPUT_FILE"
  exit 1
fi
echo "开始分析日志文件：$LOG_FILE" | tee -a "$OUTPUT_FILE"
echo | tee -a "$OUTPUT_FILE"

# 分析今天日志中排名前二十的URL及其流量
echo "正在分析今日流量消耗排名前二十的URL：" | tee -a "$OUTPUT_FILE"
awk -v today="$TODAY" '$4 ~ today {print $7, $10}' "$LOG_FILE" | \
awk '{url_traffic[$1] += $2} END {for (url in url_traffic) print url, url_traffic[url]}' | \
sort -nrk2 | head -20 | \
awk '{
    if ($2 >= 1073741824)
        printf "%s %.2f GB\n", $1, $2/1073741824;
    else if ($2 >= 1048576)
        printf "%s %.2f MB\n", $1, $2/1048576;
    else if ($2 >= 1024)
        printf "%s %.2f KB\n", $1, $2/1024;
    else
        printf "%s %.2f B\n", $1, $2;
}' | tee -a "$OUTPUT_FILE"
echo | tee -a "$OUTPUT_FILE"

# 统计今日截止目前的总流量消耗
echo "今日截止目前的总流量消耗：" | tee -a "$OUTPUT_FILE"
awk -v today="$TODAY" '$4 ~ today {sum += $10} END {
    if (sum >= 1073741824)
        printf "%.2f GB\n", sum/1073741824;
    else if (sum >= 1048576)
        printf "%.2f MB\n", sum/1048576;
    else if (sum >= 1024)
        printf "%.2f KB\n", sum/1024;
    else
        printf "%.2f B\n", sum;
}' "$LOG_FILE" | tee -a "$OUTPUT_FILE"

# 输出缓存文件的路径
echo
echo "分析结果已保存至文件：$OUTPUT_FILE"
