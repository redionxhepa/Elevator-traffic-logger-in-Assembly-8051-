ORG 0000H
LJMP MAIN

ORG 0003H
LJMP EX0_ISR

;ORG 000BH
;LJMP T0_ISR

ORG 0013H
LJMP EX1_ISR
;***************************************
;		Ports
;***************************************
sda equ P0.0 ; serial data line
scl equ P0.1 ;serial clock line

CLK BIT P1.3
CS BIT P1.4
DIN BIT P1.5

DEBUG BIT P2.0

;***************************************
; 		Variables
;***************************************
SPEED EQU 30h
BRIGHT EQU 31h

WADDR EQU 32h
WDATA EQU 33h

MAX EQU 4EH
MIN EQU 4FH
SAMPLE EQU 50H
PREV_SAMPLE EQU 51H
DELTA EQU 52H
FLOOR  EQU 53H

THRESHOLD_5 EQU 54H
THRESHOLD_4 EQU 55H
THRESHOLD_3 EQU 56H
THRESHOLD_2 EQU 57H
THRESHOLD_1 EQU 58H

TEMP EQU 5AH

P_1 EQU 60H
P_2 EQU 61H
P_3 EQU 62H

RTC_SEC EQU 63H
RTC_MIN EQU 64H
RTC_HOUR EQU 65H
RTC_DATE EQU 66H
RTC_MON EQU 67H
RTC_YEAR EQU 68H

LOCATION EQU 69H
INDEX_IN_CHAR EQU 6Ah


;EX: 17-07-30 15:51:27 145 5

ELAPSED10SEC BIT 7CH
RUNNING BIT 7DH
STILL_SENDING BIT 7EH
DATA_IS_SENT_ONCE BIT 7FH
;***************************************


MAIN:
MOV TMOD,#20H ;mode 2 timer 0
SETB TCON.2 ;make INT1 edge-triggered interrupt
SETB TCON.0 ;make INT0 edge-triggered interrupt
;SETB IP.2
;SETB IP.0
MOV IE,#10000101B ;enable External INT 0 AND 1
MOV TH1,#0E8H ; Baud rate = 1200bps
MOV SCON,#50H
SETB TR1 ;start the timer
ACALL CONFIGURE

MOV MIN, #107
MOV MAX, #53
ACALL CALCULATE_THRESHOLDS

CPL DEBUG
ACALL DELAY1SEC
CPL DEBUG
ACALL DELAY1SEC
CPL DEBUG
ACALL DELAY1SEC

RESTART_PROGRAM:

MOV R5, #200
READ_AGAIN:
LCALL READ_PRESSURE
LCALL CHECK_FLOORS
LCALL SHOW_FLOOR
DJNZ R5, READ_AGAIN

;LCALL CHECK_RUNNING
; IF ELEVATOR IS STOPPED
;JB RUNNING, SKIP_SEND
	;MOV A, FLOOR

;	; IF AT 5TH FLOOR
;	CJNE A, #5, SKIP_UPDATE1
;	MOV MIN, P_2
;	SKIP_UPDATE1:
;
;	; IF AT GROUND FLOOR
;	CJNE A, #0, SKIP_UPDATE2
;	MOV MAX, SAMPLE
;	LCALL CALCULATE_THRESHOLDS
;	SKIP_UPDATE2:

	; IF 10SEC ELAPSED FROM PREV TRANSMISSION
	;JNB ELAPSED10SEC, SKIP_SEND
		LCALL READ_RTC
		LCALL SEND_DATA
		ACALL DELAY1SEC
		;CLR ELAPSED10SEC
		;SETB TF0
SKIP_SEND:

SJMP RESTART_PROGRAM









;%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
EX0_ISR:
	MOV MAX, SAMPLE
	LCALL CALCULATE_THRESHOLDS
	;MOV FLOOR, #0
RETI

;%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

;	JB ELAPSED10SEC ,SKIP_10 
;	CLR TR0
;	MOV TH0,#HIGH 0 ;0.06 sec
;	MOV TL0,#LOW 0
;	SETB TR0
;	INC r6
;	CJNE r6,#165,SKIP_10
;	setb ELAPSED10SEC
;	MOV r6,#0 ;restart
;	SKIP_10: 
;RETI


