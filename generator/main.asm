; Authors: Oskar Herman, Sylwester D¹browski
; Project for Microprocessor thechnics class at AGH University of Krakow
; Summer semester of 2025
; 
; Description : bla bla bla 

;-----------------------------------------------------------------------------------------------------------------------------

.include "m328PBdef.inc"
.cseg

.org 0x00
	rjmp prog_start
;DEFINITION OF INTERUPTS:
.org INT0addr
	rjmp control_mode
.org 0x60
;7seg decoder (digits are fine but we need new select system):
sgm: .DB 0x3f, 0x06, 0x5b, 0x4f, 0x66, 0x6d, 0x7d, 0x07, 0x7f, 0x6f, 0x77, 0x7c,0x39, 0x5e, 0x79, 0x71

;-----------------------------------------------------------------------------------------------------------------------------
.org 0x100

prog_start:
    ;stack implementation
	ldi r16, high(ramend)
	out sph, r16
	ldi r16, low(ramend)
	out spl, r16
	;We can use portB for 7seg display (port D is needed for waveform generator).
	ldi r16, 0xff
	out ddrb, r16
	; and portE for selection of display
	ldi r16, 0x0f
	out ddre, r16
	; portC diodes for duty cycle display (last is connected to VCC)
	ldi r16, 0x3f
	out ddrc, r16
	;special setting for portD
	;PD6 - outout of waveform generator
	;keybord:
	;PD2 - INT0 button
	;PD0-PD5 is all we needed
	ldi r16, 0b01000000
	out ddrd, r16
	ldi r16, 0b00111111 ;pull up resistors
	out portd, r16
	;allocation and default set of control registers:
	ldi r25, 1 ; r25 is a register for type of signal: default 1-PWM, 2-sine, 3-triang 
	ldi r26, 4 ; r26 is a register for frequency (default 488 Hz)
	ldi r27, 50 ; r27 is a register for duty cycle (default 50%)
	ldi r28, 5 ; r28 is a register for step of changing duty cycle 
	ldi r16, 1;
	mov r2, r16;
	eor r1, r1; r1 is a register for interrupt controll (it is set, when iterrupt occured)
	;Interrupt enable (external interrupt from PD2 triggered by raising edge):
	ldi r16, (1<<int0)
	out eimsk, r20
	ldi r16, (1<<isc01)|(1<<isc00)
	sts eicra, r20
	rjmp PWM ; jump to default signal

;-----------------------------------------------------------------------------------------------------------------------------

control_mode:
; Control mode is using 6 buttons:
; PD2 - enter/exit control mode
; PD3 - choose signal: PWM (display0: P), sine (S) or triangle (|-) 
; PD0 - increase frequency (display1-3)
; PD1 - decrease frequency (display1-3)
; PD4 - increase duty cycle (display2-3)
; PD5 - decrease duty cycle (display2-3) [we can use diodes to display current duty cycle and change it 10:10:90]

	cli ;diseble interrupts
cm_loop:
	call display ; display current settings
	call LEDdriver
	; check if button is pressed
cm_signal:
	sbis portd, 3 
	inc r25
	cpi r25, 4 ; if greater than 3 load 1 
	brne cm_freq 
	ldi r25, 1
cm_freq:
	sbis portd, 0
	inc r26
	cpi r26, 6 ; if greater than 5 load 1
	brne cm_freq_dec
	ldi r26, 1
cm_freq_dec: 
	sbis portd, 1
	dec r26 
	brne cm_dc ; if less than 1 load 5
	ldi r26, 5 	
cm_dc:
	sbis portd, 4
	add r27, r28
	cpi r27, 95 ; if greater than 90 load 10
	brne cm_dc_dec
	ldi r27, 10
cm_dc_dec:
	sbis portd, 5
	sub r27, r28
	cpi r27, 5 ; if less than 10 load 90
	brne cm_if_done 
	ldi r27, 90
cm_if_done:
	sbis portd, 2 ; if it is pressed exit cm_loop
	rjmp cm_done
	call delay_20ms ; delay should prevent user from reading the button twice
	rjmp cm_loop ; otherwise return to begining
cm_done: 
	mov r1, r2 ; set 'private interrupt flag'
	reti

