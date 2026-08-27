#!/usr/bin/env bash

set -euo pipefail

# Auto-ban IPs that frequently appear as clients in nginx error logs.
# Requires: gawk, ipset, iptables

LOG_DIR="/www/wwwlogs"
LOG_PATTERN="*.error.log"
WINDOW_SECONDS=120
THRESHOLD=30
BAN_SECONDS=86400
IPSET_NAME="nginx_error_client_ban"
DRY_RUN=0

usage() {
  cat <<'EOF'
Usage:
  auto_ban_error_client.sh [options]

Options:
  --log-dir PATH          Directory containing nginx error logs (default: /www/wwwlogs)
  --log-pattern GLOB      Glob pattern for error log files (default: *.error.log)
  --window SECONDS        Time window to inspect in seconds (default: 120)
  --threshold N           Ban when a client IP appears at least N times (default: 30)
  --ban-seconds SECONDS   Ban TTL in seconds (default: 86400 = 24h)
  --set-name NAME         ipset set name (default: nginx_error_client_ban)
  --dry-run               Print candidates only, do not ban
  -h, --help              Show this help

Examples:
  sudo ./auto_ban_error_client.sh --dry-run
  sudo ./auto_ban_error_client.sh --window 300 --threshold 50 --ban-seconds 86400
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --log-dir)
      [[ $# -ge 2 ]] || { echo "Missing value for --log-dir" >&2; exit 1; }
      LOG_DIR="$2"
      shift 2
      ;;
    --log-pattern)
      [[ $# -ge 2 ]] || { echo "Missing value for --log-pattern" >&2; exit 1; }
      LOG_PATTERN="$2"
      shift 2
      ;;
    --window)
      [[ $# -ge 2 ]] || { echo "Missing value for --window" >&2; exit 1; }
      WINDOW_SECONDS="$2"
      shift 2
      ;;
    --threshold)
      [[ $# -ge 2 ]] || { echo "Missing value for --threshold" >&2; exit 1; }
      THRESHOLD="$2"
      shift 2
      ;;
    --ban-seconds)
      [[ $# -ge 2 ]] || { echo "Missing value for --ban-seconds" >&2; exit 1; }
      BAN_SECONDS="$2"
      shift 2
      ;;
    --set-name)
      [[ $# -ge 2 ]] || { echo "Missing value for --set-name" >&2; exit 1; }
      IPSET_NAME="$2"
      shift 2
      ;;
    --dry-run)
      DRY_RUN=1
      shift
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

if [[ ! -d "$LOG_DIR" ]]; then
  echo "Log directory not found: $LOG_DIR" >&2
  exit 1
fi

if ! [[ "$WINDOW_SECONDS" =~ ^[0-9]+$ && "$THRESHOLD" =~ ^[0-9]+$ && "$BAN_SECONDS" =~ ^[0-9]+$ ]]; then
  echo "window/threshold/ban-seconds must be non-negative integers." >&2
  exit 1
fi

if [[ "$WINDOW_SECONDS" -eq 0 || "$THRESHOLD" -eq 0 || "$BAN_SECONDS" -eq 0 ]]; then
  echo "window/threshold/ban-seconds must be greater than zero." >&2
  exit 1
fi

if ! command -v gawk >/dev/null 2>&1; then
  echo "gawk is required. Install: apt install -y gawk" >&2
  exit 1
fi

NOW_EPOCH="$(date +%s)"
CUTOFF_EPOCH="$((NOW_EPOCH - WINDOW_SECONDS))"

mapfile -t LOG_FILES < <(find "$LOG_DIR" -maxdepth 1 -name "$LOG_PATTERN" -type f 2>/dev/null || true)

if [[ ${#LOG_FILES[@]} -eq 0 ]]; then
  echo "No log files found matching: ${LOG_DIR}/${LOG_PATTERN}"
  exit 0
fi

# Nginx error logs normally contain: ... client: 1.2.3.4, ...
candidate_lines="$({
  gawk -v cutoff="$CUTOFF_EPOCH" '
    function to_epoch(date_str, time_str,    date_parts, time_parts) {
      split(date_str, date_parts, "/")
      split(time_str, time_parts, ":")
      return mktime(sprintf("%04d %02d %02d %02d %02d %02d",
        date_parts[1], date_parts[2], date_parts[3],
        time_parts[1], time_parts[2], time_parts[3]))
    }

    /^[0-9]{4}\/[0-9]{2}\/[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}/ && /client:/ {
      epoch = to_epoch($1, $2)
      if (epoch < cutoff) next

      for (i = 1; i <= NF; i++) {
        if ($i == "client:") {
          ip = $(i + 1)
          gsub(/,$/, "", ip)
          if (ip ~ /^[0-9]+(\.[0-9]+){3}$/ || ip ~ /^[0-9A-Fa-f:]+$/) {
            count[ip]++
          }
          break
        }
      }
    }

    END {
      for (ip in count) {
        print ip, count[ip]
      }
    }
  ' "${LOG_FILES[@]}" | sort -k2,2nr
} || true)"

if [[ -z "$candidate_lines" ]]; then
  echo "No client IP activity found in last ${WINDOW_SECONDS}s across ${#LOG_FILES[@]} log file(s)."
  exit 0
fi

echo "Client IPs appearing in nginx error logs in last ${WINDOW_SECONDS}s:"
echo "$candidate_lines"

to_ban="$(awk -v n="$THRESHOLD" '$2 >= n {print $1}' <<< "$candidate_lines")"

if [[ -z "$to_ban" ]]; then
  echo "No IP reached threshold >= ${THRESHOLD}."
  exit 0
fi

echo "IPs reaching threshold >= ${THRESHOLD} (will be banned for ${BAN_SECONDS}s):"
echo "$to_ban"

if [[ "$DRY_RUN" -eq 1 ]]; then
  echo "Dry-run mode: no firewall changes applied."
  exit 0
fi

if [[ "$EUID" -ne 0 ]]; then
  echo "Run as root (or use --dry-run)." >&2
  exit 1
fi

if ! command -v ipset >/dev/null 2>&1; then
  echo "ipset is required. Install: apt install -y ipset" >&2
  exit 1
fi

if ! command -v iptables >/dev/null 2>&1; then
  echo "iptables is required. Install: apt install -y iptables" >&2
  exit 1
fi

if ! ipset list "$IPSET_NAME" >/dev/null 2>&1; then
  ipset create "$IPSET_NAME" hash:ip timeout "$BAN_SECONDS"
fi

if ! iptables -C INPUT -m set --match-set "$IPSET_NAME" src -j DROP >/dev/null 2>&1; then
  iptables -I INPUT -m set --match-set "$IPSET_NAME" src -j DROP
fi

while IFS= read -r ip; do
  [[ -z "$ip" ]] && continue
  ipset add "$IPSET_NAME" "$ip" timeout "$BAN_SECONDS" -exist
  echo "Banned $ip for ${BAN_SECONDS}s"
done <<< "$to_ban"

echo "Done."
