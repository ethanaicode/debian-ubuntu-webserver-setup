#!/usr/bin/env bash

set -euo pipefail

# Auto ban high-frequency 404 scanner IPs from nginx access logs.
# Default behavior:
# - Look back 120 seconds
# - Count only requests with status=404 AND suspicious probe patterns
# - Ban IPs that hit threshold (>= 12)
# - Use ipset + iptables for timed ban

LOG_FILE="/var/log/nginx/access.log"
WINDOW_SECONDS=120
THRESHOLD=12
BAN_SECONDS=86400
IPSET_NAME="nginx_404_scanners"
DRY_RUN=0

usage() {
  cat <<'EOF'
Usage:
  auto_ban_404_scanners.sh [options]

Options:
  --log-file PATH         Nginx access log path (default: /var/log/nginx/access.log)
  --window SECONDS        Time window to inspect (default: 120)
  --threshold N           Ban when suspicious 404 count >= N (default: 12)
  --ban-seconds SECONDS   Ban TTL in seconds (default: 86400)
  --set-name NAME         ipset name (default: nginx_404_scanners)
  --dry-run               Print candidates only, do not ban
  -h, --help              Show this help

Examples:
  ./auto_ban_404_scanners.sh --dry-run
  sudo ./auto_ban_404_scanners.sh --window 180 --threshold 15
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --log-file)
      LOG_FILE="$2"
      shift 2
      ;;
    --window)
      WINDOW_SECONDS="$2"
      shift 2
      ;;
    --threshold)
      THRESHOLD="$2"
      shift 2
      ;;
    --ban-seconds)
      BAN_SECONDS="$2"
      shift 2
      ;;
    --set-name)
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

if [[ ! -f "$LOG_FILE" ]]; then
  echo "Log file not found: $LOG_FILE" >&2
  exit 1
fi

if ! [[ "$WINDOW_SECONDS" =~ ^[0-9]+$ && "$THRESHOLD" =~ ^[0-9]+$ && "$BAN_SECONDS" =~ ^[0-9]+$ ]]; then
  echo "window/threshold/ban-seconds must be positive integers." >&2
  exit 1
fi

# Suspicious URI patterns often used by scanners.
SUSPICIOUS_RE='/(\.git|\.svn|\.hg|\.bzr)(/|$)|/\.DS_Store($|\?)|/\.(htaccess|htpasswd)($|\?)|/(docker-compose|docker)\.ya?ml($|\?)|/serverless\.yml($|\?)|/terraform\.tfvars($|\?)|/(Dockerfile|dockerfile)($|\?)|/(id_rsa|id_dsa|authorized_keys)($|\?)|/\.env(\..+)?($|\?)|\.(bak|old|orig|save|swp)($|\?)|/(vendor/phpunit|phpunit)/|/(actuator|jolokia)/(env|heapdump|logfile|configprops|beans)|(^|[?&])(load|file|path)=.*(\.\.|%2e%2e|%2f|%5c|\.aws|credentials)|/jw($|\?)'

NOW_EPOCH="$(date +%s)"
CUTOFF_EPOCH="$((NOW_EPOCH - WINDOW_SECONDS))"

# Output: "ip count"
candidate_lines="$({
  awk -v cutoff="$CUTOFF_EPOCH" -v re="$SUSPICIOUS_RE" '
    BEGIN {
      month["Jan"]=1; month["Feb"]=2; month["Mar"]=3; month["Apr"]=4;
      month["May"]=5; month["Jun"]=6; month["Jul"]=7; month["Aug"]=8;
      month["Sep"]=9; month["Oct"]=10; month["Nov"]=11; month["Dec"]=12;
    }
    function ts_to_epoch(raw, a, d, mon, y, h, mi, s, t) {
      # raw example: 08/Jul/2026:15:13:55
      split(raw, a, /[\/:]/)
      d=a[1]; mon=month[a[2]]; y=a[3]; h=a[4]; mi=a[5]; s=a[6]
      if (!mon) return 0
      t = sprintf("%04d %02d %02d %02d %02d %02d", y, mon, d, h, mi, s)
      return mktime(t)
    }
    {
      ip=$1
      status=$9
      uri=$7
      raw=substr($4,2)
      epoch=ts_to_epoch(raw)

      if (epoch < cutoff) next
      if (status != 404) next
      if (uri !~ re) next

      count[ip]++
    }
    END {
      for (ip in count) {
        print ip, count[ip]
      }
    }
  ' "$LOG_FILE" | sort -k2,2nr
} || true)"

if [[ -z "$candidate_lines" ]]; then
  echo "No suspicious 404 scanner activity found in last ${WINDOW_SECONDS}s."
  exit 0
fi

echo "Candidates in last ${WINDOW_SECONDS}s (status=404 + suspicious URI):"
echo "$candidate_lines"

to_ban="$(echo "$candidate_lines" | awk -v n="$THRESHOLD" '$2 >= n {print $1}')"

if [[ -z "$to_ban" ]]; then
  echo "No IP reached threshold >= ${THRESHOLD}."
  exit 0
fi

echo "IPs reaching threshold >= ${THRESHOLD}:"
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

# Create or update timed set.
if ! ipset list "$IPSET_NAME" >/dev/null 2>&1; then
  ipset create "$IPSET_NAME" hash:ip timeout "$BAN_SECONDS"
else
  # Refresh timeout config if set already exists.
  current_header="$(ipset list "$IPSET_NAME" | head -n 10 || true)"
  if ! echo "$current_header" | grep -q "timeout ${BAN_SECONDS}"; then
    echo "Warning: existing set timeout differs from --ban-seconds=${BAN_SECONDS}; using existing set config."
  fi
fi

# Ensure drop rule exists once.
if ! iptables -C INPUT -m set --match-set "$IPSET_NAME" src -j DROP >/dev/null 2>&1; then
  iptables -I INPUT -m set --match-set "$IPSET_NAME" src -j DROP
fi

while IFS= read -r ip; do
  [[ -z "$ip" ]] && continue
  ipset add "$IPSET_NAME" "$ip" timeout "$BAN_SECONDS" -exist
  echo "Banned $ip for ${BAN_SECONDS}s"
done <<< "$to_ban"

echo "Done."