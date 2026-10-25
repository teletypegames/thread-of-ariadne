; -----------------------------------------------------------
; main.asm - THREAD OF ARIADNE for the C64
;   two-player co-op labyrinth escape: player 1 is Theseus,
;   starting in the heart of an octagonal labyrinth and
;   running for its rim with Ariadne's red thread unwinding
;   behind him; player 2 is Ariadne, who never moves him but
;   turns the four concentric rings of the labyrinth so their
;   doors open the way; minotaurs roam the corridors, the
;   thread is all he has and it may not cross itself; eight
;   levels, the doors fewer, the pillars more and the thread
;   shorter on each
;
; Files:
;   defs.asm    - constants, zero page, macros
;   intro.asm   - TTG boot logo (ported from rabbitc64)
;   title.asm   - title card: the thread winds out of a maze
;   menu.asm    - main menu over the dark rings
;   options.asm - optional extras: minotaurs, gear rings,
;                 short thread, start level, music
;   story.asm   - the legend + who steers what
;   credits.asm - the crew
;   rings.asm   - the octagonal ring geometry and drawing
;   play.asm    - the game itself
;   win.asm     - escape screen, returns to the menu
;   over.asm    - game over screen with retry
;   common.asm  - shared routines, input, RNG, texts
;   sound.asm   - single-voice SFX driver
;   music.asm   - two-voice music player (the other voices)
;   gfx.asm     - RAM charset, sprite engine, fades
;
; Build: acme -f cbm -o thread-of-ariadne.prg main.asm
; -----------------------------------------------------------

* = $0801

; ---- BASIC stub: 10 SYS 2064 ----
; so after LOAD"*",8,1 it's enough to type RUN
!byte $0c, $08          ; address of next line
!byte $0a, $00          ; line number: 10
!byte $9e               ; SYS token
!byte $20, $32, $30, $36, $34   ; " 2064"
!byte $00               ; end of line
!byte $00, $00          ; end of program

* = $0810                ; = 2064 in decimal

!src "defs.asm"

start:
    sei                  ; no KERNAL IRQ - raster polling must not jitter
    cld
    lda #BLACK
    sta BORDER
    sta BG
    lda #0
    sta SPR_EN           ; the actors arrive with the game screen
    sta framectr
    sta fheld
    jsr gfx_init         ; RAM charset + VIC + sprite registers
    jsr sfx_init
    jsr music_init

!ifdef AUTOPLAY {        ; test builds boot straight into one state
    jsr new_run
    jsr play_init
} else {
!ifdef AUTOSTORY {
    jsr story_init
} else {
!ifdef AUTOTITLE {
    jsr title_init
} else {
!ifdef AUTOOPTIONS {
    jsr options_init
} else {
!ifdef AUTOCREDITS {
    jsr credits_init
} else {
!ifdef AUTOWIN {
    jsr win_init
} else {
!ifdef AUTOLOSE {
    jsr lose_init
} else {
    jsr intro_init       ; TTG logo, then the title card, then the menu
}
}
}
}
}
}
}

; ============================================================
; main loop - one state update per PAL frame, synced to the
; raster beam in the lower border; the loop also paints the
; border (event flashes decay back to the screen's base
; color) and, when a screen asks for one, lays a background
; band behind the status row with two more raster waits
; ============================================================
main:
    jsr wait_frame       ; raster line RAS_SYNC, once a frame
    lda bflash           ; border: flash, else the base color
    beq mb_base
    dec bflash
    lda bcolor
    jmp mb_border
mb_base:
    lda borbase
mb_border:
    sta BORDER
    inc framectr
    jsr rand8            ; stir the RNG once per frame
    jsr sfx_update       ; advance the sound effect
    jsr music_update     ; and the two music voices
    lda statbg           ; $ff = no band: update right away
    bmi mb_update
mb_w1:
    bit SCRCTL           ; the beam reaches line 256...
    bpl mb_w1
mb_w2:
    bit SCRCTL           ; ...and wraps to line 0
    bmi mb_w2
mb_w3:
    lda RASTER
    cmp #49              ; still in the border above the window
    bcc mb_w3
    lda statbg
    sta BG
mb_w4:
    lda RASTER
    cmp #57              ; the switch back lands on the status
    bcc mb_w4            ; row's empty bottom pixel line
    lda #BLACK
    sta BG
mb_update:
!ifdef SCRIPT {
    jsr script_tick      ; test builds: the scripted joysticks
}
    jsr call_update
    jmp main

call_update:
    jmp (updvec)         ; each update runs exactly one frame, ends with rts

; ---- wait for raster line RAS_SYNC (leave it first, so a
; fast update cannot run twice in the same frame) ----
wait_frame:
    lda RASTER
    cmp #RAS_SYNC
    beq wait_frame
wf_hit:
    lda RASTER
    cmp #RAS_SYNC
    bne wf_hit
    rts

; ============================================================
; the states and everything they share
; ============================================================
!src "intro.asm"
!src "title.asm"
!src "menu.asm"
!src "options.asm"
!src "story.asm"
!src "credits.asm"
!src "rings.asm"
!src "play.asm"
!src "win.asm"
!src "over.asm"
!src "common.asm"
!src "sound.asm"
!src "music.asm"
!src "gfx.asm"
!ifdef SCRIPT {
!src "script.asm"
}
