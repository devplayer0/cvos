BUSYBOX_VERSION=1.30.1
LINUX_VERSION=5.1.4

BUSYBOX_DIR=busybox-$(BUSYBOX_VERSION)
LINUX_DIR=linux-$(LINUX_VERSION)

BUSYBOX_BIN=$(BUSYBOX_DIR)/busybox
KERNEL_IMAGE=$(LINUX_DIR)/arch/x86_64/boot/bzImage

PDF := sample.pdf

JOBS=$(shell nproc)
DIST := bootable.pdf

MKSQUASH_OPTS := -b 1M -comp xz -Xdict-size 100%
QEMU_CMD := qemu-system-x86_64 -machine q35 -m 2G -enable-kvm -vga qxl -usb -device usb-tablet -net nic -net user
OVMF := /usr/share/ovmf/x64/OVMF_CODE.fd

.PHONY: default all clean app boot_bios boot_uefi boot_uefi_indirect

default: $(DIST)
all: default

$(BUSYBOX_DIR).tar.bz2:
	curl -L -o $@ https://busybox.net/downloads/$@
$(BUSYBOX_DIR): $(BUSYBOX_DIR).tar.bz2
	cp busybox_config $@/.config
	tar jxf $<

$(LINUX_DIR).tar.xz:
	curl -L -o $@ https://mirrors.edge.kernel.org/pub/linux/kernel/v5.x/$@
$(LINUX_DIR): $(LINUX_DIR).tar.xz
	cp kernel_config $@/.config
	tar Jxf $<

$(BUSYBOX_BIN): $(BUSYBOX_DIR) $(BUSYBOX_DIR)/.config
	$(MAKE) -C $< -j$(JOBS)

initramfs/bin/busybox: $(BUSYBOX_BIN)
	cp $< $@

$(KERNEL_IMAGE): $(LINUX_DIR) $(LINUX_DIR)/.config initramfs/bin/busybox
	$(MAKE) -C $< -j$(JOBS)

rootfs/:
	./mk_root.sh $@
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
	-rm -f rootfs/

	-rm -rf $(LINUX_DIR)

	-rm -f initramfs/bin/busybox
	-rm -rf $(BUSYBOX_DIR)

	-rm -f $(BUSYBOX_DIR).tar.bz2
	-rm -f $(LINUX_DIR).tar.xz
