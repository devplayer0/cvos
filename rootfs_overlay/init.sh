#!/bin/sh

source /etc/profile

apk add --no-progress rsync
rsync -rlptD --exclude /init.sh /mnt/ /

sed -i '/^#ttyS0.*getty/s/^#//' /etc/inittab
echo "ttyS0" >> /etc/securetty
> /etc/fstab
setup-udev -n
rc-update add fix-apk-cache
rc-update add acpid default
rc-update add xorg default

apk del --no-progress rsync