;%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
EX1_ISR:
	MOV MIN, P_2
	MOV SAMPLE, #0
	MOV PREV_SAMPLE, #0
	;MOV FLOOR, #5
RETI



;%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
DELAY1SEC:
	MOV R3,#5
	BACK_3:MOV R2,#250
	BACK_2:MOV R1,#250
	BACK_1:NOP
	DJNZ R1,BACK_1
	DJNZ R2,BACK_2
	DJNZ R3,BACK_3
RET


;%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
CONFIGURE:
	;RESET COMMAND FOR PRESSURE SENSOR
	lcall i2cinit
	lcall startc
	mov a,#11101110b
	acall send
	mov a,#1EH
	acall send
	acall stop
	
	CLR ELAPSED10SEC
	SETB TF0
	CLR DATA_IS_SENT_ONCE
	
	CLR RUNNING

;	MOV BRIGHT, #01H
;	MOV INDEX_IN_CHAR, #1
;	MOV LOCATION, #0

	;ACALL CONFIGURE_DISPLAY
RET

;%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
READ_PRESSURE:
	
	; ADC conversion comand D1(for pressure measurement)
        lcall i2cinit
	lcall startc
	mov a,#11101110b
	acall send
	mov a,#40H; ;according to the data sheet
	acall send	
	acall stop
	ACALL DELLAY10ms

	
	;SEND  the ADC READ COMMAND
	lcall i2cinit
	lcall startc
	mov a,#11101110b
	acall send
	mov a,#00H; ;according to the data sheet
	acall send
	acall stop	

		
	; READING PART
	lcall i2cinit
	lcall startc
	mov a,#11101111b
	acall send		
	; Read the first byte
	acall recv
	acall ACK
	MOV P_1,A
	; Read the  second byte
	acall recv
	acall ACK
        MOV P_2,A 
      	; Read the third byte byte
	acall recv
	acall nak
	acall stop
	MOV P_3,A 


	MOV A, P_2

	; CHECKS IF A IS SMALLER THAN MIN
	CLR C
	CJNE A, MIN, $+3
	JC SKIP_VALUE
	MOV PREV_SAMPLE, SAMPLE

	CLR C
	SUBB A, MIN
	MOV SAMPLE, A
	SKIP_VALUE:


RET



	
;%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
READ_RTC:
;READING SECONDS
	lcall i2cinit
	lcall startc
	mov a,#11010000b
	acall send
	mov a,#00H; ;according to the data sheet
	acall send
	acall stop
;+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++	
	lcall i2cinit
	lcall startc
	mov a,#11010001b   ;
	acall send
	acall recv
	acall nak	
	acall stop
	MOV RTC_SEC,A
;+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;READING MINUTES
	lcall i2cinit
	lcall startc
	mov a,#11010000b
	acall send
	mov a,#01H; ;according to the data sheet
	acall send
	acall stop
;+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
	lcall i2cinit
	lcall startc
	mov a,#11010001b
	acall send
	acall recv
	acall nak
	acall stop
	MOV RTC_MIN,A
;+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
;READING HOURS
	lcall i2cinit
	lcall startc
	mov a,#11010000b
	acall send
	mov a,#02H; ;according to the data sheet
	acall send
	acall stop
;+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
	lcall i2cinit
	lcall startc
	mov a,#11010001b
	acall send
	acall recv
	acall nak
	ANL A, #00111111B
	acall stop
	MOV RTC_HOUR,A
;++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
	;READING DATE
	lcall i2cinit
	lcall startc
	mov a,#11010000b
	acall send
	mov a,#04H; ;according to the data sheet
	acall send
	acall stop
;+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
	lcall i2cinit
	lcall startc
	mov a,#11010001b
	acall send
	acall recv
	acall nak
	acall stop
	MOV RTC_DATE,A
;+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
 	;READING MONTH
	lcall i2cinit
	lcall startc
	mov a,#11010000b
	acall send
	mov a,#05H; ;according to the data sheet
	acall send
	acall stop
;+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
	lcall i2cinit
	lcall startc
	mov a,#11010001b
	acall send
	acall recv
	acall nak
	ANL A, #00011111B
	acall stop
	MOV RTC_MON,A
;+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
 	;READING YEAR
	lcall i2cinit
	lcall startc
	mov a,#11010000b
	acall send
	mov a,#06H; ;according to the data sheet
	acall send
	acall stop
