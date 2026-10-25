; -----------------------------------------------------------
; play.asm - the game: eight levels of the octagonal
; labyrinth; player 1 (joystick 2) is Theseus, starting in
; its heart and running for the rim with the thread
; unwinding behind him, player 2 (joystick 1) is Ariadne:
; she picks one of the four rings and turns it, so its doors
; slide around to where Theseus can step through
;
; the thread: every fresh cell Theseus steps on costs one
; length of it and is marked; stepping back onto the cell he
; came from winds the last length up again; he cannot cross
; the thread anywhere else, and neither can a minotaur - so
; it guards his back; when it runs out he has to wind back
; and find a shorter way
;
; a ring cannot turn while the thread, Theseus or a minotaur
; is in one of its doors (the border blips red); with the gear
; rings option a turn also drags the next ring outward one
; cell the other way
;
; the walls, pillars and the thread are chars (the screen is
; the data structure), Theseus, Ariadne's selector and the
; minotaurs are hardware sprites gliding between the cells
;
; screen layout: status on row 0 (over the colored raster
; band), the labyrinth on rows 2-22, hints on row 24
; -----------------------------------------------------------

; ---- a fresh run from the menu: the picked start level, the
; clock and the score zeroed ----
new_run:
    lda opt_level
    sec
    sbc #1
    sta lvl
    lda #0
    sta tframe
    sta tsec
    sta tmin
    sta scorel
    sta scoreh
    rts

play_init:
    jsr clear_screen
    lda #MUS_GAME
    jsr music_play       ; the dance, held across the levels
    +prtext 0, 0, WHITE, txt_level, 5
    lda lvl              ; level number 1-8 next to the label
    clc
    adc #$31
    sta SCREEN+6
    lda #YELLOW
    sta COLRAM+6
    +prtext 0, 16, WHITE, txt_thread, 6
    +prtext 0, 28, WHITE, txt_score, 5
    +prtext 24, 1, DGREY, txt_hint, txt_hinte-txt_hint

    ; the labyrinth: the rim, the pillars, the four rings
    lda #CX
    sta gcx0
    lda #CY
    sta gcy0
    jsr gen_all
    lda #CH_RIM
    sta rch
    lda #COL_RIM
    sta rcol
    lda #RRIM
    jsr fill_ring
    ldx lvl
    lda lvpillar,x
    sta pi_n
    ldx pi_n
    lda #4
    jsr set_pillars
    ldx pi_n
    lda #6
    jsr set_pillars
    ldx pi_n
    lda #8
    jsr set_pillars
    lda #0
    sta selr
    sta ptmp
pi_walls:
    ldx lvl
    lda lvdoors,x
    tax
    lda ptmp
    asl
    clc
    adc #RMIN
    pha
    jsr set_doors
    pla
    jsr wall_col
    jsr draw_wall
    inc ptmp
    lda ptmp
    cmp #NWALLS
    bne pi_walls

    ; Theseus in the heart, the thread's first cell under him
    lda #CX
    sta hx
    sta THX
    lda #CY
    sta hy
    sta THY
    lda #1
    sta tlen
    lda #CH_THREAD
    sta SCREEN+CY*40+CX
    lda #COL_THREAD
    sta COLRAM+CY*40+CX

    ; this level's thread: shorter with the short thread option
    ldx lvl
    lda lvthread,x
    sta budget
    lda opt_short
    beq pi_long
    lda budget
    lsr
    lsr
    sta ptmp
    lda budget
    sec
    sbc ptmp
    sta budget
pi_long:

    jsr spawn_minos

    ; the sprites: on their cells straight away
    lda hx
    sta tgc
    lda hy
    sta tgr
    jsr set_target
    ldx #SP_HERO
    jsr spr_jump
    jsr sel_target
    ldx #SP_SEL
    jsr spr_jump
    lda #WHITE
    sta SPRCOL+SP_HERO
    lda #COL_SEL
    sta SPRCOL+SP_SEL

    ; input state: fire still held from the previous screen
    ; must be released first
    lda #0
    sta endflag
    sta rheld
    sta cheld
    lda #1
    sta udheld2
    lda #STATCOL         ; the status row gets its color band
    sta statbg
    jsr upd_score
    +setupd play_update
    jmp upd_sprites      ; positions, shapes and enables now

; ---- A = wall ring radius: rcol = its color (yellow when it
; is the one Ariadne holds); A is kept ----
wall_col:
    pha
    sec
    sbc #RMIN
    lsr
    cmp selr
    beq wc_sel
    lda #COL_WALL
    bne wc_set           ; always taken
wc_sel:
    lda #COL_SEL
