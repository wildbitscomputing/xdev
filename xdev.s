;
; 64tass Cross Dev Stub for the Jr Micro Kernel
;
; Build with "make" (requires 64tass).
;

; Most of the time this does nothing, it checks to see if it needs to do
; something for the FoenixMgr, if not, it just runs the next kernel firmware
; program
;

; Current Functions:
;   Launch Program that is loaded into memory, via runpgx, or runpgz
;   Copy a file to the SDCARD if FoenixMgr has placed one in memory (pcopy)
;

        .cpu "65c02"

; some Kernel Stuff
		.include "kernel_api.s"

; The springboard saves the active MMU configuration and restores it with
; CPU slot 5 mapped to physical block 5 before launching the uploaded program.

; Some Global Direct page stuff

; MMU modules needs 0-1F

	.virtual $20
temp0 .fill 4
temp1 .fill 4
temp2 .fill 4
temp3 .fill 4
	.endv

; Event Buffer at $30
event_type = $30
event_buf  = $31
event_ext  = $32

event_file_data_read  = event_type+kernel_event_event_t_file_data_read
event_file_data_wrote = event_type+kernel_event_event_t_file_wrote_wrote

; arguments
args_buf = $40
args_buflen = $42

old_sp = $A0

mmu_lock_springboard = $60 ; about 17 bytes

crossdev_signature = $80
crossdev_pc        = $88  ; jump to here

; File uses $B0-$BF
; Term uses $C0-$CF
; Kernel uses $F0-FF

; One 8 KiB kernel module mapped at $A000. See the boot block below.

		* = $A000
sig		.byte $f2,$56		; signature
		.byte 1            ; 1 8k block
		.byte 5            ; mount at $a000
		.word start		; start here
		.byte 1			; version
		.byte 0			; reserved
		.byte 0			; reserved
		.byte 0			; reserved
		.text 'xdev' 		; firmware module name
		.byte 0
		.byte 0
		.text 'CrossDev - FoenixMgr[runpgx,runpgz,pcopy].'	; description
		.byte 0

start
		; check for springboard
		ldx #7
_check_crossdev
		lda @w txt_crossdev,x
		cmp @b crossdev_signature,x
		bne _no_crossdev

		dex
		bpl _check_crossdev

		; break the signature, so the next reset will work
		stz @b crossdev_signature

		; we need to unmap ourselves so slot 5 is mapped to slot 5
		jsr mmu_unlock

		lda #5
		sta old_mmu0+5	; when lock is called it will map $A000 to physical $A000

		; need to place a copy of mmu_lock, where it won't be unmapped
		ldx #mmu_lock_end-mmu_lock
_copy_springboard		lda mmu_lock,x
		sta mmu_lock_springboard,x
		dex
		bpl _copy_springboard

		; construct more stub code
		lda #$20   ; jsr mmu_lock_springboard
		sta temp0
		lda #<mmu_lock_springboard
		sta temp0+1
		lda #>mmu_lock_springboard
		sta temp0+2

		lda #$6C ; jmp (|abs)
		sta temp0+3

		lda #<crossdev_pc
		sta @b temp0+4
		lda #>crossdev_pc
		sta @b temp0+5

		jmp temp0

_no_crossdev

		; check for pcopy, file copy request
		ldx #7
_check_pcopy
		lda @w txt_copyfile,x
		cmp @b crossdev_signature,x
		bne _no_pcopy

		dex
		bpl _check_pcopy

		; break the signature, so the next reset will work
		stz @b crossdev_signature

		jsr pcopy

_no_pcopy
		; just boot the machine, into the next program

		lda #$42	; next boot module; xdev occupies firmware block $41
		sta kernel_args_run_block_id
		jmp kernel_RunBlock

;------------------------------------------------------------------------------
txt_crossdev .text 'CROSSDEV'
txt_copyfile .text 'COPYFILE'

;------------------------------------------------------------------------------
; Strings and other includes

		.include "mmu.s"
		.include "term.s"
		.include "file.s"
		.include "crc32.s"
		.include "pcopy.s"

; Fail if the module outgrows its single 8 KiB firmware block.
firmware_end
        .cerror firmware_end > $C000, "xdev exceeds its 8 KiB firmware block"
        .fill $C000-*,$EA
