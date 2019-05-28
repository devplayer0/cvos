BUSYBOX_REPO=git://git.busybox.net/busybox
BUSYBOX_REV=bcb1fc3e6ca6fe902610f507eaf9b0b58a5c583a
LINUX_VERSION=5.1.5

BUSYBOX_DIR=busybox
LINUX_DIR=linux-$(LINUX_VERSION)

BUSYBOX_BIN=$(BUSYBOX_DIR)/busybox
KERNEL_IMAGE=$(LINUX_DIR)/arch/x86_64/boot/bzImage

PDF := sample.pdf

JOBS=$(shell nproc)
DIST := bootable.pdf

MKSQUASH_OPTS := -b 1M -comp xz -Xdict-size 100%
QEMU_CMD := qemu-system-x86_64 -machine q35 -m 2G -cpu host -smp 2 -enable-kvm -vga qxl -usb -device usb-tablet -net nic -net user
OVMF := /usr/share/ovmf/x64/OVMF_CODE.fd

.PHONY: default all clean app boot_bios boot_uefi boot_uefi_indirect

default: $(DIST)
all: default

$(BUSYBOX_DIR):
	git clone $(BUSYBOX_REPO) $@
	git -C $@ checkout -q -b cvos $(BUSYBOX_REV)
	git -C $@ am ../0001-losetup-Add-partition-scanning-option.patch
	cp busybox_config $@/.config

$(LINUX_DIR).tar.xz:
	curl -L -o $@ https://mirrors.edge.kernel.org/pub/linux/kernel/v5.x/$@
$(LINUX_DIR): $(LINUX_DIR).tar.xz
	tar Jxf $<
	INITRAMFS_UID=$$(id -u) INITRAMFS_GID=$$(id -g) envsubst < kernel_config > $@/.config

alpine_buildroot/:
	./mk_buildroot.sh $@

$(BUSYBOX_BIN): | $(BUSYBOX_DIR) $(BUSYBOX_DIR)/.config alpine_buildroot/
	./buildroot_exec.sh alpine_buildroot/ ./buildroot_busybox.sh $(BUSYBOX_DIR) -j$(JOBS)
initramfs/bin/busybox: $(BUSYBOX_BIN)
	cp $< $@

$(KERNEL_IMAGE): $(LINUX_DIR) $(LINUX_DIR)/.config initramfs/ initramfs/bin/busybox
	$(MAKE) -C $< -j$(JOBS)

mupdf-x11-minimal.apk: | alpine_buildroot/
	./buildroot_exec.sh alpine_buildroot/ ./buildroot_mupdf.sh $@

rootfs/: rootfs_overlay/ mupdf-x11-minimal.apk
	./mk_root.sh $@ $< mupdf-x11-minimal.apk
rootfs.sfs: rootfs/
	sudo mksquashfs $< $@ -noappend $(MKSQUASH_OPTS)

$(DIST): $(PDF) $(KERNEL_IMAGE) rootfs.sfs
	./mk_disk.py bootloader.asm $< $(KERNEL_IMAGE) rootfs.sfs $@

boot_bios: $(DIST)
	$(QEMU_CMD) -drive file=$<,media=disk,format=raw
boot_uefi: $(DIST)
	$(QEMU_CMD) -bios $(OVMF) -drive file=$<,media=disk,format=raw

boot_uefi_indirect: $(DIST)
	./boot_uefi_indirect.sh "$(QEMU_CMD)" "$(OVMF)" "$(DIST)"

clean:
	-rm -f $(DIST)

	-rm -f rootfs.sfs
	-sudo rm -rf rootfs/

	-rm -f mupdf-x11-minimal.apk
	-sudo rm -rf alpine_buildroot/

	-rm -rf $(LINUX_DIR)

	-rm -f initramfs/bin/busybox
	-sudo rm -rf $(BUSYBOX_DIR)

	-rm -f $(LINUX_DIR).tar.xz