wc_set:
    sta rcol
    pla
    rts

; ---- the minotaurs: on random cells of the outer corridor ----
spawn_minos:
    lda #0
    sta nmino
    ldx #NMINO-1
sm_clr:
    sta mx,x             ; no stale cell from the last level
    sta my,x
    dex
    bpl sm_clr
    lda opt_mino
    beq sm_done
    ldx lvl
    lda lvmino,x
    sta nmino
    beq sm_done
    lda #0
    sta mi
sm_one:
    lda #8
    jsr ring_ptrs
sm_pick:
    jsr rand_cell
    tay
    jsr cell_at
    lda (scrlo),y
    cmp #CH_FLOOR
    bne sm_pick
    ldy gi
    lda (ptrx),y
    sta ttx
    lda (ptry),y
    sta tty
    jsr mino_at          ; not on top of the other one
    bcs sm_pick
    ldx mi
    lda ttx
    sta mx,x
    sta tgc
    lda tty
    sta my,x
    sta tgr
    jsr rand8
    and #3
    sta mdir,x
    txa                  ; staggered beats
    asl
    asl
    clc
    adc #MINO_TIME
    sta mtime,x
    lda #COL_MINO
    sta SPRCOL+SP_MINO,x
    jsr set_target
    lda mi
    clc
    adc #SP_MINO
    tax
    jsr spr_jump
    inc mi
    lda mi
    cmp nmino
    bne sm_one
sm_done:
    rts

; ============================================================
; one frame of play
; ============================================================
play_update:
    inc tframe           ; the run clock: 50 frames = one second
    lda tframe
    cmp #50
    bne pu_clock
    lda #0
    sta tframe
    inc tsec
    lda tsec
    cmp #60
    bne pu_clock
    lda #0
    sta tsec
    inc tmin
    lda tmin
    cmp #100             ; the clock pegs at 99:59
    bne pu_clock
    lda #99
    sta tmin
pu_clock:
    jsr upd_hero
    lda endflag
    bne pu_end
    jsr upd_minos
    lda endflag
    bne pu_end
    jsr upd_ariadne
    jsr upd_rim
    jsr upd_status
    jmp upd_sprites
pu_end:
    cmp #1
    beq pu_win
    lda #SFX_LOSE
    jsr sfx_play
    +fadeto lose_init
pu_win:
    lda #SFX_WIN
    jsr sfx_play
    jsr bank_thread      ; the thread left over pays the score
    inc lvl
    lda lvl
    cmp #NLEVELS         ; the last level won: out for good
    bcs pw_final
    +fadeto play_init
pw_final:
    dec lvl
    +fadeto win_init

; ---- score += the thread left over * 10 (BCD) ----
bank_thread:
    jsr thread_left
    beq bt_done
    tax
    sed
bt_loop:
    clc
    lda scorel
    adc #$10
    sta scorel
    lda scoreh
    adc #0
    sta scoreh
    dex
    bne bt_loop
    cld
bt_done:
    rts

; ---- A = the thread still on the ball: budget - (tlen - 1) ----
thread_left:
    lda budget
    sec
    sbc tlen
    clc
    adc #1
    rts

; ---- player 1: Theseus walks the corridors, one cell a step ----
upd_hero:
    jsr read_joy
    and #$0f
    sta rdir2
    bne uh_held
    lda #0
    sta rheld
    rts
uh_held:
    lda rheld
    beq uh_first
    dec rtimer
    beq uh_rep
    rts
uh_rep:
    lda #REP_PERIOD
    sta rtimer
    jmp uh_move
uh_first:
    lda #1
    sta rheld
    lda #REP_HOLD
    sta rtimer
uh_move:
    ldx hx
    ldy hy
    lda rdir2
    lsr
    bcs uh_up
    lsr
    bcs uh_down
    lsr
    bcs uh_left
    inx                  ; right
    jmp uh_try
uh_up:
    dey
    jmp uh_try
uh_down:
    iny
    jmp uh_try
uh_left:
    dex
uh_try:
    stx ttx
    sty tty
    ldx tlen             ; back onto the cell he came from?
    cpx #2
    bcc uh_fwd
    dex
    dex
    lda THX,x
    cmp ttx
    bne uh_fwd
    lda THY,x
    cmp tty
    bne uh_fwd
    ldx tlen             ; then the thread winds up: his cell
    dex                  ; goes back to plain corridor
    stx tlen
    lda THY,x
    tay
    lda THX,x
    tax
    jsr put_floor
    jsr hero_to
    lda #SFX_WIND
    jmp sfx_play
uh_fwd:
    ldx tty
    jsr row_ptr
    ldy ttx
    lda (scrlo),y
    cmp #CH_RIM
    beq uh_out
    cmp #CH_FLOOR
    bne uh_stop          ; a wall, a pillar or the thread itself
    jsr mino_at          ; walking into a minotaur ends it
    bcs uh_dead
    jsr thread_left
    beq uh_short         ; the ball is empty: wind back first
    ldx tlen             ; the thread runs on to the new cell
    lda ttx
    sta THX,x
    lda tty
    sta THY,x
    inc tlen
    ldy ttx
    lda #CH_THREAD
    sta (scrlo),y
    lda #COL_THREAD
    sta (collo),y
    jsr hero_to
    lda #SFX_STEP
    jmp sfx_play
uh_stop:
    rts
uh_out:
    lda #1
    sta endflag
    jmp hero_to
uh_dead:
    lda #2
    sta endflag
    rts
uh_short:
    jmp deny_blip

hero_to:                 ; Theseus stands on (ttx, tty) now
    lda ttx
    sta hx
    lda tty
    sta hy
    rts

put_floor:               ; cell (X, Y) back to dark corridor
    stx ptmp
    tya
    tax
    jsr row_ptr
    ldy ptmp
    lda #CH_FLOOR
    sta (scrlo),y
    lda #BLACK
    sta (collo),y
    rts

; ---- the minotaurs: staggered random walkers ----
upd_minos:
    lda #0
    sta mi
um_loop:
    ldx mi
    cpx nmino
    bcs um_done
    dec mtime,x
    bne um_next
    lda #MINO_TIME
    sta mtime,x
    jsr mino_step
    lda endflag
    bne um_done
um_next:
    inc mi
    jmp um_loop
um_done:
    rts

mino_step:
    jsr rand8            ; 1 in 4: wander off in a new direction
    and #3
    beq ms_newdir
    ldx mi
    lda mdir,x
    jsr mtry_dir
    bcc ms_done
ms_newdir:
    lda #8
    sta mtries
ms_pick:
    jsr rand8
    and #3
    jsr mtry_dir
    bcc ms_done
    dec mtries           ; hemmed in on all sides: sit this one out
    bne ms_pick
ms_done:
    rts

mtry_dir:                ; A = direction; C clear when it moved (or won)
    tax
    ldy mi
    lda mx,y
    clc
    adc rdx,x
    sta ttx
    lda my,y
    clc
    adc rdy,x
    sta tty
    stx mtd
    lda hx               ; onto Theseus: the level is over
    cmp ttx
    bne mt_nohero
    lda hy
    cmp tty
    bne mt_nohero
    lda #2
    sta endflag
    clc
    rts
mt_nohero:
    ldx tty              ; only the open corridor: not the
    jsr row_ptr          ; thread, not the rim
    ldy ttx
    lda (scrlo),y
    cmp #CH_FLOOR
    bne mt_no
    jsr mino_at
    bcs mt_no
    ldx mi
    lda ttx
    sta mx,x
    lda tty
    sta my,x
    lda mtd
    sta mdir,x
    clc
    rts
mt_no:
    sec
    rts

; ---- is a minotaur standing on (ttx, tty)? C set if so ----
mino_at:
    ldx #0
ma_loop:
    cpx nmino
    bcs ma_no
    lda mx,x
    cmp ttx
    bne ma_next
    lda my,x
    cmp tty
    beq ma_yes
ma_next:
    inx
    bne ma_loop          ; always taken
ma_no:
    clc
    rts
ma_yes:
    sec
    rts

; ---- player 2: Ariadne picks a ring and turns it ----
upd_ariadne:
    jsr read_joy2
    sta j2bits
    and #JOY_UP+JOY_DOWN
    beq ua_udrel
    lda udheld2
    bne ua_lr
    lda #1
    sta udheld2
    lda selr
    sta ptmp             ; the ring she lets go of
    lda j2bits
    and #JOY_UP          ; up: a ring further out
    beq ua_in
    lda selr
    cmp #NWALLS-1
    beq ua_lr
    inc selr
    jmp ua_pick
ua_in:
    lda selr
    beq ua_lr
    dec selr
ua_pick:
    lda ptmp             ; the old ring back to marble, the new
    asl                  ; one in yellow
    clc
    adc #RMIN
    jsr wall_col
    jsr paint_wall
    jsr sel_radius
    jsr wall_col
    jsr paint_wall
    lda #SFX_CURSOR
    jsr sfx_play
    jmp ua_lr
ua_udrel:
    lda #0
    sta udheld2
ua_lr:
    lda j2bits
    and #JOY_LEFT+JOY_RIGHT
    sta cdir
    bne ua_held
    lda #0
    sta cheld
    rts
