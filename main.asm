	SECTION "Ream RIC",CODE_C

	INCLUDE "hw.i"

; Main
display_window_hstart		EQU $81
display_window_hstop		EQU $1c1

; Horiz-Starscrolling
hss_starscrolling_vstart    EQU $9b
hss_starscrolling_height    EQU 127

hss_image_x_size		EQU 1	; star dot
hss_image_y_size		EQU 1
hss_image_depth			EQU 2

hss_used_sprites_number		EQU 2
hss_reused_sprites_number	EQU (hss_starscrolling_height/(hss_image_y_size+1))*hss_used_sprites_number

hss_random_x_max		EQU display_window_hstop-display_window_hstart
hss_x_min			EQU display_window_hstart-hss_image_x_size
hss_x_max			EQU display_window_hstop
hss_sprite_x_restart		EQU (display_window_hstop-display_window_hstart)+hss_image_x_size

hss_plane1_x_speed		EQU 3
hss_plane2_x_speed		EQU 2
hss_plane3_x_speed		EQU 1

hss_objects_per_sprite_number	EQU hss_reused_sprites_number/hss_used_sprites_number
hss_objects_number		EQU hss_objects_per_sprite_number*hss_used_sprites_number



;;    ---  screen buffer dimensions  ---

w	=352
h	=256
bplsize	=w*h/8
ScrBpl	=w/8

;;    ---  logo dimensions  ---

logow		=224
logoh		=70
logomargin	=(320-logow)/2
logobpl		=logow/8
logobwid	=logobpl*3

;;    ---  font dimensions  ---
fontw		=288
fonth		=100
fontbpls	=3
FontBpl		=fontw/8

plotY	=110
plotX	=w-32

logobgcol	=$000
bgcol		=$000


********************  MACROS  ********************
	;dc.w $0180,$0000,$0182,$00da,$0184,$06ef,$0186,$0867
	;dc.w $0188,$02ec,$018a,$04a9,$018c,$0335,$018e,$0000

logocolors:macro
	dc.w $00da,$06ef,$0867
	dc.w $02ec,$04a9,$0335,$0000
	endm

********************  DEMO  ********************


Start:

OSoff:
	movem.l d1-a6,-(sp)

	move.l 4.w,a6		;execbase
	move.l #gfxname,a1
	jsr -408(a6)		;oldopenlibrary()
	move.l d0,a1
	move.l 38(a1),OldCopperlist ;original copper ptr

	jsr -414(a6)		;closelibrary()

	move.w $dff01c,OldIntena
	move.w $dff002,OldDmacon

	move.w #$138,d0		;wait for EOFrame
	bsr.w WaitRaster
	move.w #$7fff,$dff09a	;disable all bits in INTENA
	move.w #$7fff,$dff09c	;disable all bits in INTREQ
	move.w #$7fff,$dff09c	;disable all bits in INTREQ
	move.w #$7fff,$dff096	;disable all bits in DMACON
	move.w #$87e0,$dff096

	bsr Init
	bsr	InitSprites
	bsr mt_init

	move.l #Copper,$dff080

	movem.l d0-a6,-(sp)
	movem.l (sp)+,d0-a6

	bsr Main

OSon:

	bsr mt_end

	movem.l d0-a6,-(sp)
	movem.l (sp)+,d0-a6

	move.w #$7fff,$dff096
	move.w	OldDmacon(pc),d3
	or.w #$8200,d3
	move.w d3,$dff096
	move.w #$000f,$dff096	;make sure sound DMA is off.

	move.l	OldCopperlist(pc),$dff080
	move.w	OldIntena(pc),d5
	or #$c000,d5
	move d5,$dff09a
	movem.l (sp)+,d1-a6
	moveq #0,d0
	rts			;end of program return to AmigaOS

********** ROUTINES **********
Main:
	movem.l d0-a6,-(sp)
**************************

MainLoop:
	move.w #$02a,d0		;wait for EOFrame
	bsr.w WaitRaster
	btst #2,$dff016
	bne.b .normb
	move.w #$02b,d0		;wait for EOFrame
	bsr.w Player


.normb:

;-----frame loop start---

	bsr	SwapSprites
	bsr	SetSpritePointers

	bsr BounceScroller

	lea Sine,a0
	move.w SineCtr,d6
	move.w #$10-6+71,d7
	add.w (a0,d6.w),d7  