;+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
	lcall i2cinit
	lcall startc
	mov a,#11010001b
	acall send
	acall recv
	acall nak
	acall stop
	MOV RTC_YEAR,A
RET




;%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
SEND_DATA:
    	MOV A,RTC_YEAR
    	ACALL CONVERT_TO_ASCII_BCD
	ACALL send_serially_BCD ;year

	ACALL sendminus
	
    	MOV A,RTC_MON
    	ACALL CONVERT_TO_ASCII_BCD
    	ACALL send_serially_BCD ;month

    	ACALL sendminus

    	MOV A,RTC_DATE
    	ACALL CONVERT_TO_ASCII_BCD
    	ACALL send_serially_BCD ;date

    	ACALL sendspace

    	MOV A,RTC_HOUR
    	ACALL CONVERT_TO_ASCII_BCD
	ACALL send_serially_BCD ;hour

	ACALL send2dots

    	MOV A,RTC_MIN
    	ACALL CONVERT_TO_ASCII_BCD
	ACALL send_serially_BCD  ;minutes

    	ACALL send2dots
    	
    	MOV A,RTC_SEC
    	ACALL CONVERT_TO_ASCII_BCD
	ACALL send_serially_BCD ;seconds

	ACALL sendspace
	
	MOV A,P_2
    	ACALL CONVERT_TO_ASCII
	ACALL send_serially;seconds

	  
	ACALL sendspace


        CLR TI
        MOV A,FLOOR
        ADD A, #30H
	MOV SBUF,A
	JNB TI,$
	
    	CPL DEBUG; FOR DEBUGGING
RET

;%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
SEND_SERIALLY:
; send setially the first byte (in our case digit)
        CLR TI
        MOV A,R4
	MOV SBUF,A
	JNB TI,$

;send serially the second byte (in our case digit)
	CLR TI
        MOV A,R3
	MOV SBUF,A
	JNB TI,$

;send serially the third byte (in our case digit)
	CLR TI
        MOV A,R2
	MOV SBUF,A
	JNB TI,$
RET 
        
;%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
send_serially_BCD:
   ;;send serially the first byte (in our case digit)
	CLR TI
        MOV A,R2
	MOV SBUF,A
	JNB TI,$

;   ;;send serially the second byte (in our case digit)
	CLR TI
        MOV A,R3
	MOV SBUF,A
	JNB TI,$
RET 

;%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
send2dots:
        CLR TI
        MOV A,#':'
	MOV SBUF,A
	JNB TI,$
RET 

;%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
sendspace:
	CLR TI
        MOV A,#' '
	MOV SBUF,A                
	JNB TI,$ 
RET 
sendminus:
        CLR TI
        MOV A,#'-'
	MOV SBUF,A                
	JNB TI,$       
RET 




;%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
CONVERT_TO_ASCII:
	;first digit
	MOV B,#100
	DIV AB
	ADD A,#30H
	MOV r4,A ;done with first digit
	;Second digit
	MOV A,B 
	MOV B,#10
	DIV AB
	ADD A,#30H
	Mov r3,A 
	;last digit
	MOV A,B 
	ADD A,#30H
	MOV r2,A 
RET
	
;%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%	
CONVERT_TO_ASCII_BCD:
	MOV B,A     ;example 35H (firstly save the value of a)
	ANL A,#0FH  ; 05;
	ADD A,#30H  ; 35H;
	MOV R3,A 
	MOV A,B  ;again 35H
	SWAP A 
	ANL A,#0FH  ; 05;
	ADD A,#30H  ; 35H;    so the asccı values for 35H are saved in  R1='3'  r2='5'
	MOV R2,A
RET 



;%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
DELLAY10MS:
	MOV R3,#50
	BACK__3:MOV R2,#64
	BACK__2:NOP
	DJNZ R2,BACK__2
	DJNZ R3,BACK__3
RET	

