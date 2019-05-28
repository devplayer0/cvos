#!/bin/sh
set -e

if [ "$#" != 1 ]; then
	echo "usage: $0 <buildroot dir>" >&2
	exit 1
fi

sudo rm -rf "$1"
PATH=$PATH:/bin sudo ./alpine-make-rootfs \
	--branch edge \
	--packages "alpine-sdk linux-headers" \
	"$1"