;;    ---  in front or behind flag  ---

	lea BarInFront,a2	;default source address for RGB color values 
	cmp.w #50*2,d6
	blt.s .behind
	cmp.w #150*2,d6
	bge.s .behind
	bra.s .cont
.behind:
	lea BarBehind,a2
.cont:

	lea x1,a0
	move d7,d0
	moveq #6-1,d1
.loop:
	move.b d0,(a0)
	add.w #1,d0

	move.w (a2)+,d2			;background color from list
	move.w d2,6(a0)
	move.w (a2)+,6+4*1(a0)
	move.w (a2)+,6+4*2(a0)
	move.w (a2)+,6+4*3(a0)
	move.w (a2)+,6+4*4(a0)
	move.w (a2)+,6+4*5(a0)
	move.w (a2)+,6+4*6(a0)
	move.w (a2)+,6+4*7(a0)

	add.w #4*9,a0			;step to next.
	DBF d1,.loop

	bsr Scrollit

	moveq #32,d2
	move.b LastChar(PC),d0
	cmp.b #'I',d0
	bne.s .noi
	moveq #16,d2
.noi:
	move.w ScrollCtr(PC),d0
	addq.w #2,d0 ;Scroll
	cmp.w d2,d0
	blo.s .nowrap

	move.l ScrollPtr(PC),a0
	cmp.l #ScrollTextWrap,a0
	blo.s .noplot
	lea Text(PC),a0
.noplot:
	bsr PlotChar			;preserves a0

	addq.w #1,a0
	move.l a0,ScrollPtr

	clr.w d0
.nowrap:
	move.w d0,ScrollCtr

	bsr	HorizStarscrolling

;-----frame loop end---

	bsr mt_music

	btst #6,$bfe001
	bne.w MainLoop

**************************

	movem.l (sp)+,d0-a6
	rts

row	=288*3*20/8
col	=4

PlotChar:	;a0=scrollptr
	movem.l d0-a6,-(sp)
	lea $dff000,a6
	bsr BlitWait

	moveq #0,d0
	move.b (a0)+,d0			;ASCII value
	move.b d0,LastChar

	sub.w #32,d0
	lea FontTbl(PC),a0
	move.b (a0,d0.w),d0
	divu #9,d0			;row
	move.l d0,d1
	swap d1				;remainder (column)

	mulu #row,d0
	mulu #col,d1

	add.l d1,d0			;offset into font bitmap
	add.l #Font,d0

	move.l #$09f00000,bltcon0(a6)
	move.l #$ffffffff,bltafwm(a6)
	move.l d0,bltapth(a6)
	move.l #Screen+ScrBpl*3*plotY+plotX/8,bltdpth(a6)
	move.w #FontBpl-col,bltamod(a6)
	move.w #ScrBpl-col,bltdmod(a6)

	move.w #20*3*64+2,bltsize(a6)
	movem.l (sp)+,d0-a6
	rts

Scrollit:
;;    ---  scroll!  ---
bltoffs	=plotY*ScrBpl*3

blth	=20
bltw	=w/16
bltskip	=0				;modulo
brcorner=blth*ScrBpl*3-2

	movem.l d0-a6,-(sp)
	lea $dff000,a6
	bsr BlitWait

	move.l #$29f00002,bltcon0(a6)
	move.l #$ffffffff,bltafwm(a6)
	move.l #Screen+bltoffs+brcorner,bltapth(a6)
	move.l #Screen+bltoffs+brcorner,bltdpth(a6)
	move.w #bltskip,bltamod(a6)
	move.w #bltskip,bltdmod(a6)

	move.w #blth*3*64+bltw,bltsize(a6)
	movem.l (sp)+,d0-a6
	rts

Init:
	movem.l d0-a6,-(sp)
	moveq #0,d1
	lea Screen,a1
	move.w #bplsize*fontbpls/2-1,d0
.loop:	move.w #0,(a1)+
	addq.w #1,d1
	dbf d0,.loop

	lea Logo,a0		;ptr to first bitplane of logo
	lea CopBplP,a1		;where to poke the bitplabvane pointer words.
	move #3-1,d0
