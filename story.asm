; -----------------------------------------------------------
; story.asm - the legend of Theseus and Ariadne, plus who
; steers what; a static card, fire returns to the menu
; -----------------------------------------------------------

story_init:
    jsr clear_screen
    lda #MUS_TITLE
    jsr music_play       ; already playing: it rolls on unbroken

    +prbig 1, 10, WHITE, txt_story, 5

    +prtext  7,  1, WHITE,  txt_s1, txt_s1e-txt_s1
    +prtext  8,  1, WHITE,  txt_s2, txt_s2e-txt_s2
    +prtext  9,  1, WHITE,  txt_s3, txt_s3e-txt_s3
    +prtext 10,  2, YELLOW, txt_s4, txt_s4e-txt_s4
    +prtext 11,  4, YELLOW, txt_s5, txt_s5e-txt_s5

    +prtext 13,  4, LRED,   txt_s6, txt_s6e-txt_s6
    +prtext 14,  3, LRED,   txt_s7, txt_s7e-txt_s7

    +prtext 16,  7, LGREEN, txt_s8, txt_s8e-txt_s8
    +prtext 17,  3, LGREY,  txt_s9, txt_s9e-txt_s9
    +prtext 18,  7, LBLUE,  txt_s10, txt_s10e-txt_s10
    +prtext 19,  3, LGREY,  txt_s11, txt_s11e-txt_s11
    +prtext 20,  8, LGREY,  txt_s12, txt_s12e-txt_s12

    +setupd story_update
    rts

story_update:
    ; blink the return prompt
    lda framectr
    and #32
    bne st_hide
    +prtext 23, 13, YELLOW, txt_return, 13
    jmp st_input
st_hide:
    +prtext 23, 13, YELLOW, txt_blank, 13
st_input:
    jsr start_edge
    beq st_stay
    +fadeto menu_init
st_stay:
    rts

; ---- story texts ----
txt_story: !scr "story"
txt_s1:  !scr "beneath the palace of king minos lies"
txt_s1e:
txt_s2:  !scr "the labyrinth. theseus has reached its"
txt_s2e:
txt_s3:  !scr "heart - now he must find the way out."
txt_s3e:
txt_s4:  !scr "ariadne turns the rings of the maze"
txt_s4e:
txt_s5:  !scr "and her red thread follows him."
txt_s5e:
txt_s6:  !scr "beware the minotaurs! the thread"
txt_s6e:
txt_s7:  !scr "is all he has - it may not cross."
txt_s7e:
txt_s8:  !scr "p1 - theseus: joy2 / wasd"
txt_s8e:
txt_s9:  !scr "step back on the thread to wind it"
txt_s9e:
txt_s10: !scr "p2 - ariadne: joy1 / ijkl"
txt_s10e:
txt_s11: !scr "up/down: ring  left/right: turn it"
txt_s11e:
txt_s12: !scr "hold fire to turn faster"
txt_s12e:
