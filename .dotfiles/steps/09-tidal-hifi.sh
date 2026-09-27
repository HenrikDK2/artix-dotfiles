#!/bin/bash

for CONFIG in \
    "$HOME/.var/app/com.mastermindzh.tidal-hifi/config/tidal-hifi/config.json" \
    "$HOME/.config/tidal-hifi/config.json"; do

    mkdir -p "$(dirname "$CONFIG")"
    [ -f "$CONFIG" ] || echo '{}' > "$CONFIG"
    jq '.menuBar = false | .notifications = false' "$CONFIG" > "$CONFIG.tmp" &&
        mv "$CONFIG.tmp" "$CONFIG"
done

echo "Done."
