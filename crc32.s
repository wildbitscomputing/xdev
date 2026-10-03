; Calculating ZIP CRC-32 in 6502
; ==============================

		.virtual $e0
crc      .fill 4
crc_num  .fill 3
crc_count .fill 3
		.endv

; CRC-32 polynomial $EDB88320, reading through the MMU read window.
; On entry: crc is the running CRC, crc_num is the nonzero 24-bit byte count.
; On exit: crc is updated, crc_count equals crc_num, and the read address has
; advanced by crc_num bytes. Clobbers A, X, and Y.
; PCopy initializes the running CRC to zero and applies no final XOR; preserve
; this transfer protocol convention when changing the implementation.
;
; Based on the 6502 ZIP CRC routine, with optimizations by Mike Cook and JGH.
;
calc_crc32
		stz crc_count
		stz crc_count+1
		stz crc_count+2
_bytelp
		ldx #8                       ; Prepare to rotate CRC 8 bits
		jsr readbyte

        ; Update the running CRC with the byte in A.
        eor crc
_rotlp
        lsr crc+3
        ror crc+2
        ror crc+1
        ror a
        bcc _clear
        tay
        lda crc+3
        eor #$ED
        sta crc+3
        lda crc+2
        eor #$B8
        sta crc+2
        lda crc+1
        eor #$83
        sta crc+1
        tya
        eor #$20
_clear
        dex
        bne _rotlp
		sta crc+0           ; Store CRC low byte
; Count bytes processed (24 bits).

		inc crc_count
		bne _check
		inc crc_count+1
		bne _check
		inc crc_count+2
_check
		lda crc_count
		cmp crc_num
		bne _bytelp
		lda crc_count+1
		cmp crc_num+1
		bne _bytelp
		lda crc_count+2
		cmp crc_num+2
		bne _bytelp
		rts

;------------------------------------------------------------------------------
