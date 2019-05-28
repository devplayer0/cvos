#!/bin/sh
set -e
source /etc/profile

if [ "$#" -lt 1 ]; then
	echo "usage: $0 <busybox dir> [make args...]" >&2
	exit 1
fi

DIR="$1"
shift 1

make -C "$DIR" $@
