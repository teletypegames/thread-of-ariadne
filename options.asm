; -----------------------------------------------------------
; options.asm - optional extras, toggled with fire:
;   minotaurs     - the bulls roam the corridors from level 3
;   gear rings    - a turn also drags the next ring outward
;                   one cell the other way
;   short thread  - every level's thread a quarter shorter
;   start level   - which level a fresh run begins on (1-8)
;   music         - the lyre of crete on or off
; the settings live here and survive between levels
; -----------------------------------------------------------

OPT_ITEMS = 6

options_init:
    jsr clear_screen
    lda #MUS_TITLE
    jsr music_play       ; already playing: it rolls on unbroken

    +prbig 1, 6, WHITE, txt_options, 7

    +prtext 20, 4, LGREY, txt_oh1, txt_oh1e-txt_oh1
    +prtext 21, 1, LGREY, txt_oh2, txt_oh2e-txt_oh2
    +prtext 22, 6, LGREY, txt_oh3, txt_oh3e-txt_oh3
    +prtext 23, 4, LGREY, txt_oh4, txt_oh4e-txt_oh4
    +prtext 24, 8, LGREY, txt_oh5, txt_oh5e-txt_oh5

    lda #0
    sta optsel
    +setupd options_update
    rts

options_update:
    ; joystick / w-s steps the cursor (edge detected)
    jsr read_joy
    lda joyb
    and #3
    beq ou_udrel
    lda udheld
    bne ou_udend
    lda #1
    sta udheld
    lda joyb
    and #1               ; up
    beq ou_down
    lda optsel
    beq ou_udend
    dec optsel
    lda #SFX_CURSOR
    jsr sfx_play
    jmp ou_udend
ou_down:
    lda optsel
    cmp #OPT_ITEMS-1
    beq ou_udend
    inc optsel
    lda #SFX_CURSOR
    jsr sfx_play
    jmp ou_udend
ou_udrel:
    lda #0
    sta udheld
ou_udend:

    ; the option lines, the picked one in yellow
    ldx #0
oo_items:
    txa
    pha
    jsr draw_oitem
    pla
    tax
    inx
    cpx #OPT_ITEMS
    bne oo_items

    ; the current value next to each setting
    ldx opt_mino
    lda #7
    jsr put_oval
    ldx opt_gear
    lda #9
    jsr put_oval
    ldx opt_short
    lda #11
    jsr put_oval
    lda opt_level        ; the start level as a digit
    ora #$30
    sta SCREEN+13*40+24
    lda #LGREEN
    sta COLRAM+13*40+24
    ldx opt_music
    lda #15
    jsr put_oval

    ; blinking '>' cursor in front of the picked line
    lda #$20
    sta SCREEN+7*40+7
    sta SCREEN+9*40+7
    sta SCREEN+11*40+7
    sta SCREEN+13*40+7
    sta SCREEN+15*40+7
    sta SCREEN+17*40+7
    lda framectr
    and #16
    bne ou_fire
    ldx optsel
    lda ocur_lo,x
    sta scrlo
    lda ocur_hi,x
    sta scrhi
    ldy #0
    lda #62              ; '>'
    sta (scrlo),y
    lda scrhi
    clc
    adc #$d4             ; same cell in color RAM
    sta scrhi
    lda #YELLOW
    sta (scrlo),y

ou_fire:
    ; fire toggles the picked setting / leaves on back
    jsr start_edge
    beq ou_done
    lda optsel
    cmp #5
    beq ou_back
    cmp #4
    beq ou_tmusic
    cmp #3
    beq ou_tlevel
    cmp #2
    beq ou_tshort
    cmp #1
    beq ou_tgear
    lda opt_mino
    eor #1
    sta opt_mino
    jmp ou_tsfx
ou_tgear:
    lda opt_gear
    eor #1
    sta opt_gear
    jmp ou_tsfx
ou_tshort:
    lda opt_short
    eor #1
    sta opt_short
    jmp ou_tsfx
