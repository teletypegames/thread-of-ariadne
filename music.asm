; -----------------------------------------------------------
; music.asm - two-voice music player on SID voices 2 and 3,
; so voice 1 stays free for the SFX driver: voice 2 carries
; the bass and the hand drum, voice 3 the melody - a plucked
; lyre over the front end, the reedy aulos in the game
;
; every tune is written in the dorian mode on d (d e f g a b
; c), the old greek mode; the game dance runs in 7/8, the
; kalamatianos step: slow - quick - quick
;
; a tune is an order list per voice; an order entry is the
; address of a pattern, a pattern is a run of note/length
; pairs closed by MEND, and a zero word closes the order
; list (it wraps back to its start, so a tune loops forever)
;
; lengths count ticks and a tick is `speed` frames, so the
; tempo sits in the tune header: 4 ticks = a quarter note
;
; note byte: octave 1-6 in the high nibble, semitone in the
; low one; MREST silences the voice, MDRUM strikes the drum
; -----------------------------------------------------------

; ---- note names for the pattern data ----
O1 = $10                 ; octave 1: c-1 (32.7 hz) ...
O2 = $20
O3 = $30
O4 = $40
O5 = $50
O6 = $60                 ; ... octave 6: b-6 (1975.5 hz)
NC  = 0
NCS = 1
ND  = 2
NDS = 3
NE  = 4
NF  = 5
NFS = 6
NG  = 7
NGS = 8
NA  = 9
NAS = 10
NB  = 11

MREST = 0                ; rest: gate off, the release fades it
MDRUM = 2                ; the hand drum: a noise slap
MEND  = $ff              ; end of pattern

; ---- instruments ----
INS_DRONE = 0            ; soft triangle drone under the title
INS_BASS  = 1            ; plucked pulse bass for the drum grooves
INS_LEAD  = 2            ; narrow pulse: the reedy aulos
INS_HORN  = 3            ; fuller pulse for the escape fanfare
INS_MOAN  = 4            ; wavering triangle for the game over
INS_LYRE  = 5            ; a plucked string that rings out

DRUM_FH = $28            ; the drum's noise pitch
DRUM_AD = $05            ; and its short decay

; ============================================================
; driver
; ============================================================

; ---- silence both music voices, forget the tune ----
music_init:
    lda #$ff
    sta mus_tune
    ; fall through

; ---- stop the music, but remember which tune it was ----
music_stop:
    lda #0
    sta mus_on
    sta SID+$0b          ; voice 2: waveform, gate and pitch
    sta SID+$07
    sta SID+$08
    sta SID+$12          ; voice 3: the same
    sta SID+$0e
    sta SID+$0f
    rts

; ---- A = tune id: start it, unless it is already running ----
music_play:
    cmp mus_tune
    bne music_start
    ldy mus_on
    bne mx_pdone         ; the same tune is on: let it run on
music_start:
    sta mus_tune
    lda opt_music
    beq music_stop       ; muted: the tune is remembered, not played
    ldy mus_tune
    lda tune_speed,y
    sta mus_speed
    lda #1
    sta mus_tick         ; the first tick lands on the next frame
    lda tune_ordalo,y    ; voice 2 follows the bass order list
    sta ordlo
    lda tune_ordahi,y
    sta ordhi
    lda tune_ordblo,y    ; voice 3 the melody's
    sta ordlo+1
    lda tune_ordbhi,y
    sta ordhi+1
    ldx #0
    lda tune_insa,y
    tay
    jsr mx_setins
    ldy mus_tune
    ldx #1
    lda tune_insb,y
    tay
    jsr mx_setins
    ldx #1
mx_stch:
    lda #0
    sta ordpos,x
    sta chvib,x
    sta chvibt,x
    sta chvibp,x
    lda #1
    sta chdur,x          ; expires on the first tick
    jsr mx_nextpat
    dex
    bpl mx_stch
    lda #1
    sta mus_on
mx_pdone:
    rts

; ---- copy instrument Y into channel X's shadow registers ----
mx_setins:
    lda ins_ctrl,y
    sta chctrl,x
    lda ins_ad,y
    sta chad,x
    lda ins_sr,y
    sta chsr,x
    lda ins_pw,y
    sta chpw,x
    lda ins_vdep,y
    sta chvdep,x
    lda ins_vdel,y
    sta chvdel,x
    rts

