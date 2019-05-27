#!/bin/sh
set -e

TIMEZONE="Europe/Dublin"
PACKAGES="alpine-base eudev xf86-input-libinput xf86-video-modesetting xorg-server xrandr mupdf-x11 xdotool xmessage"

if [ "$#" != 2 ]; then
	echo "usage: $0 <target rootfs path> <overlay dir>" >&2
	exit 1
fi

sudo rm -rf "$1"
PATH=$PATH:/bin sudo ./alpine-make-rootfs \
	--branch edge \
	--packages "$PACKAGES" \
	--timezone "$TIMEZONE" \
	--script-chroot \
	"$1" \
	"$2/init.sh"