ua_held:
    lda cheld
    beq ua_first
    dec ctimer
    beq ua_rep
    rts
ua_rep:
    lda j2bits           ; fire held: turn faster
    and #JOY_FIRE
    beq ua_slow
    lda #FAST_PERIOD
    bne ua_per           ; always taken
ua_slow:
    lda #CREP_PERIOD
ua_per:
    sta ctimer
    jmp turn_sel
ua_first:
    lda #1
    sta cheld
    lda #CREP_HOLD
    sta ctimer
    ; fall through: the first press turns at once

; ---- turn the ring Ariadne holds one cell (and with the gear
; option the next one out the other way) ----
turn_sel:
    lda cdir
    and #JOY_LEFT        ; left = counterclockwise
    beq ts_cw
    lda #1
ts_cw:
    sta tdir
    jsr sel_radius
    jsr ring_busy
    bcs ts_deny
    jsr gear_radius
    beq ts_go
    jsr ring_busy
    bcs ts_deny
ts_go:
    lda tdir
    sta rdir
    jsr sel_radius
    jsr wall_col
    jsr turn_ring
    jsr gear_radius
    beq ts_sfx
    lda tdir
    eor #1               ; the geared ring turns the other way
    sta rdir
    jsr gear_radius
    jsr wall_col
    jsr turn_ring
ts_sfx:
    lda #SFX_ROTATE
    jmp sfx_play
ts_deny:
    jmp deny_blip

sel_radius:              ; A = the radius of the ring she holds
    lda selr
    asl
    clc
    adc #RMIN
    rts

gear_radius:             ; A = the ring the turn drags along, 0 = none
    lda opt_gear
    beq gear_none
    lda selr
    cmp #NWALLS-1
    beq gear_none
    asl
    clc
    adc #RMIN+2
    rts
gear_none:
    lda #0
    rts

; ---- C set when ring A cannot turn: the thread, Theseus or
; a minotaur is in one of its doors ----
ring_busy:
    jsr ring_ptrs
    jsr door_base
    stx gbase
    lda dcount,x
    sta gn
rb_door:
    ldx gbase
    ldy dstart,x
    jsr cell_busy
    bcs rb_yes
    jsr next_cell
    jsr cell_busy
    bcs rb_yes
    inc gbase
    dec gn
    bne rb_door
    clc
rb_yes:
    rts

cell_busy:               ; C set when cell Y holds the thread or a bull
    jsr cell_at
    lda (scrlo),y
    ldy gi
    cmp #CH_THREAD
    beq cb_yes
    lda (ptrx),y
    sta ttx
    lda (ptry),y
    sta tty
    jsr mino_at          ; keeps Y
    rts
cb_yes:
    sec
    rts

; ---- red border blip + buzz: a ring that cannot turn, or an
; empty ball of thread ----
deny_blip:
    lda #6
    sta bflash
    lda #RED
    sta bcolor
    lda #SFX_DENY
    jmp sfx_play

; ---- the rim glimmers: its glyph's dots shift every few
; frames (a new char definition moves every rim cell at once) ----
upd_rim:
    lda framectr
    and #7
    bne ur_done
    lda framectr
    and #8               ; 0 or 8: one of the two patterns
    tay
    ldx #0
ur_copy:
    lda rim_gfx,y
    sta CHARSET+CH_RIM*8,x
    iny
    inx
    cpx #8
    bne ur_copy
ur_done:
    rts

rim_gfx:
    !byte %10001000, %00000000, %00100010, %00000000
    !byte %10001000, %00000000, %00100010, %00000000
    !byte %00000000, %01000100, %00000000, %00010001
    !byte %00000000, %01000100, %00000000, %00010001

; ---- status row: the clock and the thread left ----
upd_status:
    lda tmin
    jsr two_digits
    stx SCREEN+9         ; clock cells: row 0, columns 9-13
    sta SCREEN+10
    lda #$3a             ; ':'
    sta SCREEN+11
    lda tsec
    jsr two_digits
    stx SCREEN+12
    sta SCREEN+13
    ldx #4
us_ccol:
    lda #LGREY
    sta COLRAM+9,x
    dex
    bpl us_ccol
    jsr thread_left
    pha
    jsr two_digits
    stx SCREEN+23        ; thread cells: columns 23-24
    sta SCREEN+24
    pla
    cmp #10              ; the last few lengths glow red
    lda #LGREEN
    bcs us_tcol
    lda #LRED
us_tcol:
    sta COLRAM+23
    sta COLRAM+24
    rts

