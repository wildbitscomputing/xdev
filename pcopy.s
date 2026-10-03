;
; PCopy program, for Jr
;

; Maximum transfer size: 447 KiB.
MAX_LENGTH = $6FC00

;------------------------------------------------------------------------------
; Some Global Direct page stuff

; MMU modules needs 0-1F

; Event Buffer at $30

;args = $300

xfer_data = $10000

; first thing is a c string with the name of the file
; second thing is the CRC32 (4 bytes, little-endian)
; third thing is the file length (3 bytes, little-endian)
; followed by file data

; File uses $B0-$BF
; Term uses $C0-$CF
; Kernel uses $F0-FF
; crc32 uses  $E0-E9

		.virtual $2000
filename .fill 256
crc32    .fill 4
len24    .fill 3
		.endv

;

pcopy
		jsr TermInit					; Clear Terminal, etc
		jsr mmu_unlock					; Set us up, so we can read/write system memory

		; Looking for data message
		lda #<txt_look_for_data
		ldx #>txt_look_for_data
		jsr TermPUTS

		ldy #`xfer_data
		lda #<xfer_data
		ldx #>xfer_data
		jsr TermPrintAXYH
		jsr TermCR

		lda #<xfer_data
		ldx #>xfer_data
		ldy #`xfer_data
		jsr set_read_address

		; Print out the filename
		; copy the filename into our mapped space
		ldx #0
_name	jsr readbyte
		sta filename,x
		inx
		cmp #0
		bne _name

		lda #<txt_filename
		ldx #>txt_filename
		jsr TermPUTS

		lda #<filename
		ldx #>filename
		jsr TermPUTS
		jsr TermCR

;-----------------------------------------------

		; Print out the CRC 32
		lda #<txt_crc32
		ldx #>txt_crc32
		jsr TermPUTS

		ldx #0
_crc32  jsr readbyte
		sta crc32,x
		inx
		cpx #4
		bcc _crc32

		lda crc32+3
		jsr TermPrintAH
		lda crc32+2
		jsr TermPrintAH
		lda crc32+1
		jsr TermPrintAH
		lda crc32+0
		jsr TermPrintAH
		jsr TermCR

;--------------------------------------------------

		; Print out the length
		lda #<txt_length
		ldx #>txt_length
		jsr TermPUTS

		ldx #0
_len	jsr readbyte
		sta len24,x
		inx
		cpx #3
		bcc _len

		lda len24
		ldx len24+1
		ldy len24+2
		jsr TermPrintAXYH
		jsr TermCR

		lda len24+2
		cmp #`MAX_LENGTH
		bcc _length_good
		bne _length_bad
		lda len24+1
		cmp #>MAX_LENGTH
		bcc _length_good
		bne _length_bad
		lda len24
		cmp #<MAX_LENGTH
		bcc _length_good
		beq _length_good
_length_bad

		jsr TermCR
		lda #<txt_bad_len
		ldx #>txt_bad_len
		jsr TermPUTS
_bad_len bra _bad_len

_length_good

;--------------------------------------------------

pcopy_data_start   = temp1
pcopy_length  = temp2

		; save data start for the write later, if we decide to write
		jsr get_read_address
		sta pcopy_data_start
		stx pcopy_data_start+1
		sty pcopy_data_start+2

; Save the length for CRC verification and writing.
		lda len24
		sta pcopy_length			; used for the read in
		lda len24+1
		sta pcopy_length+1
		lda len24+2 		; used for CRC status
		sta pcopy_length+2

; display crc
		lda #<txt_calc32
		ldx #>(txt_calc32+1)
		jsr TermPUTS

; Calculate CRC in chunks, updating the progress display.
		jsr fancy_crc

; Display the result CRC
		lda crc+2
		ldx crc+3
		jsr TermPrintAXH
		lda crc
		ldx crc+1
		jsr TermPrintAXH
		jsr TermCR

; match
		lda #<txt_match
		ldx #>txt_match
		jsr TermPUTS

		lda crc32
		cmp crc
		bne _no
		lda crc32+1
		cmp crc+1
		bne _no
		lda crc32+2
		cmp crc+2
		bne _no
		lda crc32+3
		cmp crc+3
		bne _no

		lda #<txt_yes
		ldx #>txt_yes
		jsr TermPUTS
		jsr TermCR
		bra _save_that_file
_no
		lda #<txt_no
		ldx #>txt_no
		jsr TermPUTS

; crc did not match
		jsr mmu_lock
_crc_failed bra _crc_failed

_save_that_file

		lda #<txt_create
		ldx #>txt_create
		jsr TermPUTS

		lda #<filename
		ldx #>filename
		jsr TermPUTS
		jsr TermCR

