#!/bin/bash

# DOES NOT currently support "all" nodes as the name suggests, only supports
# EC2 instances.

set -euo pipefail

# Set to true to run without prompting for confirmation
NON_INTERACTIVE=true

# Blacklist of hostnames to skip
BLACKLIST=(
    "ip-172-31-40-69.us-west-2.compute.internal" # teleport auth,proxy,etc.
    "teleport-agent-0" # k8s node
    "teleport-agent-0" # k8s node
    "digitalocean-classroom6-ocean-nyc2-01" # no idea what the hell this is
    "digitalocean-classroom6-ocean-nyc2-01" # no idea what the hell this is
    "digitalocean-classroom6-ocean-sfo2-01" # no idea what the hell this is
    "digitalocean-classroom6-ocean-sfo3-01" # no idea what the hell this is
    "baprod-i-0e8e6a10e0d33feab" # prod instance, temporarily blacklisting
    "baprod-i-0c78fb294ae271f89" # prod instance, temporarily blacklisting
    "baprod-i-0b9204b04910dafb8" # prod instance, temporarily blacklisting
    "baprod-i-0788268eb77dd22a2" # prod instance, temporarily blacklisting
    "torchboard-prod-i-0452cd0f98bb86303" # prod instance, temporarily blacklisting
    "aops-prod-i-0b02bdf6857c3e084" # prod instance, temporarily blacklisting
    "aops-prod-i-0680fa592d6536ae8" # prod instance, temporarily blacklisting
    "baprod-i-03751c1fe7b3faa71" # prod instance, temporarily blacklisting
    "baprod-i-0106c6e326a5ce046" # prod instance, temporarily blacklisting
    "baprod-i-0f4ed88724196e460" # prod instance, temporarily blacklisting
    "academy-prod-i-06fb86750dcef89ce" # prod instance, temporarily blacklisting
    "baprod-i-0fd16a8156fc97a50" # prod instance, temporarily blacklisting
    "baprod-i-0cd6da511b2b22b17" # prod instance, temporarily blacklisting
    "baprod-i-0ac310e9c2c7cb882" # prod instance, temporarily blacklisting
    "baprod-i-0cc545e5dd5fe0550" # prod instance, temporarily blacklisting
    "aops-prod-i-0b86b6746eb875c98" # prod instance, temporarily blacklisting
    "aops-oldroot-i-00f1c5ae18e1e27d4" # oldroot account, temporarily blacklisting
    "aops-oldroot-i-0f0d8fc46c83c59d4" # oldroot account, temporarily blacklisting
    "aops-oldroot-i-024cdcea098182cbf" # oldroot account, temporarily blacklisting
    "aops-oldroot-i-0bb0db45bff4b2307" # oldroot account, temporarily blacklisting
    "aops-oldroot-i-016eb030f1cd40e45" # oldroot account, temporarily blacklisting
    "aops-oldroot-i-0583d99f954ef5aac" # oldroot account, temporarily blacklisting
    "aops-oldroot-i-0c8a170058d1f874c" # oldroot account, temporarily blacklisting
    "aops-oldroot-i-0372d78552c410ade" # oldroot account, temporarily blacklisting
    "aops-oldroot-i-07e9b8fd9352983f5" # oldroot account, temporarily blacklisting
    "aops-oldroot-i-0c108007c107b2e79" # oldroot account, temporarily blacklisting
    # Add more hostnames to skip here
)

# Get all node hostnames from Teleport inventory and store in array
CLIENT_HOSTNAMES=($(tctl inventory ls --upgrader=none --format json | jq -r '.[].spec.hostname'))

for hostname in "${CLIENT_HOSTNAMES[@]}"; do
    # Check if hostname is in blacklist
    if [[ " ${BLACKLIST[@]} " =~ " ${hostname} " ]]; then
        echo "Skipping blacklisted hostname: $hostname"
        continue
    fi
    
    echo "About to process: $hostname"
    
    # Get detailed information about the host using tsh ls
    echo "Host details:"
    tsh ls --search "$hostname" --format json 2>/dev/null | jq -r '.[] | "  - Name: \(.spec.hostname)\n  - Address: \(.spec.addr)\n  - AWS Name: \(.metadata.labels."aws/Name" // "not set")\n  - Status: \(.status.phase // "unknown")"' 2>/dev/null || echo "  Unable to retrieve detailed information"
    echo
    
    if [ "$NON_INTERACTIVE" = false ]; then
        read -p "Continue? (y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            echo "Processing: $hostname"
            ./enroll-ec2.sh "$hostname"
        else
            echo "Skipping: $hostname"
        fi
    else
        echo "Processing: $hostname (non-interactive mode)"
        ./enroll-ec2.sh "$hostname"
    fi
done