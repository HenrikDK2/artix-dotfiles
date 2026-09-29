#!/usr/bin/env bash
set -uo pipefail

if [[ $EUID -ne 0 ]]; then
    echo "ERROR: This script must be run as root."
    exit 1
fi

section() {
    echo
    echo "==> $1"
}

run_if_exists() {
    if command -v "$1" >/dev/null 2>&1; then
        "$@"
    fi
}

section "Cleaning user Trash (>7 days)"
while IFS=: read -r username _ uid _ _ home shell; do
    # Normal human users only.
    [[ "$uid" -ge 1000 ]] || continue
    [[ "$uid" -lt 60000 ]] || continue
    [[ -d "$home" ]] || continue

    trash="$home/.local/share/Trash"

    if [[ -d "$trash/files" ]]; then
        find "$trash/files" \
            -mindepth 1 \
            -mtime +7 \
            -exec rm -rf -- {} + 2>/dev/null || true
    fi

    if [[ -d "$trash/info" ]]; then
        find "$trash/info" \
            -mindepth 1 \
            -mtime +7 \
            -exec rm -f -- {} + 2>/dev/null || true
    fi

done < /etc/passwd
echo "Done."


orphans="$(pacman -Qtdq 2>/dev/null || true)"
if [[ -n "$orphans" ]]; then
	section "Removing orphaned packages"
	pacman -Rns --noconfirm $orphans >/dev/null 2>&1 || true
	echo "Done."
fi


section "Cleaning pacman cache"
if [ "$(du -sB1 /var/cache/pacman/pkg 2>/dev/null | awk '{print $1}')" -gt $((5 * 1024 * 1024 * 1024)) ]; then
    pacman -Scc --noconfirm >/dev/null 2>&1 || true
    echo "Done."
else
    echo "Cache is 5 GB or smaller. Skipping cleanup."
fi


if command -v flatpak >/dev/null 2>&1; then
	section "Cleaning unused Flatpak runtimes"
	flatpak uninstall --unused --system -y >/dev/null 2>&1 || true

	# Also clean per-user Flatpak installations.
	while IFS=: read -r username _ uid _ _ home shell; do
	    [[ "$uid" -ge 1000 ]] || continue
	    [[ "$uid" -lt 60000 ]] || continue
	    [[ -d "$home" ]] || continue

	    if [[ -d "$home/.local/share/flatpak" ]]; then
	        runuser -u "$username" -- \
	            flatpak uninstall --unused -y >/dev/null 2>&1 || true
	    fi
	done < /etc/passwd

	echo "Done."
fi


section "Cleaning /tmp (>7 days)"
find /tmp \
    -xdev \
    -mindepth 1 \
    -mtime +7 \
    -exec rm -rf -- {} + 2>/dev/null || true
echo "Done."


section "Cleaning /var/tmp (>30 days)"
find /var/tmp \
    -xdev \
    -mindepth 1 \
    -mtime +30 \
    -exec rm -rf -- {} + 2>/dev/null || true

echo "Done."
echo
echo "Cleanup complete"
