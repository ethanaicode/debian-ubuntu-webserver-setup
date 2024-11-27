#!/bin/bash
# 这个脚本接受一个数字（字节为单位的流量），并转换为适当的单位

bytes=$1  # 从命令行参数获取字节数

if (( bytes >= 1073741824 )); then
    printf "%.2f GB\n" $(echo "$bytes/1073741824" | bc -l)
elif (( bytes >= 1048576 )); then
    printf "%.2f MB\n" $(echo "$bytes/1048576" | bc -l)
elif (( bytes >= 1024 )); then
    printf "%.2f KB\n" $(echo "$bytes/1024" | bc -l)
else
    printf "%.2f B\n" $bytes
fi