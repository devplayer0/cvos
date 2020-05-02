#!/bin/sh
set -e

TIMEZONE="Europe/Dublin"
PACKAGES="alpine-base eudev xf86-input-libinput xf86-video-modesetting xf86-video-qxl \
	xf86-video-vesa xorg-server xwininfo xdotool xmessage"

if [ "$#" != 3 ]; then
	echo "usage: $0 <target rootfs path> <overlay dir> <mupdf-x11 .apk>" >&2
	exit 1
fi

sudo rm -rf "$1"
PATH=$PATH:/bin sudo ./alpine-make-rootfs \
	--branch v3.11 \
	--packages "$PACKAGES" \
	--timezone "$TIMEZONE" \
	--script-chroot \
	"$1" \
	"./chroot_init_root.sh" \
	"$2" "$3"
