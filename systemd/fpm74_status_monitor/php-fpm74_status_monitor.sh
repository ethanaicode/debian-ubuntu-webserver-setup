#!/usr/bin/env bash

set -euo pipefail

# Monitor PHP-FPM 7.4 traffic once per invocation.
# The systemd timer runs this script every minute.

STATUS_URL="http://127.0.0.1/phpfpm_74_status"
LOG_DIR="/var/log/php-fpm-monitor"
LOG_FILE="$LOG_DIR/php-fpm74-status.log"
STATE_FILE="/var/lib/php-fpm-monitor/php-fpm74.state"

usage() {
  cat <<'EOF'
Usage:
  php-fpm74_status_monitor.sh [options]

Options:
  --url URL             PHP-FPM status URL (default: http://127.0.0.1/phpfpm_74_status)
  --log-file PATH       Output log path (default: /var/log/php-fpm-monitor/php-fpm74-status.log)
  --state-file PATH     Counter state path (default: /var/lib/php-fpm-monitor/php-fpm74.state)
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
    --state-file)
      [[ $# -ge 2 ]] || { echo "Missing value for --state-file" >&2; exit 1; }
      STATE_FILE="$2"
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

if ! command -v curl >/dev/null 2>&1; then
  echo "curl is required. Install: apt install -y curl" >&2
  exit 1
fi

mkdir -p "$LOG_DIR"
mkdir -p "$(dirname "$STATE_FILE")"

status_output="$(curl --fail --silent --show-error --max-time 5 "$STATUS_URL" 2>&1)" || {
  timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
  printf '%s status=unavailable error=%s\n' "$timestamp" "$status_output" >> "$LOG_FILE"
  exit 1
}

get_metric() {
  local metric="$1"
  awk -F: -v key="$metric" '$1 == key {sub(/^[[:space:]]+/, "", $2); print $2; exit}' <<< "$status_output"
}

# accepted conn is cumulative since PHP-FPM started. Its delta over elapsed
# time is the same request-rate concept shown as Traffic by systemctl status.
accepted_conn="$(get_metric 'accepted conn')"

if [[ -z "$accepted_conn" || ! "$accepted_conn" =~ ^[0-9]+$ ]]; then
  timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
  printf '%s status=invalid metric=accepted_conn\n' "$timestamp" >> "$LOG_FILE"
  exit 1
fi

timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
now_epoch="$(date +%s)"
traffic="N/A"

if [[ -f "$STATE_FILE" ]]; then
  read -r previous_epoch previous_accepted < "$STATE_FILE" || true
  if [[ "${previous_epoch:-}" =~ ^[0-9]+$ && "${previous_accepted:-}" =~ ^[0-9]+$ ]]; then
    elapsed=$((now_epoch - previous_epoch))
    delta=$((accepted_conn - previous_accepted))
    if (( elapsed > 0 && delta >= 0 )); then
      traffic="$(awk -v requests="$delta" -v seconds="$elapsed" 'BEGIN {printf "%.2f", requests / seconds}')"
    fi
  fi
fi

printf '%s %s\n' "$now_epoch" "$accepted_conn" > "$STATE_FILE"

if [[ "$traffic" == "N/A" ]]; then
  level="baseline"
else
  level="ok"
fi

printf '%s status=%s traffic=%s req/sec accepted_conn=%s\n' \
  "$timestamp" "$level" "$traffic" "$accepted_conn" >> "$LOG_FILE"

echo "$(tail -n 1 "$LOG_FILE")"
