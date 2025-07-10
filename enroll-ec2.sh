#!/bin/bash

set -euo pipefail

# Set to true to run without prompting for confirmation
NON_INTERACTIVE=true

# Sudo password can be provided via environment variable
# If SUDO_PASSWORD is set, it will be used for hosts that require sudo password
# If not set and passwordless sudo fails, script will prompt for password (if NON_INTERACTIVE=false)

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

# Test if passwordless sudo works
echo "Testing sudo access..."
if tsh ssh -o StrictHostKeyChecking=no "$TARGET_USERNAME@$TARGET_HOSTNAME" "sudo -n true" 2>/dev/null; then
    echo "Passwordless sudo available - proceeding with standard sudo"
    # ssh to the machine and run `sudo teleport-update enable`
    if tsh ssh -o StrictHostKeyChecking=no "$TARGET_USERNAME@$TARGET_HOSTNAME" "sudo /usr/local/bin/teleport-update enable --base-url https://nexus-anon.aops.tools/repository/devops"; then
        echo "Successfully enabled teleport-update"
    else
        echo "Initial attempt failed, checking if --overwrite is needed..."
        # Capture the error output more reliably
        ERROR_OUTPUT=$(tsh ssh -o StrictHostKeyChecking=no "$TARGET_USERNAME@$TARGET_HOSTNAME" "sudo /usr/local/bin/teleport-update enable --base-url https://nexus-anon.aops.tools/repository/devops 2>&1" 2>/dev/null || true)
        echo "DEBUG: Captured error output:"
        echo "$ERROR_OUTPUT"
        echo "DEBUG: End of error output"
        if echo "$ERROR_OUTPUT" | grep -q "file present\|Use --overwrite\|A non-packaged or outdated installation"; then
            echo "Detected existing Teleport installation, retrying with --overwrite flag..."
            tsh ssh -o StrictHostKeyChecking=no "$TARGET_USERNAME@$TARGET_HOSTNAME" "sudo /usr/local/bin/teleport-update enable --base-url https://nexus-anon.aops.tools/repository/devops --overwrite"
        else
            echo "Failed to enable teleport-update (unknown error)"
            echo "Error output: $ERROR_OUTPUT"
            exit 1
        fi
    fi
else
    echo "Passwordless sudo not available - checking for sudo password"
    if [ -n "${SUDO_PASSWORD:-}" ]; then
        echo "Using provided sudo password"
        # ssh to the machine and run `echo password | sudo -S teleport-update enable`
        if echo "$SUDO_PASSWORD" | tsh ssh -o StrictHostKeyChecking=no "$TARGET_USERNAME@$TARGET_HOSTNAME" "sudo -S /usr/local/bin/teleport-update enable --base-url https://nexus-anon.aops.tools/repository/devops"; then
            echo "Successfully enabled teleport-update"
        else
            echo "Initial attempt failed, checking if --overwrite is needed..."
            # Capture the error output more reliably
            ERROR_OUTPUT=$(echo "$SUDO_PASSWORD" | tsh ssh -o StrictHostKeyChecking=no "$TARGET_USERNAME@$TARGET_HOSTNAME" "sudo -S /usr/local/bin/teleport-update enable --base-url https://nexus-anon.aops.tools/repository/devops 2>&1" 2>/dev/null || true)
            echo "DEBUG: Captured error output:"
            echo "$ERROR_OUTPUT"
            echo "DEBUG: End of error output"
            if echo "$ERROR_OUTPUT" | grep -q "file present\|Use --overwrite\|A non-packaged or outdated installation"; then
                echo "Detected existing Teleport installation, retrying with --overwrite flag..."
                echo "$SUDO_PASSWORD" | tsh ssh -o StrictHostKeyChecking=no "$TARGET_USERNAME@$TARGET_HOSTNAME" "sudo -S /usr/local/bin/teleport-update enable --base-url https://nexus-anon.aops.tools/repository/devops --overwrite"
            else
                echo "Failed to enable teleport-update (unknown error)"
                echo "Error output: $ERROR_OUTPUT"
                exit 1
            fi
        fi
    elif [ "$NON_INTERACTIVE" = false ]; then
        read -s -p "Enter sudo password for $TARGET_USERNAME@$TARGET_HOSTNAME: " SUDO_PASSWORD
        echo
        # ssh to the machine and run `echo password | sudo -S teleport-update enable`
        if echo "$SUDO_PASSWORD" | tsh ssh -o StrictHostKeyChecking=no "$TARGET_USERNAME@$TARGET_HOSTNAME" "sudo -S /usr/local/bin/teleport-update enable --base-url https://nexus-anon.aops.tools/repository/devops"; then
            echo "Successfully enabled teleport-update"
        else
            echo "Initial attempt failed, checking if --overwrite is needed..."
            # Capture the error output more reliably
            ERROR_OUTPUT=$(echo "$SUDO_PASSWORD" | tsh ssh -o StrictHostKeyChecking=no "$TARGET_USERNAME@$TARGET_HOSTNAME" "sudo -S /usr/local/bin/teleport-update enable --base-url https://nexus-anon.aops.tools/repository/devops 2>&1" 2>/dev/null || true)
            echo "DEBUG: Captured error output:"
            echo "$ERROR_OUTPUT"
            echo "DEBUG: End of error output"
            if echo "$ERROR_OUTPUT" | grep -q "file present\|Use --overwrite\|A non-packaged or outdated installation"; then
                echo "Detected existing Teleport installation, retrying with --overwrite flag..."
                echo "$SUDO_PASSWORD" | tsh ssh -o StrictHostKeyChecking=no "$TARGET_USERNAME@$TARGET_HOSTNAME" "sudo -S /usr/local/bin/teleport-update enable --base-url https://nexus-anon.aops.tools/repository/devops --overwrite"
            else
                echo "Failed to enable teleport-update (unknown error)"
                echo "Error output: $ERROR_OUTPUT"
                exit 1
            fi
        fi
    else
        echo "Error: Non-interactive mode is enabled but sudo password is required"
        echo "Please either:"
        echo "  1. Set SUDO_PASSWORD environment variable, or"
        echo "  2. Run with NON_INTERACTIVE=false to enter the sudo password"
        exit 1
    fi
fi
