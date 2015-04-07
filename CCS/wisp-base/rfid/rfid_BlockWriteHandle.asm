;/**@file		rfid_BlockWriteHandle.asm
;*	@brief
;* 	@details
;*
;*	@author		Aaron Parks, Justin Reina, UW Sensor Systems Lab
;*	@created
;*	@last rev
;*
;*	@notes		In a blockwrite, data is transmitted in the clear (not cover coded by RN16)
;*				BLOCKWRITE: {CMD [8], MEMBANK [2], WordPtr [6?], WordCount [8], Data [VAR], RN [16], CRC [16]}
;*
;*	@section
;*
;*	@todo		Show the blockwrite command bitfields here
;*  @todo		Add CRC check for R=>T command, even if it needs to be after-the-fact
;*  @todo		Figure out why using R12 doesn't work here...
;*/

   .cdecls C,LIST, "../globals.h"
   .cdecls C,LIST, "rfid.h"

R_bits      .set  R5
R_byteCount	.set  R12
R_scratch2	.set  R13
R_scratch1	.set  R14
R_scratch0	.set  R15

   	.ref cmd
	.def  handleBlockWrite
	.global RxClock, TxClock
	.sect ".text"

handleBlockWrite:

;Wait for first two bytes to come in. then memBank is in cmd[1].b7b6
waitOnBits_0:
	CMP     #16, R_bits             ;[2] Proceed when R_bits > 16 (ceil 8+2 -> 16)
	JLO     waitOnBits_0            ;[2]
; Put Proper memBankPtr into WritePtr. Switch on Membank
calc_memBank:
	MOV.B	(cmd+1), R_scratch0     ;[3] load cmd byte 2 into R15. memBank is in b7b6 (0xC0)
	AND.B	#0xC0, R_scratch0       ;[2] mask of non-memBank bits, then switch on it to load corr memBankPtr
	RRA		R_scratch0              ;[1] move b7b6 down to b1b0
	RRA		R_scratch0              ;[1] move b7b6 down to b1b0
	RRA		R_scratch0              ;[1] move b7b6 down to b1b0
	RRA		R_scratch0              ;[1] move b7b6 down to b1b0
	RRA		R_scratch0              ;[1] move b7b6 down to b1b0
	RRA		R_scratch0              ;[1] move b7b6 down to b1b0

	MOV.B   R_scratch0, &(RWData.memBank) ;[3] store the memBank
; Now wait until we have all bits to extract the WordPtr.
waitOnBits_1:
	CMP.W   #24, R_bits                   ;[2] while(bits<24) (ceil 8+2+8 -> 24)
	JLO     waitOnBits_1                  ;[2]

 ;Extract WordPtr.
calc_wordPtr:
	MOV.B 	(cmd+1), R_scratch0           ;[3] bring in top 6 bits into b5-b0 of R15 (wordCt.b7-b2)
	MOV.B 	(cmd+2), R_scratch1           ;[3] bring in bot 2 bits into b7b6  of R14 (wordCt.b1-b0)
	RLC.B	R_scratch1                    ;[1] pull out b7 from R14 (wordCt.b1)
	RLC.B	R_scratch0                    ;[1] shove it into R15 at bottom (wordCt.b1)
	RLC.B	R_scratch1                    ;[1] pull out b7 from R14 (wordCt.b0)
	RLC.B	R_scratch0                    ;[1] shove it into R15 at bottom (wordCt.b0)
	MOV.B	R_scratch0, R_scratch0        ;[1] mask wordPtr to just lower 8 bits
	;MOV.B	R_scratch0, &(RWData.wordPtr) ;[3] store the wordPtr
	MOV.B	R_scratch0, &(RWData.wrData) ;[3] store the wordCnt



; Wait until we have all bits to extract WordCount.
waitOnBits_2:
	CMP.W   #32, R_bits                   ;[2] while(bits<32) (ceil 8+2+8+8 -> 32)
	JLO     waitOnBits_2                  ;[2]

calc_wordCnt:
	MOV.B 	(cmd+2), R_scratch0           ;[3] bring in top 6 bits into b5-b0 of R15 (wordCt.b7-b2)
	MOV.B 	(cmd+3), R_scratch1           ;[3] bring in bot 2 bits into b7b6  of R14 (wordCt.b1-b0)
	RLC.B	R_scratch1                    ;[1] pull out b7 from R14 (wordCt.b1)
	RLC.B	R_scratch0                    ;[1] shove it into R15 at bottom (wordCt.b1)
	RLC.B	R_scratch1                    ;[1] pull out b7 from R14 (wordCt.b0)
	RLC.B	R_scratch0                    ;[1] shove it into R15 at bottom (wordCt.b0)
	MOV.B	R_scratch0, R_scratch0        ;[1] mask wordPtr to just lower 8 bits
	;MOV.B	R_scratch0, &(RWData.wrData) ;[3] store the wordCnt

; Wait until we have the next byte of data to write.
waitOnBits_3:
	CMP.W   #48, R_bits                   ;[2]
	JLO     waitOnBits_3                  ;[2]
 ;TODO: Store wordCnt*Words instead of just one word.
