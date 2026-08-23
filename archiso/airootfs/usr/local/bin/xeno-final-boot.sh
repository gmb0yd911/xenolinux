#!/bin/bash
set -e

# 1. Sync kernel and initramfs to /boot/efi (FAT32 ESP)
mkdir -p /boot/efi
for moddir in /usr/lib/modules/*; do
    if [ -f "$moddir/vmlinuz" ]; then
        cp -f "$moddir/vmlinuz" /boot/vmlinuz-linux-zen
        break
    fi
done

if [ ! -s /boot/vmlinuz-linux-zen ] && [ -f /run/archiso/bootmnt/arch/boot/x86_64/vmlinuz-linux-zen ]; then
    cp -f /run/archiso/bootmnt/arch/boot/x86_64/vmlinuz-linux-zen /boot/vmlinuz-linux-zen
fi

/usr/bin/mkinitcpio -P

cp -f /boot/vmlinuz-linux-zen /boot/efi/vmlinuz-linux-zen 2>/dev/null || true
cp -f /boot/initramfs-linux-zen.img /boot/efi/initramfs-linux-zen.img 2>/dev/null || true
cp -f /boot/initramfs-linux-zen-fallback.img /boot/efi/initramfs-linux-zen-fallback.img 2>/dev/null || true

# 2. Get UUIDs and filesystem type
ROOT_UUID=$(grub-probe --target=fs_uuid / 2>/dev/null || blkid -s UUID -o value $(findmnt -n -o SOURCE /) 2>/dev/null || true)
EFI_UUID=$(grub-probe --target=fs_uuid /boot/efi 2>/dev/null || blkid -s UUID -o value $(findmnt -n -o SOURCE /boot/efi) 2>/dev/null || true)
ROOT_FSTYPE=$(grub-probe --target=fs / 2>/dev/null || findmnt -n -o FSTYPE / 2>/dev/null || echo "")

ROOT_FLAGS=""
if [ "$ROOT_FSTYPE" = "btrfs" ]; then
    ROOT_FLAGS="rootflags=subvol=@"
fi

# 3. Create /etc/grub.d/06_xeno_efi to automatically generate the primary boot entry
cat << 'EOF' > /etc/grub.d/06_xeno_efi
#!/bin/sh
exec tail -n +3 $0
# Custom Xeno Linux EFI Boot Entry
EOF

if [ -n "$EFI_UUID" ] && [ -n "$ROOT_UUID" ]; then
cat << EOF >> /etc/grub.d/06_xeno_efi
menuentry 'Xeno Linux' --class xeno --class gnu-linux --class gnu --class os \$menuentry_id_option 'gnulinux-xeno-efi-${ROOT_UUID}' {
	load_video
	set gfxpayload=keep
	insmod gzio
	insmod fat
	insmod part_gpt
	search --no-floppy --fs-uuid --set=root ${EFI_UUID}
	echo 'Loading Linux linux-zen ...'
	linux /vmlinuz-linux-zen root=UUID=${ROOT_UUID} rw ${ROOT_FLAGS} quiet loglevel=3
	echo 'Loading initial ramdisk ...'
	initrd /initramfs-linux-zen.img
}
menuentry 'Xeno Linux (fallback initramfs)' --class xeno --class gnu-linux --class gnu --class os \$menuentry_id_option 'gnulinux-xeno-fallback-${ROOT_UUID}' {
	load_video
	set gfxpayload=keep
	insmod gzio
	insmod fat
	insmod part_gpt
	search --no-floppy --fs-uuid --set=root ${EFI_UUID}
	echo 'Loading Linux linux-zen ...'
	linux /vmlinuz-linux-zen root=UUID=${ROOT_UUID} rw ${ROOT_FLAGS} quiet loglevel=3
	echo 'Loading initial ramdisk ...'
	initrd /initramfs-linux-zen-fallback.img
}
EOF
chmod 755 /etc/grub.d/06_xeno_efi
fi

/usr/bin/grub-mkconfig -o /boot/grub/grub.cfg 2>/dev/null || true
sync