; ============================================================
; called once per frame by the main loop: the tick drives the
; notes, every frame bends the vibrato
; ============================================================
music_update:
    lda mus_on
    beq mx_done
    dec mus_tick
    bne mx_vibs
    lda mus_speed
    sta mus_tick
    ldx #1
mx_ticks:
    jsr mx_chtick
    dex
    bpl mx_ticks
mx_vibs:
    ldx #1
mx_vibch:
    jsr mx_chvib
    dex
    bpl mx_vibch
mx_done:
    rts

; ---- one tick of channel X: count the note out, then take
; the next event from the pattern ----
mx_chtick:
    dec chdur,x
    beq mx_fetch
    rts
mx_fetch:
    lda patlo,x
    sta musptr
    lda pathi,x
    sta musptr+1
    ldy #0
    lda (musptr),y
    cmp #MEND
    bne mx_event
    jsr mx_nextpat       ; the pattern ran out: on to the next
    jmp mx_fetch
mx_event:
    sta chnote,x
    iny
    lda (musptr),y
    sta chdur,x
    lda patlo,x          ; step over the pair
    clc
    adc #2
    sta patlo,x
    bcc mx_nowrap
    inc pathi,x
mx_nowrap:
    lda chnote,x
    ; fall through: play it

; ---- A = note code, X = channel: set the voice up ----
mx_note:
    ldy chofs,x          ; y = this voice's register offset
    cmp #MREST
    beq mx_rest
    cmp #MDRUM
    beq mx_drum
    pha
    and #$0f             ; the semitone picks the top octave's pitch
    tay
    lda notefl,y
    sta chflo,x
    lda notefh,y
    sta chfhi,x
    pla
    lsr
    lsr
    lsr
    lsr                  ; the octave halves it down from octave 6
    sta mtmp
    lda #6
    sec
    sbc mtmp
    beq mx_gate
    tay
mx_oct:
    lsr chfhi,x
    ror chflo,x
    dey
    bne mx_oct
mx_gate:
    ldy chofs,x
    lda chad,x
    sta SID+5,y
    lda chsr,x
    sta SID+6,y
    lda #0
    sta SID+2,y          ; pulse width low
    lda chpw,x
    sta SID+3,y
    lda #0
    sta SID+4,y          ; gate down first: a clean retrigger
    lda chflo,x
    sta SID+0,y
    lda chfhi,x
    sta SID+1,y
    lda chctrl,x
    sta SID+4,y          ; waveform + gate: the note sounds
    lda #0
    sta chvibt,x         ; the vibrato swells in after the attack
    sta chvibp,x
    lda chvdep,x
    sta chvib,x
    rts
mx_rest:
    lda #0
    sta chvib,x
    lda chctrl,x
    and #$fe             ; gate down, the release carries it out
    sta SID+4,y
    rts
mx_drum:
    lda #0
    sta chvib,x
    sta SID+4,y
    sta SID+0,y
    sta SID+6,y          ; no sustain: the decay is the whole slap
    lda #DRUM_AD
    sta SID+5,y
    lda #DRUM_FH
    sta SID+1,y
    lda #$81             ; noise + gate
    sta SID+4,y
    rts

; ---- channel X: take the next pattern off the order list ----
mx_nextpat:
    ldy ordpos,x
    lda ordlo,x
    sta musptr
    lda ordhi,x
    sta musptr+1
    lda (musptr),y
    sta patlo,x
    iny
    lda (musptr),y
    bne mx_npok          ; a zero page closes the list: wrap
    lda #0               ; back to the head of the list
    tay
    sta ordpos,x
    lda (musptr),y
    sta patlo,x
    iny
    lda (musptr),y
mx_npok:
    sta pathi,x
    iny
    tya
    sta ordpos,x
    rts

; ---- channel X: bend the pitch once the note has settled ----
mx_chvib:
    lda chvib,x
    beq mx_vdone         ; this voice or this note does not waver
    lda chvibt,x
    cmp chvdel,x
    bcs mx_vrun
    inc chvibt,x         ; still inside the delay
mx_vdone:
    rts
mx_vrun:
    ldy chvibp,x         ; 12 frames around the circle: ~4 hz
    iny
    cpy #12
    bcc mx_vph
    ldy #0
