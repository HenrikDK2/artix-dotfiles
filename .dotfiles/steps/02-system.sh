#!/bin/bash

# Copying system configs
mkdir -p /tmp/system_files
cp -rf "$SCRIPT_DIR/files/system/"* /tmp/system_files/
chown -R root:root /tmp/system_files
cp -rf /tmp/system_files/* /

# Enable lib32 packages
sed -i '/^#\[lib32\]$/,+1 s/^#//' /etc/pacman.conf

# Enable Arch Linux repository support
install_needed_pkgs artix-archlinux-support
curl -fsSL https://archlinux.org/mirrorlist/all/ | grep '^#Server = https://' | sed 's/^#//' | head -n 10 | sudo tee /etc/pacman.d/mirrorlist-arch >/dev/null
grep -q '^\[extra\]$' /etc/pacman.conf || printf '\n[extra]\nInclude = /etc/pacman.d/mirrorlist-arch\n' | sudo tee -a /etc/pacman.conf >/dev/null
grep -q '^\[multilib\]$' /etc/pacman.conf || printf '\n[multilib]\nInclude = /etc/pacman.d/mirrorlist-arch\n' | sudo tee -a /etc/pacman.conf >/dev/null
pacman-key --populate archlinux

# System Packages
install_needed_pkgs "${PACKAGES[@]}"

# Add Flathub systemwide & install Flatpak packages
flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
flatpak install -y --system flathub "${FLATPAK_PACKAGES[@]}"

# Timezone
ln -sf /usr/share/zoneinfo/Europe/Copenhagen /etc/localtime
hwclock --systohc

# Localization
for locale in "${LOCALES[@]}"; do
   	sed -i "s/^#$locale/$locale/" /etc/locale.gen
done

echo "LANG=$LANG" | tee /etc/locale.conf
echo "LC_TIME=$LANG" | tee -a /etc/locale.conf
echo "KEYMAP=$KEYMAP" | tee /etc/vconsole.conf
locale-gen

# Hostname
echo "$HOSTNAME" > /etc/hostname
echo "127.0.0.1   localhost" > /etc/hosts
echo "::1         localhost" >> /etc/hosts
echo "127.0.1.1   ${HOSTNAME}.localdomain ${HOSTNAME}" >> /etc/hosts

# Sudoers config
echo "%wheel ALL=(ALL:ALL) ALL" > /etc/sudoers.d/config
echo "ALL ALL=(root) NOPASSWD: /usr/bin/dinitctl --system list" >> /etc/sudoers.d/config

# Default to fish shell
[[ "$SHELL" != */fish ]] && chsh -s "$(which fish)"

# Create the configured user if it does not already exist.
if ! id "$USERNAME" &>/dev/null; then
    useradd --create-home --shell /bin/fish "$USERNAME"
fi

# Set the user's password only when a new password was configured.
if (( USER_PASSWORD_CHANGED )); then
    printf '%s:%s\n' "$USERNAME" "$USER_PASSWORD" |
        chpasswd
fi

# Set root's password only when a new password was configured.
if (( ROOT_PASSWORD_CHANGED )); then
    printf 'root:%s\n' "$ROOT_PASSWORD" |
        chpasswd
fi

# Add the user to the groups needed by the desktop/system.
usermod --append --groups wheel "$USERNAME"

# Add dotfiles to user
HOME="/home/$USERNAME"

if [ ! -d "$HOME/.dotfiles" ]; then
	rm -rf "$HOME/.git"
	(
		cd "$HOME"
		git remote add origin "https://github.com/HenrikDK2/artix-dotfiles"
		git fetch
		git reset --hard origin/main
		git checkout main
	)

	git remote remove origin
	git remote add origin "git@github.com:HenrikDK2/artix-dotfiles.git"

	# Fix ownership
	sudo chown -R "$USERNAME:$USERNAME" "$HOME"
fi

# Autologin
echo 'GETTY_BAUD=38400' > /etc/dinit.d/config/agetty-tty1.conf
echo 'GETTY_TERM=linux' >> /etc/dinit.d/config/agetty-tty1.conf
echo "GETTY_ARGS=\"--autologin $USERNAME\"" >> /etc/dinit.d/config/agetty-tty1.conf

# Link user/system services
link() {
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
link /etc/dinit.d/user \
     "$HOME/.config/dinit.d/boot.d" \
     "${USER_SERVICES[@]}"

# System services
link /etc/dinit.d \
     /etc/dinit.d/boot.d \
     "${SYSTEM_SERVICES[@]}"
