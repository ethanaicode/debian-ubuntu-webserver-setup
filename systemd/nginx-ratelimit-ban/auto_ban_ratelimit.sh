#!/usr/bin/env bash

set -euo pipefail

# Auto ban IPs that repeatedly trigger nginx limit_req (rate limiting).
# Scans nginx error logs for "limiting requests" entries and bans
# IPs that exceed the threshold within the time window.
#
# Requires: ipset, iptables
# Log pattern matched:
#   YYYY/MM/DD HH:MM:SS [error] ... limiting requests, excess: ... client: <IP>, ...

LOG_DIR="/www/wwwlogs"
LOG_PATTERN="*.error.log"    # glob relative to LOG_DIR
KEYWORDS=()                  # fixed-string keywords; a line matching any one is counted
DEFAULT_KEYWORD="limiting requests"
WINDOW_SECONDS=120
THRESHOLD=30
BAN_SECONDS=86400
IPSET_NAME="nginx_ratelimit_ban"
DRY_RUN=0

usage() {
  cat <<'EOF'
Usage:
  auto_ban_ratelimit.sh [options]

Options:
  --log-dir PATH          Directory containing nginx error logs (default: /www/wwwlogs)
  --log-pattern GLOB      Glob pattern for error log files (default: *.error.log)
  --keyword TEXT          Log keyword to count (plain text, case-sensitive). Repeatable;
                          a line matching ANY keyword is counted.
                          (default: "limiting requests")
  --window SECONDS        Time window to inspect in seconds (default: 120)
  --threshold N           Ban when limit_req trigger count >= N (default: 30)
  --ban-seconds SECONDS   Ban TTL in seconds (default: 86400 = 24h)
  --set-name NAME         ipset set name (default: nginx_ratelimit_ban)
  --dry-run               Print candidates only, do not ban
  -h, --help              Show this help

Examples:
  sudo ./auto_ban_ratelimit.sh --dry-run
  sudo ./auto_ban_ratelimit.sh --window 120 --threshold 30 --ban-seconds 86400
  sudo ./auto_ban_ratelimit.sh --keyword "access forbidden by rule" --dry-run
  sudo ./auto_ban_ratelimit.sh --keyword "limiting requests" --keyword "access forbidden by rule"
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --log-dir)    LOG_DIR="$2";       shift 2 ;;
    --log-pattern) LOG_PATTERN="$2"; shift 2 ;;
    --keyword)
      [[ $# -ge 2 && -n "$2" ]] || { echo "Missing value for --keyword" >&2; exit 1; }
      KEYWORDS+=("$2"); shift 2 ;;
    --window)     WINDOW_SECONDS="$2"; shift 2 ;;
    --threshold)  THRESHOLD="$2";    shift 2 ;;
    --ban-seconds) BAN_SECONDS="$2"; shift 2 ;;
    --set-name)   IPSET_NAME="$2";   shift 2 ;;
    --dry-run)    DRY_RUN=1;         shift ;;
    -h|--help)    usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage; exit 1 ;;
  esac
done

if [[ ! -d "$LOG_DIR" ]]; then
  echo "Log directory not found: $LOG_DIR" >&2
  exit 1
fi

if ! [[ "$WINDOW_SECONDS" =~ ^[0-9]+$ && "$THRESHOLD" =~ ^[0-9]+$ && "$BAN_SECONDS" =~ ^[0-9]+$ ]]; then
  echo "window/threshold/ban-seconds must be positive integers." >&2
  exit 1
fi

if [[ ${#KEYWORDS[@]} -eq 0 ]]; then
  KEYWORDS=("$DEFAULT_KEYWORD")
fi

# Join keywords with a newline, which cannot appear inside a log line
KEYWORDS_STR="$(printf '%s\n' "${KEYWORDS[@]}")"

if ! command -v gawk >/dev/null 2>&1; then
  echo "gawk is required. Install: apt install -y gawk" >&2
  exit 1
fi

NOW_EPOCH="$(date +%s)"
CUTOFF_EPOCH="$((NOW_EPOCH - WINDOW_SECONDS))"

# Collect all matching log files
mapfile -t LOG_FILES < <(find "$LOG_DIR" -maxdepth 1 -name "$LOG_PATTERN" -type f 2>/dev/null || true)

if [[ ${#LOG_FILES[@]} -eq 0 ]]; then
  echo "No log files found matching: ${LOG_DIR}/${LOG_PATTERN}"
  exit 0
fi

# Parse nginx error log entries for limit_req rejections.
# Nginx error log format:
#   2026/07/14 10:23:01 [error] 12345#12345: *1 limiting requests, excess: 5.123 by zone "api_per_ip", client: 1.2.3.4, ...
candidate_lines="$({
  gawk -v cutoff="$CUTOFF_EPOCH" -v keywords="$KEYWORDS_STR" '
    BEGIN {
      kw_count = split(keywords, kw, "\n")
    }
    function matches_keyword(line,    k) {
      for (k = 1; k <= kw_count; k++) {
        if (kw[k] != "" && index(line, kw[k]) > 0) return 1
      }
      return 0
    }
    function to_epoch(date_str, time_str,    a, b, y, mon, d, h, mi, s) {
      # date_str: 2026/07/14   time_str: 10:23:01
      split(date_str, a, "/")
      split(time_str, b, ":")
      y=a[1]; mon=a[2]; d=a[3]
      h=b[1]; mi=b[2]; s=b[3]
      return mktime(sprintf("%04d %02d %02d %02d %02d %02d", y, mon, d, h, mi, s))
    }
    /client:/ && matches_keyword($0) {
      epoch = to_epoch($1, $2)
      if (epoch < cutoff) next

      # Extract client IP: "client: 1.2.3.4,"
      for (i = 1; i <= NF; i++) {
        if ($i == "client:") {
          ip = $(i+1)
          # Strip trailing comma
          gsub(/,$/, "", ip)
          if (ip ~ /^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$/ || ip ~ /^[0-9a-fA-F:]+$/) {
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
  echo "No log lines matching [${KEYWORDS[*]}] found in last ${WINDOW_SECONDS}s across ${#LOG_FILES[@]} log file(s)."
  exit 0
fi

echo "IPs matching [${KEYWORDS[*]}] in last ${WINDOW_SECONDS}s:"
echo "$candidate_lines"

to_ban="$(echo "$candidate_lines" | awk -v n="$THRESHOLD" '$2 >= n {print $1}')"

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

if ! command -v gawk >/dev/null 2>&1; then
  echo "gawk is required. Install: apt install -y gawk" >&2
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

# Create ipset if it does not exist
if ! ipset list "$IPSET_NAME" >/dev/null 2>&1; then
  ipset create "$IPSET_NAME" hash:ip timeout "$BAN_SECONDS"
fi

# Ensure iptables DROP rule exists (idempotent)
if ! iptables -C INPUT -m set --match-set "$IPSET_NAME" src -j DROP >/dev/null 2>&1; then
  iptables -I INPUT -m set --match-set "$IPSET_NAME" src -j DROP
fi

while IFS= read -r ip; do
  [[ -z "$ip" ]] && continue
  ipset add "$IPSET_NAME" "$ip" timeout "$BAN_SECONDS" -exist
  echo "Banned $ip for ${BAN_SECONDS}s"
done <<< "$to_ban"

echo "Done."
