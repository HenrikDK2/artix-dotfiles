#!/bin/bash

configure-locale() {
    local menu_selection="Primary locale"
    local choice
    local selected
    local locale_list
    local -a menu_items

    # Build the list from locales available on the system.
    if [[ -f /usr/share/i18n/SUPPORTED ]]; then
        locale_list="$(
            awk '{print $1}' /usr/share/i18n/SUPPORTED |
                sort -fu
        )"
    else
        locale_list="$(
            locale -a 2>/dev/null |
                sort -fu
        )"
    fi

    if [[ -z "$locale_list" ]]; then
        gum_no_items "No locales found."
        return
    fi

    # Make sure the primary locale is part of LOCALES.
    if [[ -n "$LANG" ]]; then
        local found=0

        for locale in "${LOCALES[@]}"; do
            if [[ "${locale%% *}" == "$LANG" ]]; then
                found=1
                break
            fi
        done

        if (( ! found )); then
            LOCALES=("$LANG" "${LOCALES[@]}")
        fi
    fi

    while true; do
        clear

        menu_items=(
            "Primary locale"
            "Add locale"
            "Remove locale"
            "Show selected"
            "Done"
        )

        choice="$(
            gum choose \
                --padding "1 2" \
                --selected "$menu_selection" \
                --header "Primary: ${LANG:-Not set}" \
                "${menu_items[@]}"
        )"

        [[ -z "$choice" ]] && return

        case "$choice" in

            "Primary locale")
                menu_selection="$choice"

                selected="$(
                    printf '%s\n' "$locale_list" |
                        gum_current_first "$LANG" |
                        gum filter \
                            --padding "1 2" \
                            --placeholder "Search locale..." \
                            --header "Current: ${LANG:-Not set}"
                )"

                if [[ -n "$selected" ]]; then
                    LANG="$selected"

                    # Ensure primary locale is in the enabled locale list.
                    local found=0

                    for locale in "${LOCALES[@]}"; do
                        if [[ "${locale%% *}" == "$LANG" ]]; then
                            found=1
                            break
                        fi
                    done

                    if (( ! found )); then
                        LOCALES=("$LANG" "${LOCALES[@]}")
                    fi
                fi
                ;;

            "Add locale")
                menu_selection="$choice"

                selected="$(
                    printf '%s\n' "$locale_list" |
                        while IFS= read -r locale; do
                            already_selected=0

                            for configured in "${LOCALES[@]}"; do
                                if [[ "${configured%% *}" == "$locale" ]]; then
                                    already_selected=1
                                    break
                                fi
                            done

                            (( already_selected == 0 )) &&
                                printf '%s\n' "$locale"
                        done |
                        gum filter \
                            --padding "1 2" \
                            --placeholder "Search locale..." \
                            --header "Select locale to add"
                )"

                if [[ -n "$selected" ]]; then
                    LOCALES+=("$selected")
                fi
                ;;

            "Remove locale")
                menu_selection="$choice"

                if (( ${#LOCALES[@]} <= 1 )); then
                    gum style \
                        --foreground 1 \
                        --padding "1 2" \
                        "At least one locale must remain."

                    sleep 1
                    continue
                fi

                selected="$(
                    printf '%s\n' "${LOCALES[@]}" |
                        gum filter \
                            --padding "1 2" \
                            --placeholder "Search locale..." \
                            --header "Select locale to remove"
                )"

                if [[ -n "$selected" ]]; then
                    # Don't allow removing the primary locale.
                    if [[ "${selected%% *}" == "$LANG" ]]; then
                        gum style \
                            --foreground 1 \
                            --padding "1 2" \
                            "The primary locale cannot be removed."

                        sleep 1
                        continue
                    fi

                    local new_locales=()

                    for locale in "${LOCALES[@]}"; do
                        if [[ "$locale" != "$selected" ]]; then
                            new_locales+=("$locale")
                        fi
                    done

                    LOCALES=("${new_locales[@]}")
                fi
                ;;

            "Show selected")
                menu_selection="$choice"

                clear

                gum style \
                    --padding "1 2" \
                    "Primary: ${LANG:-Not set}" \
                    "" \
                    "Configured locales:"

                if (( ${#LOCALES[@]} )); then
                    printf '  %s\n' "${LOCALES[@]}"
                else
                    echo "  None"
                fi

                echo
                read -r -n 1 -s -p "Press any key to continue..."
                echo
                ;;

            "Done")
                return
                ;;

        esac
    done
}
