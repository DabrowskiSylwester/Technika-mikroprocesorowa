; Authors: Oskar Herman, Sylwester D¹browski
; Project for Microprocessor thechnics class at AGH University of Krakow
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
;7seg decoder:
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
	ldi r25, 1 ; r25 is a register for type of signal: 1-PWM, 2-sine, 3-triang 
	ldi r26, 8 ; r26 is a register for frequency (default 500Hz)
	ldi r27, 50 ; r27 is a register for duty cycle (default 50%)
	ldi r28, 10 ; r28 is a register for step of changing duty cycle 
	;Interrupt enable (external interrupt from PD2 triggered by raising edge):
	ldi r16, (1<<int0)
	out eimsk, r20
	ldi r16, (1<<isc01)|(1<<isc00)
	sts eicra, r20
	sei
waiting: rjmp waiting ;waiting for interupt that opens control mode

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
	cpi r26, 11 ; if greater than 10 load 1
	brne cm_freq_dec
	ldi r26, 1
cm_freq_dec: 
	sbis portd, 1
	dec r26 
	brne cm_dc ; if less than 1 load 10
	ldi r26, 10 	
cm_dc:
	sbis portd, 4
	add r27, r28
	cpi r27, 100 ; if greater than 100 load 10
	brne cm_dc_dec
	ldi r27, 10
cm_dc_dec:
	sbis portd, 5
	sub r27, r28
	brne cm_if_done ; if less than 10 load 90
	ldi r27, 90
cm_if_done:
	sbis portd, 2 ; if it is pressed exit cm_loop
	rjmp cm_done
	rjmp cm_loop
cm_done:
	sei
	reti

;-----------------------------------------------------------------------------------------------------------------------------
;In every place when we expect interupts we have to call fuction, that check in which mode should work.
;???????It is necessary, becouse we have to use reti to be done with interrupt and reti will send us to last.
;We have to check it. If there were option to ignore reti, it would be better.
;We can simply enable interupts after jump to proper mode.?????????????????? 

;-----------------------------------------------------------------------------------------------------------------------------

clk_source:
; As reference clock we can use128 kHz Internal Oscillator
; CKSEL[3:0] = 0b0011 
; PWM frequencies: f_PWM=128kHz/(N*256)
; N={1,8,64,256,1024}
; 0.5Hz (N=1024), ~2Hz, 8Hz, 62.5Hz, 500Hz
; Or 8Mhz clock
; CKSEL[3:0] = 0b0010 
; 30.5Hz, 122Hz, 488Hz, 3.9KhZ, 31kHz
; We can stores availible frequencies as a integers:
; 1=>0.5Hz, 2=>2Hz, 3=>8Hz, 4=>30.5Hz 5=>62.5Hz, 
; 6=>122Hz, 7=>488Hz, 8=>500Hz, 9=>3.9kHz 10=>31kHz

;-----------------------------------------------------------------------------------------------------------------------------

PWM:
; PWM with timers:
; We are using 8bit timer/counter0.
; We are using internal clock system to provide clk signal.
; TCNT0 is a register where counting takes place. 
; We can use fast PWM mode (WGM0[2:0]=0x3) 
; If TCNT0 == OCR0A then output is cleared. 
; OCR0A have to be set as time_on in first cycle and time_off in second. 
; We can take signal from waveform generator -> OC0A = PD6 

;-----------------------------------------------------------------------------------------------------------------------------

sine:

;-----------------------------------------------------------------------------------------------------------------------------

triang:

;-----------------------------------------------------------------------------------------------------------------------------

delay_1s: 
	push r17
	push r18
	push r19
	ldi r17, 255
loop1s1: ldi r18, 255
loop1s2: ldi r19,90
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

delay_8ms: 
	push r17
	push r18
	push r19
	ldi r17, 255
loop8ms1: ldi r18, 255
loop8ms2: ldi r19,251
loop8ms3: dec r19
	brne loop8ms3
	dec r18
	brne loop8ms2
	dec r17
	brne loop8ms1
	pop r19
	pop r18
	pop r17
	ret

;-----------------------------------------------------------------------------------------------------------------------------