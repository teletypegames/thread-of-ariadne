; -----------------------------------------------------------
; title.asm - the title card between the TTG logo and the
; menu: big THREAD OF / ARIADNE under the rolling Aegean wash,
; below it the two inner rings of the labyrinth with a door
; in each, and the red thread winding out of the heart
; through them, a cell at a time, Theseus at its end;
; advances to the menu after a few seconds or on fire
; -----------------------------------------------------------

TITLE_TIME = 250         ; frames before it advances on its own
TITLE_CY   = 18          ; center row of the little labyrinth
TPATH_LEN  = 8           ; cells of the thread's way out
TPATH_STEP = 12          ; frames per cell

title_init:
    jsr clear_screen
    lda #MUS_TITLE
    jsr music_play       ; already playing: it rolls on unbroken

    +prbig 1, 2, CYAN, txt_t1, 9
    +prbig 7, 6, LBLUE, txt_t2, 7

    ; rings 3 and 5 around the little heart, a door in each
    lda #CX
    sta gcx0
    lda #TITLE_CY
    sta gcy0
    lda #3
    jsr gen_ring
    lda #5
    jsr gen_ring
    lda #3
    jsr ring_ptrs
    jsr title_door
    lda #COL_WALL
    sta rcol
    lda #3
    jsr draw_wall
    lda #5
    jsr ring_ptrs
    jsr title_door
    lda #5
    jsr draw_wall

    +prtext 24, 1, LGREY, txt_waits, txt_waitse-txt_waits

    lda #TITLE_TIME
    sta titlet
    lda #0
    sta washphase
    sta tpos
    lda #1
    sta tstep
    +setupd title_update
    rts

title_door:              ; open cells 0 and 1 of the current ring
    ldy #0
    lda #1
    sta (ptrd),y
    iny
    sta (ptrd),y
    rts

title_update:
    jsr wash_title       ; the Aegean wash rolls down the title

    ; the thread winds on, a cell every TPATH_STEP frames
    dec tstep
    bne tu_input
    lda #TPATH_STEP
    sta tstep
    ldx tpos
    cpx #TPATH_LEN
    bcs tu_input
    txa
    beq tu_head          ; the first cell has no thread behind it
    dex                  ; the old head turns into thread
    jsr tpath_cell
    lda #CH_THREAD
    sta (scrlo),y
    lda #COL_THREAD
    sta (collo),y
tu_head:
    ldx tpos             ; Theseus steps on
    jsr tpath_cell
    lda #$51             ; filled dot
    sta (scrlo),y
    lda #WHITE
    sta (collo),y
    inc tpos

tu_input:
    ; fire skips, otherwise wait out the timer
    jsr start_edge
    beq tu_tick
    +fadeto menu_init
tu_tick:
    dec titlet
    bne tu_done
    +fadeto menu_init
tu_done:
    rts

; ---- cell X of the thread's way: scrlo/collo at its row,
; Y = its column ----
tpath_cell:
    lda tpathy,x
    clc
    adc #TITLE_CY
    pha
    lda tpathx,x
    clc
    adc #CX
    tay
    pla
    tax
    jmp row_ptr          ; keeps Y

; ---- the way out: up through the door of ring 3, a step
; left along the corridor, up through the door of ring 5 ----
tpathx: !byte 0, 0, 0, 0, 0, $ff, $ff, $ff
tpathy: !byte 0, $ff, $fe, $fd, $fc, $fc, $fb, $fa

txt_waits:  !scr "theseus waits in the heart of the maze"
txt_waitse:

; ---- title variables ----
titlet:    !byte 0       ; frames left before auto-advancing
tpos:      !byte 0       ; thread cells drawn so far
tstep:     !byte 0       ; frames to the next one
