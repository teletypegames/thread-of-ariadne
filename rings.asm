; -----------------------------------------------------------
; rings.asm - the octagonal rings of the labyrinth
;
; a ring of radius R is walked once around like a turtle,
; clockwise from the left end of its top edge: a straight run
; of 2*(R-CHAMFER) cells, a staircase of CHAMFER (step, step)
; pairs across the corner, and so on for the eight sides -
; 8*R cells in all; every cell's screen column and row, the
; glyph it wears as a wall and its door flag go into the
; ring's slot of the RAM tables, so turning a ring is just a
; matter of moving its doors (a short list of where each one
; starts) one cell on, which shuts one cell and opens another
;
; the diagonal pieces: a staircase cell on the outer side of
; the step gets the half-block that leans inward, the one on
; the inner side the half-block that leans outward; together
; they draw a clean 45 degree band (the first cell of each
; staircase joins the straight edge, so it stays a block)
; -----------------------------------------------------------

; ---- point the six slot pointers at ring A's slots, and set
; rlen = 8*R, rlenm1 = 8*R-1 ----
ring_ptrs:
    sta gr
    sec
    sbc #RMIN
    tax
    lda ringofs_lo,x
    sta ptrx
    sta ptry
    sta ptrg
    sta ptrd
    sta ptrl
    sta ptrh
    lda ringofs_hi,x
    clc
    adc #>RINGX
    sta ptrx+1
    clc
    adc #>(RINGY-RINGX)
    sta ptry+1
    clc
    adc #>(RINGG-RINGY)
    sta ptrg+1
    clc
    adc #>(RINGD-RINGG)
    sta ptrd+1
    clc
    adc #>(RINGL-RINGD)
    sta ptrl+1
    clc
    adc #>(RINGH-RINGL)
    sta ptrh+1
    lda gr
    asl
    asl
    asl
    sta rlen
    sec
    sbc #1
    sta rlenm1
    rts

; ---- walk ring A around (gcx0, gcy0) into its slots; every
; door starts shut ----
gen_ring:
    jsr ring_ptrs
    lda gr
    sec
    sbc #CHAMFER
    sta gstr
    asl
    sta gstr2            ; the straight runs: 2*(R-CHAMFER) cells
    lda gcx0             ; start: the left end of the top edge
    sec
    sbc gstr
    sta gx
    lda gcy0
    sec
    sbc gr
    sta gy
    ldy #0
    sty gseg
gr_seg:
    lda gseg
    lsr                  ; even = a straight side, odd = a corner;
    tax                  ; seg/2 is the (first) direction either way
    stx gd1
    bcs gr_diag
    lda gstr2
    sta gcnt
gr_st:
    lda gcnt
    beq gr_next
    lda #CH_WALL
    jsr gr_put
    ldx gd1
    jsr gr_move
    dec gcnt
    jmp gr_st
gr_diag:
    inx                  ; the second step turns a quarter clockwise
    txa
    and #3
    sta gd2
    lda #CHAMFER
    sta gcnt
gr_pair:
    lda gcnt
    cmp #CHAMFER         ; the first cell still belongs to the edge
    bne gr_pa
    lda #CH_WALL
    bne gr_pput          ; always taken
gr_pa:
    ldx gseg
    lda glyph_a,x
gr_pput:
    jsr gr_put
    ldx gd1
    jsr gr_move
    ldx gseg
    lda glyph_b,x
    jsr gr_put
    ldx gd2
    jsr gr_move
    dec gcnt
    bne gr_pair
gr_next:
    inc gseg
    lda gseg
    cmp #8
    bne gr_seg
    rts

gr_put:                  ; cell Y = (gx, gy), glyph A, door shut
    sta (ptrg),y
    lda gx
    sta (ptrx),y
    lda gy
    sta (ptry),y
    tax                  ; and its screen address
    lda mul40lo,x
    clc
    adc gx
    sta (ptrl),y
    lda mul40hi,x
    adc #>SCREEN
    sta (ptrh),y
    lda #0
    sta (ptrd),y
    iny
    rts

