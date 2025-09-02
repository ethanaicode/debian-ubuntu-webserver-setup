#!/usr/bin/env bash
# file: quick_http.sh
# 说明：快速启动一个 HTTP 文件服务器，支持局域网访问，用于快速分享文件
#     推荐在 macOS 上使用，其他系统请自行修改脚本
# 使用方法：./quick_http.sh [端口]

# 定义脚本执行环境
set -euo pipefail

# 定义常量
DIR="/Applications/MAMP/htdocs/shares"
PORT="${1:-33333}"   # 可通过第一个参数自定义端口，如：./quick_http.sh 8080

# 端口简单校验
if ! [[ "$PORT" =~ ^[0-9]+$ ]] || (( PORT < 1 || PORT > 65535 )); then
  echo "无效端口：$PORT（应为 1-65535 的整数）"
  exit 1
fi

# 目录检查
if [[ ! -d "$DIR" ]]; then
  echo "目录不存在：$DIR"
  exit 1
fi

cd "$DIR"

# 获取本机局域网 IP（优先 Wi-Fi，有线为 en1，兜底用 Python 获取默认路由 IP）
get_ip() {
  ipconfig getifaddr en0 2>/dev/null || \
  ipconfig getifaddr en1 2>/dev/null || \
  python3 - <<'PY'
import socket
s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
try:
    s.connect(("8.8.8.8", 80))
    print(s.getsockname()[0])
finally:
    s.close()
PY
}

IP="$(get_ip || echo 127.0.0.1)"
URL_LOCAL="http://localhost:${PORT}"
URL_LAN="http://${IP}:${PORT}"

echo "📂 当前目录：$PWD"
echo "🚀 启动 HTTP 服务中（0.0.0.0:${PORT}）..."
echo "🔗 本机访问：$URL_LOCAL"
echo "🌐 局域网访问：$URL_LAN"
echo "⏹ 按 Ctrl+C 可停止服务"

# 自动在本机打开页面（可选项，需要的话可以取消注释）
# command -v open >/dev/null && open "$URL_LOCAL" >/dev/null 2>&1 || true

# 监听所有网卡，支持局域网访问
exec python3 -m http.server "$PORT" --bind 0.0.0.0