;%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
CHECK_FLOORS:
	MOV A, SAMPLE
	CLR C 
	CJNE A,THRESHOLD_5,$+3
	JNC  FOUR
	mov floor,#5 ;at the fifth floor
	SJMP EXIT_CHECK
	FOUR: CLR C 
	CJNE A,THRESHOLD_4,$+3
	JNC THREE 
	MOV floor,#4 ;at the fourth floor
	SJMP EXIT_CHECK 

	THREE:CLR C 
	CJNE A,THRESHOLD_3,$+3
	JNC TWO 
	MOV floor,#3 ;at the third floor
	SJMP EXIT_CHECK 

	TWO:CLR C 
	CJNE A,THRESHOLD_2,$+3
	JNC ONE 
	MOV floor,#2 ;at the second floor
	SJMP EXIT_CHECK 
	
	ONE:CLR C 
	CJNE A,THRESHOLD_1,$+3
	JNC ZERO 
	MOV floor,#1 ;at the first floor
	SJMP EXIT_CHECK 

	ZERO: CLR C
  	MOV floor,#0 ;at the ground floor

	EXIT_CHECK: 
RET

;%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
CHECK_RUNNING:	
	MOV A, SAMPLE
	MOV B, PREV_SAMPLE
	
	CLR C 
	CJNE A,B,$+3
	JC A_SMALLER
	CLR C
	SUBB A,B
	mov delta,A 
	SJMP exit_check2
	
	A_SMALLER: 	
	XCH A, B
	CLR C
	SUBB A,B
	MOV delta,A  

	exit_check2:
	CLR C 
	CJNE A,#3,$+3
	JNC MOVING
	CLR RUNNING
	SJMP EXIT_CHECK3
	MOVING: SETB RUNNING 
	CLR DATA_IS_SENT_ONCE
	EXIT_CHECK3: 
RET




;%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
CALCULATE_THRESHOLDS:
	MOV A, MAX
	;threshold for floor 5
	MOV B,#10
	DIV AB
	MOV THRESHOLD_5,A 

	;threshold for floor 4
	MOV A,MAX
	MOV B,#10
	DIV AB
	MOV TEMP,A 
	MOV A,MAX
	MOV B,#5
	DIV AB
	ADD A,TEMP                           
	MOV THRESHOLD_4,A 
	;threshold for floor 3
	MOV A,MAX
	MOV B,#10
	DIV AB
	MOV TEMP,A 
	MOV A,MAX
	MOV B,#5
	DIV AB
	MOV B,#2
	MUL AB 
	ADD A,TEMP
	MOV threshold_3,A 
	;threshold for floor 2
	MOV A,MAX
	MOV B,#10
	DIV AB
	MOV TEMP,A 

	MOV A,MAX
	MOV B,#5
	DIV AB
	MOV B,#3
	MUL AB 
	ADD A,TEMP
	MOV threshold_2,A 
	;threshold for floor 1
	MOV A,MAX
	MOV B,#10
	DIV AB
	MOV TEMP,A 

	MOV A,MAX
	MOV B,#5
	DIV AB
	MOV B,#4
	MUL AB 
	ADD A,TEMP
	MOV THRESHOLD_1,A 
RET



;***************************************
;Initializing I2C Bus Communication
;***************************************
i2cinit:
	setb sda
	setb scl
RET
 
;****************************************
;ReStart Condition for I2C Communication
;****************************************
rstart:
	clr scl
	setb sda
	setb scl
	clr sda
RET
 
;****************************************
;Start Condition for I2C Communication
;****************************************
startc:
	setb scl
	clr sda
	clr scl
RET
 
;*****************************************
;Stop Condition For I2C Bus
;*****************************************
stop:
	clr scl
	clr sda
	setb scl
	setb sda
RET
 
;*****************************************
;Sending Data to slave on I2C bus
;*****************************************
send:
	mov r7,#08
back:
	clr scl
	rlc a
	mov sda,c
	setb scl
	djnz r7,back
	clr scl
	setb sda
	setb scl
	mov c, sda
	clr scl
RET
 
;*****************************************
;ACK and NAK for I2C Bus
;*****************************************
ack:
	clr sda
	setb scl
	clr scl
	setb sda
RET
 
nak:
	setb sda
	setb scl
	clr scl
	setb scl
RET
 
;*****************************************
;Receiving Data from slave on I2C bus
;*****************************************
recv:
	mov r7,#08
back2:
	clr scl
	setb scl
	mov c,sda
	rlc a
	djnz r7,back2
	clr scl
	setb sda
RET

