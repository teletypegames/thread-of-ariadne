; -----------------------------------------------------------
; intro.asm - boot screen ported from rabbitc64: giant TTG
; letters built from 8x8 bitmaps with an Aegean color wash
; running down them, TELETYPE GAMES / PRESENTS below;
; advances to the title card after a few seconds or
; on fire
; -----------------------------------------------------------

INTRO_LROW = 3           ; top cell row of the giant letters
INTRO_TIME = 250         ; frames before it advances on its own

intro_init:
    jsr clear_screen
    lda #MUS_TITLE
    jsr music_play       ; the song of the pyramid carries the whole front end

    ; T T G at columns 6 / 16 / 26
    lda #<glyph_t
    sta txtlo
    lda #>glyph_t
    sta txthi
    lda #6
    sta g8col
    jsr draw_glyph8
    lda #16
    sta g8col
    jsr draw_glyph8
    lda #<glyph_g
    sta txtlo
    lda #>glyph_g
    sta txthi
    lda #26
    sta g8col
    jsr draw_glyph8

    +prtext 13, 13, WHITE, txt_ttgname, 14
    +prtext 15, 16, LGREY, txt_presents, 8

    lda #INTRO_TIME
    sta introt
    lda #0
    sta washphase
    +setupd intro_update
    rts

intro_update:
    ; Aegean wash: recolor the letter rows from the cyclic ramp
    inc washphase
    lda #0
    sta g8row
iw_row:
    lda #INTRO_LROW
    clc
    adc g8row
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
    ldy #33              ; the letters span columns 6-33
iw_col:
    lda (scrlo),y
    cmp #$a0             ; only touch the letter blocks
    bne iw_skip
    lda rtmp
    sta (collo),y
iw_skip:
    dey
    cpy #5
    bne iw_col
    inc g8row
    lda g8row
    cmp #8
    bne iw_row

    ; fire skips, otherwise wait out the timer
    jsr start_edge
    beq iw_tick
    +fadeto title_init
iw_tick:
    dec introt
    bne iw_done
    +fadeto title_init
iw_done:
    rts

; ---- draw an 8x8-cell giant letter: txtlo/hi = 8-byte
; bitmap, g8col = left cell column ----
draw_glyph8:
    lda #0
    sta g8row
g8_row:
    lda #INTRO_LROW
    clc
    adc g8row
    tax
    jsr row_ptr
    ldy g8row
    lda (txtlo),y
    sta curbits
    ldy g8col
    lda #8
    sta bitcnt
g8_bit:
    asl curbits          ; leftmost pixel first
    bcc g8_next
    lda #$a0             ; inverse space = solid block
    sta (scrlo),y
    lda #CYAN
    sta (collo),y
g8_next:
    iny
    dec bitcnt
    bne g8_bit
    inc g8row
    lda g8row
    cmp #8
    bne g8_row
    rts

; ---- 8x8 letter bitmaps ----
glyph_t:
    !byte %11111111
    !byte %11111111
    !byte %00111100
    !byte %00111100
    !byte %00111100
    !byte %00111100
    !byte %00111100
    !byte %00111100
glyph_g:
    !byte %00111100
    !byte %01111110
    !byte %11000011
    !byte %11000000
    !byte %11001111
    !byte %11000011
    !byte %01111110
    !byte %00111100

; ---- intro variables ----
introt:    !byte 0       ; frames left before auto-advancing
g8row:     !byte 0       ; glyph renderer / wash internals
g8col:     !byte 0
