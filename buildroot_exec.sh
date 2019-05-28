#!/bin/sh
set -e

if [ "$#" -lt 2 ]; then
	echo "usage: $0 <buildroot> <command> [args...]" >&2
	exit 1
fi

PATH=$PATH:/bin sudo ./alpine-make-rootfs \
	--no-install \
	--script-chroot \
	-- \
	"$1" \
	"$2" \
	${@:3}
