#!/bin/bash

# This script will review the SSL certificate expiration date for the given domains.
# It will connect to the domain and get the certificate expiration date.

# Define if we want to use localhost or the remote domain
use_localhost=false

# Define the domains to review
domains=("example.com" "anotherdomain.com")

# Read domains from a file (same dir as script). If the file exists AND is non-empty,
# override the built-in domains=(...) list. Ignore blank lines and lines starting with '#'.

# Define the domains file to review
DOMAINS_FILE="${DOMAINS_FILE:-domains.txt}"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
DOMAINS_PATH="$SCRIPT_DIR/$DOMAINS_FILE"

if [[ -s "$DOMAINS_PATH" ]]; then
  tmp_domains=()
  while IFS= read -r line || [[ -n "$line" ]]; do
    # trim leading/trailing whitespace
    line="${line#"${line%%[![:space:]]*}"}"
    line="${line%"${line##*[![:space:]]}"}"

    # skip empty lines
    [[ -z "$line" ]] && continue
    # skip comments: lines starting with '#'
    [[ "$line" =~ ^# ]] && continue

    tmp_domains+=("$line")
  done < "$DOMAINS_PATH"

  # only override if we actually collected something
  if ((${#tmp_domains[@]})); then
    domains=("${tmp_domains[@]}")
  fi
fi

for domain in "${domains[@]}"; do
    if [ "$use_localhost" = true ]; then
        # connect to localhost and get the certificate
        expire_date=$(echo | timeout 5 openssl s_client -connect localhost:443 -servername $domain 2>/dev/null | openssl x509 -noout -dates | grep notAfter | cut -d= -f2)
    else
        # connect to the remote domain and get the certificate
        expire_date=$(echo | timeout 5 openssl s_client -connect $domain:443 -servername $domain 2>/dev/null | openssl x509 -noout -dates | grep notAfter | cut -d= -f2)
    fi

    # Check if expire_date is empty
    if [ -z "$expire_date" ]; then
        echo "Domain: $domain, Failed to get the certificate"
        continue
    fi

    # Calculate days left
    day_left=$(( ($(date -d "$expire_date" +%s) - $(date +%s)) / 86400 ))

    # Format the expiration date
    expire_date=$(date -d "$expire_date" '+%Y-%m-%d %H:%M:%S')

    # Print the result
    echo "Domain: $domain, Expire Date: $expire_date, Days Left: $day_left"
done