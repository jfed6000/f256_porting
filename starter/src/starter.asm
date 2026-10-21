********************************************************************
* starter - the smallest complete F256 game skeleton (NitrOS-9 Level 2)
*
* Everything a game needs on day one, and nothing else, each part the way
* the porting guide says (README.md in the guide's repo; section numbers
* below are its):
*
*   - graphics memory from the driver (SS.GfxAlloc), outside the 64K, filled
*     one 8K window at a time from files (section 3)
*   - a CLUT (SS.ClutWrite), a tile set, a tile map on a layer, scrolled
*     every frame (SS.TsSet, SS.TmSet, SS.Layer, SS.TmScrl) (section 6)
*   - a sprite: our own record table registered with the driver, pushed once
*     a frame (SS.SprReg, SS.SprPush) (section 6)
*   - held keys (SS.LiveKeys): the arrows move the sprite (section 9)
*   - a note on the SAM2695 through the MIDI FIFO at $FF30 (section 8.5)
*   - a pause when our terminal goes to the background (SS.WSig), and a clean
*     exit on every path - Q, a signal, an error - that switches off what
*     VICKY reads BEFORE freeing it (sections 6 and 10)
*
* Keys: arrows move the ball, Z or space plays a note, Q quits.
* Run it from its asset directory: chd /dd/STARTER ; starter
*
* Grow it into a game by replacing Update (what happens each frame) and the
* art (tools/mkassets.py).  Keep the shape: one pass a 60 Hz tick, every
* number from the converter's equates, every exit through Cleanup.
********************************************************************

                    nam       starter
                    ttl       F256 starter

                    ifp1
                    use       defsfile
                    use       assets.d
                    endc

tylg                set       Prgrm+Objct
atrv                set       ReEnt+rev
rev                 set       $00
edition             set       1

* blocks for each asset (assets.d has the byte sizes)
NTilBlk             equ       (TIL.Size+$1FFF)/$2000
NMapBlk             equ       (MAP.Size+$1FFF)/$2000
NSprBlk             equ       (SPR.Size+$1FFF)/$2000
NRecs               equ       1                   sprite records we own (up to 128)
CamMax              equ       MAP.W*16-320        the camera's right-hand stop

* SS.LiveKeys sense bits (the arrows; space is unreliable across machines,
*   so the note also has a letter key)
KY.Up               equ       %00001000
KY.Down             equ       %00010000
KY.Left             equ       %00100000
KY.Right            equ       %01000000
KY.Space            equ       %10000000

* the MIDI FIFO (fixed I/O: an approved absolute-address exception, section 8.5)
MidiData            equ       $FF31
MidiTxCnt           equ       $FF38               bytes waiting to go out (16-bit, big-endian)
MidiRoom            equ       2048-64             leave it this much room

                    mod       eom,name,tylg,atrv,start,size

* the direct page (U = DP = the data area at entry)
sigcode             rmb       1                   a quit signal (0 = none)
paused              rmb       1                   1 = our terminal is in the background
wsigok              rmb       1                   1 = SS.WSig is registered
mcrlo               rmb       1                   the display mode on entry, put back on exit
mcrhi               rmb       1
gfxon               rmb       1                   1 = our display mode is on
regd                rmb       1                   1 = the sprite table is registered
tilblk              rmb       1                   each asset's first block (0 = none)
mapblk              rmb       1
sprblk              rmb       1
fpath               rmb       1                   LoadFile: the path, the block, blocks left,
lblk                rmb       1                   where the block is mapped
lcnt                rmb       1
lmap                rmb       2
cam                 rmb       2                   the camera's x in the map
camdir              rmb       1                   0 = panning right, 1 = left
bx                  rmb       2                   the ball, screen pixels (its top left)
by                  rmb       2
keys                rmb       1                   the sense bits this frame
note                rmb       1                   frames left of the note sounding (0 = none)
notek               rmb       1                   1 = the note key was down last frame
tmrec               rmb       12                  an SS.TmSet record
dpend               equ       .
* larger things, reached through U
recs                rmb       NRecs*8             our sprite table, registered with the driver
clut                rmb       1024                clut.bin, on its way to CLUT 0
                    rmb       512                 the stack
size                equ       .

name                fcs       /starter/
                    fcb       edition

