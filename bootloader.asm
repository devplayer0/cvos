; CVOS bootloader - a modified Minimal Linux Bootloader (see below) 

; Minimal Linux Bootloader
; ========================

; @ author:	Sebastian Plotz
; @ version:	1.0
; @ date:	24.07.2012

; Copyright (C) 2012 Sebastian Plotz

; Minimal Linux Bootloader is free software: you can redistribute it and/or modify
; it under the terms of the GNU General Public License as published by
; the Free Software Foundation, either version 3 of the License, or
; (at your option) any later version.

; Minimal Linux Bootloader is distributed in the hope that it will be useful,
; but WITHOUT ANY WARRANTY; without even the implied warranty of
; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
; GNU General Public License for more details.

; You should have received a copy of the GNU General Public License
; along with Minimal Linux Bootloader. If not, see <http://www.gnu.org/licenses/>.

; Memory layout
; =============

; 0x07c00 - 0x07dff	Bootstrap code
;			+ custom EFISTUB PE header
;			+ partition table
;			+ MBR signature
; 0x07e00 - main boot code load address
;			+ embedded PDF size
; 0x10000 - 0x17fff	Real mode kernel
; 0x18000 - 0x1dfff	Stack and heap
; 0x1e000 - 0x1ffff	Kernel command line
; 0x20000 - 0x2fdff	temporal space for
;			protected-mode kernel

; base_ptr = 0x10000
; heap_end = 0xe000
; heap_end_ptr = heap_end - 0x200 = 0xde00
; cmd_line_ptr = base_ptr + heap_end = 0x1e000

; DOS signature
db 0x4d
db 0x5a

; MBR load address
org	0x7c00
	cli
	xor	ax, ax
	mov	ds, ax
	mov	ss, ax
	mov	sp, 0x7c00				; setup stack ...
	mov	ax, 0x1000
	mov	es, ax
	sti

read_main:
	mov ah, 0x42
	mov si, dap
	mov dl, 0x80
	int 0x13					; load the rest of the boot code
	jc error

	jmp	bl_main					; jump to the kernel loading code

error:
	mov	si, error_msg
msg_loop:
	lodsb
	and	al, al
	jz	reboot
	mov	ah, 0xe
	mov	bx, 7
	int	0x10
	jmp	short msg_loop

reboot:
	xor	ax, ax
	int	0x16
	int	0x19
	jmp	0xf000:0xfff0			; BIOS reset code


	times	0x3c-($-$$)	db	0
	dd our_pe-0x7c00			; pe header offset


; Disk Address Packet
dap:
	db	0x10			; size of DAP
	db	0				; unused
.count:
	dw	0x0001			; number of sectors (inital value: read the main boot code sector)
.offset:
	dw	0				; destination: offset
.segment:
	dw	0x7e0			; destination: segment (initial value: ram after bootsector load address)
.lba:
	dd	1				; low bytes of LBA address (initial value: main boot code sector)
	dd	0				; high bytes of LBA address

error_msg	db	'CV loader error', 0

; pe header that will point into the kernel (for direct EFISTUB boot)
our_pe:
	; pe magic
	db 'PE'
	dw 0

coff_header:
	dw 0x8664		; x86-64
	dw 4			; number of sections
	dd 0			; timestamp
	dd 0			; PointerToSymbolTable
	dd 1			; NumberOfSymbols
	dw section_table - optional_header ; SizeOfOptionalHeader
	dw 0x206 		; Characteristics

optional_header:
	dw 0x20b 		; PE32+
	db 0x02			; MajorLinkerVersion
	db 0x14			; MinorLinkerVersion

	; to be filled
	dd 0 			; SizeOfCode
	dd 0			; SizeOfInitializedData
	dd 0			; SizeOfUninitializedData

	dd 0x0000		; AddressOfEntryPoint
	dd 0x0200		; BaseOfCode

