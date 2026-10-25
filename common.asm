; -----------------------------------------------------------
; common.asm - routines shared by the states: screen drawing,
; text printing, big block font, input and the RNG
; (ported from rabbitc64, trimmed to what this game needs)
; -----------------------------------------------------------

; ---- clear screen RAM, fill color RAM with black ----
clear_screen:
    ldx #0
cls_loop:
    lda #$20             ; space
    sta SCREEN,x
    sta SCREEN+$100,x
    sta SCREEN+$200,x
    sta SCREEN+$2e8,x
    lda #BLACK
    sta COLRAM,x
    sta COLRAM+$100,x
    sta COLRAM+$200,x
    sta COLRAM+$2e8,x
    inx
    bne cls_loop
    rts

; ---- print a text line: txtlo/hi, prow, pcol, pcolor, plen ----
print_text:
    ldx prow
    lda mul40lo,x
    clc
    adc pcol
    sta scrlo
    sta collo
    lda mul40hi,x
    adc #>SCREEN         ; carry still valid from the low-byte add
    sta scrhi
    clc
    adc #$d4             ; COLRAM - SCREEN high byte distance
    sta colhi
    ldy #0
pt_loop:
    lda (txtlo),y
    sta (scrlo),y
    lda pcolor
    sta (collo),y
    iny
    cpy plen
    bne pt_loop
    rts

; ---- set scrlo/hi + collo/hi to the start of char row X ----
row_ptr:
    lda mul40lo,x
    sta scrlo
    sta collo
    lda mul40hi,x
    clc
    adc #>SCREEN
    sta scrhi
    clc
    adc #$d4             ; COLRAM - SCREEN high byte distance
    sta colhi
    rts

; ---- input ----
; joystick 1 shares the CIA port B lines the keyboard rows use,
; so before any key scan we note which rows the stick itself is
; grounding (jmask) and treat those rows as released - a held
; joystick 1 direction must not read as a phantom keypress

; read joystick port 2 merged with w/a/s/d + space (the runner),
; active-high bits in A and joyb
read_joy:
!ifdef SCRIPT {
    lda scr_j1
    sta joyb
    rts
}
    lda #$ff             ; deselect every keyboard column first
    sta CIA1_PA
    lda CIA1_PB
    eor #$ff
    and #$1f
    sta jmask            ; rows grounded by joystick 1 right now
    lda CIA1_PA
    eor #$ff
    and #$1f
    sta joyb             ; joystick 2 bits
    lda #$fd             ; keyboard column 1: w / a / s
    sta CIA1_PA
    lda CIA1_PB
    ora jmask
    and #$02             ; 'w' = up: row bit 1
    bne rj_now
    lda joyb
    ora #JOY_UP
    sta joyb
rj_now:
    lda CIA1_PB
    ora jmask
    and #$04             ; 'a' = left: row bit 2
    bne rj_noa
    lda joyb
    ora #JOY_LEFT
    sta joyb
rj_noa:
    lda CIA1_PB
    ora jmask
    and #$20             ; 's' = down: row bit 5
    bne rj_nos
    lda joyb
    ora #JOY_DOWN
    sta joyb
rj_nos:
    lda #$fb             ; 'd' = right: keyboard column 2, row bit 2
    sta CIA1_PA
    lda CIA1_PB
    ora jmask
    and #$04
    bne rj_nod
    lda joyb
    ora #JOY_RIGHT
    sta joyb
rj_nod:
    lda #$7f             ; space = fire: keyboard column 7, row bit 4
    sta CIA1_PA
    lda CIA1_PB
    ora jmask
    and #$10
    bne rj_nosp
    lda joyb
    ora #JOY_FIRE
    sta joyb
rj_nosp:
    lda #$ff
    sta CIA1_PA
    lda joyb
    rts

; read joystick port 1 merged with i/j/k/l + return (the wall
; spinner), active-high bits in A and joyb2
read_joy2:
!ifdef SCRIPT {
    lda scr_j2
    sta joyb2
    rts
}
    lda #$ff             ; no column selected: port B = joystick 1
    sta CIA1_PA
    lda CIA1_PB
    eor #$ff
    and #$1f
    sta joyb2            ; joystick 1 bits
    sta jmask            ; ... which also ground the key rows below
    lda #$ef             ; keyboard column 4: i / j / k
    sta CIA1_PA
    lda CIA1_PB
    ora jmask
    and #$02             ; 'i' = up: row bit 1
    bne rk_noi
    lda joyb2
    ora #JOY_UP
    sta joyb2
