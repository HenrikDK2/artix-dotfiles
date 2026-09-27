#!/bin/bash

set-disk-partitions() {
    local disk="$1"
    local suffix

    [[ -z "$disk" ]] && return 1

    DRIVE="$disk"

    if [[ "$DRIVE" =~ [0-9]$ ]]; then
        suffix="p"
    else
        suffix=""
    fi

    BOOT_PART="${DRIVE}${suffix}1"
    SWAP_PART="${DRIVE}${suffix}2"
    ROOT_PART="${DRIVE}${suffix}3"
    HOME_PART="${DRIVE}${suffix}4"
    HOME_MODE=""
}

show-home-layout-error() {
    local expected="$1"
    local selected="$2"

    gum style \
        --border rounded \
        --border-foreground 1 \
        --padding "1 2" \
        --margin "1 0" \
        "$(gum style --foreground 1 --bold 'Unsupported /home layout')" \
        "" \
        "The selected /home partition is on the installation disk," \
        "but its partition number is not supported." \
        "" \
        "$(gum style --foreground 2 "Expected: $expected")" \
        "$(gum style --foreground 1 "Selected: $selected")" \
        "" \
        "Only partition 4 can be used for an existing /home" \
        "on the installation disk."

    gum confirm \
        "Return to home configuration?" \
        --default=true \
        --affirmative="Continue" \
        --negative="Cancel" \
        >/dev/null
}

configure-home() {
    local selected

    selected="$(
        printf '%s\n' \
            "Use existing partition" \
            "Create new /home partition" |
        gum filter \
            --padding "1 2" \
            --placeholder "Select home configuration..." \
            --header "Home partition"
    )"

    [[ -z "$selected" ]] && return 1

    case "$selected" in
        "Use existing partition")
            configure-existing-home
            ;;

        "Create new /home partition")
            HOME_MODE="create"

            # /home will be partition 4 on DRIVE.
            set-disk-partitions "$DRIVE"
            ;;
    esac
}

configure-existing-home() {
    local partition_list
    local selected
    local home_disk
    local suffix
    local expected_home

    partition_list="$(
        lsblk \
            -lnp \
            -o NAME,SIZE,FSTYPE,LABEL,TYPE |
        awk \
            -v boot="$BOOT_PART" \
            -v swap="$SWAP_PART" \
            -v root="$ROOT_PART" '
            $NF == "part" &&
            $1 != boot &&
            $1 != swap &&
            $1 != root &&
            $3 != "vfat" &&
            $3 != "swap" {
                printf "%-18s %-8s %-12s %s\n", \
                    $1, \
                    $2, \
                    ($3 == "" ? "unformatted" : $3), \
                    ($4 == "" ? "" : $4)
            }
        '
    )"

    if [[ -z "$partition_list" ]]; then
        gum_no_items "No suitable home partitions found."
        return 1
    fi

    selected="$(
        printf '%s\n' "$partition_list" |
            gum filter \
                --padding "1 2" \
                --placeholder "Search home partition..." \
                --header "Select existing /home partition"
    )"

    [[ -z "$selected" ]] && return 1

    HOME_PART="$(awk '{print $1}' <<< "$selected")"

    if [[ ! -b "$HOME_PART" ]]; then
        gum style \
            --border rounded \
            --border-foreground 1 \
            --padding "1 2" \
            "$(gum style --foreground 1 --bold 'Invalid home partition')" \
            "" \
            "The selected partition does not exist:" \
            "$(gum style --foreground 1 "$HOME_PART")"

        gum confirm \
            "Return to home configuration?" \
            --default=true \
            --affirmative="Continue" \
            --negative="Cancel" \
            >/dev/null

        return 1
    fi

    # Determine which disk contains the selected partition.
    home_disk="$(lsblk -no PKNAME "$HOME_PART" 2>/dev/null)"

    if [[ -z "$home_disk" ]]; then
        gum style \
            --border rounded \
            --border-foreground 1 \
            --padding "1 2" \
            "$(gum style --foreground 1 --bold 'Unable to determine home disk')" \
            "" \
            "Could not determine which disk contains:" \
            "$(gum style --foreground 1 "$HOME_PART")"

        gum confirm \
            "Return to home configuration?" \
            --default=true \
            --affirmative="Continue" \
            --negative="Cancel" \
            >/dev/null

        return 1
    fi

    home_disk="/dev/$home_disk"

    # Existing /home on another disk is supported.
    if [[ "$home_disk" != "$DRIVE" ]]; then
        HOME_MODE="existing"
        return 0
    fi

    # Existing /home is on the installation disk.
    #
    # Only the expected layout is supported:
    #
    #   p1 = EFI
    #   p2 = swap
    #   p3 = root
    #   p4 = home
    #
    # Anything else cannot safely be handled by this installer.

    if [[ "$DRIVE" =~ [0-9]$ ]]; then
        suffix="p"
    else
        suffix=""
    fi

    expected_home="${DRIVE}${suffix}4"

    if [[ "$HOME_PART" != "$expected_home" ]]; then
        show-home-layout-error \
            "$expected_home" \
            "$HOME_PART"

        return 1
    fi

    HOME_MODE="existing"
}

configure-disk() {
    local disk_list
    local selected

    disk_list="$(
        lsblk \
            -dn \
            -o NAME,SIZE,MODEL,TYPE |
        awk '
            $NF == "disk" {
                model = $3

                for (i = 4; i < NF; i++)
                    model = model " " $i

                if (model == "")
                    model = "Unknown"

                printf "/dev/%s  %s  %s\n", \
                    $1, $2, model
            }
        '
    )"

    if [[ -z "$disk_list" ]]; then
        gum_no_items "No disks found."
        return 1
    fi

    selected="$(
        printf '%s\n' "$disk_list" |
            gum filter \
                --padding "1 2" \
                --placeholder "Search installation disk..." \
                --header "Current: ${DRIVE:-Not set}"
    )"

    [[ -z "$selected" ]] && return 1

    set-disk-partitions "${selected%% *}"

    configure-home
}