gr_move:                 ; one step in direction X
    lda gx
    clc
    adc rdx,x
    sta gx
    lda gy
    clc
    adc rdy,x
    sta gy
    rts

; ---- every ring of the labyrinth around (gcx0, gcy0) ----
gen_all:
    lda #RMIN
    sta gall
ga_loop:
    lda gall
    jsr gen_ring
    inc gall
    lda gall
    cmp #RRIM+1
    bne ga_loop
    rts

; ---- cell Y of the current ring: scrlo/collo point at it
; and Y = 0 (the index stays in gi) ----
cell_at:
    sty gi
    lda (ptrl),y
    sta scrlo
    sta collo
    lda (ptrh),y
    sta scrhi
    clc
    adc #$d4             ; COLRAM - SCREEN high byte distance
    sta colhi
    ldy #0
    rts

; ---- draw wall ring A: walls in rcol, open doors as floor ----
draw_wall:
    jsr ring_ptrs
    ldy #0
dw_loop:
    lda (ptrd),y
    bne dw_door
    lda (ptrg),y
    sta gch
    jsr cell_at
    lda gch
    sta (scrlo),y
    lda rcol
    sta (collo),y
    jmp dw_next
dw_door:
    jsr cell_at
    lda #CH_FLOOR
    sta (scrlo),y
    lda #BLACK
    sta (collo),y
dw_next:
    ldy gi
    iny
    cpy rlen
    bne dw_loop
    rts

; ---- recolor wall ring A's wall cells in rcol ----
paint_wall:
    jsr ring_ptrs
    ldy #0
pw_loop:
    lda (ptrd),y
    bne pw_next
    jsr cell_at
    lda rcol
    sta (collo),y
    ldy gi
pw_next:
    iny
    cpy rlen
    bne pw_loop
    rts

; ---- fill every cell of ring A with char rch in rcol ----
fill_ring:
    jsr ring_ptrs
    ldy #0
fr_loop:
    jsr cell_at
    lda rch
    sta (scrlo),y
    lda rcol
    sta (collo),y
    ldy gi
    iny
    cpy rlen
    bne fr_loop
    rts

; ---- open X evenly spaced doors (two cells wide) in wall
; ring A, the first one at a random cell; the doors' first
; cells go into the ring's door list ----
set_doors:
    stx gn
    stx gcnt
    jsr ring_ptrs
    jsr door_base
    lda gcnt
    sta dcount,x
    stx gbase
    jsr spread           ; gstep = 8R / n, gpos = a random cell
sd_loop:
    ldx gbase
    lda gpos
    sta dstart,x
    inc gbase
    tay
    lda #1
    sta (ptrd),y
    jsr next_cell
    lda #1
    sta (ptrd),y
    jsr spread_next
    dec gn
    bne sd_loop
    rts

; ---- X = the door list of wall ring gr: (R - RMIN) / 2 * 4 ----
door_base:
    lda gr
    sec
    sbc #RMIN
    asl                  ; (R-3)/2 * 4 = (R-3) * 2
    tax
    rts

; ---- Y = the cell after / before cell Y, around the ring ----
next_cell:
    iny
    cpy rlen
    bne nc_done
    ldy #0
nc_done:
    rts
prev_cell:
    dey
    bpl pc_done
    ldy rlenm1
pc_done:
    rts

; ---- stand X evenly spaced pillars across corridor ring A ----
set_pillars:
    stx gn
    cpx #0
    beq spl_done
    jsr ring_ptrs
    jsr spread
spl_loop:
    ldy gpos
    jsr cell_at
    lda #CH_PILLAR
    sta (scrlo),y
    lda #COL_PILLAR
    sta (collo),y
    jsr spread_next
    dec gn
    bne spl_loop
spl_done:
    rts

; ---- gstep = rlen / gn (gn = 1-4), gpos = random cell ----
spread:
    lda rlen
    ldx #0
