#!/usr/bin/env bash

set -euo pipefail

# Monitor PHP-FPM 7.4 status metrics once per invocation.
# The systemd timer runs this script every minute.

STATUS_URL="http://127.0.0.1/phpfpm_74_status"
LOG_DIR="/var/log/php-fpm-monitor"
LOG_FILE="$LOG_DIR/php-fpm74-status.log"
QUEUE_WARN=10

usage() {
  cat <<'EOF'
Usage:
  php-fpm74_status_monitor.sh [options]

Options:
  --url URL             PHP-FPM status URL (default: http://127.0.0.1/phpfpm_74_status)
  --log-file PATH       Output log path (default: /var/log/php-fpm-monitor/php-fpm74-status.log)
  --queue-warn N        Warn when listen queue >= N (default: 10)
  -h, --help            Show this help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --url)
      [[ $# -ge 2 ]] || { echo "Missing value for --url" >&2; exit 1; }
      STATUS_URL="$2"
      shift 2
      ;;
    --log-file)
      [[ $# -ge 2 ]] || { echo "Missing value for --log-file" >&2; exit 1; }
      LOG_FILE="$2"
      LOG_DIR="$(dirname "$LOG_FILE")"
      shift 2
      ;;
    --queue-warn)
      [[ $# -ge 2 ]] || { echo "Missing value for --queue-warn" >&2; exit 1; }
      QUEUE_WARN="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if ! [[ "$QUEUE_WARN" =~ ^[0-9]+$ ]]; then
  echo "queue-warn must be a non-negative integer." >&2
  exit 1
fi

if ! command -v curl >/dev/null 2>&1; then
  echo "curl is required. Install: apt install -y curl" >&2
  exit 1
fi

mkdir -p "$LOG_DIR"

status_output="$(curl --fail --silent --show-error --max-time 5 "$STATUS_URL" 2>&1)" || {
  timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
  printf '%s status=unavailable error=%s\n' "$timestamp" "$status_output" >> "$LOG_FILE"
  exit 1
}

get_metric() {
  local metric="$1"
  awk -F: -v key="$metric" '$1 == key {sub(/^[[:space:]]+/, "", $2); print $2; exit}' <<< "$status_output"
}

# Parse the stable plain-text status keys so the log remains easy to process.
accepted_conn="$(get_metric 'accepted conn')"
listen_queue="$(get_metric 'listen queue')"
max_listen_queue="$(get_metric 'max listen queue')"
idle_processes="$(get_metric 'idle processes')"
active_processes="$(get_metric 'active processes')"
max_active_processes="$(get_metric 'max active processes')"
total_processes="$(get_metric 'total processes')"

for metric in accepted_conn listen_queue max_listen_queue idle_processes active_processes max_active_processes total_processes; do
  if [[ -z "${!metric}" || ! "${!metric}" =~ ^[0-9]+$ ]]; then
    timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
    printf '%s status=invalid metric=%s\n' "$timestamp" "$metric" >> "$LOG_FILE"
    exit 1
  fi
done

timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
if (( listen_queue >= QUEUE_WARN )); then
  level="warning"
else
  level="ok"
fi

printf '%s status=%s accepted_conn=%s listen_queue=%s max_listen_queue=%s idle_processes=%s active_processes=%s max_active_processes=%s total_processes=%s\n' \
  "$timestamp" "$level" "$accepted_conn" "$listen_queue" "$max_listen_queue" \
  "$idle_processes" "$active_processes" "$max_active_processes" "$total_processes" >> "$LOG_FILE"

echo "$(tail -n 1 "$LOG_FILE")"
