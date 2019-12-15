# <img src="logo.png" alt="CVos logo" width="24" height="24"> CVos - a bootable PDF
CVos "converts" a PDF into a bootable disk image (based on Linux) which can view
itself - while remaining usable as a PDF!

<p align="center">
  <img alt="Demo" src="demo.gif?raw=true">
</p>

You can grab a sample bootable PDF from the [releases page](https://github.com/devplayer0/cvos/releases) (it's a
copy of my CV!).

Inspired by [Curriculum Bootloader](https://github.com/pjimenezmateo/curriculum-bootloader).

## How do I boot it?
Glad you asked. There are two ways to boot a CVos PDF:
  - Write the PDF directly to a disk (e.g. flash drive) - bootable by BIOS / UEFI systems
  - Execute the PDF as an EFI binary

### In a virtual machine
The easiest way to try a CVos PDF.
You should be able to attach the PDF as a disk image to the VM and boot.

If you're on Linux and have [QEMU][qemu] installed, you can use the `Makefile` in this repo:
  - `make DIST=/path/to/bootable.pdf boot_bios` will boot the PDF with a BIOS-based VM
  - `make DIST=/path/to/bootable.pdf boot_uefi` will use a UEFI-based VM (requires [OVMF][ovmf])
  - `make DIST=/path/to/bootable.pdf boot_uefi_indirect` will create a temporary disk image and copy the PDF to it,
  executing the PDF as an EFI binary (also requires [OVMF][ovmf])

See `QEMU_CMD` for the base command used to run QEMU.
Pass `OVMF=/path/to/OVMF_CODE.fd` to `make` if your OVMF BIOS file isn't in the default location.

### On real hardware
An x86_64-based system is required.

By writing the PDF directly to a disk, you can boot it on a BIOS / UEFI system:
  1. Run `dd if=/path/to/bootable.pdf of=/dev/SOMETHING bs=1M oflag=direct`
      - **Be sure to replace `/dev/SOMETHING` with the path to your USB drive**
  2. Start your machine and boot from the drive (you will probably need to spam a key to get a boot menu)

If you're on Windows, something like [Rufus](https://rufus.ie) in DD mode should work.

You can also copy the PDF to a FAT12/16/32-formatted disk and boot as an EFI binary (requires a UEFI system):
  1. Create the directories `/EFI/Boot` in the root of the drive
  2. Copy your PDF to `/EFI/Boot/bootx64.efi` (note the changed extension)
  3. Boot your machine from the disk as before

## How can I make my own PDF bootable?
You'll need:
  - A Linux system
  - Git
  - The dependencies needed to build the Linux kernel
  - curl
  - [Netpbm](http://netpbm.sourceforge.net)
  - sudo
  - SquashFS tools (`mksquashfs`)
  - `mkfs.fat`
  - [NASM](https://nasm.us)
  - Python 3
  - [Python `pefile`](https://pypi.org/project/pefile/)
  - [fatcat](https://github.com/Gregwar/fatcat)
  - [QPDF](http://qpdf.sourceforge.net)
  - [QEMU][qemu] and [OVMF][ovmf] (for testing)

Clone this repo, run `make PDF=/path/to/your.pdf` and wait - a `bootable.pdf` will be produced.
See above for boot instructions.

Not passing `PDF=` to `make` will use the included sample PDF ([my CV](sample.pdf)).

**Be sure check if it still works as a PDF on its own - unfortunately not all seem to be compatible.**

## How does it work?
The main reason this works is that **the PDF header only needs to appear within the first 1024 bytes of a PDF file**.

Given this, there are several components which allow the PDF to be bootable (and remain usable) in 3 distinct ways:
BIOS, EFI and "indirect EFI" (EFI binary on another disk).

### BIOS booting
In order to boot on a BIOS system, there must be an [MBR](https://en.wikipedia.org/wiki/Master_boot_record) boot sector
at the start of the file (since it will be burned directly to disk).

CVos' loader is based on Sebastian Plotz's [Minimal Linux Bootloader](http://sebastian-plotz.blogspot.com/2012/07/1.html),
with modifications to allow a for PE header (required for booting as a standalone EFI binary, see below) to fit.

The boot process looks like this:
  1. BIOS loads the MBR and starts executing it as real-mode code
  2. The main code for the loader resides beyond the MBR, so it loads that sector into memory and jumps into it
  3. Main loader code loads the kernel into memory and jumps into it
  [as required by the Linux documentation](https://github.com/torvalds/linux/blob/master/Documentation/x86/boot.rst)

Since the PDF must start within the first 1024 bytes of the file, it is inserted right after the end of the bootloader
code (at offset `0x38a`). The size of the PDF in bytes is written as a 32-bit unsigned integer just before this
(at `0x386`) so that Linux knows how to extract it later.

The offset of the kernel (LBA) is also calculated and written in the boot code at assembly time, since it comes after
the PDF.

### EFI booting
In order to be bootable on an EFI system, the disk must contain a FAT filesystem (in this case a FAT12 just large enough
to fit the kernel). UEFI firmwares will automatically look for an EFI binary at `/EFI/Boot/bootx64.efi` on and load it.

Since the kernel can be built as an EFI binary ([EFISTUB](https://www.kernel.org/doc/Documentation/efi-stub.txt)), it is
placed as `/EFI/Boot/bootx64.efi` on the FAT12. The BIOS loader (as described above) loads the kernel directly from its
position in the FAT12.

### Indirect EFI booting
The [PE](https://docs.microsoft.com/en-us/windows/desktop/debug/pe-format) header (EFI binaries are PE's) can be
(almost\*) arbitrarily placed within the file - a 32-bit value at `0x3c` points to the main header.

In the PDF, the header is essentially a copy of the [kernel's EFISTUB PE header][kernel_pe] with the physical offsets
modified to point to their locations in the PDF (past the actual PDF content).

The UEFI can then load the kernel's EFISTUB code appropriately if the file is executed as an EFI binary.

\*: *UEFI firmwares don't seem to like the header being placed after the lowest loaded virtual address of sections
in the binary. Since Linux loads its initial EFI code at `0x200`, the PE header must be within the first 512 bytes of
the file, leading to the requirement to relocate most of the BIOS loader code.*

### Finding and mounting the root filesystem
Once the kernel has been executed, a simple `initramfs` (embedded into the kernel) locates and mounts the root filesystem.

As described above, the first partition in the MBR is the FAT12 acting as an "ESP". The second partition contains a
[squashed](https://www.kernel.org/doc/Documentation/filesystems/squashfs.txt),
[Alpine Linux](https://alpinelinux.org)-based root filesystem.

When loaded, the `initramfs` searches available disks for an MBR disk signature of `0xcafebabe` - this signature is
hardcoded into the MBR of the image. This works for BIOS and UEFI booting.

If the PDF was booted as an EFI binary ("indirect"), the disk signature will not be directly available. The `initramfs`
will then try mounting each FAT filesystem on any disks on the system, looking for the magic value in
`/EFI/Boot/bootx64.efi`, if the file exists. If the signature is found, a loop device is set up representing the same
"disk" as if the PDF had been booted directly.

At this point, the root filesystem is mounted as the lower portion of an
[OverlayFS](https://www.kernel.org/doc/Documentation/filesystems/overlayfs.txt), with the upper filesystem being a `tmpfs`.
This is because the SquashFS is read-only. With the overlay, any writes will go into RAM, similar to many live CDs.

### "Extracting" and showing the PDF
The last thing the `initramfs` does before switching root to the Alpine rootfs is to extract the PDF to a file that can be
read by the PDF viewer. The size of the PDF is read from the value written to `0x386` in the PDF, and `dd` is used to
extract it to `/embedded.pdf`.

Once Alpine's init system takes over, an X server is started, a welcome message is shown and the PDF viewer is opened on
`/embedded.pdf`.

### Building initramfs BusyBox and MuPDF
In order to reduce the size of the initramfs as much as possible, a customised static BusyBox binary is built.
A customised build of [MuPDF](https://mupdf.com) is also used as the PDF viewer in the rootfs.

In order to reduce the size of BusyBox as much as possible, it is built against [musl](https://www.musl-libc.org), which,
for the same reason, is used by Alpine as its implementation of libc. Since most Linux distributions ship with glibc,
it makes sense to build BusyBox in an Alpine chroot environment.

Although a MuPDF package [is available](https://pkgs.alpinelinux.org/package/edge/main/x86_64/mupdf) for Alpine, this
build ships with over 40MiB of fonts, while many PDF's embed their fonts. To reduce this overhead, a customised MuPDF
Alpine package is built in the same chroot environment as BusyBox.

This buildroot environment (separate from the root filesystem) is created using a slightly modified
[`alpine-make-rootfs`](https://github.com/alpinelinux/alpine-make-rootfs).

### Building the root filesystem
The root filesystem is built via `alpine-make-rootfs`, as with the buildroot. The necessary packages are installed, a
chroot script copies the [OpenRC](https://github.com/OpenRC/openrc) services + tweaked messages (`motd` etc.) and
enables the services to start on boot.

### Producing the PDF / image
Once all of the necessary components have been built (initramfs BusyBox, kernel, MuPDF and root filesystem), a Python
script, `mk_disk.py`, combines them with the MBR code, creating the FAT12 file system and calculating all necessary
offsets to produce the final bootable PDF.

## Overhead
  - Kernel is ~6MiB (XZ-compressed, including ~0.5MiB `initramfs`)
  - XZ-compressed SquashFS root filesystem is ~13MiB
  - About ~20MiB of the *compressed* rootfs is saved by using the customised build of MuPDF for Alpine

The total size of the bootable PDF is then: original PDF size + ~19MiB

[ovmf]: https://github.com/tianocore/tianocore.github.io/wiki/OVMF
[qemu]: https://www.qemu.org
[kernel_pe]: https://github.com/torvalds/linux/blob/9fb67d643f6f1892a08ee3a04ea54022d1060bb0/arch/x86/boot/header.S#L100
