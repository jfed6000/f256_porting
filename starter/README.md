# starter: the smallest complete F256 game skeleton

A NitrOS-9 Level 2 program for the Wildbits F256 that does, in about 1.3K of 6809, everything a game needs on its
first day: graphics memory from the driver, a CLUT, a tile set and a scrolling tile map, a sprite in a registered
table, held keys, a note on the SAM2695, a pause when its terminal is hidden, and a clean exit from every path. Each
part follows the porting guide one directory up (`../README.md`); the source cites the sections.

```
make                          # the art (tools/mkassets.py -> assets/, src/assets.d), then the module
make install DSK=/abs/x.dsk   # CMDS/starter and /STARTER/*.bin on a disk image (ToolShed's os9)
make mame                     # install onto a copy of the image and run it in the Wildbits MAME, with snapshots
```

On the machine: `chd /dd/STARTER`, then `starter`. Arrows move the ball, Z or space plays a note, Q quits.

Set `NITROS9DIR` (the NitrOS-9 tree, for its defs) and `LWASM` for your machine, and `MAMEDIR`, `ROMS` and `IMAGE`
for `make mame`. Checked 2026-10-20 in the Wildbits MAME (Longview, Jr2 image): it starts, draws, scrolls, takes Q
and exits to the shell. Held arrow keys can't be scripted in MAME, and MAME doesn't voice the SAM2695 (guide 8.5):
the ball's movement and the note are for the machine.

## What's here

| File | |
|---|---|
| `src/starter.asm` | the program: start-up, allocation, loading, the display, the frame loop (`Input`, `Update`, `Draw`), the note, the pause, `Cleanup` |
| `tools/mkassets.py` | the art, drawn in code, and `src/assets.d`, the equates the program assembles against (the formats are in its header) |
| `tools/mame.sh`, `tools/starter.lua` | the MAME run: a copy of the image, the install, keys typed by script, snapshots in `mame/snap/wbjr2/` |
| `CLAUDE.md` | instructions for an AI assistant working on a project grown from this (the guide's section 15 and `../CLAUDE-template.md`) |

## Growing it into a game

Keep the shape: one pass a 60 Hz tick, every number from the converter's equates, every exit through `Cleanup`,
nothing VICKY reads freed before it's switched off. Then, in roughly this order (guide section 14):

1. **Your art.** Replace `tools/mkassets.py` with your converter, keeping its contract: binaries plus a generated
   defs file. For sprites bigger than 32×32, cut frames into cells with a frame record each (guide section 6;
   Texas Shitkickers' `export.js` and `draw.a`). For an original game, consider a browser prototype that draws
   the art and exports it (guide 14b).
2. **The game.** `Update` is one frame. Give the program test levers on its command line early (an autopilot,
   invulnerability, start anywhere: guide section 13).
3. **A host model.** Run the module on a host 6809 with the OS-9 calls answered by a script (guide section 13;
   Texas Shitkickers' `tools/hostrun.py`, Tempest's `tools/osrun.py`). It is where most bugs get found.
4. **Text and the HUD**: words pre-drawn as frames, changing text drawn into dynamic sprite cells (guide 6), or a
   bitmap layer if you have one free.
5. **Music**: a sequencer playing MIDI converted to blocks (guide 8.5; Texas Shitkickers' `snd.a`, `midi2tsk.py`).
6. **Terminal lockdown** (echo off, one quit key) and a numbers sign-off behind a build flag (guide sections 10, 13).
7. **When it outgrows 32K**: stage modules (guide 3a).