SHOW_FLOOR:
	MOV DPTR, #SEVEN_SEGMENTS
	MOV A, FLOOR
	MOVC A, @A+DPTR
	CPL A
	MOV P2, A
RET



SEVEN_SEGMENTS:
;GFEDCBA0
DB 01111110B ;0
DB 01100000B ;1
DB 10110110B ;2
DB 10011110B ;3
DB 11001100B ;4
DB 11011010B ;5


;;%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
;CONFIGURE_DISPLAY:
;	MOV WADDR, #00h
;	MOV WDATA, #00h  ;nop
;
;	MOV R2,#8
;	QWERTY:
;	ACALL SEND_DISPLAY
;
;	DJNZ R2, QWERTY
;
;	SETB CS
;	CLR CS
;
;
;	MOV WADDR, #09h
;	MOV WDATA, #00h  ;decoding BCD
;	;CLR CS
;	ACALL SEND_DISPLAY
;	SETB CS
;	nop
;	CLR CS
;
;	MOV A, BRIGHT
;
;	MOV WADDR, #0Ah
;	MOV WDATA, A  ;brightness 
;	;CLR CS
;	ACALL SEND_DISPLAY
;	SETB CS
;	nop
;	CLR CS
;
;	MOV WADDR, #0bh
;	MOV WDATA, #07h  ;scanlimitï¼8 LEDs
;	;CLR CS
;	ACALL SEND_DISPLAY
;	SETB CS
;	nop
;	CLR CS
;
;	MOV WADDR, #0ch
;	MOV WDATA, #01h  ;power-down modeï¼0ï¼normal modeï¼1
;	;CLR CS
;	ACALL SEND_DISPLAY
;	SETB CS
;	nop
;	CLR CS
;
;	MOV WADDR, #0fh
;	MOV WDATA, #00h  ;test display
;	;CLR CS
;	ACALL SEND_DISPLAY
;	SETB CS
;	nop
;	CLR CS
;
;
;	MOV WADDR, #00h
;	MOV WDATA, #00h  ;nop
;	ACALL SEND_DISPLAY
;	SETB CS
;	nop
;	CLR CS
;
;	ACALL SEND_DISPLAY
;	SETB CS
;	nop
;	CLR CS
;
;	ACALL SEND_DISPLAY
;	SETB CS
;	nop
;	CLR CS
;
;	ACALL SEND_DISPLAY
;	SETB CS
;	nop
;	CLR CS
;
;	ACALL SEND_DISPLAY
;	SETB CS
;	nop
;	CLR CS
;
;	ACALL SEND_DISPLAY
;	SETB CS
;	nop
;	CLR CS
;
;	ACALL SEND_DISPLAY
;	SETB CS
;	nop
;	CLR CS
;RET

;;%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%	
;SEND_DISPLAY:
;	;CLR CS
;	MOV A, WADDR
;
;	MOV R4, #8
;	FIRST:
;	RLC A
;	MOV DIN, C
;	SETB CLK
;	CLR CLK
;	DJNZ r4, FIRST
;
;	MOV A, WDATA
;
;	MOV R4, #8
;	SECOND:
;	RLC A
;	MOV DIN, C
;	SETB CLK
;	CLR CLK
;	DJNZ r4, SECOND
;RET
;
;DISPLAY_FLOOR:
;		MOV DPTR, #CHAR_MAP
;		MOV A, FLOOR
;		ADD A, #30H
;		CLR C
;		SUBB A, #20h
;		CJNE A, #1, $+3
;		JC FIRST_CHAR
;		MOV R7, A
;FIND_LUT:
;		MOV A,DPL
;		ADD A, #8
;		MOV DPL, A
;		MOV A, DPH
;		ADDC A, #0
;		MOV DPH, A
;
;		DJNZ R7, FIND_LUT
;FIRST_CHAR:
;		CLR A
;		MOVC A, @A+DPTR 	; A now has the length of the char
;		MOV TEMP, A
;		INC TEMP		; temp now holds length + 1
;		MOV A, INDEX_IN_CHAR
;		CJNE A, TEMP, $+3
;		JC STILL_INSIDE
;		CLR STILL_SENDING
;		AJMP DISPLAY_FLOOR
;STILL_INSIDE:
;		MOV A, INDEX_IN_CHAR
;
;		MOVC A, @A+DPTR ; get the proper column
;
;		MOV @R1, A 	; append last data
;		INC LOCATION
;		MOV A, LOCATION
;		CJNE A, #32, $+3
;		JC CONTINUE
;		MOV LOCATION, #0
;		CONTINUE:
;RET