.bpll:
	move.l a0,d1
	swap d1
	move.w d1,2(a1)		;hi word
	swap d1
	move.w d1,6(a1)		;lo word

	addq #8,a1		;point to next bpl to poke in copper
	lea logobpl(a0),a0
	dbf d0,.bpll

	move.l	#NullSpr,d0
	lea	SprP+(2*8),a1
	moveq	#(8-hss_used_sprites_number)-1,d7

.sprpl:
	swap	d0
	move.w	d0,2(a1)	;SPRxPTH
	swap	d0
	move.w	d0,6(a1)	;SPRxPTL
	swap	d0
	addq.w	#8,a1		;next sprite pointers
	dbf	d7,.sprpl

	lea FontE-7*2,a0
	lea FontCopP+2,a1
	moveq #7-1,d0
.coll:	move.w (a0)+,(a1)+
	addq.w #2,a1
	DBF d0,.coll

	movem.l (sp)+,d0-a6
	rts

	CNOP 0,4

InitSprites:
	bsr	hss_init_xy_coordinates
	bsr	hss_init_sprites_bitmaps
	bsr	hss_init_objects_speed
	bsr	CopySpritesStructures
	rts

	CNOP 0,4
hss_init_xy_coordinates:
	moveq	#0,d3
	not.w	d3			; mask for low word
	move.w	#hss_random_x_max,d4
	lea	SpritesConstruction(pc),a1
	lea	hss_objects_x_coordinates(pc),a2
	move.w	#hss_x_min,a4
	lea	custom,a6
	moveq	#hss_used_sprites_number-1,d7
hss_init_xy_coordinates_loop1:
	move.w	vhposr(a6),d5		; f(x)
	move.l	(a1)+,a0		; sprite structure
	move.w	#hss_starscrolling_vstart,a5
	moveq	#hss_objects_per_sprite_number-1,d6
hss_init_xy_coordinates_loop2:
	mulu.w	vhposr(a6),d5		; f(x)*a
	move.w	vhposr(a6),d1
	swap	d1
	move.b	ciab+ciatodlow,d1
	lsl.w	#8,d1
	move.b	ciab+ciatodlow,d1	; b
	add.l	d1,d5			; (f(x)*a)+b
	and.l	d3,d5			; only low word
	divu.w	d4,d5			; f(x+1) = [(f(x)*a)+b]/mod
	swap	d5			; remainder
	move.w	d5,d0			; store f(x+1)
	add.w	a4,d0			; x + left border
	move.w	d0,(a2)+		; x
	move.w	a5,d1			; y
	bsr.s	hss_init_sprite_header
	addq.w	#8,a0 			; next object/star in sprite structure
	addq.w	#hss_image_y_size+1,a5	; increase y
	dbf	d6,hss_init_xy_coordinates_loop2
	dbf	d7,hss_init_xy_coordinates_loop1
	rts

; Input
; d0.w	x
; d1.w	y
; a0.l	sprite structure
; Result
	CNOP 0,4
hss_init_sprite_header:
	moveq	#hss_image_y_size,d2
	add.w	d1,d2			; VSTOP
	lsl.w	#7,d2			; EV8 EV7 EV6 EV5 EV4 EV3 EV2 EV1 EV0 --- --- --- --- --- --- ---
	lsl.w	#8,d1		 	; SV7 SV6 SV5 SV4 SV3 SV2 SV1 SV0 --- --- --- --- --- --- --- ---
	addx.w	d2,d2			; EV7 EV6 EV5 EV4 EV3 EV2 EV1 EV0 --- --- --- --- --- --- --- SV8
	addx.b	d2,d2			; EV7 EV6 EV5 EV4 EV3 EV2 EV1 EV0 --- --- --- --- --- --- SV8 EV8
	lsr.w	#1,d0			; --- --- --- --- --- --- --- --- SH8 SH7 SH6 SH5 SH4 SH3 SH2 SH1
	addx.b	d2,d2			; EV7 EV6 EV5 EV4 EV3 EV2 EV1 EV0 --- --- --- --- --- SV8 EV8 SH0
	move.b	d0,d1			; SV7 SV6 SV5 SV4 SV3 SV2 SV1 SV0 SH8 SH7 SH6 SH5 SH4 SH3 SH2 SH1
	swap	d1			; high word: SPRxPOS
	move.w	d2,d1			; low word: SPRxCTL
	move.l	d1,(a0)			; SPRxPOS + SPRxCTL
	rts

	CNOP 0,4
