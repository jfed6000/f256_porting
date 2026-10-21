# starter - the smallest complete F256 game skeleton (NitrOS-9 Level 2, 6809)
#
#   make                         the art (tools/mkassets.py), then the module
#   make install DSK=/abs/x.dsk  CMDS/starter, and the art in /STARTER, on a disk image (ToolShed's os9)
#   make mame                    install onto a copy of the image and run it in the Wildbits MAME, with snapshots
#
# Set these for your machine (or on the command line): where the NitrOS-9 tree is (for its defs), the assembler.

NITROS9DIR ?= $(HOME)/projects/wild/main/nitros9
LWASM      ?= lwasm
AS          = $(LWASM) --no-warn=ifp1 --6809 --format=os9 \
              --pragma=nosymbolcase,condundefzero,dollarnotlocal \
              --includedir=$(NITROS9DIR)/defs
AFLAGS      = -I $(NITROS9DIR)/level2/wildbits -I src -Dwildbits=1
# The module budget (guide section 3): 32,768 keeps a block free for a stage module and two windows; the data area
# must fit one 8K block with the parameters above it.
BUDGET      = 32768
DATAMAX     = 7936
ASSETS      = assets/clut.bin assets/tiles.bin assets/map.bin assets/sprite.bin

all: starter

$(ASSETS) src/assets.d: tools/mkassets.py
	python3 tools/mkassets.py

starter: src/starter.asm src/assets.d
	$(AS) $(AFLAGS) --list=$@.list --map=$@.map -o $@ src/starter.asm
	@n=$$(stat -c %s $@); echo "starter: $$n bytes of $(BUDGET)"; test $$n -le $(BUDGET) || { echo "over the module budget"; exit 1; }
	@d=$$((0x$$(grep "Symbol: size " $@.map | sed 's/.*= //'))); echo "data area: $$d bytes of $(DATAMAX)"; test $$d -le $(DATAMAX) || { echo "the data area is over one block"; exit 1; }

install: starter $(ASSETS)
	@test -n "$(DSK)" || { echo "usage: make install DSK=/absolute/path/to/image.dsk"; exit 1; }
	-os9 makdir $(DSK),STARTER 2>/dev/null
	os9 del $(DSK),CMDS/starter 2>/dev/null; os9 copy -r starter $(DSK),CMDS/starter && os9 attr -e -pe $(DSK),CMDS/starter
	for f in $(ASSETS); do n=$$(basename $$f); os9 del $(DSK),STARTER/$$n 2>/dev/null; os9 copy -r $$f $(DSK),STARTER/$$n || exit 1; done

mame: starter $(ASSETS)
	tools/mame.sh

clean:
	rm -f starter starter.list starter.map
	rm -rf mame

.PHONY: all install mame clean
