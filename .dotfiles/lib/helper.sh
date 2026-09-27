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
