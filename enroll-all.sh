#!/bin/bash

# DOES NOT currently support "all" nodes as the name suggests, only supports
# EC2 instances.

set -euo pipefail

# Set to true to run without prompting for confirmation
NON_INTERACTIVE=false

# To run non-interactively with a sudo password, set the SUDO_PASSWORD environment variable:
# export SUDO_PASSWORD="your_sudo_password"
# Then set NON_INTERACTIVE=true

# Blacklist of hostnames to skip
BLACKLIST=(
    "ip-172-31-40-69.us-west-2.compute.internal" # teleport auth,proxy,etc.
    "teleport-agent-0" # k8s node
    "teleport-agent-0" # k8s node
    "baprod-i-0b9204b04910dafb8" # prod instance, temporarily blacklisting
    "aops-oldroot-i-016eb030f1cd40e45"
    "torchboard-prod-i-0452cd0f98bb86303"
    "aops-oldroot-i-0c8a170058d1f874c"
    "aops-prod-i-0b02bdf6857c3e084"
    "aops-prod-i-0b02bdf6857c3e084" # prod academy
    "aops-prod-i-0680fa592d6536ae8" # prod academy
    "baprod-i-0cc545e5dd5fe0550" # ba prod
    "aops-prod-i-0b86b6746eb875c98" # prod aops
    "digitalocean-classroom6-ocean-nyc2-02"

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