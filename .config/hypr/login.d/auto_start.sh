#!/bin/sh

AUTOSTART_DIR="$HOME/.config/autostart"

if [ -d "$AUTOSTART_DIR" ]; then
    for desktop in "$AUTOSTART_DIR"/*.desktop; do
        [ -e "$desktop" ] || continue

        # Skip entries explicitly disabled
        grep -q '^Hidden=true' "$desktop" && continue

        # Get the Exec line
        command=$(grep '^Exec=' "$desktop" | cut -d= -f2- | sed 's/ *%[fFuUdDnNickvm]//g')

        [ -n "$command" ] && sh -c "$command" &
    done
fi
