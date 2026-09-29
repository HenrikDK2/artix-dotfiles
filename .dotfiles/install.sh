#!/bin/bash

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_PATH="${SCRIPT_DIR}/$(basename -- "${BASH_SOURCE[0]}")"

USERNAME="henrik"

USER_PASSWORD=""
USER_PASSWORD_CHANGED=0

ROOT_PASSWORD=""
ROOT_PASSWORD_CHANGED=0

HOSTNAME="Artix"

TIMEZONE="Europe/Copenhagen"
LOCALES=(
	"da_DK.UTF-8"
	"en_US.UTF-8"
)

LANG="da_DK.UTF-8"
KEYMAP="dk"

USER_SERVICES=( dbus wireplumber pipewire pipewire-pulse )
SYSTEM_SERVICES=( NetworkManager userspawn ufw auto-update system-tuning system-maintenance gameboost )

INSTALLER_PACKAGES=( gum refind gdisk gawk xkeyboard-config )
FLATPAK_PACKAGES=(
   "io.github.kolunmi.Bazaar"
   "org.mozilla.firefox"
   "com.valvesoftware.Steam"
   "com.valvesoftware.Steam.CompatibilityTool.Proton-GE"
   "com.discordapp.Discord"
   "com.mastermindzh.tidal-hifi"
   "dev.zed.Zed"
   "org.mozilla.thunderbird"
   "org.qbittorrent.qBittorrent"
   "com.github.tchx84.Flatseal"
   "io.github.flattool.Ignition"
)

PACKAGES=(
    # Network & security
    "networkmanager"
    "networkmanager-dinit"
    "networkmanager-openvpn"
    "network-manager-applet"
    "ufw" "ufw-dinit"

    # Desktop
    "hyprland"
    "hyprlock"
    "waybar"
    "rofi"
    "mako"
    "swaybg"
    "alacritty"
    "nemo"
    "nemo-fileroller"
    "wl-clipboard"
    "xdg-desktop-portal-hyprland"
    "xdg-desktop-portal-gtk"
    "xorg-xwayland"

    # Applications
    "mpv"
    "micro"
    "imv"
    "flatpak"
	"protontricks"
    "steam-devices"
    "fuse"

    # System & CLI
    "userspawn-dinit"
    "fish"
    "fastfetch"
    "btop"
    "man-db"
    "bash-completion"
    "gnome-keyring"
    "libsecret"
    "libnotify"
    "jq"
    "yad"
    "zenity"
    "readline"

    # Development
    "git"

    # Screenshots
    "slurp"
    "grim"
    "satty"

    # Archives
    "unrar"
    "unzip"
    "7zip"
    "cabextract"
    "libunrar"

    # Audio
    "pipewire"
    "pipewire-dinit"
    "pipewire-audio"
    "pipewire-pulse"
    "pipewire-pulse-dinit"
    "wireplumber"
    "wireplumber-dinit"
    "pavucontrol"

    # Fonts & icons
    "papirus-icon-theme"
    "cantarell-fonts"
    "otf-font-awesome"
    "ttf-jetbrains-mono"
    "ttf-droid"
    "ttf-dejavu"
)

# Disk
DRIVE=""
BOOT_PART=""
SWAP_PART=""
ROOT_PART=""
HOME_PART=""
HOME_MODE=""

# Require root
if ((EUID)); then
    echo "This installer requires root privileges."
    exec su -c "bash '$SCRIPT_PATH'"
fi

# Require UEFI
if [[ ! -d /sys/firmware/efi ]]; then
    echo "Error: UEFI boot required." >&2
    echo "Reboot the ISO using UEFI instead of Legacy/CSM mode." >&2
    exit 1
fi

# Detect live ISO
IS_LIVE_ISO=$([[ -d /home/artix && $(grep -c 'label=ARTIX_' /proc/cmdline) -gt 0 ]] && echo 1 || echo 0)

# Load libraries
source "$SCRIPT_DIR/lib/helper.sh"
source "$SCRIPT_DIR/lib/gui/main.sh"

install_needed_pkgs "${INSTALLER_PACKAGES[@]}"

# Runtime setup
if [[ -f "$SCRIPT_DIR/runtime.sh" ]]; then
    source "$SCRIPT_DIR/runtime.sh"
else
    configure-system-gui
fi

# Execute installation steps
for script in "$SCRIPT_DIR"/steps/*.sh; do
    [[ -f "$script" ]] && source "$script"
done

# Cleanup
[[ -f "$SCRIPT_DIR/runtime.sh" ]] && rm -rf "$SCRIPT_DIR"