hss_init_sprites_bitmaps:
	moveq	#1,d1
	ror.w	#1,d1			; $00008000
	move.l	d1,d2
	swap	d2			; $80000000
	move.l	d2,d0
	or.w	d1,d0			; $80008000
	lea	SpritesConstruction(pc),a2
	move.l	(a2)+,a0
	addq.w	#4,a0			; skip header
	move.l	(a2),a1
	addq.w	#4,a1			; skip header
	moveq	#(hss_objects_per_sprite_number/hss_used_sprites_number)-1,d7
hss_init_sprites_bitmaps_loop:
	move.l	d0,(a0)			; plane 1&2
	addq.w	#8,a0			; next object/star in sprite structure
	move.l	d1,(a1)			; plane 1&2
	addq.w	#8,a1
	move.l	d1,(a0)			; plane 1&2
	addq.w	#8,a0
	move.l	d2,(a1)			; plane 1&2
	addq.w	#8,a1
	dbf	d7,hss_init_sprites_bitmaps_loop
	rts

	CNOP 0,4
hss_init_objects_speed:
	moveq	#hss_plane1_x_speed,d0
	swap	d0
	addq.b	#hss_plane2_x_speed,d0
	moveq	#hss_plane2_x_speed,d1
	swap	d1
	addq.b	#hss_plane3_x_speed,d1
	lea	hss_x_step_table(pc),a0
	moveq	#(hss_objects_per_sprite_number/hss_used_sprites_number)-1,d7
hss_init_objects_speed_loop:
	move.l	d0,(a0)+		; x speed, sprite0
	move.l	d1,(a0)+		; x speed, sprite1
	dbf	d7,hss_init_objects_speed_loop
	rts

	CNOP 0,4
CopySpritesStructures:
	movem.l	SpritesConstruction(pc),a0-a1
	movem.l	SpritesDisplay(pc),a2-a3
	move.w	#((NullSpr-Spr1_2)/2)-1,d7 ; number of words to copy
CopySpritesStructuresLoop:
	move.w	(a0)+,(a2)+		; sprite0 structure
	move.w	(a1)+,(a3)+		; sprite1 structure
	dbf	d7,CopySpritesStructuresLoop
	rts


CopyB:	;d0,a0,a1=count,source,destination
.loop:	move.b (a0)+,(a1)+
	subq.l #1,d0
	bne.s .loop
	rts

BlitWait:
	tst dmaconr(a6)			;for compatibility
.waitblit:
	btst #6,dmaconr(a6)
	bne.s .waitblit
	rts

WaitRaster:		;wait for rasterline d0.w. Modifies d0-d2/a0.
	move.l #$1ff00,d2
	lsl.l #8,d0
	and.l d2,d0
	lea $dff004,a0
.wr:	move.l (a0),d1
	and.l d2,d1
	cmp.l d1,d0
	bne.s .wr
	rts

	CNOP 0,4

SwapSprites:
	movem.l	SpritesConstruction(pc),d0-d1 ; SRPR0/1 pointers
	movem.l	SpritesDisplay(pc),d2-d3 ; SRPR0/1 pointers
	movem.l	d0-d1,SpritesDisplay
	movem.l	d2-d3,SpritesConstruction
	rts

	CNOP 0,4
SetSpritePointers:
	lea	SpritesDisplay(pc),a0
	lea	SprP+2,a1		; sprite pointers in copperlist
	moveq	#hss_used_sprites_number-1,d7
SetSpritePointersLoop:
	move.l	(a0)+,d0
	swap	d0
	move.w	d0,(a1)			; SPRxPTH
	swap	d0
	move.w	d0,4(a1)		; SPRxPTL
	addq.w	#8,a1			; next sprite pointers
	dbf	d7,SetSpritePointersLoop
	rts

BounceScroller:
	MOVEM.L D0-A6,-(SP)

	lea Screen,a0		;ptr to first bitplane of font
	move.w BounceY(PC),d0
	move.w BounceYaccel(PC),d1
	add.w d1,BounceYspeed
	add.w BounceYspeed(PC),d0
	bpl.s .nobounce
	move.w #58,BounceYspeed
	clr.w d0
.nobounce:
	move.w d0,BounceY

	lsr.w #4,d0

	mulu #3*ScrBpl,d0
	add.l d0,a0

	lea ScrBplP,a1		;where to poke the bitplane pointer words.
	moveq #fontbpls-1,d0
