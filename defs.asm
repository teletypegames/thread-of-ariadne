; -----------------------------------------------------------
; defs.asm - hardware registers, constants, zero page, macros
; included first by main.asm
; -----------------------------------------------------------

; ---- hardware registers ----
RASTER  = $d012          ; current raster line
BORDER  = $d020          ; border color register
BG      = $d021          ; background color register
SCREEN  = $0400          ; screen RAM (40x25 chars)
COLRAM  = $d800          ; color RAM
SCRCTL  = $d011          ; control 1: raster msb, y-scroll
SPR_EN  = $d015          ; sprite enable bits
SPRX0   = $d000          ; sprite 0 x (x/y pairs go up from here)
SPRY0   = $d001          ; sprite 0 y
SPRMSB  = $d010          ; 9th x position bit of each sprite
SPRDBLY = $d017          ; sprite y expand
VMCSB   = $d018          ; memory setup: screen + charset base
SPRPRI  = $d01b          ; sprite/background priority
SPRMCEN = $d01c          ; sprite multicolor enable
SPRDBLX = $d01d          ; sprite x expand
SPRCOL  = $d027          ; sprite colors, 8 registers
CPUPORT = $01            ; 6510 port: ROM/RAM banking
CIA1_PA = $dc00          ; CIA1 port A: keyboard columns / joystick 2
CIA1_PB = $dc01          ; CIA1 port B: keyboard rows / joystick 1
CIA1_TA = $dc04          ; CIA1 timer A low byte: free-running entropy

CHARSET = $3800          ; RAM charset: ROM font + the custom tiles
SPRPTR  = SCREEN + $3f8  ; sprite shape pointers

; ---- SID registers ----
; voice 1 belongs to the SFX driver, voices 2 and 3 to the
; music player, which reaches their registers as SID+n,y
; (y = 7 for voice 2, 14 for voice 3)
SID      = $d400         ; the chip's base
SID_V1FL = $d400         ; voice 1 frequency low
SID_V1FH = $d401         ; voice 1 frequency high
SID_V1PL = $d402         ; voice 1 pulse width low
SID_V1PH = $d403         ; voice 1 pulse width high
SID_V1CR = $d404         ; voice 1 control (waveform + gate)
SID_V1AD = $d405         ; voice 1 attack/decay
SID_V1SR = $d406         ; voice 1 sustain/release
SID_VOL  = $d418         ; filter mode + master volume

; ---- SFX IDs ----
SFX_CURSOR = 0           ; ring pick / menu step: click
SFX_SELECT = 1           ; menu fire: rising tone
SFX_ROTATE = 2           ; a ring turns: stone grinding on stone
SFX_DENY   = 3           ; blocked turn or step: low buzz
SFX_WIN    = 4           ; out of the labyrinth: rising jingle
SFX_LOSE   = 5           ; caught: descending sweep
SFX_STEP   = 6           ; the thread unwinds a cell: soft tick
SFX_WIND   = 7           ; the thread winds back up: a lower tick
NSFX       = 8

; ---- music IDs ----
MUS_TITLE = 0            ; the lyre song: intro, title, menu, story
MUS_GAME  = 1            ; the 7/8 dance under the levels
MUS_WIN   = 2            ; the escape song
MUS_LOSE  = 3            ; the game over dirge

; ---- colors ----
BLACK   = 0
WHITE   = 1
RED     = 2
CYAN    = 3
PURPLE  = 4
GREEN   = 5
BLUE    = 6
YELLOW  = 7
ORANGE  = 8
BROWN   = 9
LRED    = 10
DGREY   = 11
MGREY   = 12
LGREEN  = 13
LBLUE   = 14
LGREY   = 15

; ---- joystick bits (after read_joy / read_joy2, active high) ----
JOY_UP    = 1
JOY_DOWN  = 2
JOY_LEFT  = 4
JOY_RIGHT = 8
JOY_FIRE  = 16

