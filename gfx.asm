; -----------------------------------------------------------
; gfx.asm - the graphics layer:
;   - the ROM font is copied into RAM and the custom tiles are
;     stamped over it (marble wall, the four diagonal halves,
;     pillar, thread, rim)
;   - a small sprite engine: every actor lives on the char
;     grid, its sprite glides toward the cell a few pixels a
;     frame
;   - fade to black: the transition between two screens
; -----------------------------------------------------------

; ---- one-time setup: font to RAM, custom tiles, VIC ----
gfx_init:
    lda #$33             ; char ROM in at $d000 (I/O out briefly)
    sta CPUPORT
    lda #$d0
    sta txthi
    lda #>CHARSET
    sta scrhi
    lda #0
    sta txtlo
    sta scrlo
    ldx #8               ; 2 KB: the full uppercase set
gc_page:
    ldy #0
gc_byte:
    lda (txtlo),y
    sta (scrlo),y
    iny
    bne gc_byte
    inc txthi
    inc scrhi
    dex
    bne gc_page
    lda #$37             ; I/O back in
    sta CPUPORT
    ldx #63              ; the eight custom tiles
gc_tiles:
    lda tile_gfx,x
    sta CHARSET+CH_WALL*8,x
    dex
    bpl gc_tiles
    ; VIC: screen at $0400, charset at $3800
    lda #$1e
    sta VMCSB
    ; sprites: hires, unexpanded, in front of the chars
    lda #0
    sta SPRDBLY
    sta SPRDBLX
    sta SPRMCEN
    sta SPRPRI
    sta SPRMSB
    rts

; ============================================================
; sprite engine
; ============================================================

; grid cell (tgc, tgr) -> pixel target tgxl/tgxh, tgy
set_target:
    lda #0
    sta tgxh
    lda tgc
    asl
    rol tgxh
    asl
    rol tgxh
    asl
    rol tgxh
    clc
    adc #24              ; first visible pixel column
    sta tgxl
    bcc st_y
    inc tgxh
st_y:
    lda tgr
    asl
    asl
    asl
    clc
    adc #50              ; first visible raster line
    sta tgy
    rts

; sprite X snaps straight onto the target
spr_jump:
    lda tgxl
    sta sprxl,x
    lda tgxh
    sta sprxh,x
    lda tgy
    sta spry,x
    rts

; sprite X slides gspd pixels per axis toward the target; the
; actors re-target every frame, so the distance always fits in
; a signed byte and a step never overshoots
spr_glide:
    lda tgxl
    sec
    sbc sprxl,x
    sta dtmp
    lda tgxh
    sbc sprxh,x          ; the high byte only carries the sign
    lda dtmp
    beq sg_y
    bmi sg_left
    cmp gspd             ; rightward: step = min(distance, speed)
    bcc sg_rgo
    lda gspd
sg_rgo:
    clc
    adc sprxl,x
    sta sprxl,x
    bcc sg_y
    inc sprxh,x
    jmp sg_y
sg_left:
    eor #$ff             ; leftward: the same on the distance
    clc
    adc #1
    cmp gspd
    bcc sg_lgo
    lda gspd
sg_lgo:
    sta dtmp
    lda sprxl,x
    sec
    sbc dtmp
    sta sprxl,x
    bcs sg_y
    dec sprxh,x
sg_y:
    lda tgy
    sec
    sbc spry,x
    beq sg_done
    bmi sg_up
    cmp gspd
    bcc sg_dgo
    lda gspd
sg_dgo:
    clc
    adc spry,x
    sta spry,x
    rts
sg_up:
    eor #$ff
    clc
    adc #1
    cmp gspd
    bcc sg_ugo
    lda gspd
sg_ugo:
    sta dtmp
    lda spry,x
    sec
    sbc dtmp
    sta spry,x
sg_done:
    rts

; push all eight sprite positions + the x msb bits to the VIC
spr_commit:
    lda #0
    sta dtmp
    ldx #7
sc_loop:
    lda sprxh,x
    beq sc_low
    lda dtmp
    ora sprbit,x
    sta dtmp
sc_low:
    txa
    asl
    tay
    lda sprxl,x
    sta SPRX0,y
    lda spry,x
    sta SPRY0,y
    dex
    bpl sc_loop
    lda dtmp
    sta SPRMSB
    rts

sprbit: !byte 1, 2, 4, 8, 16, 32, 64, 128

; ============================================================
; fade to black - six passes walk every color RAM cell (and
; the sprite colors) down the luminance chains, half a screen
; per frame; then control jumps to the init routine the
; +fadeto macro left in fadevec
; ============================================================
fade_start:
    lda #$ff
    sta statbg           ; no status band while fading
    lda #0
    sta bflash
    sta borbase
    sta fadecnt
    sta fadehalf
    +setupd fade_update
    rts

fade_update:
    lda fadehalf         ; half the color RAM per frame
    eor #1
    sta fadehalf
    bne fu_hi
    ldx #0
fu_lo:
    lda COLRAM,x
    and #15
    tay
    lda fadetbl,y
    sta COLRAM,x
    lda COLRAM+$100,x
    and #15
    tay
    lda fadetbl,y
    sta COLRAM+$100,x
    inx
    bne fu_lo
    rts
fu_hi:
    ldx #0
fu_hi2:
    lda COLRAM+$200,x
    and #15
    tay
    lda fadetbl,y
    sta COLRAM+$200,x
    lda COLRAM+$2e8,x
    and #15
    tay
    lda fadetbl,y
    sta COLRAM+$2e8,x
    inx
    bne fu_hi2
    ldx #7               ; the sprites sink with the screen