ou_tlevel:
    ldx opt_level        ; cycle 1-8, wrapping back to 1
    inx
    cpx #NLEVELS+1
    bne ou_tlst
    ldx #1
ou_tlst:
    stx opt_level
    jmp ou_tsfx
ou_tmusic:               ; the song stops where it is, or starts over
    lda opt_music
    eor #1
    sta opt_music
    beq ou_moff
    lda mus_tune
    jsr music_start
    jmp ou_tsfx
ou_moff:
    jsr music_stop
ou_tsfx:
    lda #SFX_SELECT
    jsr sfx_play
ou_done:
    rts
ou_back:
    lda #SFX_SELECT
    jsr sfx_play
    +fadeto menu_init

; ---- draw option line X, yellow when it is the picked one ----
draw_oitem:
    lda oitem_lo,x
    sta txtlo
    lda oitem_hi,x
    sta txthi
    lda oitem_row,x
    sta prow
    lda #9
    sta pcol
    lda oitem_len,x
    sta plen
    lda #WHITE
    cpx optsel
    bne do_store
    lda #YELLOW
do_store:
    sta pcolor
    jmp print_text

; ---- print the on/off value: X = 0/1, A = screen row ----
put_oval:
    sta prow
    lda ovtx_lo,x
    sta txtlo
    lda ovtx_hi,x
    sta txthi
    lda ovcol,x
    sta pcolor
    lda #24
    sta pcol
    lda #3
    sta plen
    jmp print_text

; ---- option tables ----
oitem_lo:  !byte <txt_omino, <txt_ogear, <txt_oshort, <txt_olev
           !byte <txt_omus, <txt_oback
oitem_hi:  !byte >txt_omino, >txt_ogear, >txt_oshort, >txt_olev
           !byte >txt_omus, >txt_oback
oitem_len: !byte 9, 10, 12, 11, 5, 4
oitem_row: !byte 7, 9, 11, 13, 15, 17
ocur_lo:                 ; cursor cells: column 7 of those rows
    !byte <(SCREEN+7*40+7), <(SCREEN+9*40+7), <(SCREEN+11*40+7)
    !byte <(SCREEN+13*40+7), <(SCREEN+15*40+7), <(SCREEN+17*40+7)
ocur_hi:
    !byte >(SCREEN+7*40+7), >(SCREEN+9*40+7), >(SCREEN+11*40+7)
    !byte >(SCREEN+13*40+7), >(SCREEN+15*40+7), >(SCREEN+17*40+7)
ovtx_lo:   !byte <txt_off, <txt_on
ovtx_hi:   !byte >txt_off, >txt_on
ovcol:     !byte LGREY, LGREEN

; ---- option texts ----
txt_omino:  !scr "minotaurs"
txt_ogear:  !scr "gear rings"
txt_oshort: !scr "short thread"
txt_olev:  !scr "start level"
txt_omus:  !scr "music"
txt_oback: !scr "back"
txt_on:    !scr "on "
txt_off:   !scr "off"
txt_oh1:   !scr "minotaurs: bulls from level 3 on"
txt_oh1e:
txt_oh2:   !scr "gear: a turn drags the next ring back"
txt_oh2e:
txt_oh3:   !scr "short: a quarter less thread"
txt_oh3e:
txt_oh4:   !scr "start: a fresh run's first level"
txt_oh4e:
txt_oh5:   !scr "music: the lyre of crete"
txt_oh5e:

; ---- the settings themselves (session-wide) ----
!ifdef FORCEOPTS {       ; test builds start with them all on
opt_mino:  !byte 1
opt_gear:  !byte 1
opt_short: !byte 1
} else {
opt_mino:  !byte 1       ; 1 = the minotaurs roam (from level 3)
opt_gear:  !byte 1       ; 1 = a turn drags the next ring along
opt_short: !byte 0       ; 1 = a quarter less thread
}
opt_level: !byte 1       ; a fresh run's first level: 1-8
opt_music: !byte 1       ; 1 = the music plays (the sfx stay on)
optsel:    !byte 0       ; picked line: 0-5
