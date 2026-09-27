#!/bin/bash
set -u

CONFIG="$SCRIPT_DIR/files/user/qBittorrent"

# Fail fast once, instead of letting every user/path iteration below
# attempt a `cp -r` from a source that doesn't exist.
if [[ ! -d "$CONFIG" ]]; then
    echo "Missing source config: $CONFIG" >&2
    exit 1
fi

for home in /home/*; do
    [[ -d "$home" ]] || continue

    user="${home##*/}"
    [[ "$(getent passwd "$user" | cut -d: -f6)" == "$home" ]] || continue

    group=$(id -gn "$user")
    echo "Processing user: $user"

    for path in \
        "$home/.config/qBittorrent" \
        "$home/.var/app/org.qbittorrent.qBittorrent/config/qBittorrent"
    do
        if [[ -d "$path" ]]; then
            echo "  — Already exists: $path"
            continue
        fi

        mkdir -p "$path"
        cp -r "$CONFIG/." "$path/"
        chown -R "$user:$group" "$path"

        echo "  ✔ Copied: $path"
    done
done
