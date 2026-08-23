#!/bin/bash
set -e

DISK_IMG="$HOME/xeno-test-disk.qcow2"
DISK_SIZE="30G"
ISO_DIR="$HOME/Xeno-Iso-Out"
ISO_IMG=$(ls -t "$ISO_DIR"/xenolinux-*.iso 2>/dev/null | head -n1)
VARS_FILE="/tmp/xeno_ovmf_vars.fd"

if [ ! -f "$VARS_FILE" ]; then
    cp /usr/share/edk2/x64/OVMF_VARS.4m.fd "$VARS_FILE"
fi

case "$1" in
    reset)
        echo "Recreating $DISK_IMG ($DISK_SIZE)..."
        rm -f "$DISK_IMG" "$VARS_FILE"
        cp /usr/share/edk2/x64/OVMF_VARS.4m.fd "$VARS_FILE"
        qemu-img create -f qcow2 "$DISK_IMG" "$DISK_SIZE"
        echo "Virtual disk reset complete."
        exit 0
        ;;
    boot)
        if [ ! -f "$DISK_IMG" ]; then
            echo "Error: Disk image $DISK_IMG does not exist. Run './test-vm.sh install' first."
            exit 1
        fi
        echo "Booting installed Xeno Linux from virtual disk: $DISK_IMG"
        exec qemu-system-x86_64 \
            -enable-kvm \
            -cpu host \
            -m 4096 \
            -smp 4 \
            -vga virtio \
            -display sdl,gl=on \
            -drive if=pflash,format=raw,unit=0,file=/usr/share/edk2/x64/OVMF_CODE.4m.fd,read-only=on \
            -drive if=pflash,format=raw,unit=1,file="$VARS_FILE" \
            -drive file="$DISK_IMG",if=virtio,format=qcow2,cache=writeback \
            -net nic,model=virtio -net user
        ;;
    install|*)
        if [ -z "$ISO_IMG" ] || [ ! -f "$ISO_IMG" ]; then
            echo "Error: No ISO found in $ISO_DIR"
            exit 1
        fi

        if [ ! -f "$DISK_IMG" ]; then
            echo "Creating virtual disk $DISK_IMG ($DISK_SIZE)..."
            qemu-img create -f qcow2 "$DISK_IMG" "$DISK_SIZE"
        fi

        echo "Booting ISO: $ISO_IMG"
        echo "Target Disk: $DISK_IMG ($DISK_SIZE)"
        exec qemu-system-x86_64 \
            -enable-kvm \
            -cpu host \
            -m 4096 \
            -smp 4 \
            -vga virtio \
            -display sdl,gl=on \
            -drive if=pflash,format=raw,unit=0,file=/usr/share/edk2/x64/OVMF_CODE.4m.fd,read-only=on \
            -drive if=pflash,format=raw,unit=1,file="$VARS_FILE" \
            -drive file="$ISO_IMG",media=cdrom,readonly=on \
            -drive file="$DISK_IMG",if=virtio,format=qcow2,cache=writeback \
            -boot d \
            -net nic,model=virtio -net user
        ;;
esac