store_Word:
	;Pull out Data and stuff into R14 (safe, R14 isn't used by RX_SM)
	MOV.B 	(cmd+3), R14			;[3] bring in top 6 bits into b5-b0 of R14 (data.b15-b10)
	MOV.B 	(cmd+4), R13			;[3] bring in mid 8 bits into b7-b0 of R13 (data.b9-b2)
	MOV.B 	(cmd+5), R12			;[3] bring in bot 2 bits into b7b6  of R12 (data.b1b0)

	RLC.B	R13						;[1]
	RLC.B	R14						;[1]
	RLC.B	R13						;[1]
	RLC.B	R14						;[1]
	RRC.B	R13						;[1]
	RRC.B	R13						;[1]

	RLC.B	R12						;[1]
	RLC.B	R13						;[1]
	RLC.B	R12						;[1]
	RLC.B	R13						;[1]

	SWPB	R14						;[1]
	BIS		R13, R14				;[1] merge b15-b8(R14) and b7-b(R13) together into R14
	MOV     R14, &(RWData.wrData+2)   ;[3] move the data out

; Wait on handle.
waitOnBits_4:
	CMP.W   #64, R_bits                   ;[2]
	JLO     waitOnBits_4                  ;[2]

; Pull handle into R14.
	MOV.B 	(cmd+5), R14			;[3] bring in top 6 bits into b5-b0 of R14 (data.b15-b10)
	MOV.B 	(cmd+6), R13			;[3] bring in mid 8 bits into b7-b0 of R13 (data.b9-b2)
	MOV.B 	(cmd+7), R12			;[3] bring in bot 2 bits into b7b6  of R12 (data.b1b0)

	RLC.B	R13						;[1]
	RLC.B	R14						;[1]
	RLC.B	R13						;[1]
	RLC.B	R14						;[1]
	RRC.B	R13						;[1]
	RRC.B	R13						;[1]

	RLC.B	R12						;[1]
	RLC.B	R13						;[1]
	RLC.B	R12						;[1]
	RLC.B	R13						;[1]

	SWPB	R14						;[1]
	BIS		R13, R14				;[1] merge b15-b8(R14) and b7-b(R13) together into R14

; Check if handle matches.
	CMP		R14, &rfid.handle       ;[2]
	JNE		exit_safely             ;[2] Handle doesn't match, so exit.

; Load up function call, the transmit.
	MOV		(rfid.handle), R_scratch0;[3] bring in the RN16
	SWPB	R_scratch0				;[1] swap bytes so we can shove full word out in one call (MSByte into dataBuf[0],...)
	MOV		R_scratch0, &(rfidBuf)	;[3] load the MSByte

	MOV		#(rfidBuf),		R13		;[2] load &dataBuf[0] as dataPtr
	MOV		#(2),			R14		;[2] load num of bytes in ACK

	MOV 	#ZERO_BIT_CRC, R12 		;[2]

	CALLA	#crc16_ccitt			;[5+196]

	;STORE CRC16
	MOV.B	R12,	&(rfidBuf+3)	;[3] store lower CRC byte first
	SWPB	R12						;[1] move upper byte into lower byte
	MOV.B	R12,	&(rfidBuf+2)	;[3] store upper CRC byte

	CLRC                            ;[3]
	RRC.B	(rfidBuf)               ;[6]
	RRC.B	(rfidBuf+1)             ;[6]
	RRC.B	(rfidBuf+2)             ;[6]
	RRC.B	(rfidBuf+3)             ;[6]
	RRC.B	(rfidBuf+4)             ;[6]

; Wait on CRC16 bits.
waitOnBits_5:
	CMP.W   #74, R_bits                   ;[2]
	JLO     waitOnBits_5                  ;[2]

	; Now prepare to respond to the reader, so disable interrupts.
	DINT							;[3]
	NOP                             ;[1]

	CLR		&TA0CTL					;[4]

	; Wait ~RTCAL delay before replying.
	;MOV		#TX_TIMING_BWR, R15 	;[2]
	MOV		#5000, R15 	;[2]

; [14]

timing_delay_for_BlockWrite:
	DEC		R15						    ;[1]
	JNZ		timing_delay_for_BlockWrite	;[2]

	MOV		#rfidBuf, 	R12			;[2] load the &rfidBuf[0]
	MOV		#(4),		R13			;[1] load into corr reg (numBytes)
	MOV		#1,			R14			;[1] load numBits=1
	MOV.B	#TREXT_ON,	R15			;[3] load TRext

	CALLA	#TxFM0					;[5] call the routine

	CALLA   #RxClock	;Switch to RxClock

	BIC		#(GIE), SR				;[1] don't need anymore bits, so turn off Rx_SM
	NOP
	CLR		&TA0CTL

	;Call user hook function if it's configured (if it's non-NULL)
	CMP.B		#(0), &(RWData.bwrHook)       ;[]
	JEQ			blockwriteHandle_SkipHookCall;[]
	MOV			&(RWData.bwrHook), R_scratch0 ;[]
	CALLA		R_scratch0                    ;[]

blockwriteHandle_SkipHookCall:

	;Modify Abort Flag if necessary (i.e. if in std_mode
	BIT.B		#(CMD_ID_WRITE), (rfid.abortOn);[] Should we abort on WRITE?
	JNZ			blockwriteHandle_BreakOutofRFID	;[]
	RETA								;[] else return w/o setting flag

; If configured to abort on successful WRITE, set abort flag cause it just happened!
blockwriteHandle_BreakOutofRFID:

	BIS.B		#1, (rfid.abortFlag);[] by setting this bit we'll abort correctly!
	RETA

exit_safely:
	; Tie up loose ends with timers and interrupts and such
	NOP;
	CLR &TA0CTL;
	RETA;

	.end
