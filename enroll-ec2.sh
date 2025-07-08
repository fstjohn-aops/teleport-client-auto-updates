#!/bin/bash

set -euo pipefail

# Set to true to run without prompting for confirmation
NON_INTERACTIVE=true

POSSIBLE_USERNAMES=("website" "ec2-user" "cloud-user" "ubuntu")

if [ $# -eq 0 ]; then
    echo "Error: TARGET_HOSTNAME argument is required"
    echo "Usage: $0 <target_hostname>"
    exit 1
fi

TARGET_HOSTNAME="$1"

# Try to SSH to TARGET_HOSTNAME with each possible username
for username in "${POSSIBLE_USERNAMES[@]}"; do
    echo "Trying username: $username"
    if tsh ssh -o StrictHostKeyChecking=no "$username@$TARGET_HOSTNAME" "echo 'SSH connection successful'" 2>/dev/null; then
        echo "Successfully connected with username: $username"
        TARGET_USERNAME="$username"
        break
    else
        echo "Failed to connect with username: $username"
    fi
done

# Check if we found a working username
if [ -z "${TARGET_USERNAME:-}" ]; then
    echo "Error: Could not connect with any of the attempted usernames: ${POSSIBLE_USERNAMES[*]}"
    exit 1
fi

# Get AWS Name tag if available
echo "Found working username: $TARGET_USERNAME"
echo "Host details:"
tsh ls --search "$TARGET_HOSTNAME" --format json 2>/dev/null | jq -r '.[] | "  - Name: \(.spec.hostname)\n  - Address: \(.spec.addr)\n  - AWS Name: \(.metadata.labels."aws/Name" // "not set")\n  - Status: \(.status.phase // "unknown")"' 2>/dev/null || echo "  Unable to retrieve detailed information"
echo

if [ "$NON_INTERACTIVE" = false ]; then
    read -p "Proceed with enabling teleport-update on $TARGET_HOSTNAME as $TARGET_USERNAME? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Operation cancelled by user"
        exit 0
    fi
else
    echo "Proceeding automatically (non-interactive mode)"
fi

# ssh to the machine and run `sudo teleport-update enable`
tsh ssh -o StrictHostKeyChecking=no "$TARGET_USERNAME@$TARGET_HOSTNAME" "sudo /usr/local/bin/teleport-update enable --base-url https://nexus-anon.aops.tools/repository/devops"
