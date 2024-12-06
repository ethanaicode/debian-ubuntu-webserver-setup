#!/bin/bash

# This script will review the SSL certificate expiration date for the given domains.
# It will connect to the domain and get the certificate expiration date.

# Define if we want to use localhost or the remote domain
use_localhost=true

# Define the domains to review
domains=("example.com" "anotherdomain.com")

for domain in "${domains[@]}"; do
    if [ "$use_localhost" = true ]; then
        # connect to localhost and get the certificate
        expire_date=$(echo | openssl s_client -connect localhost:443 -servername $domain 2>/dev/null | openssl x509 -noout -dates | grep notAfter | cut -d= -f2)
    else
        # connect to the remote domain and get the certificate
        expire_date=$(echo | openssl s_client -connect $domain:443 -servername $domain 2>/dev/null | openssl x509 -noout -dates | grep notAfter | cut -d= -f2)
    fi
    # format the date
    day_left=$(( ($(date -d "$expire_date" +%s) - $(date +%s)) / 86400 ))
    expire_date=$(date -d "$expire_date" '+%Y-%m-%d %H:%M:%S')
    echo "Domain: $domain, Expire Date: $expire_date, Days Left: $day_left"
done