********************************************************************
* start - U = DP = the data area
********************************************************************
start               leax      ,u                  the direct page cleared (OS-9 doesn't)
                    ldb       #dpend
st1                 clr       ,x+
                    decb
                    bne       st1
                    leax      Icpt,pcr            install the intercept BEFORE registering
                    os9       F$Icpt              for signals: an unintercepted one kills us
                    lbsr      WSigSet
                    leax      MsgHead,pcr
                    lbsr      WriteLn
                    clra                          remember the display mode
                    ldb       #SS.MCR
                    os9       I$GetStt            X = MCR low, Y = MCR high
                    tfr       x,d
                    stb       <mcrlo
                    tfr       y,d
                    stb       <mcrhi
                    ldd       #144                the ball in the middle
                    std       <bx
                    ldd       #100
                    std       <by
                    lbsr      Alloc
                    lbcs      Fail
                    lbsr      LoadAll
                    lbcs      Fail
                    lbsr      Display
                    lbcs      Fail

********************************************************************
* the frame loop: one pass a 60 Hz tick (F$Sleep X = 2: X = 1 only yields)
********************************************************************
Main                ldx       #2
                    os9       F$Sleep
                    tst       <sigcode
                    lbne      Quit
                    tst       <paused
                    lbne      Hidden
                    lbsr      Input               carry = Q
                    lbcs      Quit
                    lbsr      Update              this is where the game goes
                    lbsr      Draw
                    lbcs      Fail
                    lbra      Main

* Hidden - our terminal is hidden: nothing runs, and the sound stops.  The
*   driver restores our CLUTs, tile maps and sprites when we come back.
Hidden              lbsr      NoteOff
pw1                 ldx       #30
                    os9       F$Sleep             (cut short by the foreground signal)
                    tst       <sigcode
                    lbne      Quit
                    tst       <paused
                    bne       pw1
                    lbra      Main

Quit                lbsr      Cleanup
                    leax      MsgBye,pcr
                    lbsr      WriteLn
                    clrb
                    os9       F$Exit

Fail                pshs      b
                    lbsr      Cleanup
                    leax      MsgErr,pcr
                    lbsr      WriteLn
                    puls      b
                    os9       F$Exit              (the shell prints the error number)

* Icpt - the signal intercept, U = the data area: the terminal's
*   background/foreground signals pause and resume; abort and interrupt quit
Icpt                cmpb      #S$WinBg
                    bne       ic1
                    stb       paused,u
                    rti
ic1                 cmpb      #S$WinFg
                    bne       ic2
                    clr       paused,u
                    rti
ic2                 cmpb      #S$Abort
                    blo       ic9
                    cmpb      #S$Intrpt
                    bhi       ic9
                    stb       sigcode,u
ic9                 rti

* WSigSet / WSigClr - ask to be told when our terminal is hidden or shown.
*   A driver without SS.WSig fails the call, and the program never pauses.
WSigSet             clra
                    ldb       #SS.WSig
                    ldx       #S$WinBg*256+S$WinFg
                    os9       I$SetStt
                    bcs       ws1
                    inc       <wsigok
ws1                 rts
WSigClr             tst       <wsigok
                    beq       ws2
                    clra
                    ldb       #SS.WSig
                    ldx       #0
                    os9       I$SetStt
                    clr       <wsigok
ws2                 rts

********************************************************************
* Alloc - every asset's blocks, once, at start-up (section 3).
*   Exit: carry = error in B
********************************************************************
Alloc               ldx       #NTilBlk
                    bsr       GfxAlloc
                    bcs       al9
                    tfr       x,d
                    stb       <tilblk
                    ldx       #NMapBlk
                    bsr       GfxAlloc
                    bcs       al9
                    tfr       x,d
                    stb       <mapblk
                    ldx       #NSprBlk
                    bsr       GfxAlloc
                    bcs       al9
                    tfr       x,d
                    stb       <sprblk
                    clrb
al9                 rts

* GfxAlloc - X = how many consecutive blocks.  Exit: X = the first, carry = error
GfxAlloc            pshs      u
                    clra                          path 0: our terminal
                    ldb       #SS.GfxAlloc
                    os9       I$SetStt
                    puls      u,pc

* GfxFree - B = the first block (0 = none), A = how many
GfxFree             tstb
                    beq       gf9
                    pshs      u
                    pshs      a
                    clra
                    tfr       d,x                 R$X = the first block
                    puls      b
                    clra
                    tfr       d,u                 R$U = the count
                    clra
                    ldb       #SS.GfxFree
                    os9       I$SetStt
                    puls      u
gf9                 rts

********************************************************************
* LoadAll - the assets into their blocks, the CLUT into the data area.
*   Exit: carry = error in B
********************************************************************
LoadAll             lda       <tilblk
                    ldb       #NTilBlk
                    leax      FTiles,pcr
                    bsr       LoadFile
                    bcs       la9
                    lda       <mapblk
                    ldb       #NMapBlk
                    leax      FMap,pcr
                    bsr       LoadFile
                    bcs       la9
                    lda       <sprblk
                    ldb       #NSprBlk
                    leax      FSprite,pcr
                    bsr       LoadFile
                    bcs       la9
                    leax      FClut,pcr           a small file: straight into the data area
                    lda       #READ.
                    os9       I$Open
                    bcs       la9
                    pshs      a
                    leax      clut,u
                    ldy       #1024
                    os9       I$Read
                    puls      a
                    pshs      cc,b
                    os9       I$Close
                    puls      cc,b
la9                 rts

* LoadFile - X = a file name, A = the first block, B = how many: the file
*   read into the blocks one 8K window at a time, never more than one window
*   mapped (section 3).  A short file is not an error.  Exit: carry = error in B
LoadFile            sta       <lblk
                    stb       <lcnt
                    lda       #READ.
                    os9       I$Open
                    bcs       lf9
                    sta       <fpath
lf1                 pshs      u
                    clra
                    ldb       <lblk
                    tfr       d,x
                    ldb       #1
                    os9       F$MapBlk            U = where it's mapped: use that, never assume
                    bcs       lf8
                    stu       <lmap
                    tfr       u,x
                    ldy       #$2000
                    lda       <fpath
                    os9       I$Read              Y = bytes read
                    pshs      cc,b
                    ldu       <lmap
                    ldb       #1
                    os9       F$ClrBlk
                    puls      cc,b
                    puls      u                   the data area again
                    bcc       lf2
                    cmpb      #E$EOF
                    beq       lf3
                    bra       lf7
lf2                 cmpy      #$2000              a short read: the end of the file
                    blo       lf3
                    inc       <lblk
                    dec       <lcnt
                    bne       lf1
lf3                 lda       <fpath
                    os9       I$Close
                    clrb
                    rts
lf8                 puls      u
lf7                 pshs      b
                    lda       <fpath
                    os9       I$Close
                    puls      b
                    coma
lf9                 rts

********************************************************************
* Display - the CLUT, the sprite table, the tile set, the map, the layers,
*   the display mode.  Exit: carry = error in B
********************************************************************
Display             leax      clut,u              CLUT 0: sprites and tiles share it here
                    ldy       #0                  R$Y = CLUT number * 256 + first entry
                    ldd       #256
                    pshs      u
                    tfr       d,u                 R$U = how many
                    clra
                    ldb       #SS.ClutWrite
                    os9       I$SetStt
                    puls      u
                    lbcs      ds9
                    leax      recs,u              our sprite table: the driver reads it from
                    pshs      u                   our memory, so a terminal switch restores it
                    ldy       #0                  R$Y = 0: it's in our own map
                    ldu       #NRecs              R$U = the records we own
                    clra
                    ldb       #SS.SprReg
                    os9       I$SetStt
                    puls      u
                    lbcs      ds9
                    inc       <regd
                    pshs      u                   tile set 0: the tiles block, linear (CFG 0)
                    clra
                    ldb       <tilblk
                    tfr       d,x                 R$X = the block
                    ldy       #0                  R$Y = CFG 0 : set 0
                    ldu       #0                  R$U = the offset in the block
                    clra
                    ldb       #SS.TsSet
                    os9       I$SetStt
                    puls      u
                    lbcs      ds9
                    lbsr      ClearTmRec          tile map 0: the map block, 16x16 tiles
                    leax      tmrec,u
                    lda       #%00000001          on, 16x16
                    sta       ,x
                    lda       <mapblk
                    sta       1,x                 the block
                    ldd       #0
                    std       2,x                 the offset in it
                    ldd       #MAP.W
                    std       4,x
                    ldd       #MAP.H
                    std       6,x
                    ldy       #0
                    lbsr      SendRec
                    bcs       ds9
                    ldx       #0                  layer 0 (in front) shows tile map 0 (source 4)
                    ldy       #4
                    lbsr      OneLayer
                    bcs       ds9
                    ldx       #1                  layers 1 and 2: maps 1 and 2, which are off
                    ldy       #5
                    lbsr      OneLayer
                    bcs       ds9
                    ldx       #2
                    ldy       #6
                    lbsr      OneLayer
                    bcs       ds9
                    pshs      u                   graphics, tiles and sprites on, text off
                    ldx       #FX_GRF+FX_TIL+FX_SPR
                    ldy       #FT_OMIT            (the mode byte left as it is)
                    clra
                    ldb       #SS.MCR
                    os9       I$SetStt
                    puls      u
                    bcs       ds9
                    inc       <gfxon
                    clrb
ds9                 rts

* SendRec - X = an SS.TmSet record, Y = the map number
SendRec             pshs      u
                    clra
                    ldb       #SS.TmSet
                    os9       I$SetStt
                    puls      u,pc

* OneLayer - X = layer 0-2, Y = its source (4-6 = tile maps 0-2)
OneLayer            pshs      u
                    clra
                    ldb       #SS.Layer
                    os9       I$SetStt
                    puls      u,pc

ClearTmRec          leax      tmrec,u
                    ldb       #12
ct1                 clr       ,x+
                    decb
                    bne       ct1
                    rts

********************************************************************
* Input - the keys held now (SS.LiveKeys): sense bits in A, up to six
*   ordinary keys in X, Y and U - lower case.  Exit: carry = Q is down
********************************************************************
Input               pshs      u
                    clra
                    ldb       #SS.LiveKeys
                    os9       I$GetStt
                    stu       ,--s                the call returns its keys in U too
                    pshs      x,y                 ,s = the six key codes
                    ldu       6,s                 our data area again
                    bcc       in1
                    clra                          an older driver: no keys
                    clrb
                    std       ,s
                    std       2,s
                    std       4,s
in1                 sta       <keys
                    clr       ,-s                 ,s = the note key seen
                    leax      1,s
                    ldb       #6
in2                 lda       ,x+
                    cmpa      #'q
                    beq       in8
                    cmpa      #'z
                    bne       in3
                    inc       ,s
in3                 decb
                    bne       in2
                    lda       <keys
                    bita      #KY.Space
                    beq       in4
                    inc       ,s
in4                 lda       ,s                  the note: on the press, not while held
                    beq       in5
                    tst       <notek
                    bne       in5
                    lbsr      NoteOn
in5                 lda       ,s+
                    sta       <notek
                    leas      8,s
                    andcc     #$FE
                    rts
in8                 leas      9,s
                    orcc      #1
                    rts

********************************************************************
* Update - one frame of the "game": the ball follows the arrows, the camera
*   pans back and forth, the note runs down.  Replace this.
********************************************************************
Update              lda       <keys
                    bita      #KY.Left
                    beq       up1
                    ldd       <bx
                    subd      #2
                    blt       up1
                    std       <bx
up1                 lda       <keys
                    bita      #KY.Right
                    beq       up2
                    ldd       <bx
                    addd      #2
                    cmpd      #320-32
                    bgt       up2
                    std       <bx
up2                 lda       <keys
                    bita      #KY.Up
                    beq       up3
                    ldd       <by
                    subd      #2
                    blt       up3
                    std       <by
up3                 lda       <keys
                    bita      #KY.Down
                    beq       up4
                    ldd       <by
                    addd      #2
                    cmpd      #240-32
                    bgt       up4
                    std       <by
up4                 ldd       <cam                the camera: 1 px a frame, back and forth
                    tst       <camdir
                    bne       up5
                    addd      #1
                    cmpd      #CamMax
                    blo       up6
                    inc       <camdir
                    bra       up6
up5                 subd      #1
                    bne       up6
                    clr       <camdir
up6                 std       <cam
                    tst       <note               the note: off after a quarter second
                    beq       up9
                    dec       <note
                    bne       up9
                    lbsr      NoteOff
up9                 rts

********************************************************************
* Draw - the sprite's record, one SprPush; the map's scroll.
*   Exit: carry = error in B
********************************************************************
Draw                leay      recs,u              a record: CTRL, 24-bit address, X, Y
                    lda       #%00000001          on, CLUT 0, layer 0, 32x32
                    sta       ,y
                    lda       <sprblk             the address: the block * $2000 (BlkAddr)
                    clrb
                    lsra
                    rorb
                    lsra
                    rorb
                    lsra
                    rorb
                    std       1,y
                    clr       3,y
                    ldd       <bx                 the visible screen starts at 32,32
                    addd      #32
                    std       4,y
                    ldd       <by
                    addd      #32
                    std       6,y
                    pshs      u
                    ldy       #0                  R$Y = the first record
                    ldu       #NRecs              R$U = how many
                    clra
                    ldb       #SS.SprPush
                    os9       I$SetStt
                    puls      u
                    bcs       dr9
                    pshs      u                   the map's scroll
                    ldx       <cam                R$X = x
                    ldy       #0                  R$Y = the map number
                    ldu       #0                  R$U = y
                    clra
                    ldb       #SS.TmScrl
                    os9       I$SetStt
                    puls      u
dr9                 rts

********************************************************************
* The note, on the SAM2695: three bytes into the MIDI FIFO (section 8.5).
*   If the FIFO is nearly full the bytes are dropped rather than wait.
********************************************************************
NoteOn              lda       #15                 a quarter second
                    sta       <note
                    ldx       #NoteOnMsg
                    bra       Midi3
NoteOff             clr       <note
                    ldx       #NoteOffMsg
* Midi3 - X = the offset of three MIDI bytes from Msgs
Midi3               ldd       MidiTxCnt
                    cmpd      #MidiRoom
                    bhi       mi9
                    tfr       x,d
                    leax      Msgs,pcr
                    leax      d,x
                    lda       ,x+
                    sta       MidiData
                    lda       ,x+
                    sta       MidiData
                    lda       ,x
                    sta       MidiData
mi9                 rts
Msgs                equ       *
NoteOnMsg           equ       *-Msgs
                    fcb       $90,60,100          channel 1 note on: middle C (GM piano)
NoteOffMsg          equ       *-Msgs
                    fcb       $80,60,0
AllOffMsg           equ       *-Msgs
                    fcb       $B0,123,0           all notes off

********************************************************************
* Cleanup - every exit path.  What VICKY reads goes off BEFORE the blocks
*   are freed: it reads them by physical address and has no idea we've gone
*   (section 6, "switch it off before you free it").
********************************************************************
Cleanup             pshs      cc,d,x,y
                    ldx       #AllOffMsg          silence
                    lbsr      Midi3
                    lbsr      WSigClr
                    tst       <regd               the sprite off, then the table given up
                    beq       cu1
                    leay      recs,u
                    clr       ,y
                    pshs      u
                    ldy       #0
                    ldu       #NRecs
                    clra
                    ldb       #SS.SprPush
                    os9       I$SetStt
                    ldu       #0                  R$U = 0 gives the table up
                    clra
                    ldb       #SS.SprReg
                    os9       I$SetStt
                    puls      u
                    clr       <regd
cu1                 lbsr      ClearTmRec          the tile map off (a zero record)
                    leax      tmrec,u
                    ldy       #0
                    lbsr      SendRec
                    pshs      u                   the tile set off (address 0)
                    ldx       #0
                    ldy       #0
                    ldu       #0
                    clra
                    ldb       #SS.TsSet
                    os9       I$SetStt
                    puls      u
                    tst       <gfxon              the display mode as it was
                    beq       cu2
                    pshs      u
                    clra
                    ldb       <mcrlo
                    tfr       d,x
                    ldb       <mcrhi
                    tfr       d,y
                    clra
                    ldb       #SS.MCR
                    os9       I$SetStt
                    puls      u
                    clr       <gfxon
cu2                 lda       #NTilBlk            and only then free the blocks
                    ldb       <tilblk
                    lbsr      GfxFree
                    lda       #NMapBlk
                    ldb       <mapblk
                    lbsr      GfxFree
                    lda       #NSprBlk
                    ldb       <sprblk
                    lbsr      GfxFree
                    clr       <tilblk
                    clr       <mapblk
                    clr       <sprblk
                    puls      cc,d,x,y,pc

* WriteLn - X = a $0D-terminated line, to path 1
WriteLn             pshs      d,x,y,u
                    lda       #1
                    ldy       #80
                    os9       I$WritLn
                    puls      d,x,y,u,pc

FTiles              fcc       /tiles.bin/
                    fcb       $0D
FMap                fcc       /map.bin/
                    fcb       $0D
FSprite             fcc       /sprite.bin/
                    fcb       $0D
FClut               fcc       /clut.bin/
                    fcb       $0D
MsgHead             fcc       /starter: arrows move, Z or space plays a note, Q quits/
                    fcb       $0D
MsgBye              fcc       /starter: bye./
                    fcb       $0D
MsgErr              fcc       "starter failed - run it from its directory (chd /dd/STARTER)"
                    fcb       $0D

                    emod
eom                 equ       *
                    end
