#!/bin/bash

configure-timezone() {
    local timezone_list
    local selected

    timezone_list="$(
        find /usr/share/zoneinfo \
            -type f \
            -not -path '/usr/share/zoneinfo/posix/*' \
            -not -path '/usr/share/zoneinfo/right/*' \
            -not -name 'posixrules' \
            -not -name 'leapseconds' \
            -printf '%P\n' |
        sort
    )"

    if [[ -z "$timezone_list" ]]; then
        gum_no_items "No timezones found."
        return
    fi

    selected="$(
        printf '%s\n' "$timezone_list" |
            gum_current_first "$TIMEZONE" |
            gum filter \
                --padding "1 2" \
                --placeholder "Search timezone..." \
                --header "Current: ${TIMEZONE:-Not set}"
    )"

    [[ -n "$selected" ]] && TIMEZONE="$selected"
}
