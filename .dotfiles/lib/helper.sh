#!/bin/bash

install_needed_pkgs() {
    local missing=()
    local pkg

    for pkg in "$@"; do
        if ! pacman -Q "$pkg" &>/dev/null; then
            missing+=("$pkg")
        fi
    done

    if ((${#missing[@]})); then
        pacman -Sy --ask 4 "${missing[@]}"
    fi
}

# Link dinit services
dinit_link() {
    local src="$1"
    local dst="$2"
    shift 2

    mkdir -p "$dst"

    for s; do
        if [[ -e "$src/$s" ]]; then
            ln -sf "$src/$s" "$dst/$s"
        else
            echo "Warning: missing service $src/$s"
        fi
    done
}

# User services
dinit_link_user() {
    local user="$1"
    shift

    local home=$(getent passwd "$user" | cut -d: -f6)

    if [[ -z "$home" ]]; then
        echo "Error: unknown user $user"
        return 1
    fi

    dinit_link \
        /etc/dinit.d/user \
        "$home/.config/dinit.d/boot.d" \
        "$@"
}

# System services
dinit_link_system() {
    dinit_link \
        /etc/dinit.d \
        /etc/dinit.d/boot.d \
        "$@"
}