extra_header_fields:
	dq 0			; ImageBase
	dd 0x20			; SectionAlignment
	dd 0x20			; FileAlignment
	dw 0			; MajorOperatingSystemVersion
	dw 0			; MinorOperatingSystemVersion
	dw 0			; MajorImageVersion
	dw 0			; MinorImageVersion
	dw 0			; MajorSubsystemVersion
	dw 0			; MinorSubsystemVersion
	dd 0			; Win32VersionValue

	; to be filled
	dd 0			; size of image

	dd 0x200		; SizeOfHeaders
	dd 0			; CheckSum
	dw 0xa			; Subsystem (EFI application)
	dw 0			; DllCharacteristics
	dq 0			; SizeOfStackReserve
	dq 0			; SizeOfStackCommit
	dq 0			; SizeOfHeapReserve
	dq 0			; SizeOfHeapCommit
	dd 0			; LoaderFlags
	dd 0x6			; NumberOfRvaAndSizes

	dq 0			; ExportTable
	dq 0			; ImportTable
	dq 0			; ResourceTable
	dq 0			; ExceptionTable
	dq 0			; CertificationTable
	dq 0			; BaseRelocationTable

section_table:
	; offsets and sizes to be filled

	db '.setup'
	db 0
	db 0
	dd 0
	dd 0x0			; startup_{32,64}
	dd 0			; Size of initialized data
					; on disk
	dd 0x0			; startup_{32,64}
	dd 0			; PointerToRelocations
	dd 0			; PointerToLineNumbers
	dw 0			; NumberOfRelocations
	dw 0			; NumberOfLineNumbers
	dd 0x60500020	; Characteristics (section flags)

	; The EFI application loader requires a relocation section
	; because EFI applications must be relocatable. The .reloc
	; offset & size fields are filled in by build.c.
	db '.reloc'
	db 0
	db 0
	dd 0
	dd 0
	dd 0			; SizeOfRawData
	dd 0			; PointerToRawData
	dd 0			; PointerToRelocations
	dd 0			; PointerToLineNumbers
	dw 0			; NumberOfRelocations
	dw 0			; NumberOfLineNumbers
	dd 0x42100040	; Characteristics (section flags)

	db '.text'
	db 0
	db 0
	db 0
	dd 0
	dd 0x0			; startup_{32,64}
	dd 0			; Size of initialized data
					; on disk
	dd 0x0			; startup_{32,64}
	dd 0			; PointerToRelocations
	dd 0			; PointerToLineNumbers
	dw 0			; NumberOfRelocations
	dw 0			; NumberOfLineNumbers
	dd 0x60500020	; Characteristics (section flags)

	db '.bss'
	db 0
	db 0
	db 0
	db 0
	dd 0
	dd 0x0
	dd 0			; Size of initialized data
					; on disk
	dd 0x0
	dd 0			; PointerToRelocations
	dd 0			; PointerToLineNumbers
	dw 0			; NumberOfRelocations
	dw 0			; NumberOfLineNumbers
	dd 0xc8000080	; Characteristics (section flags)



	times	440-($-$$)	db	0

	; NT "disk signature"
	dd 0xcafebabe
	dw 0

	; partition table
	; partition no 1 - "ESP" (where the kernel lives and can be booted from on a UEFI system)
	db 0			; inactive
	; chs first sector (to be filled)
	db 0			; head
	db 0			; (bits 7-6 are cylinder, 5-0 are sector)
	db 0			; rest of cylinder
	db 0x1			; partition type ("FAT12")
	; chs last sector (to be filled)
	db 0			; head
	db 0			; (bits 7-6 are cylinder, 5-0 are sector)
	db 0			; rest of cylinder
	dd 0			; lba first sector (to be filled)
	dd 0			; number of sectors (to be filled)

	; partition no 2 - linux root filesystem
	db 0			; inactive
	; chs first sector (to be filled)
	db 0			; head
	db 0			; (bits 7-6 are cylinder, 5-0 are sector)
	db 0			; rest of cylinder
	db 0x83			; partition type ("Linux filesystem")
	; chs last sector (to be filled)
	db 0			; head
	db 0			; (bits 7-6 are cylinder, 5-0 are sector)
	db 0			; rest of cylinder
	dd 0			; lba first sector (to be filled)
	dd 0			; number of sectors (to be filled)

	times 16 db 0
	times 16 db 0

	; mbr magic
	dw	0xaa55

; this code won't be loaded by the bios, so we'll have to load it into ram ourselves
extra_code:

bl_main:
	mov dword [current_lba], kernel_lba

