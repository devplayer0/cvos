#!/bin/sh
set -e

ESP_SIZE=64M

if [[ $# -ne 3 ]]; then
	echo "usage: $0 <qemu cmd> <ovmf> <dist image>" >&2
	exit 1
fi

QEMU_CMD="$1"
OVMF="$2"
DIST="$3"

ESP="$(mktemp /tmp/esp-XXXXXX.img)"
truncate -s $ESP_SIZE $ESP
sgdisk --new=1 --typecode=1:EF00 $ESP
LOOP="$(sudo losetup --find --show --partscan $ESP)"
sudo mkfs.fat -F32 -n ESP ${LOOP}p1

MOUNT=$(mktemp -d /tmp/esp-XXXXXX)
sudo mount ${LOOP}p1 $MOUNT
sudo mkdir -p $MOUNT/efi/boot
sudo cp $DIST $MOUNT/efi/boot/bootx64.efi
sudo umount $MOUNT
rmdir $MOUNT

$QEMU_CMD -bios $OVMF -drive file=$ESP,media=disk,format=raw
sudo losetup -d $LOOP
rm $ESP
