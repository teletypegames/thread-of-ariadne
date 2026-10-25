# Thread of Ariadne

**Thread of Ariadne** - a two-player co-op octagonal labyrinth escape
for the Commodore 64 (6502 assembly, ACME + VICE). Concept stage: no
code yet.

**Player 1** (joystick 2) is Theseus: he starts in the heart of the
labyrinth and has to reach its outer rim, leaving a thread on every
cell he crosses. **Player 2** (joystick 1) is Ariadne, the labyrinth
master: she never moves a character - she turns the four concentric
octagonal rings (up / down picks a ring, left / right turns it
clockwise or counterclockwise) to open or close the way in front of
Theseus.

Planned tech: standard 40x25 text mode, a centered 32x24 play field
under a status row (score, thread length, time left / danger), a
custom charset at `$3000` (horizontal and vertical walls, four
diagonal corner pieces for the octagons, thread markers, open floor),
sprite 0 for Theseus and sprite 1 for the ring selector. Each ring's
chars live in a fixed-length linear array; a turn shifts the array
and copies the changed bytes back to screen memory, and collision is
a look at the target char.

Project page: https://wiki.teletypegames.org/projects/thread-of-ariadne
