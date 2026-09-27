#!/bin/bash

user-exists() {
    getent passwd "$1" >/dev/null 2>&1
}

user-has-password() {
    local status

    status="$(
        passwd -S "$1" 2>/dev/null |
            awk '{print $2}'
    )"

    [[ "$status" == "P" || "$status" == "PS" ]]
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

configure-user() {
    local menu_selection="Username"
    local choice
    local value
    local password
    local password_confirm
    local password_status

    while true; do
        clear

        password_status="$(
            get-user-password-status "$USERNAME"
        )"

        choice="$(
            gum choose \
                --padding "1 2" \
                --selected "$menu_selection" \
                --header \
                    "Username: ${USERNAME:-Not set} | Password: $password_status" \
                "Username" \
                "Password" \
                "Done"
        )"

        [[ -z "$choice" ]] && return

        case "$choice" in
            "Username")
                menu_selection="$choice"

                value="$(
                    gum input \
                        --padding "1 2" \
                        --value "$USERNAME" \
                        --prompt "Username: " \
                        --placeholder "Enter username..."
                )"

                [[ -n "$value" ]] && USERNAME="$value"
                ;;

            "Password")
                menu_selection="$choice"

                password="$(
                    gum input \
                        --padding "1 2" \
                        --password \
                        --prompt "New password: "
                )"

                [[ -z "$password" ]] && continue

                password_confirm="$(
                    gum input \
                        --padding "1 2" \
                        --password \
                        --prompt "Confirm password: "
                )"

                if [[ "$password" != "$password_confirm" ]]; then
                    gum style \
                        --foreground 1 \
                        --padding "1 2" \
                        "Passwords do not match."

                    sleep 1
                    continue
                fi

                USER_PASSWORD="$password"
                USER_PASSWORD_CHANGED=1
                ;;

            "Done")
                return
                ;;
        esac
    done
}