rk_noi:
    lda CIA1_PB
    ora jmask
    and #$04             ; 'j' = left: row bit 2
    bne rk_noj
    lda joyb2
    ora #JOY_LEFT
    sta joyb2
rk_noj:
    lda CIA1_PB
    ora jmask
    and #$20             ; 'k' = down: row bit 5
    bne rk_nok
    lda joyb2
    ora #JOY_DOWN
    sta joyb2
rk_nok:
    lda #$df             ; 'l' = right: keyboard column 5, row bit 2
    sta CIA1_PA
    lda CIA1_PB
    ora jmask
    and #$04
    bne rk_nol
    lda joyb2
    ora #JOY_RIGHT
    sta joyb2
rk_nol:
    lda #$fe             ; return = fire: keyboard column 0, row bit 1
    sta CIA1_PA
    lda CIA1_PB
    ora jmask
    and #$02
    bne rk_noret
    lda joyb2
    ora #JOY_FIRE
    sta joyb2
rk_noret:
    lda #$ff
    sta CIA1_PA
    lda joyb2
    rts

; fire held on either side? (stick fire, space or return)
; returns A != 0 when pressed
start_pressed:
    jsr read_joy
    and #JOY_FIRE
    bne sp_done
    jsr read_joy2
    and #JOY_FIRE
sp_done:
    rts

; edge-detected start: A = 1 only on the frame fire/space goes down
start_edge:
    jsr start_pressed
    beq se_up
    lda fheld
    bne se_no
    lda #1
    sta fheld
    rts                  ; A = 1: fresh press
se_up:
    lda #0
    sta fheld
se_no:
    lda #0
    rts

; ---- RNG: 8-bit LFSR stirred with the free-running CIA timer
; (the timer counts every cycle, so call timing = entropy) ----
rand8:
    lda seed
    asl
    bcc r8_tap
    eor #$1d
r8_tap:
    eor CIA1_TA
    sta seed
    rts

; ---- draw a text line with big 3x5 block letters ----
; txtlo/hi = text (screen codes), bigrow/bigcol = top-left cell,
; bigcolor = color, biglen = char count; each letter is 3 cells
; wide + 1 gap, 5 cells tall
draw_big:
    lda #0
    sta bigi
db_char:
    ldy bigi
    lda (txtlo),y
    cmp #$20             ; space: leave the cell empty
    beq db_next
    tax
    lda bigmap,x         ; screen code -> glyph index
    sta glyphbase
    asl                  ; glyph base = index * 5
    asl
    clc
    adc glyphbase
    sta glyphbase
    lda bigi             ; cell x = bigcol + charindex * 4
    asl
    asl
    clc
    adc bigcol
    sta charx
    lda #0
    sta rowidx
db_row:
    lda bigrow           ; row pointers from the row*40 tables
    clc
    adc rowidx
    tax
    lda mul40lo,x
    sta scrlo
    sta collo
    lda mul40hi,x
    clc
    adc #>SCREEN
    sta scrhi
    clc
    adc #$d4
    sta colhi
    lda glyphbase
    clc
    adc rowidx
    tax
    lda bigglyphs,x
    asl                  ; 3-bit pattern up to bits 7-5
    asl
    asl
    asl
    asl
    sta curbits
    ldy charx
    lda #3
    sta bitcnt
db_bit:
    asl curbits          ; leftmost pixel first
    bcc db_nobit
    lda #$a0             ; inverse space = solid block
    sta (scrlo),y
    lda bigcolor
    sta (collo),y
db_nobit:
    iny
    dec bitcnt
    bne db_bit
    inc rowidx
    lda rowidx
    cmp #5
    bne db_row
db_next:
    inc bigi
    lda bigi
    cmp biglen
    beq db_done
    jmp db_char          ; too far for a relative branch
db_done:
    rts

; ---- shared tables ----

; row * 40 lookup tables (25 rows)
mul40lo:
    !byte $00, $28, $50, $78, $a0, $c8, $f0, $18, $40, $68
    !byte $90, $b8, $e0, $08, $30, $58, $80, $a8, $d0, $f8
    !byte $20, $48, $70, $98, $c0
mul40hi:
    !byte $00, $00, $00, $00, $00, $00, $00, $01, $01, $01
    !byte $01, $01, $01, $02, $02, $02, $02, $02, $02, $02
    !byte $03, $03, $03, $03, $03