.bpll2:	move.l a0,d1
	swap d1
	move.w d1,2(a1)		;hi word
	swap d1
	move.w d1,6(a1)		;lo word

	addq #8,a1		;point to next bpl to poke in copper
	lea ScrBpl(a0),a0
	dbf d0,.bpll2

	MOVEM.L (SP)+,D0-A6
	RTS


	CNOP 0,4

HorizStarscrolling:
	moveq	#-2,d2			; mask for SH0 bit
	move.w	#hss_x_max,d3
	moveq	#0,d5			; overflow x bit
	movem.l	SpritesConstruction(pc),a0-a1 ; sprite0/1 structures
	addq.w	#1,a0		`	; SPR0POS low
	addq.w	#1,a1			; SPR1POS low
	lea	hss_objects_x_coordinates(pc),a2
	lea	hss_x_step_table(pc),a4
	moveq	#hss_objects_per_sprite_number-1,d7
HorizStarscrollingLoop
	move.b	2(a0),d1		; fetch SPR0CTL low
	and.b	d2,d1			; clear SH0 bit
	move.w	(a2),d0			; x
	add.w	(a4)+,d0		; increase x
	cmp.w	d3,d0			; x max ?
	ble.s	HorizStarscrollingSkip1
	sub.w	d4,d0			; reset x
HorizStarscrollingSkip1
	move.w	d0,(a2)+
	lsr.w	#1,d0			; SH8 SH7 SH6 SH5 SH4 SH3 SH2 SH1
	addx.b	d5,d1			; --- --- --- --- --- SV8 EV8 SH0
	move.b	d0,(a0)			; SPR0POS low
	move.b	d1,2(a0)		; SPR0CTL low
	addq.w	#8,a0 			; next star/object

	move.b	2(a1),d1		; fetch SPR1CTL low
	and.b	d2,d1			; clear SH0 bit
	move.w	(a2),d0			; x
	add.w	(a4)+,d0		; increase x
	cmp.w	d3,d0			; x max ?
	ble.s	HorizStarscrollingSkip2
	sub.w	d4,d0			; reset x
HorizStarscrollingSkip2
	move.w	d0,(a2)+
	lsr.w	#1,d0			; SH8 SH7 SH6 SH5 SH4 SH3 SH2 SH1
	addx.b	d5,d1			; --- --- --- --- --- SV8 EV8 SH0
	move.b	d0,(a1)			; SPR1POS low
	move.b	d1,2(a1)		; SPR1CTL low
	addq.w	#8,a1 			; next star/object
	dbf	d7,HorizStarscrollingLoop
	rts	

	even

Player:

	INCLUDE "ProTracker2.3a-Replay.s"

********** DATA **********
	CNOP 0,4
OldCopperlist:
	DC.L 0
OldDmacon:
	DC.W 0
OldIntena:
	DC.W 0

	CNOP 0,4
SpritesConstruction:
	DC.L Spr0_1
	DC.L Spr1_1
	CNOP 0,4
SpritesDisplay:
	DC.L Spr0_2
	DC.L Spr1_2

FontTbl:
	dc.b 43,38
	blk.b 5,0
	dc.b 42
	blk.b 4,0
	dc.b 37,40,36,41
	dc.b 26,27,28,29,30,31,32,33,34,35
	blk.b 5,0
	dc.b 39,0
	dc.b 0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21
	dc.b 22,23,24,25
	EVEN

ScrollPtr:
	dc.l Text
