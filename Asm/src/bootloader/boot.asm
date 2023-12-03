org 0x7C00
bits 16
%define ENDL 0x0D, 0x0A
;
;	FAT12 header
;
jmp short start
nop
bdb_oem: db 'MSWIN4.1' ;8 bytes
bdb_bytes_per_sector: dw 512
bdb_sectors_per_cluster: db 1
bdb_reserved_sectors:  dw 1
bdb_fat_count: db 2
bdb_dir_entries_count: dw 0E0h
bdb_total_sectors: dw 2880 ; 2880 * 512 = 1.44 mb
bdb_media_descriptor_type: db 0F0h
bdb_sectors_per_fat: dw 9
bdb_sectors_per_track: dw 18
bdb_heads: dw 2
bdb_hidden_sectors: dd 0
bdb_large_sector_count: dd 0
; extended boot record
ebr_drive_number: db 0 ; 0x00 floppy
				  db 0 ; reserved byte 
ebr_signature: 	  db 29h
ebr_volume_id:    db 12h, 34h, 56h,78h
ebr_volume_label: db 'Popov    OS' ; 11 bytes
ebr_system_id: 	  db 'FAT12	  ' ; 8 bytes

start:
 jmp main
;Prints a string to the screen
; Params;
;-ds:si points to string
puts:
	;save registers we will modify
	push si
	push ax
	push bx
.loop:
	lodsb;loads next char in al
	or al,al ;verify if next char is null
	jz .done

	mov ah,0x0e;call bios interrupt
	mov bh,0
	int 0x10
	
	jmp .loop	
.done: 
	pop bx
	pop ax
	pop si
	ret
main:
;setup data segments
	mov ax,0 ;can't write to ds/es directly
	mov ds,ax
	mov es,ax
;setup stack
	mov ss,ax
	mov sp,0x7C00

	mov si,msg_hello
	call puts
	
	hlt
.floppy_error
	hlt
.halt
	jmp .halt
;
; Disk routines
;

;Converts an LBA address to a CHS address
;Params:
; -ax: LBA address
;Returns:
; -cx [bits 0-5]:sector number
; -ch [bits 6-15]: cylinder
; -dh: head
;
lba_to_chs:
	push ax
	push dl
	xor dx,dx
	div word [bdb_sectors_per_track] ;ax = LBA / sectors per track 
	inc dx ;dx = (LBA % SECTORSPerTrack+1) = sector
	mov cx, dx ;sector 
	xor dx,dx ;dx = 0
	div word[bdb_heads] ; ax = (LBA / SectorsPerTrack) / Heads = cylinder
						;dx = (LBA / SectorsPerTrack) % Heads = head
	mov dh,dl 	;dh = head
	mov ch,al	;ch = cylinder(lower 8)
	shl ah,6
	or cl,ah 	;put upper 2 bits of cylinder in CL
	pop ax
	mov dl,al	;restore dl
	pop ax
	ret

;
;	Reads sectors from a disk
;
disk_read:
	push cx ;temp save CL(number of sectors to read)
	call lba_to_chs
	pop ax 
	mov ah,02h
	mov di,3
.retry:
	pusha ; save all registers, we don't know what the bios modifies
	stc	  ;set carry flag, some BIOS'es don't seit it
	int 13h ;carry flag cleared = success
	jnc .done
	;read failed
	popa
	call_disk_reset
	dec di
	test di,di
	jnz .retry
.fail
	; after all attempts are exhausted
	jmp floppy_error
.done
	popa
msg_hello: db 'Hello world!',ENDL,0
msg_read_failed: db 'Reading from disk failed',ENDL,0
times 510-($-$$) db 0
dw 0AA55h
