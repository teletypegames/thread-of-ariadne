; -----------------------------------------------------------
; win.asm - the escape screen after the last level: big
; ESCAPED with the gold wash, the run's time and score; fire
; returns to the main menu
; -----------------------------------------------------------

win_init:
    jsr clear_screen
    lda #MUS_WIN
    jsr music_play       ; the escape song

    +prbig 3, 6, YELLOW, txt_escaped, 7

    +prtext 11, 5, WHITE, txt_welldone, txt_welldonee-txt_welldone
    +prtext 13, 7, LGREY, txt_beaten, txt_beatene-txt_beaten

    ; the round time into the readout: "time: mm:ss"
    lda tmin
    jsr two_digits
    stx txt_timev
    sta txt_timev+1
    lda tsec
    jsr two_digits
    stx txt_timev+3
    sta txt_timev+4
    +prtext 15, 14, CYAN, txt_time, txt_timee-txt_time

    ; and the score: "score: 0000"
    lda scoreh
    jsr bcd_chars
    stx txt_scorev
    sta txt_scorev+1
    lda scorel
    jsr bcd_chars
    stx txt_scorev+2
    sta txt_scorev+3
    +prtext 17, 14, YELLOW, txt_wscore, txt_wscoree-txt_wscore

    lda #0
    sta washphase
    +setupd win_update
    rts

win_update:
    ; the border celebrates along on the same gold ramp
    lda framectr
    lsr
    lsr
    and #15
    tax
    lda washtbl,x
    sta borbase

    ; the gold wash rolls down the big letters (rows 3-7)
    inc washphase
    lda #0
    sta rtmp2
wu_row:
    lda #3
    clc
    adc rtmp2
    tax
    jsr row_ptr
    lda washphase
    lsr
    clc
    adc rtmp2
    and #15
    tax
    lda washtbl,x
    sta rtmp
    ldy #32              ; the letters span columns 6-32
wu_col:
    lda (scrlo),y
    cmp #$a0
    bne wu_skip
    lda rtmp
    sta (collo),y
wu_skip:
    dey
    cpy #5
    bne wu_col
    inc rtmp2
    lda rtmp2
    cmp #5
    bne wu_row

    ; blink the prompt
    lda framectr
    and #32
    bne wu_hide
    +prtext 20, 14, YELLOW, txt_firemenu, txt_firemenue-txt_firemenu
    jmp wu_input
wu_hide:
    +prtext 20, 14, YELLOW, txt_blank, txt_firemenue-txt_firemenu
wu_input:
    jsr start_edge
    beq wu_stay
    +fadeto menu_init    ; a win leads back to the main screen
wu_stay:
    rts

bcd_chars:               ; BCD byte A -> X / A: two digit screen codes
    pha
    lsr
    lsr
    lsr
    lsr
    ora #$30
    tax
    pla
    and #$0f
    ora #$30
    rts

two_digits:              ; A (0-99) -> X / A: two digit screen codes
    ldx #$30
td_tens:
    cmp #10
    bcc td_ones
    sbc #10              ; carry is set here
    inx
    bne td_tens
td_ones:
    ora #$30
    rts

; ---- win texts ----
txt_escaped:  !scr "escaped"
txt_welldone: !scr "ariadne's thread led you out!"
txt_welldonee:
txt_beaten:   !scr "you escaped the labyrinth"
txt_beatene:
txt_time:     !scr "time: "
txt_timev:    !scr "00:00"
txt_timee:
txt_wscore:   !scr "score: "
txt_scorev:   !scr "0000"
txt_wscoree:
txt_firemenu: !scr "fire = menu"
txt_firemenue:
