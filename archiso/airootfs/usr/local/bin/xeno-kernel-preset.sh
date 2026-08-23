#!/bin/bash
chattr -R +C /boot 2>/dev/null || true
btrfs property set /boot compression none 2>/dev/null || true

rm -f /boot/vmlinuz-linux-zen
touch /boot/vmlinuz-linux-zen
chattr +C /boot/vmlinuz-linux-zen 2>/dev/null || true

for moddir in /usr/lib/modules/*; do
    if [ -f "$moddir/vmlinuz" ]; then
        cp --no-preserve=all -f "$moddir/vmlinuz" /boot/vmlinuz-linux-zen
        break
    fi
done

if [ ! -s /boot/vmlinuz-linux-zen ] && [ -f /run/archiso/bootmnt/arch/boot/x86_64/vmlinuz-linux-zen ]; then
    cp --no-preserve=all -f /run/archiso/bootmnt/arch/boot/x86_64/vmlinuz-linux-zen /boot/vmlinuz-linux-zen
fi

chmod 644 /boot/vmlinuz-linux-zen 2>/dev/null || true

cat << "EOF" > /etc/mkinitcpio.d/linux-zen.preset
# mkinitcpio preset file for the linux-zen package
ALL_config="/etc/mkinitcpio.conf"
ALL_kver="/boot/vmlinuz-linux-zen"
PRESETS=('default' 'fallback')
default_image="/boot/initramfs-linux-zen.img"
fallback_image="/boot/initramfs-linux-zen-fallback.img"
fallback_options="-S autodetect"
EOF