fu_spr:
    lda SPRCOL,x
    and #15
    tay
    lda fadetbl,y
    sta SPRCOL,x
    dex
    bpl fu_spr
    inc fadecnt
    lda fadecnt
    cmp #6               ; the longest chain is black after 5
    bne fu_stay
    lda #0
    sta SPR_EN
    jmp (fadevec)        ; its rts returns to the main loop
fu_stay:
    rts

fadetbl:                 ; each color, one step darker
    !byte $00, $0f, $09, $0c, $0b, $0b, $00, $08
    !byte $02, $00, $02, $00, $0b, $05, $06, $0c

; ---- the custom tiles ----
tile_gfx:                ; CH_WALL: veined marble
    !byte %11111111
    !byte %11111111
    !byte %11011111
    !byte %11101111
    !byte %11111111
    !byte %11111011
    !byte %11111101
    !byte %11111111
                         ; CH_TUR: the upper-right half
    !byte %11111111
    !byte %01111111
    !byte %00111111
    !byte %00011111
    !byte %00001111
    !byte %00000111
    !byte %00000011
    !byte %00000001
                         ; CH_TLR: the lower-right half
    !byte %00000001
    !byte %00000011
    !byte %00000111
    !byte %00001111
    !byte %00011111
    !byte %00111111
    !byte %01111111
    !byte %11111111
                         ; CH_TLL: the lower-left half
    !byte %10000000
    !byte %11000000
    !byte %11100000
    !byte %11110000
    !byte %11111000
    !byte %11111100
    !byte %11111110
    !byte %11111111
                         ; CH_TUL: the upper-left half
    !byte %11111111
    !byte %11111110
    !byte %11111100
    !byte %11111000
    !byte %11110000
    !byte %11100000
    !byte %11000000
    !byte %10000000
                         ; CH_PILLAR: a Cretan column, wide at
    !byte %11111111      ; the capital and the base
    !byte %01111110
    !byte %00111100
    !byte %00111100
    !byte %00111100
    !byte %00111100
    !byte %01111110
    !byte %11111111
                         ; CH_THREAD: a knot of the red thread
    !byte %00000000
    !byte %00011000
    !byte %00100100
    !byte %01011010
    !byte %01011010
    !byte %00100100
    !byte %00011000
    !byte %00000000
                         ; CH_RIM: the light outside
    !byte %10001000
    !byte %00000000
    !byte %00100010
    !byte %00000000
    !byte %10001000
    !byte %00000000
    !byte %00100010
    !byte %00000000

; ---- graphics layer variables ----
sprxl:    !fill 8, 0     ; sprite pixel positions (x low/high, y)
sprxh:    !fill 8, 0
spry:     !fill 8, 0
tgc:      !byte 0        ; set_target input: grid column / row
tgr:      !byte 0
tgxl:     !byte 0        ; set_target output: pixel target
tgxh:     !byte 0
tgy:      !byte 0
gspd:     !byte 0        ; spr_glide: pixels per frame
dtmp:     !byte 0        ; scratch
statbg:   !byte $ff      ; status band color, $ff = no band
bflash:   !byte 0        ; border flash: frames left + color
bcolor:   !byte 0
borbase:  !byte 0        ; steady border color of the screen
fadevec:  !byte 0, 0     ; where fade_update jumps when done
fadecnt:  !byte 0        ; fade passes completed
fadehalf: !byte 0        ; which color RAM half is next

!if (fadevec & 255) = 255 { !error "fadevec must not straddle a page" }

; ---- sprite shapes: 8x8 art in the top-left of each block;
; the VIC sees the char ROM shadow under $2000, so they never
; start below it ----
!if * < $2000 { !fill $2000 - *, 0 }
!align 63, 0
spr_hero0:               ; Theseus: a crested helmet...
    !byte %01100000, 0, 0
    !byte %00111100, 0, 0
    !byte %01111110, 0, 0
    !byte %11011011, 0, 0
    !byte %11111111, 0, 0
    !byte %01111110, 0, 0
    !byte %00111100, 0, 0
    !byte %00100100, 0, 0
    !fill 40, 0
spr_hero1:               ; ...that bobs as he goes
    !byte %00000000, 0, 0
    !byte %01100000, 0, 0
    !byte %00111100, 0, 0
    !byte %01111110, 0, 0
    !byte %11011011, 0, 0
    !byte %11111111, 0, 0
    !byte %01111110, 0, 0
    !byte %01000010, 0, 0
    !fill 40, 0
spr_sel0:                ; Ariadne's selector: four brackets
    !byte %11100111, 0, 0
    !byte %10000001, 0, 0
    !byte %10000001, 0, 0
    !byte %00000000, 0, 0
    !byte %00000000, 0, 0
    !byte %10000001, 0, 0
    !byte %10000001, 0, 0
    !byte %11100111, 0, 0
    !fill 40, 0
spr_mino0:               ; the minotaur: horns up...
    !byte %10000001, 0, 0
    !byte %11000011, 0, 0
    !byte %01111110, 0, 0
    !byte %01011010, 0, 0
    !byte %01111110, 0, 0
    !byte %00111100, 0, 0
    !byte %00100100, 0, 0
    !byte %00011000, 0, 0
    !fill 40, 0
spr_mino1:               ; ...and lowered for the charge
    !byte %00000000, 0, 0
    !byte %10000001, 0, 0
    !byte %11111111, 0, 0
    !byte %01011010, 0, 0
    !byte %01111110, 0, 0
    !byte %00111100, 0, 0
    !byte %00100100, 0, 0
    !byte %00011000, 0, 0
    !fill 40, 0

SPR_HERO = spr_hero0 DIV 64
SPR_SEL  = spr_sel0 DIV 64
SPR_MINO = spr_mino0 DIV 64

!if * > CHARSET { !error "the program ran into the charset at $3800" }