Text:
	dc.b "REAM RIC PRESENTS            SMELL THE STARS!            PRESS THE RIGHT MOUSE BUTTON TO RESTART THE MUSIC            HAVE YOU BEEN WAITING FOR US? IF YES THEN WELCOME TO THIS NEW INTRO!!!   WE INTRODUCE YOU TO OUR SECOND DEMO IN 2026.   IF YOU GUYS WANT TO BE IN REAM RIC CONTACT ME ON DISCORD   LOSBRTKOS...........CREDITS   CODED BY KAST601   GRAPHICS BY THEDAEMON   MUSIC BY THEMADDOCTOR            GREETINGS   ALPHA FLIGHT   THE SILENTS   RESISTANCE   ORANGES   MISTIGRIS   RAZOR 1911   MANIAX DESIGN   HOKUTO FORCE   ALL BRAZILIANS IN THE SCENE   ILKKE   NIHIRASH   HELM   GRIBFORD   NEWLINE   TEAM VYRAL   CLAY6OY   DESIRE   ARTSTATE   FANATIC2K   AGIMA   VOID   NAH-KOLOR   TEK   SCOOPEX   ZYMOSIS   ALCATRAZ   TRSI AND ALL THE LEGENDS I HAVEN'T MENTIONED...              ALSO SPECIAL THANKS GOES TO DISSIDENT OF RESISTANCE FOR HELPING ME IMPLEMENT THE STARFIELD.            THOSE WERE THE GREETINGS AND NOW WE WILL TELL YOU SOME NEWS.   KAST601 IS GOING TO BUY AN ATARI 800XE SO YOU CAN GUYS WAIT FOR ATARI 8BIT PRODUCTIONS...   GREETINGS TO THE WHOLE AMIGA DEMOSCENE FOR KEEPING THIS WHOLESOME PLATFORM ALIVE AND STILL DOING GREAT COMPOS!   GREETINGS TO THE C64 SCENE AND ATARI 8BIT SCENE FOR KEEPING THAT ALIVE TOO...   OKAY I THINK WE'RE ON THE END OF THE SCROLLTEXT. HAVE A NICE DAY AND SEE YOU AT ANOTHER PRODUCTION...                   REAM RIC INDUSTRIES, HEHEHE!!!"
	blk.b w/32,' '
ScrollTextWrap:

LastChar:dc.b 0
	EVEN
ScrollCtr:
	dc.w 0
BounceY:
	dc.w 48*8
BounceYspeed:
	dc.w 0
BounceYaccel:
	dc.w -1
SineCtr:
	dc.w 0

gfxname:
	dc.b "graphics.library",0
	EVEN

Sine:	dc.w $007
SineEnd:

; Horiz-Starscrolling
	CNOP 0,2
hss_objects_x_coordinates:
	DS.W hss_objects_number

	CNOP 0,2
hss_x_step_table:
	DS.W hss_objects_number


	SECTION TutData,DATA_C

; Double buffering for sprites
Spr0_1:
	REPT hss_reused_sprites_number
	DC.W 0,0			; SPR0POS, SPR0CTL
	DC.W 0,0			; bitplane data
	ENDR
	DC.W 0,0			; end of sprite

Spr0_2:
	REPT hss_reused_sprites_number
	DC.W 0,0			; SPR0POS, SPR0CTL
	DC.W 0,0			; bitplane data
	ENDR
	DC.W 0,0			; end of sprite

Spr1_1:
	REPT hss_reused_sprites_number
	DC.W 0,0			; SPR0POS, SPR0CTL
	DC.W 0,0			; bitplane data
	ENDR
	DC.W 0,0			; end of sprite

Spr1_2:
	REPT hss_reused_sprites_number
	DC.W 0,0			; SPR0POS, SPR0CTL
	DC.W 0,0			; bitplane data
	ENDR
	DC.W 0,0			; end of sprite

NullSpr:
	dc.w $2a20,$2b00
	dc.w 0,0
	dc.w 0,0

BarBehind:
	dc.w $000	;color00 value
	logocolors

	dc.w $000	;color00...
	logocolors

	dc.w $000
	logocolors

	dc.w $000
	logocolors

	dc.w $000
	logocolors

	dc.w logobgcol
	logocolors

BarInFront:
	dc.w $222
	dc.w $222

	dc.w $000
	logocolors


Copper:
	dc.w $1fc,0			;slow fetch mode, AGA compatibility
	dc.w $100,$0200
	DC.W $104,0
	dc.b 0,$8e,$51,$81
	dc.b 0,$90,$2c,$c1
	dc.w $92,$38+logomargin/2
	dc.w $94,$d0-logomargin/2

	dc.w $108,logobwid-logobpl
	dc.w $10a,logobwid-logobpl

	dc.w $102,0

	dc.w $1a2,$cc5
	dc.w $1a4,0
	dc.w $1a6,$752

SprP:
	dc.w $120,0
	dc.w $122,0
	dc.w $124,0
	dc.w $126,0
	dc.w $128,0
	dc.w $12a,0
	dc.w $12c,0
	dc.w $12e,0
	dc.w $130,0
	dc.w $132,0
	dc.w $134,0
	dc.w $136,0
	dc.w $138,0
	dc.w $13a,0
	dc.w $13c,0
	dc.w $13e,0

