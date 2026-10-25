; -----------------------------------------------------------
; sound.asm - single-voice SFX driver: each effect is a
; waveform + start pitch + per-frame pitch slide + duration,
; played on SID voice 1 (sustain 0, the decay shapes it)
; -----------------------------------------------------------

sfx_init:
    lda #$0f             ; full volume, no filter
    sta SID_VOL
    lda #0
    sta SID_V1CR
    sta SID_V1FH
    sta SID_V1FL
    sta sfx_timer
    rts

; ---- start effect A ----
sfx_play:
    tax
    lda #0
    sta SID_V1CR         ; retrigger the envelope cleanly
    lda sfxad,x
    sta SID_V1AD
    lda #0
    sta SID_V1SR
    sta SID_V1FL
    lda sfxfreq,x
    sta SID_V1FH
    sta sfx_fh
    lda #$08             ; 50% pulse width, if a pulse wave is used
    sta SID_V1PH
    lda #0
    sta SID_V1PL
    lda sfxctrl,x
    sta SID_V1CR
    sta sfx_ctrl
    lda sfxslide,x
    sta sfx_slide
    lda sfxdur,x
    sta sfx_timer
    rts

; ---- called once per frame by the main loop ----
sfx_update:
    lda sfx_timer
    beq su_idle
    dec sfx_timer
    bne su_slide
    lda #0               ; time is up: hard-silence the voice -
    sta SID_V1CR         ; waveform and frequency go too, so a
    sta SID_V1FH         ; hung envelope (the 6581 ADSR bug on
    sta SID_V1FL         ; fast retriggers) cannot whistle on
    rts
su_slide:
    lda sfx_fh           ; bend the pitch by the slide value
    clc
    adc sfx_slide
    sta sfx_fh
    sta SID_V1FH
su_idle:
    rts

; ---- effect tables:
; cursor, select, rotate, deny, win, lose, step, wind ----
sfxfreq:  !byte $50, $20, $0c, $06, $20, $38, $40, $28
sfxslide: !byte $00, $04, $00, $00, $02, $ff, $00, $00
sfxctrl:  !byte $11, $21, $81, $21, $11, $21, $11, $11
sfxad:    !byte $06, $08, $06, $08, $0a, $0a, $03, $03
sfxdur:   !byte $04, $0a, $05, $0c, $28, $30, $02, $02

; ---- driver variables ----
sfx_timer: !byte 0       ; frames left of the current effect
sfx_fh:    !byte 0       ; frequency high byte shadow
sfx_slide: !byte 0       ; signed per-frame pitch step
sfx_ctrl:  !byte 0       ; control register shadow