; 3x5 block font for the big titles (5 bytes per glyph,
; low 3 bits used, MSB side = left)
bigglyphs:
    !byte 0, 0, 0, 0, 0          ;  0 space
    !byte 2, 5, 7, 5, 5          ;  1 A
    !byte 3, 4, 4, 4, 3          ;  2 C
    !byte 6, 5, 5, 5, 6          ;  3 D
    !byte 7, 4, 6, 4, 7          ;  4 E
    !byte 7, 4, 6, 4, 4          ;  5 F
    !byte 7, 2, 2, 2, 7          ;  6 I
    !byte 4, 4, 4, 4, 7          ;  7 L
    !byte 5, 7, 7, 5, 5          ;  8 M
    !byte 6, 5, 5, 5, 5          ;  9 N
    !byte 7, 5, 5, 5, 7          ; 10 O
    !byte 6, 5, 6, 4, 4          ; 11 P
    !byte 6, 5, 6, 5, 5          ; 12 R
    !byte 3, 4, 2, 1, 6          ; 13 S
    !byte 7, 2, 2, 2, 2          ; 14 T
    !byte 5, 5, 2, 2, 2          ; 15 Y
    !byte 3, 4, 5, 5, 7          ; 16 G
    !byte 6, 5, 6, 5, 6          ; 17 B
    !byte 5, 5, 5, 5, 2          ; 18 V
    !byte 5, 5, 7, 5, 5          ; 19 H
    !byte 5, 5, 5, 5, 7          ; 20 U
    !byte 5, 5, 7, 7, 5          ; 21 W

bigmap:                  ; screen code (a=1..z=26) -> glyph index
    !byte  0             ; (unused)
    !byte  1, 17,  2,  3,  4,  5, 16, 19,  6,  0   ; a-j
    !byte  0,  7,  8,  9, 10, 11,  0, 12, 13, 14   ; k-t
    !byte 20, 18, 21,  0, 15,  0                   ; u-z

; ---- the Aegean wash over the two big title lines (rows 1-5 and
; 7-11): only the $a0 letter blocks are recolored, so it is
; safe over any backdrop ----
wash_title:
    inc washphase
    lda #0
    sta g8row
wt_row:
    ldx g8row
    lda wtrows,x
    tax
    jsr row_ptr
    lda washphase
    lsr                  ; half speed keeps the shimmer gentle
    clc
    adc g8row
    and #15
    tax
    lda washtbl,x
    sta rtmp
    ldy #39
wt_col:
    lda (scrlo),y
    cmp #$a0             ; only touch the letter blocks
    bne wt_skip
    lda rtmp
    sta (collo),y
wt_skip:
    dey
    bpl wt_col
    inc g8row
    lda g8row
    cmp #10
    bne wt_row
    rts

wtrows: !byte 1, 2, 3, 4, 5, 7, 8, 9, 10, 11

; ---- shared texts (screen codes) ----
; the title is split so the two lines can be placed apart
txt_t1:      !scr "thread of"
txt_t2:      !scr "ariadne"
txt_ttgname: !scr "teletype games"
txt_presents:!scr "presents"
txt_return:  !scr "fire = return"
txt_blank:   !fill 16, $20

washtbl:                 ; Aegean ramp: deep blue - turquoise - white
    !byte $06, $06, $0e, $0e, $03, $03, $01, $01
    !byte $01, $01, $03, $03, $0e, $0e, $06, $06

; ---- shared variables ----
framectr:  !byte 0       ; frame counter, incremented by the main loop
washphase: !byte 0       ; title wash offset on the big letters
seed:      !byte $a7     ; rand8 LFSR state
fheld:     !byte 0       ; fire/space edge detection state
joyb:      !byte 0       ; player 1 input bits from read_joy
joyb2:     !byte 0       ; player 2 input bits from read_joy2
jmask:     !byte 0       ; key rows grounded by joystick 1 this scan
prow:      !byte 0       ; print_text: row, column, color, length
pcol:      !byte 0
pcolor:    !byte 0
plen:      !byte 0
bigrow:    !byte 0       ; draw_big: row, column, color, length
bigcol:    !byte 0
bigcolor:  !byte 0
biglen:    !byte 0
bigi:      !byte 0       ; draw_big internals
glyphbase: !byte 0
charx:     !byte 0
rowidx:    !byte 0
bitcnt:    !byte 0
curbits:   !byte 0
rtmp:      !byte 0       ; scratch
rtmp2:     !byte 0
