#!/bin/bash

# 新版需要额外的脚本 convert_unit.sh，用于转换单位

# 默认日志文件路径和其他初始设置
DEFAULT_LOG_FILE="/var/log/nginx/access.log"
LOG_FILE="$DEFAULT_LOG_FILE"
TODAY=$(date +"%d/%b/%Y")
OUTPUT_FILE="/var/log/nginx/analyze_$(date +%Y-%m-%d).txt"

# 清空输出文件
> "$OUTPUT_FILE"

# 检查日志文件是否存在
if [ ! -f "$LOG_FILE" ]; then
  echo "Error: Log file '$LOG_FILE' not found." | tee -a "$OUTPUT_FILE"
  exit 1
fi

# 输出开始信息
echo "开始分析日志文件：$LOG_FILE" | tee -a "$OUTPUT_FILE"
echo | tee -a "$OUTPUT_FILE"

# 分析流量并使用 convert_unit.sh 转换单位
echo "正在分析今日流量消耗排名前二十的URL：" | tee -a "$OUTPUT_FILE"
awk -v today="$TODAY" '$4 ~ today {print $7, $10}' "$LOG_FILE" | \
awk '{url_traffic[$1] += $2} END {for (url in url_traffic) print url, url_traffic[url]}' | \
sort -nrk2 | head -20 | \
while read url traffic; do
    echo "$url $(./utils/convert_unit.sh $traffic)" | tee -a "$OUTPUT_FILE"
done
echo | tee -a "$OUTPUT_FILE"

# 统计总流量并转换单位
echo "今日截止目前的总流量消耗：" | tee -a "$OUTPUT_FILE"
total_traffic=$(awk -v today="$TODAY" '$4 ~ today {sum += $10} END {print sum}' "$LOG_FILE")
echo $(./utils/convert_unit.sh $total_traffic) | tee -a "$OUTPUT_FILE"

# 输出结果文件路径
echo
echo "分析结果已保存至文件：$OUTPUT_FILE"
