#!/bin/sh
set -e

CHROOT=alpine_buildroot/

if [ "$#" != 1 ]; then
	echo "usage: $0 <destination .apk>" >&2
	exit 1
fi

sudo rm -rf "$CHROOT"
PATH=$PATH:/bin sudo ./alpine-make-rootfs \
	--branch edge \
	--packages "alpine-sdk" \
	--script-chroot \
	"$CHROOT" \
	"./chroot_build_mupdf.sh" \
	"$1"
