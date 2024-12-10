#!/bin/bash

# This script will review the SSL certificate expiration date for the given domains.
# It will connect to the domain and get the certificate expiration date.

# Define if we want to use localhost or the remote domain
use_localhost=false

# Define the domains to review
domains=("example.com" "anotherdomain.com")

for domain in "${domains[@]}"; do
    # Note: macOS does not have the timeout command, 
    #     so if a domain is inaccessible or lacks a certificate, it may cause openssl to wait indefinitely.
    if [ "$use_localhost" = true ]; then
        # connect to localhost and get the certificate
        expire_date=$(echo | openssl s_client -connect localhost:443 -servername $domain 2>/dev/null | openssl x509 -noout -dates | grep notAfter | cut -d= -f2)
    else
        # connect to the remote domain and get the certificate
        expire_date=$(echo | openssl s_client -connect $domain:443 -servername $domain 2>/dev/null | openssl x509 -noout -dates | grep notAfter | cut -d= -f2)
    fi

    # Check if expire_date is empty
    if [ -z "$expire_date" ]; then
        echo "Domain: $domain, Failed to get the certificate"
        continue
    fi
    
    # Convert expire_date to seconds since the epoch
    expire_epoch=$(date -j -f "%b %d %T %Y %Z" "$expire_date" +%s)
    
    # Get the current date in seconds since the epoch
    current_epoch=$(date +%s)
    
    # Calculate days left
    day_left=$(( (expire_epoch - current_epoch) / 86400 ))

    # Format the expiration date
    formatted_date=$(date -j -f "%s" "$expire_epoch" '+%Y-%m-%d %H:%M:%S')

    # Print the result
    echo "Domain: $domain, Expire Date: $formatted_date, Days Left: $day_left"
done