;
;CHAR_MAP:
;  DB 3, 00000000b, 00000000b, 00000000b, 00000000b, 00000000b, 00000000b, 00000000b ; space		;20h
;  DB 2, 01011111b, 00000000b, 00000000b, 00000000b, 00000000b, 00000000b, 00000000b ; !
;  DB 4, 00000011b, 00000000b, 00000011b, 00000000b, 00000000b, 00000000b, 00000000b ; "
;  DB 6, 00010100b, 00111110b, 00010100b, 00111110b, 00010100b, 00000000b, 00000000b ; #
;  DB 5, 00100100b, 01101010b, 00101011b, 00010010b, 00000000b, 00000000b, 00000000b ; $
;  DB 6, 01100011b, 00010011b, 00001000b, 01100100b, 01100011b, 00000000b, 00000000b ; %
;  DB 6, 00110110b, 01001001b, 01010110b, 00100000b, 01010000b, 00000000b, 00000000b ; &
;  DB 2, 00000011b, 00000000b, 00000000b, 00000000b, 00000000b, 00000000b, 00000000b ; '
;  DB 4, 00011100b, 00100010b, 01000001b, 00000000b, 00000000b, 00000000b, 00000000b ; (
;  DB 4, 01000001b, 00100010b, 00011100b, 00000000b, 00000000b, 00000000b, 00000000b ; )
;  DB 6, 00101000b, 00011000b, 00001110b, 00011000b, 00101000b, 00000000b, 00000000b ; *
;  DB 6, 00001000b, 00001000b, 00111110b, 00001000b, 00001000b, 00000000b, 00000000b ; +
;  DB 3, 10110000b, 01110000b, 00000000b, 00000000b, 00000000b, 00000000b, 00000000b ; ,
;  DB 5, 00001000b, 00001000b, 00001000b, 00001000b, 00000000b, 00000000b, 00000000b ; -
;  DB 3, 01100000b, 01100000b, 00000000b, 00000000b, 00000000b, 00000000b, 00000000b ; .
;  DB 5, 01100000b, 00011000b, 00000110b, 00000001b, 00000000b, 00000000b, 00000000b; /
;  DB 5, 00111110b, 01000001b, 01000001b, 00111110b, 00000000b, 00000000b, 00000000b ; 0		;30h
;  DB 4, 01000010b, 01111111b, 01000000b, 00000000b, 00000000b, 00000000b, 00000000b ; 1
;  DB 5, 01100010b, 01010001b, 01001001b, 01000110b, 00000000b, 00000000b, 00000000b ; 2
;  DB 5, 00100010b, 01000001b, 01001001b, 00110110b, 00000000b, 00000000b, 00000000b ; 3
;  DB 5, 00011000b, 00010100b, 00010010b, 01111111b, 00000000b, 00000000b, 00000000b ; 4
;  DB 5, 00100111b, 01000101b, 01000101b, 00111001b, 00000000b, 00000000b, 00000000b ; 5
;  DB 5, 00111110b, 01001001b, 01001001b, 00110000b, 00000000b, 00000000b, 00000000b ; 6
;  DB 5, 01100001b, 00010001b, 00001001b, 00000111b, 00000000b, 00000000b, 00000000b ; 7
;  DB 5, 00110110b, 01001001b, 01001001b, 00110110b, 00000000b, 00000000b, 00000000b ; 8
;  DB 5, 00000110b, 01001001b, 01001001b, 00111110b, 00000000b, 00000000b, 00000000b ; 9
;  DB 3, 00101000b, 00000000b, 00000000b, 00000000b, 00000000b, 00000000b, 00000000b ; :
;  DB 3, 10000000b, 01010000b, 00000000b, 00000000b, 00000000b, 00000000b, 00000000b ; ;
;  DB 4, 00010000b, 00101000b, 01000100b, 00000000b, 00000000b, 00000000b, 00000000b ; <
;  DB 4, 00010100b, 00010100b, 00010100b, 00000000b, 00000000b, 00000000b, 00000000b ; =
;  DB 4, 01000100b, 00101000b, 00010000b, 00000000b, 00000000b, 00000000b, 00000000b ; >
;  DB 5, 00000010b, 01011001b, 00001001b, 00000110b, 00000000b, 00000000b, 00000000b ; ?
;  DB 6, 00111110b, 01001001b, 01010101b, 01011101b, 00001110b, 00000000b, 00000000b ; @		;40h
;  DB 5, 01111110b, 00010001b, 00010001b, 01111110b, 00000000b, 00000000b, 00000000b ; A
;  DB 5, 01111111b, 01001001b, 01001001b, 00110110b, 00000000b, 00000000b, 00000000b ; B
;  DB 5, 00111110b, 01000001b, 01000001b, 00100010b, 00000000b, 00000000b, 00000000b ; C
;  DB 5, 01111111b, 01000001b, 01000001b, 00111110b, 00000000b, 00000000b, 00000000b ; D
;  DB 5, 01111111b, 01001001b, 01001001b, 01000001b, 00000000b, 00000000b, 00000000b ; E
;  DB 5, 01111111b, 00001001b, 00001001b, 00000001b, 00000000b, 00000000b, 00000000b ; F
;  DB 5, 00111110b, 01000001b, 01001001b, 01111010b, 00000000b, 00000000b, 00000000b ; G
;  DB 5, 01111111b, 00001000b, 00001000b, 01111111b, 00000000b, 00000000b, 00000000b ; H
;  DB 4, 01000001b, 01111111b, 01000001b, 00000000b, 00000000b, 00000000b, 00000000b ; I
;  DB 5, 00110000b, 01000000b, 01000001b, 00111111b, 00000000b, 00000000b, 00000000b ; J
;  DB 5, 01111111b, 00001000b, 00010100b, 01100011b, 00000000b, 00000000b, 00000000b ; K
;  DB 5, 01111111b, 01000000b, 01000000b, 01000000b, 00000000b, 00000000b, 00000000b ; L
;  DB 6, 01111111b, 00000010b, 00001100b, 00000010b, 01111111b, 00000000b, 00000000b ; M
;  DB 6, 01111111b, 00000100b, 00001000b, 00010000b, 01111111b, 00000000b, 00000000b ; N
;  DB 5, 00111110b, 01000001b, 01000001b, 00111110b, 00000000b, 00000000b, 00000000b ; O
;  DB 5, 01111111b, 00001001b, 00001001b, 00000110b, 00000000b, 00000000b, 00000000b; P		;50h
;  DB 5, 00111110b, 01000001b, 01000001b, 10111110b, 00000000b, 00000000b, 00000000b ; Q
;  DB 5, 01111111b, 00001001b, 00001001b, 01110110b, 00000000b, 00000000b, 00000000b ; R
;  DB 5, 01000110b, 01001001b, 01001001b, 00110010b, 00000000b, 00000000b, 00000000b ; S
;  DB 6, 00000001b, 00000001b, 01111111b, 00000001b, 00000001b, 00000000b, 00000000b ; T
;  DB 5, 00111111b, 01000000b, 01000000b, 00111111b, 00000000b, 00000000b, 00000000b ; U
;  DB 6, 00001111b, 00110000b, 01000000b, 00110000b, 00001111b, 00000000b, 00000000b ; V
;  DB 6, 00111111b, 01000000b, 00111000b, 01000000b, 00111111b, 00000000b, 00000000b; W
;  DB 6, 01100011b, 00010100b, 00001000b, 00010100b, 01100011b, 00000000b, 00000000b ; X
;  DB 6, 00000111b, 00001000b, 01110000b, 00001000b, 00000111b, 00000000b, 00000000b ; Y
;  DB 5, 01100001b, 01010001b, 01001001b, 01000111b, 00000000b, 00000000b, 00000000b ; Z
;  DB 3, 01111111b, 01000001b, 00000000b, 00000000b, 00000000b, 00000000b, 00000000b ; [
;  DB 5, 00000001b, 00000110b, 00011000b, 01100000b, 00000000b, 00000000b, 00000000b ; \ backslash
;  DB 3, 01000001b, 01111111b, 00000000b, 00000000b, 00000000b, 00000000b, 00000000b ; ]
;  DB 4, 00000010b, 00000001b, 00000010b, 00000000b, 00000000b, 00000000b, 00000000b; hat
;  DB 5, 01000000b, 01000000b, 01000000b, 01000000b, 00000000b, 00000000b, 00000000b ; _
;  DB 3, 00000001b, 00000010b, 00000000b, 00000000b, 00000000b, 00000000b, 00000000b ; `		;60h
;  DB 5, 00100000b, 01010100b, 01010100b, 01111000b, 00000000b, 00000000b, 00000000b ; a
;  DB 5, 01111111b, 01000100b, 01000100b, 00111000b, 00000000b, 00000000b, 00000000b ; b
;  DB 5, 00111000b, 01000100b, 01000100b, 00101000b, 00000000b, 00000000b, 00000000b ; c
;  DB 5, 00111000b, 01000100b, 01000100b, 01111111b, 00000000b, 00000000b, 00000000b ; d
;  DB 5, 00111000b, 01010100b, 01010100b, 00011000b, 00000000b, 00000000b, 00000000b ; e
;  DB 4, 00000100b, 01111110b, 00000101b, 00000000b, 00000000b, 00000000b, 00000000b ; f
;  DB 5, 10011000b, 10100100b, 10100100b, 01111000b, 00000000b, 00000000b, 00000000b ; g
;  DB 5, 01111111b, 00000100b, 00000100b, 01111000b, 00000000b, 00000000b, 00000000b ; h
;  DB 4, 01000100b, 01111101b, 01000000b, 00000000b, 00000000b, 00000000b, 00000000b ; i
;  DB 5, 01000000b, 10000000b, 10000100b, 01111101b, 00000000b, 00000000b, 00000000b ; j
;  DB 5, 01111111b, 00010000b, 00101000b, 01000100b, 00000000b, 00000000b, 00000000b ; k
;  DB 4, 01000001b, 01111111b, 01000000b, 00000000b, 00000000b, 00000000b, 00000000b ; l
;  DB 6, 01111100b, 00000100b, 01111100b, 00000100b, 01111000b, 00000000b, 00000000b ; m
;  DB 5, 01111100b, 00000100b, 00000100b, 01111000b, 00000000b, 00000000b, 00000000b ; n
;  DB 5, 00111000b, 01000100b, 01000100b, 00111000b, 00000000b, 00000000b, 00000000b ; o
;  DB 5, 11111100b, 00100100b, 00100100b, 00011000b, 00000000b, 00000000b, 00000000b ; p		;70h
;  DB 5, 00011000b, 00100100b, 00100100b, 11111100b, 00000000b, 00000000b, 00000000b ; q
;  DB 5, 01111100b, 00001000b, 00000100b, 00000100b, 00000000b, 00000000b, 00000000b ; r
;  DB 5, 01001000b, 01010100b, 01010100b, 00100100b, 00000000b, 00000000b, 00000000b ; s
;  DB 4, 00000100b, 00111111b, 01000100b, 00000000b, 00000000b, 00000000b, 00000000b ; t
;  DB 5, 00111100b, 01000000b, 01000000b, 01111100b, 00000000b, 00000000b, 00000000b ; u
;  DB 6, 00011100b, 00100000b, 01000000b, 00100000b, 00011100b, 00000000b, 00000000b ; v
;  DB 6, 00111100b, 01000000b, 00111100b, 01000000b, 00111100b, 00000000b, 00000000b ; w
;  DB 6, 01000100b, 00101000b, 00010000b, 00101000b, 01000100b, 00000000b, 00000000b ; x
;  DB 5, 10011100b, 10100000b, 10100000b, 01111100b, 00000000b, 00000000b, 00000000b ; y
;  DB 4, 01100100b, 01010100b, 01001100b, 00000000b, 00000000b, 00000000b, 00000000b ; z
;  DB 4, 00001000b, 00110110b, 01000001b, 00000000b, 00000000b, 00000000b, 00000000b ; {
;  DB 2, 01111111b, 00000000b, 00000000b, 00000000b, 00000000b, 00000000b, 00000000b ; |
;  DB 4, 01000001b, 00110110b, 00001000b, 00000000b, 00000000b, 00000000b, 00000000b ; }
;  DB 5, 00001000b, 00000100b, 00001000b, 00000100b, 00000000b, 00000000b, 00000000b ; ~


 
END 


