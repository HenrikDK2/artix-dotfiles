#!/bin/bash

if (( IS_LIVE_ISO )); then
    # Sync clock
    dinitctl start chrony

    # Unmount existing mounts
    if swapon --show=NAME | grep -q "$SWAP_PART"; then
        swapoff "$SWAP_PART"
    fi

    if mountpoint -q /mnt; then
        umount -R /mnt
    fi

    # Create partition layout
    if [[ "$HOME_MODE" == "create" ]]; then
        parted -s "$DRIVE" mklabel gpt

        parted -s "$DRIVE" mkpart ESP fat32 1MiB 1GiB
        parted -s "$DRIVE" set 1 esp on

        parted -s "$DRIVE" mkpart swap linux-swap 1GiB 33GiB
        parted -s "$DRIVE" set 2 swap on

        parted -s "$DRIVE" mkpart root ext4 33GiB 83GiB
        parted -s "$DRIVE" mkpart home ext4 83GiB 100%

        partprobe "$DRIVE"
        sleep 1
    fi

    # Format EFI, swap and root
    mkfs.fat -F32 -I "$BOOT_PART"
    mkswap -f "$SWAP_PART"
    mkfs.ext4 -F "$ROOT_PART"

    # Only format newly created home
    if [[ "$HOME_MODE" == "create" ]]; then
        mkfs.ext4 -F "$HOME_PART"
    fi

    # Mount
    mount "$ROOT_PART" /mnt
    swapon "$SWAP_PART"

    mount --mkdir "$HOME_PART" /mnt/home
    mount --mkdir "$BOOT_PART" /mnt/boot

    # Install Artix
    basestrap /mnt \
        base \
        base-devel \
        dinit \
        elogind-dinit \
        linux-zen \
        linux-firmware

    # Generate fstab
    fstabgen -U /mnt > /mnt/etc/fstab

    # Copy installer into target
    # When setting to /mnt/tmp, it seems like
    # artix-chroot gets confused.
    mkdir -p /mnt/installer
    cp -R "$SCRIPT_DIR/." /mnt/installer

    # Save selected configuration for chroot
    declare -p \
        USERNAME \
        USER_PASSWORD \
        USER_PASSWORD_CHANGED \
        ROOT_PASSWORD \
        ROOT_PASSWORD_CHANGED \
        HOSTNAME \
        TIMEZONE \
        LOCALES \
        LANG \
        KEYMAP \
        DRIVE \
        BOOT_PART \
        SWAP_PART \
        ROOT_PART \
        HOME_PART \
        HOME_MODE \
        > /mnt/installer/runtime.sh

    chmod 600 /mnt/installer/runtime.sh

    # Run installer inside chroot
    artix-chroot /mnt /bin/bash /installer/install.sh
	exit 0
fi
