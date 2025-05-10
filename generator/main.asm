; Authors: Oskar Herman, Sylwester D¹browski
; Project for Microprocessor thechnics class at AGH University of Krakow
; 
; Description : bla bla bla 



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
	out ddrd r16
	ldi r16, 0b00111111 ;pull up resistors
	out portd, r16
	;Interrupt enable (external interrupt from S1 triggered by raising edge):
	ldi r16, (1<<int0)
	out eimsk, r20
	ldi r16, (1<<isc01)|(1<<isc00)
	sts eicra, r20
	sei
working: rjmp working


control_mode:
; Control mode is using 6 buttons:
; PD2 - enter/exit control mode
; PD3 - choose signal: PWM (display0: P), sine (S) or triangle (|-) 
; PD0 - increase frequency (display1-3)
; PD1 - decrease frequency (display1-3)
; PD4 - increase duty cycle (display2-3)
; PD5 - decrease duty cycle (display2-3) [we can use diodes to display current duty cycle and change it 10:10:90]

	cli
cm_loop:
	
	rjmp cm_loop
	sei
	reti
clk_source:
; As reference clock we can use128 kHz Internal Oscillator
; CKSEL[3:0] = 0b0011 
; PWM frequencies: f_PWM=128kHz/(N*256)
; 0.5Hz (N=1024), ~2Hz, 8Hz, 62.5Hz, 500Hz
; Or 8Mhz clock
; CKSEL[3:0] = 0b0010 
; 30.5Hz, 122Hz, 488Hz, 3.9KhZ, 31kHz

PWM:
; PWM with timers:
; We are using 8bit timer/counter0.
; We are using internal clock system to provide clk signal.
; TCNT0 is a register where counting takes place. 
; We can use fast PWM mode (WGM0[2:0]=0x3) 
; If TCNT0 == OCR0A then output is cleared. 
; OCR0A have to be set as time_on in first cycle and time_off in second. 
; We can take signal from waveform generator -> OC0A = PD6 

sine:



triang: