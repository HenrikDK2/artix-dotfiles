#!/bin/bash

gum_current_first() {
    local current="$1"

    if [[ -n "$current" ]]; then
        printf '%s\n' "$current"
        grep -Fxv "$current"
    else
        cat
    fi
}

gum_no_items() {
    local message="$1"

    clear

    gum style \
        --padding "1 2" \
        "$message"

    read -r -n 1 -s -p "Press any key to continue..."
    echo
}

get-user-password-status() {
    local username="$1"

    if (( USER_PASSWORD_CHANGED )); then
        printf 'New password set'
    elif ! user-exists "$username"; then
        printf 'Missing'
    elif user-has-password "$username"; then
        printf 'Set — not changing'
    else
        printf 'Missing'
    fi
}

get-root-password-status() {
    if (( ROOT_PASSWORD_CHANGED )); then
        printf 'New password set'
    elif user-has-password root; then
        printf 'Set — not changing'
    else
        printf 'Missing'
    fi
}

show-config-summary() {
    local user_password_status
    local root_password_status
    local home_status

    user_password_status="$(get-user-password-status "$USERNAME")"
    root_password_status="$(get-root-password-status)"

    gum style \
        --border rounded \
        --padding "1 2" \
        --margin "1 2" \
        "Installation Summary"

    echo

    gum style \
        --padding "0 2" \
        "User" \
        "  Username: ${USERNAME:-Not set}" \
        "  Password: ${user_password_status}"

    echo

    gum style \
        --padding "0 2" \
        "Root" \
        "  Password: ${root_password_status}"

    echo

    gum style \
        --padding "0 2" \
        "System" \
        "  Hostname: ${HOSTNAME:-Not set}" \
        "  Timezone: ${TIMEZONE:-Not set}" \
        "  Primary locale: ${LANG:-Not set}" \
        "  Keyboard: ${KEYMAP:-Not set}"

    echo

    gum style \
        --padding "0 2" \
        "Locales" \
        "$(
            if (( ${#LOCALES[@]} )); then
                printf '  %s\n' "${LOCALES[@]}"
            else
                printf '  None'
            fi
        )"

    if (( IS_LIVE_ISO )) && [[ -n "$DRIVE" ]]; then
        echo

        if [[ "$HOME_MODE" == "existing" ]]; then
            home_status="${HOME_PART} (Use existing)"
        elif [[ "$HOME_MODE" == "create" ]]; then
            home_status="${HOME_PART} (Create new)"
        else
            home_status="Not set"
        fi

        gum style \
            --padding "0 2" \
            "Disk" \
            "  Drive: ${DRIVE}" \
            "  Boot: ${BOOT_PART}" \
            "  Swap: ${SWAP_PART}" \
            "  Root: ${ROOT_PART}" \
            "  Home: ${home_status}"
    fi

    echo
    gum confirm \
        --padding "1 2" \
        "Start installation?"
}
