#!/bin/bash

configure-keyboard() {
    local keyboard_list
    local selected

    if [[ -f /usr/share/X11/xkb/rules/base.lst ]]; then
        keyboard_list="$(
            awk '
                /^! layout$/ {
                    section = 1
                    next
                }

                /^! / && !/^! layout$/ {
                    section = 0
                }

                section && NF >= 1 {
                    print $1
                }
            ' /usr/share/X11/xkb/rules/base.lst |
            sort -u
        )"
    fi

    if [[ -z "$keyboard_list" ]] &&
       [[ -f /usr/share/X11/xkb/rules/evdev.lst ]]; then
        keyboard_list="$(
            awk '
                /^! layout$/ {
                    section = 1
                    next
                }

                /^! / && !/^! layout$/ {
                    section = 0
                }

                section && NF >= 1 {
                    print $1
                }
            ' /usr/share/X11/xkb/rules/evdev.lst |
            sort -u
        )"
    fi

    if [[ -z "$keyboard_list" ]]; then
        gum_no_items "No keyboard layouts found."
        return
    fi

    selected="$(
        printf '%s\n' "$keyboard_list" |
            gum_current_first "$KEYMAP" |
            gum filter \
                --padding "1 2" \
                --placeholder "Search keyboard layout..." \
                --header "Current: ${KEYMAP:-Not set}"
    )"

    [[ -n "$selected" ]] && KEYMAP="$selected"
}
