#!/bin/sh
set -e
source /etc/profile

APK="/home/build/packages/mnt/x86_64/mupdf-x11-minimal-*.apk"

if [ "$#" != 1 ]; then
	echo "usage: $0 <destination .apk>" >&2
	exit 1
fi

sed -i "s/export JOBS=.*/export JOBS=$(nproc)/" /etc/abuild.conf

if ! id -u build > /dev/null 2>&1; then
	mkdir -p /home
	adduser -D -s /bin/sh build
	addgroup build abuild
	echo "build ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers
	su build -c "abuild-keygen -a -i -n"
fi

rm -rf $APK /home/build/mupdf-x11-minimal
cp -r /mnt/mupdf-x11-minimal /home/build/
apk update
su build -c "cd mupdf-x11-minimal && APK='apk --no-progress' SUDO_APK='abuild-apk --no-progress' abuild -r"
cp $APK "/mnt/$1"