mx_vph:
    tya
    sta chvibp,x
    lda vibtbl,y
    sta mtmp
    lda #0
    bit mtmp             ; sign-extend the step into mtmp2:mtmp
    bpl mx_vpos
    lda #$ff
mx_vpos:
    sta mtmp2
    ldy chvib,x          ; the depth is a shift count
mx_vsh:
    asl mtmp
    rol mtmp2
    dey
    bne mx_vsh
    ldy chofs,x
    clc
    lda chflo,x
    adc mtmp
    sta SID+0,y
    lda chfhi,x
    adc mtmp2
    sta SID+1,y
    rts

; ============================================================
; tables
; ============================================================

; ---- octave 6, c-6 to b-6; the lower octaves are these
; halved, which the note code shifts out ----
notefl: !byte $9c, $c0, $23, $c8, $b4, $eb, $72, $4c, $80, $12, $08, $68
notefh: !byte $45, $49, $4e, $52, $57, $5c, $62, $68, $6e, $75, $7c, $83

; ---- the vibrato circle (signed, scaled by the depth) ----
vibtbl: !byte 0, 2, 3, 4, 3, 2, 0, $fe, $fd, $fc, $fd, $fe

; ---- the voices' register offsets from $d400 ----
chofs:  !byte $07, $0e   ; voice 2 = bass, voice 3 = melody

; ---- instruments: drone, bass, lead, horn, moan, lyre ----
ins_ctrl: !byte $11, $41, $41, $41, $11, $41
ins_ad:   !byte $69, $09, $29, $18, $8a, $0a
ins_sr:   !byte $c9, $00, $c8, $b8, $ca, $00
ins_pw:   !byte $08, $08, $02, $06, $08, $04
ins_vdep: !byte 0, 0, 4, 3, 5, 0   ; vibrato depth (shift), 0 = none
ins_vdel: !byte 0, 0, 8, 10, 20, 0 ; frames before it starts

; ---- the tunes ----
tune_speed:  !byte 8, 5, 6, 12     ; frames per tick
tune_ordalo: !byte <ord_tb, <ord_gb, <ord_wb, <ord_lb
tune_ordahi: !byte >ord_tb, >ord_gb, >ord_wb, >ord_lb
tune_ordblo: !byte <ord_tm, <ord_gm, <ord_wm, <ord_lm
tune_ordbhi: !byte >ord_tm, >ord_gm, >ord_wm, >ord_lm
tune_insa:   !byte INS_DRONE, INS_BASS, INS_BASS, INS_DRONE
tune_insb:   !byte INS_LYRE, INS_LEAD, INS_HORN, INS_MOAN

; ============================================================
; the title song - a lyre over a drone: the palace at night
; ============================================================
ord_tm: !word pat_tm1, pat_tm2, pat_tm3, pat_tm4, 0
ord_tb: !word pat_tb1, pat_tb2, pat_tb3, pat_tb1, 0

pat_tm1:
    !byte O4+NA, 4, O5+ND, 4, O5+NC, 2, O4+NA, 2, O4+NG, 4
    !byte O4+NF, 4, O4+NG, 2, O4+NA, 2, O4+ND, 8
    !byte MEND
pat_tm2:
    !byte O4+ND, 2, O4+NF, 2, O4+NA, 4, O4+NG, 4, O4+NF, 2, O4+NE, 2
    !byte O4+ND, 4, O4+NE, 2, O4+NF, 2, O4+NE, 8
    !byte MEND
pat_tm3:
    !byte O4+NA, 4, O5+NC, 4, O5+ND, 4, O5+NE, 4
    !byte O5+NF, 2, O5+NE, 2, O5+ND, 2, O5+NC, 2, O5+ND, 8
    !byte MEND
pat_tm4:
    !byte O5+NC, 4, O4+NA, 4, O4+NG, 2, O4+NF, 2, O4+NE, 4
    !byte O4+ND, 12, MREST, 4
    !byte MEND

pat_tb1:
    !byte O2+ND, 16, O1+NA, 16, MEND
pat_tb2:
    !byte O2+ND, 16, O2+NC, 16, MEND
pat_tb3:
    !byte O1+NG, 16, O1+NA, 16, MEND

; ============================================================
; the game song - the kalamatianos: 7/8, slow - quick - quick,
; the aulos weaving over bass and drum
; ============================================================
ord_gm: !word pat_gm1, pat_gm2, pat_gm3, pat_gm4, 0
ord_gb: !word pat_gbd, pat_gbd, pat_gbc, pat_gbd
        !word pat_gbd, pat_gba, pat_gbd, pat_gbd, 0

