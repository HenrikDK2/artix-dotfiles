#!/bin/bash

configure-hostname() {
    local value

    value="$(
        gum input \
            --padding "1 2" \
            --value "$HOSTNAME" \
            --prompt "Hostname: " \
            --placeholder "Enter hostname..."
    )"

    [[ -n "$value" ]] && HOSTNAME="$value"
}