;-----------------------------------------------------------------------------------------------------------------------------
;?????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????
;In every place when we expect interupts do we have to call fuction, that check in which mode should work?
;???????It is necessary, becouse we have to use reti to be done with interrupt and reti will send us to last.
;We have to check it. If there were option to ignore reti, it would be better.
;We can simply enable interupts after jump to proper mode.?????????????????? 
;?????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????
;ANSWER Miko³aj Krysiak: stos siê wam rozwali!
;-----------------------------------------------------------------------------------------------------------------------------

; Clock system
; Source: Datasheet cap. 11
; As reference clock we can 8Mhz clock
; It changes clk signal for whole microcontroller, so it can be used only in PWM mode. 
; CKSEL[3:0] = 0b0010 (default), but it is diveded by 8
; PWM frequencies: f_PWM=1MHz/(N*256)
; N={1,8,64,256,1024}
; 3.8Hz, 15.3Hz, 61Hz, 488Hz, 3.9kHz
; We can stores availible frequencies as a integers:
; 1=>3.8Hz, 2=>15.3Hz, 3=>61Hz, 4=>488Hz, 5=>3.9kHz
; It is posible to use others prescalers to divide CPU Clk, but we don't use it in this project.

;-----------------------------------------------------------------------------------------------------------------------------

PWM:
; Source: Datasheet cap. 18
; PWM with timers:
; We are using 8bit timer/counter0.
; We are using internal clock system to provide clk signal.
; TCNT0 is a register where counting takes place. 
; We can use fast PWM mode (WGM0[2:0]=0x3)
; than TOP is 0xff and  
; if TCNT0 == OCR0A then output is cleared. 
; OCR0A have to be set as time_on in first cycle and time_off in second. 
; We can take signal from waveform generator -> OC0A = PD6 
	sei
	;enter fast PWM mode:
	ldi r16, 0b10000011 ;COM0A 10 COM0B 00 WGM0[1:0] 11
	out TCCR0A, r16
	;decoding frequency setting 
	call PWMfreq
	;decoding duty cycle setting :
	call PWMduty
PWM_working:

;mode checking:
	cp r1, r2 ; check if interrupt has occured
	brne PWM_working ; if not continue your normal work
	eor r1, r1 ; clear 'private interrupt flag'
	cpi r25, 1  ; if yes check what was changed (jump to proper signal-mode)
	breq PWM
	cpi r25, 2
	breq sine
	cpi r25, 3
	breq triang
	rjmp PWM_working
;-----------------------------------------------------------------------------------------------------------------------------

sine:
	sei
	;code

sine_working:
;mode checking:
	cpi r25, 1 
	breq PWM
	cpi r25, 2
	breq sine
	cpi r25, 3
	breq triang
	rjmp sine_working
;-----------------------------------------------------------------------------------------------------------------------------

triang:
	sei
	;code


triang_working:
;mode checking:
	cpi r25, 1 
	breq PWM
	cpi r25, 2
	breq sine
	cpi r25, 3
	breq triang
	rjmp triang_working
;-----------------------------------------------------------------------------------------------------------------------------
PWMfreq:
	;ldi r16, 0b00000001 ; 0000-obligatory WGMO[2] 0 CS0 [2:0] depends on frequency
	;out TCCR0B, r16
PWMfreq1: ;3.8Hz N=1024
	cpi r26, 1 ;check if selected frequency is mode 1
	brne PWMfreq2 ;if not branch to mod 2
	ldi r16, 0b00000101 ;select prescaler
	out TCCR0B, r16
	ret
PWMfreq2: ;15.3Hz, N=256
	cpi r26, 2 ;check if selected frequency is mode 2
	brne PWMfreq3 ;if not branch to mod 3
	ldi r16, 0b00000100 ;select prescaler
	out TCCR0B, r16
	ret
PWMfreq3: ; 61Hz, N=64
	cpi r26, 3 ;check if selected frequency is mode 3
	brne PWMfreq4 ;if not branch to mod 4
	ldi r16, 0b00000011 ;select prescaler
	out TCCR0B, r16
	ret
PWMfreq4: ; 488Hz, N=8
	cpi r26, 4 ;check if selected frequency is mode 4
	brne PWMfreq5 ;if not branch to mod 5
	ldi r16, 0b00000010 ;select prescaler
	out TCCR0B, r16
	ret
PWMfreq5: ; 3.9kHz, N=1
	ldi r16, 0b00000001 ;select prescaler
	out TCCR0B, r16
	ret
;-----------------------------------------------------------------------------------------------------------------------------
PWMduty:
	;duty cycle can be choosen from following series: 10% to 90% with step of 5%