CopBplP:
	dc.w $e0,0
	dc.w $e2,0
	dc.w $e4,0
	dc.w $e6,0
	dc.w $e8,0
	dc.w $ea,0
		
	dc.w $0180,$000
	dc.w $2c07,$fffe

LogoCop:
	dc.w $0180,$0000,$0182,$00da,$0184,$06ef,$0186,$0867
	dc.w $0188,$02ec,$018a,$04a9,$018c,$0335,$018e,$0000

SpritesCop:
	DC.W $1a0,0
	DC.W $1a2,$338
	DC.W $1a4,$55a
	DC.W $1a6,$77c

	dc.w $100,$3200

x1:
	dc.w $9007,$fffe
	dc.w $180,$000
	dc.w $182,0
	dc.w $184,0
	dc.w $186,0
	dc.w $188,0
	dc.w $18a,0
	dc.w $18c,0
	dc.w $18e,0
x2:
	dc.w $9107,$fffe
	dc.w $180,$000
	dc.w $182,0
	dc.w $184,0
	dc.w $186,0
	dc.w $188,0
	dc.w $18a,0
	dc.w $18c,0
	dc.w $18e,0
x3:
	dc.w $9207,$fffe
	dc.w $180,$000
	dc.w $182,0
	dc.w $184,0
	dc.w $186,0
	dc.w $188,0
	dc.w $18a,0
	dc.w $18c,0
	dc.w $18e,0
x4:
	dc.w $9307,$fffe
	dc.w $180,$000
	dc.w $182,0
	dc.w $184,0
	dc.w $186,0
	dc.w $188,0
	dc.w $18a,0
	dc.w $18c,0
	dc.w $18e,0
x5:
	dc.w $9407,$fffe
	dc.w $180,$000
	dc.w $182,0
	dc.w $184,0
	dc.w $186,0
	dc.w $188,0
	dc.w $18a,0
	dc.w $18c,0
	dc.w $18e,0
x6:
	dc.w $9407,$fffe
	dc.w $180,$000
	dc.w $182,0
	dc.w $184,0
	dc.w $186,0
	dc.w $188,0
	dc.w $18a,0
	dc.w $18c,0
	dc.w $18e,0
x7:
	dc.w $9507,$fffe
	dc.w $180,$000
	dc.w $182,0
	dc.w $184,0
	dc.w $186,0
	dc.w $188,0
	dc.w $18a,0
	dc.w $18c,0
	dc.w $18e,0

	dc.w $9607,$fffe
	dc.w $100,$0200
	dc.w $96bf,$fffe

FontCopP:
	dc.w $0182,$0ddd,$0184,$0833,$0186,$0334
	dc.w $0188,$0a88,$018a,$099a,$018c,$0556

ScrBplP:
	dc.w $e0,0
	dc.w $e2,0
	dc.w $e4,0
	dc.w $e6,0
	dc.w $e8,0
	dc.w $ea,0
	dc.w $108,ScrBpl*fontbpls-320/8
	dc.w $10a,ScrBpl*fontbpls-320/8
	dc.w $92,$38
	dc.w $94,$d0
	dc.w $100,fontbpls*$1000+$200

	dc.w $9807,$fffe
	dc.w $180,$fff
	dc.w $9a07,$fffe
	dc.w $180,$000

	dc.w $ffdf,$fffe
;;    Upper plate
	dc.w $0807,$fffe
	dc.w $180,$000
	dc.w $1907,$fffe
	dc.w $180,$fff
	dc.w $1b07,$fffe
	dc.w $180,$000	
;;    Mirror
	dc.w $17df,$fffe
	dc.w $108,(ScrBpl*fontbpls-320/8)-(ScrBpl*fontbpls*2)
	dc.w $10a,(ScrBpl*fontbpls-320/8)-(ScrBpl*fontbpls*2)

	dc.w $ffff,$fffe
CopperE:

mt_data:
	INCBIN "betrayer.mod"

Font:
	INCBIN "FontReamRIC.raw"
FontE:

Logo:	INCBIN "logo1"
LogoE:
	dcb.b logobwid*6,0

	SECTION TutBSS,BSS_C

Screen:
	ds.b bplsize*fontbpls

	END