read_kernel_bootsector:
	mov	eax, 0x0001			; load one sector
	xor	bx, bx				; no offset
	mov	cx, 0x1000			; load Kernel boot sector at 0x10000
	call	read_from_hdd

read_kernel_setup:
	xor	eax, eax
	mov	al, [es:0x1f1]		; no. of sectors to load
	cmp	ax, 0				; 4 if setup_sects = 0
	jne	read_kernel_setup.next
	mov	ax, 4
.next:
	mov	bx, 512				; 512 byte offset
	mov	cx, 0x1000
	call	read_from_hdd

check_version:
	cmp dword [es:0x202], 'HdrS'
	jb	error
	cmp	word [es:0x206], 0x204		; we need protocol version >= 2.04
	jb	error
	test	byte [es:0x211], 1
	jz	error

set_header_fields:
	mov	byte [es:0x210], 0xe1		; set type_of_loader
	or	byte [es:0x211], 0x80		; set CAN_USE_HEAP
	mov	dword [es:0x218], 0			; set ramdisk_image
	mov	dword [es:0x21c], 0			; set ramdisk_size
	mov	word [es:0x224], 0xde00		; set heap_end_ptr
	;mov	byte [es:0x226], 0x00	; set ext_loader_ver
	mov	byte [es:0x227], 0x01		; set ext_loader_type (bootloader id: 0x11)
	mov	dword [es:0x228], 0x1e000	; set cmd_line_ptr
	cld								; copy cmd_line
	mov	si, cmd_line
	mov	di, 0xe000
	mov	cx, cmd_length
	rep	movsb

read_protected_mode_kernel:
	mov	edx, [es:0x1f4]				; edx stores the number of bytes to load
	shl	edx, 4
.loop:
	cmp	edx, 0
	je	run_kernel
	cmp	edx, 0xfe00					; less than 127*512 bytes remaining?
	jb	read_protected_mode_kernel_2
	mov	eax, 0x7f					; load 127 sectors (maximum)
	xor	bx, bx						; no offset
	mov	cx, 0x2000					; load temporary to 0x20000
	call	read_from_hdd
	mov	cx, 0x7f00					; move 65024 bytes (127*512 byte)
	call	do_move
	sub	edx, 0xfe00					; update the number of bytes to load
	add	word [gdt.dest], 0xfe00
	adc	byte [gdt.dest+2], 0
	jmp	short read_protected_mode_kernel.loop

read_protected_mode_kernel_2:
	mov	eax, edx
	shr	eax, 9
	test	edx, 511
	jz	read_protected_mode_kernel_2.next
	inc	eax
.next:
	xor	bx, bx
	mov	cx, 0x2000
	call	read_from_hdd
	mov	ecx, edx
	shr	ecx, 1
	call	do_move

run_kernel:
	cli
	mov	ax, 0x1000
	mov	ds, ax
	mov	es, ax
	mov	fs, ax
	mov	gs, ax
	mov	ss, ax
	mov	sp, 0xe000
	jmp	0x1020:0

read_from_hdd:
	push	edx
	mov	[dap.count], ax
	mov	[dap.offset], bx
	mov	[dap.segment], cx
	mov	edx, [current_lba]
	mov	[dap.lba], edx
	add	[current_lba], eax			; update current_lba
	mov	ah, 0x42
	mov	si, dap
	mov	dl, 0x80					; first hard disk
	int	0x13
	jc	error
	pop	edx
	ret

do_move:
	push	edx
	push	es
	xor	ax, ax
	mov	es, ax
	mov	ah, 0x87
	mov	si, gdt
	int	0x15
	jc	error
	pop	es
	pop	edx
	ret

; Global Descriptor Table
gdt:
	times	16	db	0
	dw	0xffff						; segment limit
.src:
	dw	0
	db	2
	db	0x93						; data access rights
	dw	0
	dw	0xffff						; segment limit
.dest:
	dw	0
	db	0x10						; load protected-mode kernel to 100000h
	db	0x93						; data access rights
	dw	0
	times	16	db	0

current_lba	dd	kernel_lba			; initialize to kernel LBA
cmd_line	db	'', 0
cmd_length	equ	$ - cmd_line
