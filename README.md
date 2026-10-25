# Thread of Ariadne

**Thread of Ariadne** - a two-player co-op labyrinth escape for the
Commodore 64 (ACME + VICE), in the same spirit as
[blessingofra](../blessingofra).

The legend: beneath the palace of King Minos lies the labyrinth.
Theseus has reached its heart - now he must find the way out, and
Ariadne's red thread follows him.

**Player 1** (joystick 2, or `w a s d`) is Theseus. He starts in the
heart of an octagonal labyrinth and runs for its rim, the ring of sea
light glimmering around it. Every fresh cell he steps on unwinds one length
of the thread and marks the cell; stepping back onto the cell he came
from winds that length up again. The thread may not cross itself, so
anywhere else a thread cell is a wall for him - and for the
minotaurs, so it guards his back. When the ball is empty (the
counter on the status row) he has to wind back and find a shorter
way.

**Player 2** (joystick 1, or `i j k l`) is Ariadne. She never moves
Theseus: she holds one of the four concentric rings (up / down picks
a ring further out or in, the one she holds is turquoise, a bracket
sits on its top) and turns it (left / right, counterclockwise / clockwise,
one cell a step; hold fire to turn fast), so its doors slide round to
where Theseus can step through. A ring cannot turn while the thread,
Theseus or a minotaur is in one of its doors (the border blips red) -
once the thread runs through a ring, that ring stays put until he
winds back.

Eight levels, the doors fewer, the pillars more and the thread
shorter on each: three doors per ring and 99 lengths of thread on
level 1, one door per ring, three pillars across every corridor and
46 lengths on level 8. From level 3 the minotaurs roam the corridors
(one, then two from level 6), random walkers that cannot cross the
thread; walking into one, or one walking into Theseus, ends the run.
The thread left over at the rim pays the score: ten points a length.

The labyrinth: rings of radius 3, 5, 7 and 9 are the walls Ariadne
turns, each door two cells wide; 4, 6 and 8 are the corridors
between them, the pillars standing across them; 10 is the rim. A
ring of radius R is a closed loop of 8*R cells - straight edges
joined by staircase diagonals cut three cells deep - and with the
same cut on every ring the loops tile the plane, no gaps, no
overlaps. The diagonal cells wear half-block glyphs that draw a clean
45 degree band. Each ring is walked once like a turtle into its slot
of the RAM tables at `$4000`: screen position, glyph, door flag and
screen address per cell; a turn moves each door one cell on, which
shuts one cell and opens another.

The look is Minoan, the turquoise and blue of the frescoes and the
sea: white stone rings, the one in hand turquoise, red Cretan
columns, the red thread knotted cell to cell, the rim glimmering sea
blue, sprites for Theseus (a crested helmet), Ariadne's
selector and the bulls, a blue raster band behind the status row and
a fade to black between all screens. The titles roll an Aegean
wash (deep blue - turquoise - white) and the menu floats over the
dark blue rings.

Under it all runs the music, written in the dorian mode on d - the
old greek mode: a plucked lyre over a drone through the front end,
and under the levels the kalamatianos, the 7/8 dance (slow - quick -
quick), the reedy aulos weaving over bass and hand drum; a climbing
escape song and a dirge for the game over. Voice 1 stays free for
the sound effects.

The options screen:

- **minotaurs** (on) - the bulls from level 3 on.
- **gear rings** (on) - a turn also drags the next ring outward one
  cell the other way, like meshed gears; the ring Theseus has passed
  never drags the one he is heading for.
- **short thread** (off) - every level's thread a quarter shorter.
- **start level** - which level a fresh run begins on (1-8).
- **music** - the songs off and on; the sound effects stay either way.

Screens: TTG intro (ported from rabbitc64) -> title card (the two
inner rings with the red thread winding out of the heart) -> main
menu (play / options / story / credits) -> game -> next level, and
after the last one the escape screen with the time and the score
(back to the menu); game over lets fire retry the same level with a
fresh labyrinth, `m` backs out to the menu.

## Build & run

```
make deps       # macOS: brew install acme vice
make build      # -> thread-of-ariadne.prg
make run        # build + launch in x64sc
```

Test builds can boot straight into one state:

```
acme -DAUTOPLAY=1 -f cbm -o thread-of-ariadne.prg main.asm
# also: AUTOTITLE, AUTOOPTIONS, AUTOSTORY, AUTOCREDITS,
# AUTOWIN, AUTOLOSE; add -DFORCEOPTS=1 to start with all
# three game options turned on
```

and `-DSCRIPT=n` feeds both joysticks from a table in `script.asm`
(1 = level 1 walked straight out to the right, 2 = two steps out and
one back), so a headless VICE run plays a fixed sequence:

```
acme -DAUTOPLAY=1 -DSCRIPT=1 -f cbm -o test.prg main.asm
x64sc +sound -warp -limitcycles 15000000 -exitscreenshot shot.png \
      -autostartprgmode 1 test.prg
```

## Files

- `main.asm` - entry point, BASIC stub, per-frame state machine,
  the border/status-band raster work
- `defs.asm` - registers, constants, zero page, RAM tables, macros
- `intro.asm` - TTG boot logo with the Aegean color wash
- `title.asm` - title card: the thread winds out of the heart
- `menu.asm` - main menu card over the dark rings
- `options.asm` - the optional extras and their toggle screen
- `story.asm` - the legend of Theseus and Ariadne + the controls
- `credits.asm` - the crew
- `rings.asm` - the octagonal ring geometry: generating, drawing,
  doors, pillars, turning
- `play.asm` - the game: Theseus and the thread, Ariadne's turns,
  the minotaurs, the eight levels
- `win.asm` / `over.asm` - end screens
- `common.asm` - shared routines: printing, big block font, the
  title wash, input, RNG
- `sound.asm` - single-voice SID SFX driver
- `music.asm` - two-voice music player on SID voices 2 and 3:
  the driver, the four tunes and their patterns
- `gfx.asm` - RAM charset with the custom tiles, the sprite engine
  and the fade-to-black transition
- `script.asm` - scripted joysticks for the test builds
