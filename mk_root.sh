#!/bin/sh
set -e

if [ "$#" != 1 ]; then
	echo "usage: $0 <target rootfs path>" >&2
	exit 1
fi

TIMEZONE="Europe/Dublin"
PACKAGES="alpine-base eudev xf86-input-libinput xf86-video-modesetting xorg-server xterm xrandr"
PATH=$PATH:/bin sudo ./alpine-make-rootfs \
	--branch edge \
	--packages "$PACKAGES" \
	--timezone "$TIMEZONE" \
	--script-chroot \
	"$1" \
	- <<'SHELL'
		source /etc/profile

		setup-udev -n
SHELL