; ---- the score, four BCD digits at columns 34-37 ----
upd_score:
    lda scoreh
    ldx #34
    jsr put_bcd
    lda scorel
    ldx #36
put_bcd:                 ; BCD byte A as two digits at row 0, column X
    pha
    lsr
    lsr
    lsr
    lsr
    ora #$30
    sta SCREEN,x
    pla
    and #$0f
    ora #$30
    sta SCREEN+1,x
    lda #YELLOW
    sta COLRAM,x
    sta COLRAM+1,x
    rts

; ---- Ariadne's selector sits on the top of her ring ----
sel_target:
    lda #CX
    sta tgc
    jsr sel_radius
    sta ptmp
    lda #CY
    sec
    sbc ptmp
    sta tgr
    jmp set_target

; ---- drive the sprites from the grid state ----
upd_sprites:
    lda framectr
    lsr
    lsr
    lsr
    sta frame8
    lda hx               ; Theseus glides 2 pixels a frame
    sta tgc
    lda hy
    sta tgr
    jsr set_target
    lda #2
    sta gspd
    ldx #SP_HERO
    jsr spr_glide
    jsr sel_target       ; the selector 4
    lda #4
    sta gspd
    ldx #SP_SEL
    jsr spr_glide
    lda #1               ; the minotaurs 1
    sta gspd
    lda #0
    sta mi
usp_mino:
    ldx mi
    cpx nmino
    bcs usp_shapes
    lda mx,x
    sta tgc
    lda my,x
    sta tgr
    jsr set_target
    lda mi
    clc
    adc #SP_MINO
    tax
    jsr spr_glide
    inc mi
    bne usp_mino         ; always taken
usp_shapes:
    lda frame8           ; Theseus bobs, the bulls toss their heads
    and #1
    clc
    adc #SPR_HERO
    sta SPRPTR+SP_HERO
    lda #SPR_SEL
    sta SPRPTR+SP_SEL
    lda frame8
    lsr
    pha
    and #1
    clc
    adc #SPR_MINO
    sta SPRPTR+SP_MINO
    pla
    eor #1
    and #1
    clc
    adc #SPR_MINO
    sta SPRPTR+SP_MINO+1
    ldx nmino            ; enable: Theseus, the selector, the bulls
    lda minomask,x
    sta SPR_EN
    jmp spr_commit

minomask: !byte %00000011, %00000111, %00001111

; ---- the levels: doors per ring, pillars per corridor, the
; thread's length, minotaurs (with the option on) ----
lvdoors:  !byte 3, 3, 2, 2, 2, 1, 1, 1
lvpillar: !byte 0, 1, 1, 2, 2, 2, 3, 3
lvthread: !byte 99, 90, 80, 72, 64, 58, 52, 46
lvmino:   !byte 0, 0, 1, 1, 1, 2, 2, 2

; ---- play texts ----
txt_level:  !scr "level"
txt_thread: !scr "thread"
txt_score:  !scr "score"
txt_hint:   !scr "theseus: joy2/wasd  ariadne: joy1/ijkl"
txt_hinte:

; ---- play variables ----
lvl:     !byte 0         ; the level, 0-7
budget:  !byte 0         ; this level's thread
tlen:    !byte 0         ; cells the thread runs through (THX/THY)
hx:      !byte 0         ; Theseus (screen col / row)
hy:      !byte 0
selr:    !byte 0         ; the ring Ariadne holds: 0 = innermost
tdir:    !byte 0         ; turn direction: 0 = clockwise
nmino:   !byte 0         ; minotaurs this level (0-2)
mi:      !byte 0         ; minotaur loop index
mtries:  !byte 0
mtd:     !byte 0
mx:      !fill NMINO, 0  ; minotaur positions, headings, beats
my:      !fill NMINO, 0
mdir:    !fill NMINO, 0
mtime:   !fill NMINO, 0
endflag: !byte 0         ; 0 = playing, 1 = out, 2 = caught
rheld:   !byte 0         ; Theseus direction repeat state
rtimer:  !byte 0
rdir2:   !byte 0
cheld:   !byte 0         ; turn repeat state
ctimer:  !byte 0
cdir:    !byte 0
udheld2: !byte 0         ; ring pick edge detection state
j2bits:  !byte 0
pi_n:    !byte 0         ; pillars per corridor this level
ptmp:    !byte 0         ; scratch
ttx:     !byte 0         ; move target (col / row)
tty:     !byte 0
frame8:  !byte 0         ; framectr / 8: the animation beat
tframe:  !byte 0         ; run clock: frame, second, minute
tsec:    !byte 0
tmin:    !byte 0
scorel:  !byte 0         ; the score, four BCD digits
scoreh:  !byte 0