PWMduty10:	
	cpi r27, 10 ;check if duty cycle equals to 10%
	brne PWMduty15 ; if not go to 15%
	ldi r16, 26 
	out OCR0A, r16
	ret
PWMduty15:	
	cpi r27, 15 ;check if duty cycle equals to 15%
	brne PWMduty20 ; if not go to 20%
	ldi r16, 38 
	out OCR0A, r16
	ret
PWMduty20:	
	cpi r27, 20 ;check if duty cycle equals to 20%
	brne PWMduty25 ; if not go to 25%
	ldi r16, 51 
	out OCR0A, r16
	ret
PWMduty25:	
	cpi r27, 25 ;check if duty cycle equals to 25%
	brne PWMduty30 ; if not go to 30%
	ldi r16, 64 
	out OCR0A, r16
	ret
PWMduty30:	
	cpi r27, 30 ;check if duty cycle equals to 30%
	brne PWMduty35 ; if not go to 35%
	ldi r16, 77 
	out OCR0A, r16
	ret
PWMduty35:	
	cpi r27, 35 ;check if duty cycle equals to 35%
	brne PWMduty40 ; if not go to 40%
	ldi r16, 90 
	out OCR0A, r16
	ret
PWMduty40:	
	cpi r27, 40 ;check if duty cycle equals to 40%
	brne PWMduty45 ; if not go to 45%
	ldi r16, 102 
	out OCR0A, r16
	ret
PWMduty45:	
	cpi r27, 45 ;check if duty cycle equals to 45%
	brne PWMduty50 ; if not go to 50%
	ldi r16, 115 
	out OCR0A, r16
	ret
PWMduty50:	
	cpi r27, 50 ;check if duty cycle equals to 50%
	brne PWMduty55 ; if not go to 55%
	ldi r16, 128 
	out OCR0A, r16
	ret
PWMduty55:	
	cpi r27, 55;check if duty cycle equals to 55%
	brne PWMduty60 ; if not go to 60%
	ldi r16, 141 
	out OCR0A, r16
	ret
PWMduty60:	
	cpi r27, 60 ;check if duty cycle equals to 60%
	brne PWMduty65 ; if not go to 65%
	ldi r16, 154 
	out OCR0A, r16
	ret
PWMduty65:	
	cpi r27, 65 ;check if duty cycle equals to 65%
	brne PWMduty70 ; if not go to 70%
	ldi r16, 166 
	out OCR0A, r16
	ret
PWMduty70:	
	cpi r27, 70 ;check if duty cycle equals to 70%
	brne PWMduty75 ; if not go to 75%
	ldi r16, 179 
	out OCR0A, r16
	ret
PWMduty75:	
	cpi r27, 75 ;check if duty cycle equals to 75%
	brne PWMduty80 ; if not go to 80%
	ldi r16, 192 
	out OCR0A, r16
	ret
PWMduty80:	
	cpi r27, 80 ;check if duty cycle equals to 80%
	brne PWMduty85 ; if not go to 85%
	ldi r16, 205 
	out OCR0A, r16
	ret
PWMduty85:	
	cpi r27, 85 ;check if duty cycle equals to 85%
	brne PWMduty90 ; if not go to 90%
	ldi r16, 218 
	out OCR0A, r16
	ret
PWMduty90:	
	ldi r16, 230
	out OCR0A, r16
	ret
;-----------------------------------------------------------------------------------------------------------------------------





;-----------------------------------------------------------------------------------------------------------------------------
display:
; We need display modulus, but it cannot work in hex - it will be annoying .
; It should be no problem with it - we use "a frequency code", so we can translete into in more human way ;) 
LEDdriver:

;-----------------------------------------------------------------------------------------------------------------------------

delay_1s: ;assumption clock 8MHz
	push r17
	push r18
	push r19
	ldi r17, 255
loop1s1: ldi r18, 255
loop1s2: ldi r19,110
loop1s3: dec r19
	brne loop1s3
	dec r18
	brne loop1s2
	dec r17
	brne loop1s1
	pop r19
	pop r18
	pop r17
	ret

delay_20ms: 
	;1Mhz -> 100*100*2 ~ 20 ms
	; it is not precise
	push r17
	push r18
	
	ldi r17, 100
loop20ms1: ldi r18, 100
loop20ms2: dec r18
	brne loop20ms2
	dec r17
	brne loop20ms1
	
	pop r18
	pop r17
	ret

;-----------------------------------------------------------------------------------------------------------------------------