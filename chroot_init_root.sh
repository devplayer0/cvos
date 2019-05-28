#!/bin/sh
set -e
source /etc/profile

if [ $# -ne 2 ]; then
	echo "usage: $0 <overlay dir> <mupdf-x11 .apk>" >&2
	exit 1
fi

apk add --no-progress rsync
rsync -rlptD /mnt/$1 /

# Uncomment to enable login on the serial console at boot
#sed -i '/^#ttyS0.*getty/s/^#//' /etc/inittab
echo "ttyS0" >> /etc/securetty
> /etc/fstab
setup-udev -n
rc-update add fix-apk-cache
rc-update add acpid default
rc-update add xorg default

apk del --no-progress rsync

apk add --no-progress --allow-untrusted "/mnt/$2"
