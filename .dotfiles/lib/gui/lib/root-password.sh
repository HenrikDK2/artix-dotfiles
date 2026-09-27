#!/bin/bash

get-root-password-status() {
    if (( ROOT_PASSWORD_CHANGED )); then
        printf 'New password set'
    elif user-has-password root && ! (( IS_LIVE_ISO )); then
        printf 'Set — not changing'
    else
        printf 'Missing'
    fi
}

configure-root-password() {
    local password
    local password_confirm
    local password_status

    clear

    password_status="$(
        get-root-password-status
    )"

    gum style \
        --padding "1 2" \
        "Root password: $password_status"

    password="$(
        gum input \
            --padding "1 2" \
            --prompt "New root password: " \
            --password \
            --placeholder "Leave empty to keep current password..."
    )"

    # Empty input means keep the current password.
    [[ -z "$password" ]] && return

    password_confirm="$(
        gum input \
            --padding "1 2" \
            --prompt "Confirm root password: " \
            --password
    )"

    if [[ "$password" != "$password_confirm" ]]; then
        gum style \
            --foreground 1 \
            --padding "1 2" \
            "Passwords do not match."

        sleep 1
        return
    fi

    ROOT_PASSWORD="$password"
    ROOT_PASSWORD_CHANGED=1
}
