#!/bin/bash

# Bootloader
BOOT_DIR="/boot"
REFIND_DIR="${BOOT_DIR}/EFI/refind"
REFIND_CONF="${REFIND_DIR}/refind.conf"
REFIND_LINUX_CONF="${BOOT_DIR}/refind_linux.conf"

# CPU microcode
MICROCODE_IMG=""

# Root / swap devices
ROOT_DEVICE="$(findmnt -n -o SOURCE /)"
SWAP_DEVICE="$(swapon --show=NAME --noheadings 2>/dev/null | head -n1)"

# Kernel parameters
KERNEL_PARAMS=(
    "ro"
    "root=$ROOT_DEVICE"
)

# Detect swap / hibernation
if [[ -n "$SWAP_DEVICE" ]]; then
    KERNEL_PARAMS+=("resume=$SWAP_DEVICE")
fi

# Detect CPU microcode
if grep -q "AuthenticAMD" /proc/cpuinfo; then
    MICROCODE_IMG="amd-ucode.img"
    install_needed_pkgs amd-ucode

elif grep -q "GenuineIntel" /proc/cpuinfo; then
    MICROCODE_IMG="intel-ucode.img"
    install_needed_pkgs intel-ucode

else
    echo "Warning: Could not detect CPU vendor."
fi

# rEFInd initrd parameters
# Must be before other kernel parameters
INITRD_PARAMS=""

if [[ -n "$MICROCODE_IMG" ]]; then
    INITRD_PARAMS+="initrd=${MICROCODE_IMG} "
fi

INITRD_PARAMS+="initrd=initramfs-%v.img"

# Remaining kernel parameters
EXTRA_PARAMS=(
    "loglevel=3"
    "debugfs=off"
    "vsyscall=none"
    "processor.ignore_ppc=1"
    "split_lock_detect=off"
    "libahci.ignore_sss=1"
    "amdgpu.msi=1"
    "nvidia.NVreg_EnableMSI=1"
    "nowatchdog"
    "nmi_watchdog=0"
    "module_blacklist=iTCO_wdt"
    "amdgpu.audio=0"
    "amdgpu.ppfeaturemask=0xffffffff"
)

# Build kernel parameter string
PARAM_STR="${KERNEL_PARAMS[*]} ${INITRD_PARAMS} ${EXTRA_PARAMS[*]}"

echo "Root device:    $ROOT_DEVICE"
echo "Swap device:    ${SWAP_DEVICE:-none}"
echo "Microcode:      ${MICROCODE_IMG:-none}"
echo "Kernel params:  $PARAM_STR"

# Remove previous rEFInd installation
if [[ -f "$REFIND_LINUX_CONF" ]]; then
    rm -f "$REFIND_LINUX_CONF"
fi

if [[ -d "$BOOT_DIR/EFI" ]]; then
    rm -rf "$BOOT_DIR/EFI"
fi

# Install rEFInd
refind-install

# Generate rEFInd Linux configuration
echo "\"Boot\"    \"$PARAM_STR\"" \
    > "$REFIND_LINUX_CONF"

# Additional option for minimal boot
echo "\"Minimal Boot\"    \"ro root=$ROOT_DEVICE\"" \
    >> "$REFIND_LINUX_CONF"

# Configure rEFInd timeout
sed -i 's/^timeout .*/timeout 3/' "$REFIND_CONF"

# Configure theme
cp -rf "$SCRIPT_DIR/files/system/boot/EFI/." /boot/EFI/
chown -R root:root /boot/EFI
echo "include themes/refind-theme/theme.conf" >> "$REFIND_CONF"