; ---- the labyrinth ----
; concentric octagonal rings around the center cell, one char
; thick: a ring of radius R is a closed loop of 8*R cells -
; straight edges joined by staircase diagonals that cut the
; corners CHAMFER cells deep (with the same cut on every ring
; the loops tile the plane without gaps or overlaps)
;   R 0-2      the heart of the labyrinth, Theseus starts here
;   R 3,5,7,9  the four wall rings Ariadne turns, with doors
;   R 4,6,8    the corridors between them, with fixed pillars
;   R 10       the rim: reaching it is the way out
CHAMFER  = 3
CX       = 19            ; screen cell of the center
CY       = 12
RMIN     = 3             ; the innermost wall ring
RRIM     = 10            ; the rim
NRINGS   = RRIM - RMIN + 1
NWALLS   = 4             ; the turning rings (1 = innermost)
NLEVELS  = 8
NMINO    = 2             ; minotaur sprite slots (a level uses 0-2)
MAXDOORS = 4             ; door list slots per wall ring
TMAX     = 99            ; the longest thread (a level's budget)

; ---- characters (the custom tiles live in the RAM charset) ----
CH_WALL   = $e0          ; marble block: a straight wall piece
CH_TUR    = $e1          ; the diagonal pieces: filled upper-right,
CH_TLR    = $e2          ; lower-right,
CH_TLL    = $e3          ; lower-left,
CH_TUL    = $e4          ; upper-left half
CH_PILLAR = $e5          ; a fixed pillar across a corridor
CH_THREAD = $e6          ; a cell the thread runs through
CH_RIM    = $e7          ; the rim, the light outside
CH_FLOOR  = $20          ; space: corridor

; ---- the actors are hardware sprites ----
SP_HERO  = 0             ; player 1, Theseus
SP_SEL   = 1             ; player 2, Ariadne's ring selector
SP_MINO  = 2             ; the minotaurs ride sprites 2-3

; ---- Minoan palette: the turquoise and blue of the frescoes
; and the sea, white stone, red ochre ----
COL_WALL   = LGREY       ; white stone rings
COL_SEL    = CYAN        ; the ring Ariadne holds
COL_PILLAR = RED         ; red Cretan columns across the corridors
COL_THREAD = LRED        ; Ariadne's red thread
COL_RIM    = LBLUE       ; the rim: the glimmer of the sea outside
COL_MINO   = ORANGE      ; the minotaurs
STATCOL    = BLUE        ; background band behind the status row

; ---- game timing ----
REP_HOLD    = 10         ; hero: frames before a held dir repeats
REP_PERIOD  = 5          ; hero: frames between repeat steps
CREP_HOLD   = 12         ; ring turn: same, a touch slower...
CREP_PERIOD = 5
FAST_PERIOD = 2          ; ...and with fire held, fast
MINO_TIME   = 12         ; frames between two minotaur steps
RAS_SYNC    = 251        ; raster line polled for the frame sync

; ---- RAM tables above the program (the VIC never looks here) ----
; every ring R gets a slot of 8*R entries at RINGOFS(R):
; screen column, screen row, wall glyph, door flag and the
; cell's screen address (low / high) per cell
RINGX   = $4000
RINGY   = $4200
RINGG   = $4400
RINGD   = $4600
RINGL   = $4800
RINGH   = $4a00
THX     = $4c00          ; the thread: the cells it runs through,
THY     = $4d00          ; from the heart to Theseus

; ---- zero page pointers ----
ptrx   = $02             ; the current ring's six slots (2 bytes each)
ptry   = $04
ptrg   = $06
ptrd   = $08
ptrl   = $0a
ptrh   = $0c
txtlo  = $f5             ; text pointer for the print routines (2 bytes)
txthi  = $f6
musptr = $f7             ; music player pattern pointer (2 bytes)
updvec = $f9             ; state update vector (2 bytes)
scrlo  = $fb
scrhi  = $fc
collo  = $fd
colhi  = $fe

; ---- helper macros: print a normal / big text line ----
!macro prtext .row, .col, .color, .txt, .len {
    lda #<.txt
    sta txtlo
    lda #>.txt
    sta txthi
    lda #.row
    sta prow
    lda #.col
    sta pcol
    lda #.color
    sta pcolor
    lda #.len
    sta plen
    jsr print_text
}

!macro prbig .row, .col, .color, .txt, .len {
    lda #<.txt
    sta txtlo
    lda #>.txt
    sta txthi
    lda #.row
    sta bigrow
    lda #.col
    sta bigcol
    lda #.color
    sta bigcolor
    lda #.len
    sta biglen
    jsr draw_big
}

; ---- set the state update vector ----
!macro setupd .addr {
    lda #<.addr
    sta updvec
    lda #>.addr
    sta updvec+1
}

; ---- leave the current screen: fade to black, then run the
; init routine of the next one ----
!macro fadeto .addr {
    lda #<.addr
    sta fadevec
    lda #>.addr
    sta fadevec+1
    jmp fade_start
}
