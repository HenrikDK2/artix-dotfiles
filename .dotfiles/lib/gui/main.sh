#!/bin/bash

LIB_DIR="$SCRIPT_DIR/lib/gui/lib"

source "$LIB_DIR/common.sh"
source "$LIB_DIR/user.sh"
source "$LIB_DIR/root-password.sh"
source "$LIB_DIR/hostname.sh"
source "$LIB_DIR/timezone.sh"
source "$LIB_DIR/locale.sh"
source "$LIB_DIR/keyboard.sh"

if (( IS_LIVE_ISO )); then
    source "$LIB_DIR/disk.sh"
fi

configure-system-gui() {
    local menu_selection="User"
    local choice

    local -a menu_items=(
        "User"
        "Root Password"
        "Hostname"
        "Timezone"
        "Locale"
        "Keyboard"
    )

    if (( IS_LIVE_ISO )); then
        menu_items+=("Disk")
    fi

    menu_items+=(
        " "
        "Continue"
        "Exit"
    )

    while true; do
        clear

        choice="$(
            gum choose \
                --padding "1 2" \
                --selected "$menu_selection" \
                "${menu_items[@]}"
        )"

        [[ -z "$choice" ]] && continue

        # Blank separator.
        [[ "$choice" == " " ]] && continue

        case "$choice" in
            "User")
                menu_selection="$choice"
                configure-user
                ;;

            "Root Password")
                menu_selection="$choice"
                configure-root-password
                ;;

            "Hostname")
                menu_selection="$choice"
                configure-hostname
                ;;

            "Timezone")
                menu_selection="$choice"
                configure-timezone
                ;;

            "Locale")
                menu_selection="$choice"
                configure-locale
                ;;

            "Keyboard")
                menu_selection="$choice"
                configure-keyboard
                ;;

            "Disk")
                menu_selection="$choice"
                configure-disk
                ;;

            "Continue")
                local -a missing=()

                [[ -z "$USERNAME" ]] && missing+=("User")
                [[ -z "$HOSTNAME" ]] && missing+=("Hostname")
                [[ -z "$TIMEZONE" ]] && missing+=("Timezone")
                [[ -z "$LANG" ]] && missing+=("Locale")
                [[ -z "$KEYMAP" ]] && missing+=("Keyboard")

                if (( IS_LIVE_ISO )); then
                    [[ -z "$DRIVE" ]] && missing+=("Disk")
                    [[ -z "$HOME_MODE" ]] && missing+=("Home partition")
                    [[ -z "$ROOT_PASSWORD" ]] && missing+=("Root Password")
                    [[ -z "$USER_PASSWORD" ]] && missing+=("User Password")
                fi

                if (( ${#missing[@]} )); then
                    gum style \
                        --foreground 1 \
                        "Missing configuration:" \
                        "$(printf '  %s\n' "${missing[@]}")"

                    read -r -n 1 -s -p "Press any key to continue..."
                    echo
                    continue
                fi

                if show-config-summary; then
                    break
                fi
                ;;

            "Exit")
                echo "Installation cancelled."
                exit 0
                ;;
        esac
    done
}
