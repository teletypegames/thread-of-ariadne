; -----------------------------------------------------------
; script.asm - test builds only (-DSCRIPT=n): both joysticks
; are fed from a table instead of the CIA, so a headless VICE
; run plays a fixed sequence; an entry is (frames, player 1
; bits, player 2 bits), a zero closes the table and the last
; input is held from there on
; -----------------------------------------------------------

script_tick:
    lda scr_left
    bne sc_count
    ldy scr_pos
    lda script_tbl,y
    beq sc_done
    sta scr_left
    lda script_tbl+1,y
    sta scr_j1
    lda script_tbl+2,y
    sta scr_j2
    iny
    iny
    iny
    sty scr_pos
sc_count:
    dec scr_left
sc_done:
    rts

R1 = JOY_RIGHT
R2F = JOY_RIGHT + JOY_FIRE

script_tbl:
!if SCRIPT = 1 {         ; level 1, straight out to the right: Ariadne
    !byte 30, 0, 0       ; spins each ring until its door lets Theseus
    !byte 110, R1, R2F   ; through, then takes the next one
    !byte 4, R1, JOY_UP
    !byte 180, R1, R2F
    !byte 4, R1, JOY_UP
    !byte 240, R1, R2F
    !byte 4, R1, JOY_UP
    !byte 250, R1, R2F
    !byte 250, R1, R2F
}
!if SCRIPT = 2 {         ; two steps out, one back: the thread winds up
    !byte 30, 0, 0
    !byte 12, R1, 0
    !byte 10, 0, 0
    !byte 5, JOY_LEFT, 0
    !byte 60, 0, 0
}
    !byte 0

scr_left: !byte 0        ; frames left of the current entry
scr_pos:  !byte 0        ; offset of the next entry
scr_j1:   !byte 0        ; the scripted joystick bits
scr_j2:   !byte 0
