; Authors: Oskar Herman, Sylwester D¹browski
; Project for Microprocessor thechnics class at AGH University of Krakow
; 
; Description : bla bla bla 



.include "m328PBdef.inc"
.cseg

.org 0x00
	rjmp prog_start
;DEFINITION OF INTERUPTS:

.org 0x32
;7seg decoder:
sgm: .DB 0x3f, 0x06, 0x5b, 0x4f, 0x66, 0x6d, 0x7d, 0x07, 0x7f, 0x6f, 0x77, 0x7c,0x39, 0x5e, 0x79, 0x71
.org 0x100

prog_start:
    ;stack implementation
	ldi r16, high(ramend)
	out sph, r16
	ldi r16, low(ramend)
	out spl, r16
	;We can use portB for 7seg displayer (port D is needed for waveform generator).
	ldi r16, 0xff
	out ddrb, r16
	;we can use portE as keybord input
	ldi r16, 0x00
	out ddre r16
	ldi r16, 0x0f
	out porte, r16 ;pull-up resistors


control_mode:
; Control mode is using 4 buttons from keybord (S1-S4)	
; S1 - enter/exit control mode/
; S2 - choose signal: PWM (display0: P), sine (S) or triangle (|-) 
; S3 - increase frequency (display1-3)
; S4 - increase duty cycle (display1-3)

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