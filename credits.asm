; -----------------------------------------------------------
; credits.asm - the same crew as rabbitc64, but a new look:
; rainbow bars scrolling along the top and bottom edges in
; opposite directions, a rainbow sweep across the big
; CREDITS, each crew line in its own fixed color and the
; ai warning pulsing grey-white (no scroller, no parade)
; -----------------------------------------------------------

credits_init:
    jsr clear_screen
    lda #MUS_TITLE
    jsr music_play       ; already playing: it rolls on unbroken

    ; rainbow bars: solid blocks across rows 0 and 24
    ldx #39
ci_bars:
    lda #$a0
    sta SCREEN,x
    sta SCREEN+24*40,x
    dex
    bpl ci_bars

    +prbig 2, 6, WHITE, txt_credits, 7

    +prtext  9, 13, WHITE,  txt_ttgname, 14

    +prtext 12,  8, CYAN,   txt_crew0, txt_crew0e-txt_crew0
    +prtext 13, 10, LBLUE,  txt_crew1, txt_crew1e-txt_crew1
    +prtext 14,  9, WHITE,  txt_crew2, txt_crew2e-txt_crew2
    +prtext 15, 10, LRED,   txt_crew3, txt_crew3e-txt_crew3

    +prtext 17,  9, LGREY,  txt_ai1, txt_ai1e-txt_ai1
    +prtext 18, 12, LGREY,  txt_ai2, txt_ai2e-txt_ai2

    lda #0
    sta barphase
    +setupd credits_update
    rts

credits_update:
    ; the edge bars crawl in opposite directions
    lda framectr
    and #3
    bne cu_barsdone
    inc barphase
cu_barsdone:
    ldx #39
cu_bars:
    txa
    clc
    adc barphase
    and #7
    tay
    lda raintbl,y
    sta COLRAM,x         ; top bar: colors drift left
    lda barphase
    stx rtmp
    sec
    sbc rtmp
    and #7
    tay
    lda raintbl,y
    sta COLRAM+24*40,x   ; bottom bar: colors drift right
    dex
    bpl cu_bars

    ; rainbow sweep across the big CREDITS (rows 2-6)
    lda #0
    sta rtmp2
cu_sweep:
    lda #2
    clc
    adc rtmp2
    tax
    jsr row_ptr
    lda framectr
    lsr
    lsr
    clc
    adc rtmp2
    and #7
    tax
    lda raintbl,x
    sta rtmp
    ldy #32              ; the letters span columns 6-32
cu_scol:
    lda (scrlo),y
    cmp #$a0             ; only touch the letter blocks
    bne cu_sskip
    lda rtmp
    sta (collo),y
cu_sskip:
    dey
    cpy #5
    bne cu_scol
    inc rtmp2
    lda rtmp2
    cmp #5
    bne cu_sweep

    ; the ai warning pulses grey-white
    lda framectr
    lsr
    lsr
    lsr
    and #7
    tax
    lda pulsetbl,x
    sta rtmp
    ldx #17
    jsr row_ptr
    ldy #30
cu_p1:
    lda rtmp
    sta (collo),y
    dey
    cpy #8
    bne cu_p1
    ldx #18
    jsr row_ptr
    ldy #27
cu_p2:
    lda rtmp
    sta (collo),y
    dey
    cpy #11
    bne cu_p2

    ; blink the return prompt
    lda framectr
    and #32
    bne cu_hide
    +prtext 21, 13, CYAN, txt_return, 13
    jmp cu_input
cu_hide:
    +prtext 21, 13, CYAN, txt_blank, 13
cu_input:
    jsr start_edge
    beq cu_stay
    +fadeto menu_init    ; back to the menu
cu_stay:
    rts

; ---- tables ----
pulsetbl:                ; grey-white pulse (8 entries, cyclic)
    !byte $0b, $0c, $0f, $01, $01, $0f, $0c, $0b

raintbl:                 ; rainbow ramp
    !byte $02, $08, $07, $0d, $03, $0e, $04, $0a

; ---- the crew (content ported from rabbitc64) ----
txt_crew0: !scr "mr.zero - tasnadi zsolt"
txt_crew0e:
txt_crew1: !scr "mr.one - tari balazs"
txt_crew1e:
txt_crew2: !scr "mr.two - timar zoltan"
txt_crew2e:
txt_crew3: !scr "mr.three - mezo bela"
txt_crew3e:
txt_ai1:   !scr "warning: this game was"
txt_ai1e:
txt_ai2:   !scr "written by an ai"
txt_ai2e:

; ---- credits variables ----
barphase:  !byte 0       ; edge bar scroll offset
