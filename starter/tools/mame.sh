#!/bin/sh
# tools/mame.sh - install the starter onto a COPY of a Level 2 disk image (MAME writes into what it mounts) and run it
# headless in the Wildbits MAME with tools/starter.lua typing the commands and taking snapshots (mame/snap/wbjr2/).
#   MAMEDIR, ROMS and IMAGE say where your MAME, its ROMs and a bootable Jr2 image are.
set -e
HERE=$(cd "$(dirname "$0")/.." && pwd)
MAMEDIR=${MAMEDIR:-$HOME/projects/wild/mame}
ROMS=${ROMS:-$HOME/projects/wild/multiterm-pr/tools/mame-roms}
IMAGE=${IMAGE:-$HOME/projects/wild/multiterm-pr/images/multiterm-games-jr2.dsk}
WORK=$HERE/mame
mkdir -p "$WORK"
rm -rf "$WORK/snap"
cp "$IMAGE" "$WORK/starter.dsk"
truncate -s 134217728 "$WORK/starter.dsk"      # MAME's SD sizes: odd x 2^n blocks. Pad UP only (guide section 13)
make -C "$HERE" -s install DSK="$WORK/starter.dsk" >/dev/null
cd "$MAMEDIR"
./mame wbjr2 -rompath "$ROMS" -bios turbo -hard "$WORK/starter.dsk" -skip_gameinfo -video none -sound none -nothrottle \
  -autoboot_script "$HERE/tools/starter.lua" -snapshot_directory "$WORK/snap" 2>&1 | grep -v "NO GOOD DUMP\|^$" | tail -3 || true
ls "$WORK/snap/wbjr2/" 2>/dev/null