sr_div:
    cmp gn
    bcc sr_done
    sbc gn               ; carry is set here
    inx
    bne sr_div           ; always taken
sr_done:
    stx gstep
    jsr rand_cell
    sta gpos
    rts

spread_next:             ; gpos += gstep, around the ring
    lda gpos
    clc
    adc gstep
    cmp rlen
    bcc sn_keep
    sbc rlen             ; carry is set here
sn_keep:
    sta gpos
    rts

; ---- A = a random cell index of the current ring ----
rand_cell:
    jsr rand8
    and #$7f
    cmp rlen
    bcs rand_cell
    rts

; ---- turn wall ring A one cell, rdir 0 = clockwise, 1 =
; back: every door moves on, the cell it leaves shuts (a wall
; in rcol) and the cell it reaches opens ----
turn_ring:
    jsr ring_ptrs
    jsr door_base
    stx gbase
    lda dcount,x
    sta gn
tr_door:
    ldx gbase
    ldy dstart,x
    lda rdir
    bne tr_back
    jsr shut_cell        ; clockwise: the first cell shuts...
    jsr next_cell
    tya
    ldx gbase
    sta dstart,x
    jsr next_cell        ; ...and the one past the second opens
    jsr open_cell
    jmp tr_next
tr_back:
    jsr next_cell        ; back: the second cell shuts...
    jsr shut_cell
    ldx gbase
    ldy dstart,x
    jsr prev_cell        ; ...and the one before the first opens
    tya
    sta dstart,x
    jsr open_cell
tr_next:
    inc gbase
    dec gn
    bne tr_door
    rts

shut_cell:               ; cell Y becomes wall again (Y is kept)
    lda #0
    sta (ptrd),y
    lda (ptrg),y
    sta gch
    jsr cell_at
    lda gch
    sta (scrlo),y
    lda rcol
    sta (collo),y
    ldy gi
    rts

open_cell:               ; cell Y becomes an open door (Y is kept)
    lda #1
    sta (ptrd),y
    jsr cell_at
    lda #CH_FLOOR
    sta (scrlo),y
    lda #BLACK
    sta (collo),y
    ldy gi
    rts

; ---- tables ----
ringofs_lo:              ; slot of ring R: 4*R*(R-1) - 24
    !byte <0, <24, <56, <96, <144, <200, <264, <336
ringofs_hi:
    !byte >0, >24, >56, >96, >144, >200, >264, >336

rdx: !byte 1, 0, $ff, 0  ; right, down, left, up
rdy: !byte 0, 1, 0, $ff

glyph_a:                 ; outer staircase cells, by corner segment
    !byte 0, CH_TUR, 0, CH_TLR, 0, CH_TLL, 0, CH_TUL
glyph_b:                 ; inner staircase cells
    !byte 0, CH_TLL, 0, CH_TUL, 0, CH_TUR, 0, CH_TLR

; ---- ring variables ----
gr:      !byte 0         ; the ring at hand: radius,
rlen:    !byte 0         ; its cell count,
rlenm1:  !byte 0         ; minus one
gcx0:    !byte CX        ; the center the rings are walked around
gcy0:    !byte CY
gx:      !byte 0         ; the turtle
gy:      !byte 0
gseg:    !byte 0
gd1:     !byte 0
gd2:     !byte 0
gcnt:    !byte 0
gstr:    !byte 0
gstr2:   !byte 0
gall:    !byte 0
gi:      !byte 0         ; cell index inside the slot
gch:     !byte 0         ; scratch
gn:      !byte 0         ; doors / pillars left to place
gstep:   !byte 0
gpos:    !byte 0
rcol:    !byte 0         ; drawing color / char parameters
rch:     !byte 0
rdir:    !byte 0         ; turn direction
gbase:   !byte 0         ; door list offset
dcount:  !fill NWALLS*MAXDOORS, 0  ; doors per wall ring (at its list offset)
dstart:  !fill NWALLS*MAXDOORS, 0  ; each door's first cell
