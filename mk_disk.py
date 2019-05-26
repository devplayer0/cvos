#!/usr/bin/env python
import os
from os import path
import sys
import struct
from subprocess import check_call, check_output
import tempfile
import shutil

import pefile

BL_SIZE = 906

def sector_aligned(n):
    if n % 512 == 0:
        return n
    return n + (512 - (n % 512))

PTABLE = 446
def pentry(n):
    return PTABLE + ((n-1)*16)

PE_POINTER = 0x3c
PE_MAGIC = b'PE\0\0'

FIRST_SECTOR     = 0x8
SECTOR_COUNT     = 0xc
CHS_FIRST_SECTOR = 0x1
CHS_LAST_SECTOR  = 0x5

HEADS_PER_CYLINDER = 255
SECTORS_PER_TRACK = 63

CYLINDER_HI_MASK = 0b1100000000
def lba_to_chs(lba):
    cylinder = lba // (HEADS_PER_CYLINDER * SECTORS_PER_TRACK)
    head = (lba // SECTORS_PER_TRACK) % HEADS_PER_CYLINDER
    sector = (lba % SECTORS_PER_TRACK) + 1

    print(f'lba {lba} -> cylinder {cylinder}, head {head}, sector {sector}')
    return struct.pack('B', head) + \
        struct.pack('B', ((cylinder & CYLINDER_HI_MASK) >> 2) | (sector & 0xff)) + \
        struct.pack('B', cylinder & 0xff)

def write_psize(mbr, pnum, start, size):
    b = pentry(pnum)
    last_sector = start + size - 1

    mbr.seek(b+FIRST_SECTOR, os.SEEK_SET)
    mbr.write(struct.pack('<I', start))
    mbr.seek(b+SECTOR_COUNT, os.SEEK_SET)
    mbr.write(struct.pack('<I', size))

    mbr.seek(b+CHS_FIRST_SECTOR, os.SEEK_SET)
    mbr.write(lba_to_chs(start))
    mbr.seek(b+CHS_LAST_SECTOR, os.SEEK_SET)
    mbr.write(lba_to_chs(last_sector))

def get_fat_file_offset(fs, f):
    output = check_output(['fatcat', '-l', path.dirname(f), fs], encoding='utf8').split('\n')
    for line in output:
        words = list(filter(lambda w: len(w) != 0, line.split(' ')))
        if words[0] == 'f' and words[3] == path.basename(f):
            cluster = words[4].split('=')[1]
            break

    if not cluster:
        raise Exception(f'{f} not in {fs}')

    output = check_output(['fatcat', '-@', cluster, fs], encoding='utf8').split('\n')
    offset = int(output[1].split(' ')[0])
    print(f'{f} starts at cluster {cluster} ({offset} bytes) on {fs}')
    return offset

def main():
    if len(sys.argv) != 6:
        print(f'usage: {sys.argv[0]} <bootloader source> <pdf> <kernel> <rootfs> <output image>')
        sys.exit(1)

    bl_source = sys.argv[1]
    pdf_file = sys.argv[2]
    kernel_file = sys.argv[3]
    rootfs_file = sys.argv[4]
    out_file = sys.argv[5]
    with open(out_file, 'wb') as disk:
        with open(pdf_file, 'rb') as pdf:
            pdf.seek(0, os.SEEK_END)
            orig_pdf_size = pdf.tell()
            pdf_size = BL_SIZE + orig_pdf_size
            aligned_pdf = sector_aligned(pdf_size)
            print(f'bootloader + pdf size: {pdf_size} bytes (aligned to {aligned_pdf} bytes) - {aligned_pdf // 512} sectors')

            esp_start = aligned_pdf // 512

            kernel_size = path.getsize(kernel_file)
            print(f'kernel size: {kernel_size} bytes')
            kernel_pe = pefile.PE(kernel_file)

            esp_size = sector_aligned(kernel_size) + (64*1024)
            assert esp_size % 512 == 0
            print(f'creating fat12 filesystem of size {esp_size} ({esp_size/512} sectors)')
            with tempfile.NamedTemporaryFile('w+b', prefix='esp-', suffix='.img') as esp:
                esp.truncate(esp_size)
                check_call(['mkfs.fat', '-F12', '-n', 'ESP', esp.name])
                with tempfile.TemporaryDirectory(prefix='esp-') as esp_mount:
                    check_call(['sudo', 'mount', '-o', f'uid={os.geteuid()},gid={os.getegid()}', esp.name, esp_mount])
                    boot_dir = path.join(esp_mount, 'efi', 'boot')
                    os.makedirs(boot_dir)
                    boot_file = path.join(boot_dir, 'bootx64.efi')
                    shutil.copyfile(kernel_file, boot_file)
                    check_call(['sudo', 'umount', esp_mount])

                kernel_offset = get_fat_file_offset(esp.name, '/efi/boot/bootx64.efi')
                assert kernel_offset % 512 == 0
                esp.seek(kernel_offset + PE_POINTER, os.SEEK_SET)
                kernel_pe_offset, = struct.unpack('<I', esp.read(4))
                esp.seek(kernel_offset + kernel_pe_offset, os.SEEK_SET)
                assert esp.read(4) == PE_MAGIC
                kernel_pe_offset = aligned_pdf + kernel_offset + kernel_pe_offset
                print(f'kernel PE (efistub) offset: 0x{kernel_pe_offset:x}')

                kernel_lba = esp_start + (kernel_offset // 512)
                rfs_lba = esp_start + (esp_size // 512)
                print(f'esp lba: {esp_start}, kernel lba: {kernel_lba}, rootfs lba: {rfs_lba}')

                with open(rootfs_file, 'rb') as rootfs:
                    rootfs.seek(0, os.SEEK_END)
                    rfs_size = rootfs.tell()
                    rfs_sectors = sector_aligned(rfs_size) // 512
                    print(f'rootfs is {rfs_size} bytes ({rfs_sectors} sectors)')
                    with tempfile.NamedTemporaryFile('w+b', prefix='boot-', suffix='.bin') as bootloader:
                        check_call(['nasm', '-D', f'kernel_lba={kernel_lba}', '-D', f'pdf_size={orig_pdf_size}', '-o', bootloader.name, bl_source])
                        bootloader.seek(0, os.SEEK_END)
                        assert bootloader.tell() == BL_SIZE

                        write_psize(bootloader, 1, esp_start, esp_size // 512)
                        write_psize(bootloader, 2, rfs_lba, rfs_sectors)

                        bl_pe = pefile.PE(bootloader.name)
                        bl_oh = bl_pe.OPTIONAL_HEADER
                        k_oh = kernel_pe.OPTIONAL_HEADER

                        # Optional header standard fields
                        bl_oh.SizeOfCode = k_oh.SizeOfCode
                        bl_oh.SizeOfInitializedData = k_oh.SizeOfInitializedData
                        bl_oh.SizeOfUninitializedData = k_oh.SizeOfUninitializedData
                        bl_oh.AddressOfEntryPoint = k_oh.AddressOfEntryPoint

                        # Optional header Windows-specific (?) fields
                        bl_oh.SizeOfImage = k_oh.SizeOfImage

                        # Section headers
                        for i, section in enumerate(bl_pe.sections):
                            ks = kernel_pe.sections[i]
                            section.Misc_VirtualSize = ks.Misc_VirtualSize
                            section.VirtualAddress = ks.VirtualAddress
                            section.SizeOfRawData = ks.SizeOfRawData

                            if not section.Name.startswith(b'.bss'):
                                section.PointerToRawData = aligned_pdf + kernel_offset + ks.PointerToRawData

                        bl_pe.write(bootloader.name)
                        bl_pe.close()
                        kernel_pe.close()

                        bootloader.seek(0, os.SEEK_SET)
                        disk.write(bootloader.read())

                    pdf.seek(0, os.SEEK_SET)
                    while True:
                        data = pdf.read(512)
                        if not data:
                            break
                        disk.write(data)
                    if pdf_size != aligned_pdf:
                        padding = aligned_pdf - pdf_size
                        print(f'padding pdf by {padding} bytes')
                        disk.seek(padding, os.SEEK_CUR)

                    esp.seek(0, os.SEEK_SET)
                    while True:
                        data = esp.read(512)
                        if not data:
                            break
                        disk.write(data)

                    rootfs.seek(0, os.SEEK_SET)
                    while True:
                        data = rootfs.read(512)
                        if not data:
                            break
                        disk.write(data)

        disk_size = disk.tell()
        disk_aligned = sector_aligned(disk_size)
        if disk_size != disk_aligned:
            print(f'aligning final disk ({disk_size} bytes) to sectors ({disk_aligned} bytes)')
            disk.truncate(disk_aligned)

if __name__ == '__main__':
    main()