; Create the file

		lda #<event_type
		sta kernel_args_events
		lda #>event_type
		sta kernel_args_events+1

		; clear the event queue
		php
		sei  ; disable interrupts to keep events from queueing?
_loop
        jsr kernel_Yield
        jsr kernel_NextEvent
        bcc _loop
		; end clear event queue

		lda #<filename
		ldx #>filename
		jsr fcreate
		bcc _good

		pha
		lda #<txt_fail
		ldx #>txt_fail
		jsr TermPUTS

		pla
		jsr TermPrintAH
		jsr TermCR
		jsr mmu_lock
_failed bra _failed

_good
		lda #<txt_write
		ldx #>txt_write
		jsr TermPUTS

		lda pcopy_length
		ldx pcopy_length+1
		ldy pcopy_length+2
		jsr TermPrintAXYH
		jsr TermCR

		lda pcopy_data_start
		ldx pcopy_data_start+1
		ldy pcopy_data_start+2
		jsr set_read_address
; Where we reading from in memory
		lda pcopy_data_start+2
		jsr TermPrintAH
		lda pcopy_data_start+1
		jsr TermPrintAH
		lda pcopy_data_start+0
		jsr TermPrintAH
		jsr TermCR

		lda pcopy_length
		ldx pcopy_length+1
		ldy pcopy_length+2
		jsr fwrite

		jsr fclose
		plp 	   	; restore interrupt state

		jsr TermCR
		jsr TermCR

		lda #<txt_Complete
		ldx #>txt_Complete
		jsr TermPUTS

		jsr mmu_lock

_done   bra _done
; Wait for reset after copying.

;-----------------------------------------------
;
; Do the CRC
;
fancy_crc

_crc_count = temp3
CRC_BLOCK_SIZE = 64

		; initialize the count down
		lda pcopy_length
		sta _crc_count
		lda pcopy_length+1
		sta _crc_count+1
		lda pcopy_length+2
		sta _crc_count+2
		stz _crc_count+3

		ldx term_x
		ldy term_y
		phx
		phy

; salt crc
		stz crc
		stz crc+1
		stz crc+2
		stz crc+3

; crc_num = blocksize
		lda #<CRC_BLOCK_SIZE
		sta crc_num+0
		lda #>CRC_BLOCK_SIZE
		sta crc_num+1
		lda #`CRC_BLOCK_SIZE
		sta crc_num+2

_loop
		; Display length completed
		lda _crc_count+2
		ldx _crc_count+3
		jsr TermPrintAXH
		lda _crc_count
		ldx _crc_count+1
		jsr TermPrintAXH
		ply
		plx
		phx
		phy
		; Reset Cursor
		jsr TermSetXY

		; if :crc_count < BLOCK_SIZE
		;    crc_num = :crc_count

		lda _crc_count+2
		cmp crc_num+2
		bcc _less
		bne _go

		lda _crc_count+1
		cmp crc_num+1
		bcc _less
		bne _go

		lda _crc_count+0
		cmp crc_num+0
		bcc _less
		bne _go
_less
		; last bit, let's go!
		lda _crc_count+0
		sta crc_num+0

		lda _crc_count+1
		sta crc_num+1

		lda _crc_count+2
		sta crc_num+2

_go
; calc crc
		jsr calc_crc32

		sec
		lda _crc_count+0
		sbc crc_num+0
		sta _crc_count+0
		lda _crc_count+1
		sbc crc_num+1
		sta _crc_count+1
		lda _crc_count+2
		sbc crc_num+2
		sta _crc_count+2

		ora _crc_count+1
		ora _crc_count+0

		bne _loop

		ply
		plx

		rts

txt_look_for_data .text 'Looking for data at $'
		.byte 0
txt_filename      .text '          filename: '
		.byte 0
txt_length        .text '            length: $'
		.byte 0
txt_crc32         .text '             CRC32: $'
		.byte 0
txt_calc32		  .text '  Calculated CRC32: $'
		.byte 0
txt_match		  .text '         CRC Match: '
		.byte 0
txt_create        .text '            Create: '
		.byte 0
txt_write		  .text '             Write: $'
		.byte 0
txt_fail          .text '            Failed: $'
		.byte 0
txt_bad_len       .text ' Invalid Length'
		.byte 0

txt_Complete      .text ' Copy Completed'
		.byte 0
txt_yes .text 'yes'
		.byte 13,0
txt_no  .text 'no, data corrupt'
		.byte 13,0

txt_done .byte 13
		.text 'pcopy is done.'
		.byte 13,0