pat_gm1:
    !byte O5+ND, 6, O5+NC, 4, O4+NA, 4
    !byte O4+NG, 6, O4+NA, 4, O4+NF, 4
    !byte MEND
pat_gm2:
    !byte O4+NA, 2, O5+NC, 2, O5+ND, 2, O5+NE, 4, O5+ND, 4
    !byte O5+NC, 6, O4+NA, 4, O4+NG, 4
    !byte MEND
pat_gm3:
    !byte O4+NF, 6, O4+NG, 4, O4+NA, 4
    !byte O4+ND, 6, O4+NE, 4, O4+NF, 4
    !byte MEND
pat_gm4:
    !byte O4+NE, 6, O4+NF, 4, O4+NG, 4
    !byte O4+NA, 6, MREST, 8
    !byte MEND

pat_gbd:
    !byte O2+ND, 6, MDRUM, 4, MDRUM, 4
    !byte MEND
pat_gba:
    !byte O1+NA, 6, MDRUM, 4, MDRUM, 4
    !byte MEND
pat_gbc:
    !byte O2+NC, 6, MDRUM, 4, MDRUM, 4
    !byte MEND

; ============================================================
; the escape song - a fanfare climbing out into the light
; ============================================================
ord_wm: !word pat_wm1, pat_wm2, 0
ord_wb: !word pat_wbd, pat_wbd, pat_wba, pat_wbd, 0

pat_wm1:
    !byte O4+ND, 2, O4+NF, 2, O4+NA, 2, O5+ND, 2, O5+NC, 4, O5+ND, 4
    !byte O5+NE, 2, O5+NF, 2, O5+NE, 2, O5+ND, 2, O4+NA, 8
    !byte MEND
pat_wm2:
    !byte O4+NA, 2, O5+NC, 2, O5+ND, 2, O5+NE, 2, O5+NF, 4, O5+NE, 4
    !byte O5+ND, 12, MREST, 4
    !byte MEND

pat_wbd:
    !byte O2+ND, 4, MDRUM, 4, O2+ND, 4, MDRUM, 4
    !byte MEND
pat_wba:
    !byte O1+NA, 4, MDRUM, 4, O1+NA, 4, MDRUM, 4
    !byte MEND

; ============================================================
; the game over song - a slow dirge over the drone
; ============================================================
ord_lm: !word pat_lm1, pat_lm2, 0
ord_lb: !word pat_tb1, pat_tb1, 0

pat_lm1:
    !byte O4+ND, 4, O4+NC, 4, O3+NA, 8
    !byte O3+NG, 4, O3+NF, 4, O3+NE, 8
    !byte MEND
pat_lm2:
    !byte O3+NF, 4, O3+NE, 4, O3+ND, 8
    !byte O3+NE, 4, O3+ND, 12
    !byte MEND

; ============================================================
; driver variables (index 0 = voice 2 / bass, 1 = voice 3)
; ============================================================
mus_on:    !byte 0       ; 0 = the voices are quiet
mus_tune:  !byte $ff     ; the tune last asked for
mus_speed: !byte 8       ; frames per tick
mus_tick:  !byte 1       ; frames left of this tick
mtmp:      !byte 0       ; scratch
mtmp2:     !byte 0

ordlo:  !byte 0, 0       ; the channel's order list
ordhi:  !byte 0, 0
ordpos: !byte 0, 0       ; byte offset in it
patlo:  !byte 0, 0       ; the next event inside the pattern
pathi:  !byte 0, 0
chdur:  !byte 0, 0       ; ticks left of the sounding note
chnote: !byte 0, 0
chflo:  !byte 0, 0       ; the note's pitch, before the vibrato
chfhi:  !byte 0, 0
chvib:  !byte 0, 0       ; vibrato depth of this note (0 = none)
chvibt: !byte 0, 0       ; frames since the note started
chvibp: !byte 0, 0       ; where it is around the circle
chctrl: !byte 0, 0       ; the instrument, unpacked per channel
chad:   !byte 0, 0
chsr:   !byte 0, 0
chpw:   !byte 0, 0
chvdep: !byte 0, 0
chvdel: !byte 0, 0
