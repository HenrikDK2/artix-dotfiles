#!/usr/bin/env bash

set -u

STATE_FILE="/var/lib/fstrim-last"
INTERVAL=$((14 * 24 * 60 * 60))

if [[ -f "$STATE_FILE" ]]; then
    last_run=$(<"$STATE_FILE")

    if [[ "$last_run" =~ ^[0-9]+$ ]]; then
        now=$(date +%s)
        elapsed=$((now - last_run))

        if (( elapsed < INTERVAL )); then
            if (( elapsed < 60 )); then
                value=$elapsed
                unit="seconds"
            elif (( elapsed < 3600 )); then
                value=$((elapsed / 60))
                unit="minutes"
            elif (( elapsed < 86400 )); then
                value=$((elapsed / 3600))
                unit="hours"
            else
                value=$((elapsed / 86400))
                unit="days"
            fi

            echo "Last successful TRIM was ${value} ${unit} ago (< 14 days). Skipping..."
            exit 0
        fi
    fi
fi

echo "Running fstrim..."

mapfile -t mounts < <(
    findmnt -rn -t ext2,ext3,ext4,xfs,btrfs,f2fs -o TARGET
)

success=0

for mountpoint in "${mounts[@]}"; do
    echo "TRIM: $mountpoint"

    if /usr/bin/fstrim -v "$mountpoint"; then
        success=1
    fi
done

if (( success )); then
    date +%s > "$STATE_FILE"
    echo "TRIM completed successfully."
else
    echo "TRIM failed: no filesystem was successfully trimmed."
    exit 1
fi
