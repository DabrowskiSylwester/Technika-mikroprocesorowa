; Authors: Oskar Herman, Sylwester Dabrowski
; Project for Microprocessor thechnics class at AGH University of Krakow
; Summer semester of 2025
; 
; Description : The program provides a function generator in 3 modes (PWM, sine and triang wave formes) 
;				using PWM and RC filter.  
;				In PWM mode it is possible to choose frequency and duty cycle.
;				In sine and triang mode they are given
;				To control fuctionalities user should use control panel implemented on protoboard 
;				(description in file "Protoboard description.txt")

;-----------------------------------------------------------------------------------------------------------------------------

.include "m328PBdef.inc"
.cseg
;DEFINITION OF INTERUPTS:
.org 0x00
	rjmp prog_start
.org 0x02
	rjmp interrupt



.org 0x60
;sine LUT:
;sineLUT: .DB 127, 217, 254, 217, 127, 37, 1, 37
sineLUT: .DB 127, 152, 176, 198, 217, 233, 244, 252, 254, 252, 244, 233, 217, 198, 176, 152, 127, 102, 78, 56, 37, 21, 10, 2, 1, 2, 10, 21, 37, 56, 78, 102
;.org 0x80
;triangLUT: .DB 1, 17, 33, 49, 65, 80, 96, 112, 128, 144, 160, 176, 192, 207, 223, 239, 255, 239, 223, 207, 192, 176, 160, 144, 128, 112, 96, 80, 65, 49, 33, 17
;-----------------------------------------------------------------------------------------------------------------------------
.org 0x100

prog_start:
    ;stack implementation
	ldi r16, high(ramend)
	out sph, r16
	ldi r16, low(ramend)
	out spl, r16
	;We can use portB for mode state display (port D is needed for waveform generator).
	ldi r16, 0xff
	out ddrb, r16
	; and portE for frequency display
	ldi r16, 0x0f
	out ddre, r16
	out porte, r16 ; default ones (common anode RGB)
	; portC diodes for duty cycle display (last is connected to VCC)
	ldi r16, 0b00111111
	out ddrc, r16
	;special setting for portD
	;PD6 - output of waveform generator
	;keybord:
	;PD2 - INT0 button
	;PD0-PD5 is all we needed
	;PD7 is for 1LED
	ldi r16, 0b11000000
	out ddrd, r16
	ldi r16, 0b00111111 ;pull up resistors
	out portd, r16
	;allocation and default set of control registers:
	ldi r25, 1 ; r25 is a register for type of signal: default 1-PWM, 2-sine, 3-triang 
	ldi r26, 4 ; r26 is a register for frequency (default 488 Hz)
	;ldi r26, 1 ; r26 is a register for frequency (debugging set)
	ldi r27, 50 ; r27 is a register for duty cycle (default 50%)
	ldi r28, 5 ; r28 is a register for step of changing duty cycle 
	ldi r16, 1;
	mov r2, r16;
	eor r1, r1; r1 is a register for interrupt controll (bit0 is set, when iterrupt occured)
	;Interrupt enable (external interrupt from PD2 triggered by raising edge):
	ldi r16, 0b00000001
	out eimsk, r16
	ldi r16, 0b00000010
	sts eicra, r16
	;Clock select Clk_io = 1MHz
	ldi r16, 0b10000000
	sts CLKPR, r16
	ldi r16, 0b00000100
	sts CLKPR, r16
	rjmp PWM ; jump to default signal

;-----------------------------------------------------------------------------------------------------------------------------

interrupt:
	cli ;diseble interrupts
	sbi portb, 0 ;debuging diode
;interrupt_loop:	
	;sbic pind, 3 ; check if button 3 is pressed
	;rjmp interrupt_loop	
	mov r1, r2 ; set 'private interrupt flag'
	call delay_200ms
	reti

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

	;enter fast PWM mode:
	ldi r16, 0b10000011 ;COM0A 10 COM0B 00 WGM0[1:0] 11
	out TCCR0A, r16
	;decoding frequency setting 
	call PWMfreq
	;decoding duty cycle setting :
	call PWMduty
	call LEDdriver
	call display
	call delay_200ms
; Solution of problem with double interrupt:
	ldi r16, 1
	 out EIFR, r16
	sei
PWM_working:
	call display
;mode checking:
	cp r1, r2 ; check if interrupt has occured
	brne PWM_working ; if not continue your normal work
	call control_mode
check:
	cpi r25, 1  ; if yes check what was changed (jump to proper signal-mode)
	breq PWM
	cpi r25, 2
	breq sine
	cpi r25, 3
	breq triang
	
;-----------------------------------------------------------------------------------------------------------------------------

sine:
	; Sine is using Look-up Table, which stores values of PWM duty cycles. 
	; PWM signal is integrated in RC filter, what provide approximate sinusoid.

	call delay_200ms
	ldi r16, 1
	out EIFR, r16
	sei
	ldi r26, 5 ;set PWM frequency to 3.9kHz
	call PWMfreq
	ldi r31, high(2*sineLUT) ;pointer to LUT
	ldi r30, low(2*sineLUT)
	ldi r17, 0 ; pointer offset
sine_working:
;working
	ldi r30, low(2*sineLUT) ;reseting pointer
	add r30, r17 ;offset
	lpm r27, z ; z=r30+r31
	;call PWMduty
	out OCR0A, r27
	call delay_sleep
	inc r17
	cpi r17, 31 ; check if offset stays in range
	brne sine_mode_checking ; if yes continue
	ldi r17, 0 ; if not reset offset
;mode checking:
sine_mode_checking:
	cp r1, r2 ; check if interrupt has occured
	brne sine_working ; if not continue your normal work
	ldi r27, 50; default PWM duty cycle
	call control_mode
	cpi r25, 1  ; if yes check what was changed (jump to proper signal-mode)
	breq PWM
	cpi r25, 2
	breq sine
	cpi r25, 3
	breq triang
;-----------------------------------------------------------------------------------------------------------------------------

triang:
	; triang is using simple integration in RC filter.

	ldi r16, 0b10000011 ;COM0A 10 COM0B 00 WGM0[1:0] 11
	out TCCR0A, r16
	
	ldi r26, 4 ;set PWM freq
	ldi r27, 50;and duty cycle
	call PWMfreq
	call PWMduty
	call LEDdriver
	call display
	call delay_200ms
; Solution of problem with double interrupt:
	ldi r16, 1
	 out EIFR, r16
	sei
triang_working:
	call display
;mode checking:
	cp r1, r2 ; check if interrupt has occured
	brne triang_working ; if not continue your normal work
	call control_mode
check_triang:
	jmp check ; relatice branch out of reach ;(

	
;-----------------------------------------------------------------------------------------------------------------------------

control_mode:
; Control mode is using 6 buttons:
; PD2 - enter/exit control mode
; PD3 - choose signal: PWM (display0: P), sine (S) or triangle (|-) 
; PD0 - increase frequency (display1-3)
; PD1 - decrease frequency (display1-3)
; PD4 - increase duty cycle 
; PD5 - decrease duty cycle [we can use diodes to display current duty cycle and change it 10:5:90]

	cli ;diseble interrupts
	eor r1, r1
	
cm_loop:
	
	call display ; display current settings
	call LEDdriver
	; check if button is pressed
cm_signal:
	sbis pind, 3 
	inc r25
	cpi r25, 4 ; if greater than 3 load 1 
	brne cm_freq 
	ldi r25, 1
cm_freq:
	sbis pind, 0
	inc r26
	cpi r26, 6 ; if greater than 5 load 1
	brne cm_freq_dec
	ldi r26, 1
cm_freq_dec: 
	sbis pind, 1
	dec r26 
	cpi r26, 0
	brne cm_dc ; if less than 1 load 5
	ldi r26, 5 	
cm_dc:
	sbis pind, 4
	add r27, r28
	cpi r27, 95 ; if greater than 90 load 10
	brne cm_dc_dec
	ldi r27, 10
cm_dc_dec:
	sbis pind, 5
	sub r27, r28
	cpi r27, 5 ; if less than 10 load 90
	brne cm_if_done 
	ldi r27, 90
cm_if_done:
	sbis pind, 2 ; if it is pressed exit cm_loop
	rjmp cm_done
	call delay_200ms ; delay should prevent user from reading the button twice
	rjmp cm_loop ; otherwise return to begining
cm_done: 
	call display
	call LEDdriver 
	;call delay_200ms
	cbi portb, 0
	ret
;-----------------------------------------------------------------------------------------------------------------------------


PWMfreq:
	push r16
	push r26
	;ldi r16, 0b00000001 ; 0000-obligatory WGMO[2] 0 CS0 [2:0] depends on frequency
	;out TCCR0B, r16
PWMfreq1: ;3.8Hz N=1024
	cpi r26, 1 ;check if selected frequency is mode 1
	brne PWMfreq2 ;if not branch to mod 2
	ldi r16, 0b00000101 ;select prescaler
	out TCCR0B, r16
	rjmp PWMfreqdone
PWMfreq2: ;15.3Hz, N=256
	cpi r26, 2 ;check if selected frequency is mode 2
	brne PWMfreq3 ;if not branch to mod 3
	ldi r16, 0b00000100 ;select prescaler
	out TCCR0B, r16
	rjmp PWMfreqdone
PWMfreq3: ; 61Hz, N=64
	cpi r26, 3 ;check if selected frequency is mode 3
	brne PWMfreq4 ;if not branch to mod 4
	ldi r16, 0b00000011 ;select prescaler
	out TCCR0B, r16
	rjmp PWMfreqdone
PWMfreq4: ; 488Hz, N=8
	cpi r26, 4 ;check if selected frequency is mode 4
	brne PWMfreq5 ;if not branch to mod 5
	ldi r16, 0b00000010 ;select prescaler
	out TCCR0B, r16
	rjmp PWMfreqdone
PWMfreq5: ; 3.9kHz, N=1
	ldi r16, 0b00000001 ;select prescaler
	out TCCR0B, r16
PWMfreqdone:
	pop r26
	pop r16
	ret
;-----------------------------------------------------------------------------------------------------------------------------
PWMduty:
	push r16
	push r27
	;duty cycle can be choosen from following series: 10% to 90% with step of 5%
PWMduty10:	
	cpi r27, 10 ;check if duty cycle equals to 10%
	brne PWMduty15 ; if not go to 15%
	ldi r16, 26 
	out OCR0A, r16
	rjmp PWMdutydone
PWMduty15:	
	cpi r27, 15 ;check if duty cycle equals to 15%
	brne PWMduty20 ; if not go to 20%
	ldi r16, 38 
	out OCR0A, r16
	rjmp PWMdutydone
PWMduty20:	
	cpi r27, 20 ;check if duty cycle equals to 20%
	brne PWMduty25 ; if not go to 25%
	ldi r16, 51 
	out OCR0A, r16
	rjmp PWMdutydone
PWMduty25:	
	cpi r27, 25 ;check if duty cycle equals to 25%
	brne PWMduty30 ; if not go to 30%
	ldi r16, 64 
	out OCR0A, r16
	rjmp PWMdutydone
PWMduty30:	
	cpi r27, 30 ;check if duty cycle equals to 30%
	brne PWMduty35 ; if not go to 35%
	ldi r16, 77 
	out OCR0A, r16
	rjmp PWMdutydone
PWMduty35:	
	cpi r27, 35 ;check if duty cycle equals to 35%
	brne PWMduty40 ; if not go to 40%
	ldi r16, 90 
	out OCR0A, r16
	rjmp PWMdutydone
PWMduty40:	
	cpi r27, 40 ;check if duty cycle equals to 40%
	brne PWMduty45 ; if not go to 45%
	ldi r16, 102 
	out OCR0A, r16
	rjmp PWMdutydone
PWMduty45:	
	cpi r27, 45 ;check if duty cycle equals to 45%
	brne PWMduty50 ; if not go to 50%
	ldi r16, 115 
	out OCR0A, r16
	rjmp PWMdutydone
PWMduty50:	
	cpi r27, 50 ;check if duty cycle equals to 50%
	brne PWMduty55 ; if not go to 55%
	ldi r16, 128 
	out OCR0A, r16
	rjmp PWMdutydone
PWMduty55:	
	cpi r27, 55;check if duty cycle equals to 55%
	brne PWMduty60 ; if not go to 60%
	ldi r16, 141 
	out OCR0A, r16
	rjmp PWMdutydone
PWMduty60:	
	cpi r27, 60 ;check if duty cycle equals to 60%
	brne PWMduty65 ; if not go to 65%
	ldi r16, 154 
	out OCR0A, r16
	rjmp PWMdutydone
PWMduty65:	
	cpi r27, 65 ;check if duty cycle equals to 65%
	brne PWMduty70 ; if not go to 70%
	ldi r16, 166 
	out OCR0A, r16
	rjmp PWMdutydone
PWMduty70:	
	cpi r27, 70 ;check if duty cycle equals to 70%
	brne PWMduty75 ; if not go to 75%
	ldi r16, 179 
	out OCR0A, r16
	rjmp PWMdutydone
PWMduty75:	
	cpi r27, 75 ;check if duty cycle equals to 75%
	brne PWMduty80 ; if not go to 80%
	ldi r16, 192 
	out OCR0A, r16
	rjmp PWMdutydone
PWMduty80:	
	cpi r27, 80 ;check if duty cycle equals to 80%
	brne PWMduty85 ; if not go to 85%
	ldi r16, 205 
	out OCR0A, r16
	rjmp PWMdutydone
PWMduty85:	
	cpi r27, 85 ;check if duty cycle equals to 85%
	brne PWMduty90 ; if not go to 90%
	ldi r16, 218 
	out OCR0A, r16
	rjmp PWMdutydone
PWMduty90:	
	ldi r16, 230
	out OCR0A, r16
	
PWMdutydone:
	pop r27
	pop r16
	ret
;-----------------------------------------------------------------------------------------------------------------------------





;-----------------------------------------------------------------------------------------------------------------------------
display:
; We need display modulus, but it cannot work in hex - it will be annoying .
; It should be no problem with it - we use "a frequency code", so we can translete into in more human way ;) 
	push r25
	;reseting
	cbi portb, 1 
	cbi portb, 2
	cbi portb, 3
	cpi r25, 1 ;check if PWM
	brne display_sine
	sbi portb, 1
	rjmp display_done
display_sine:
	cpi r25, 2 ;check if sine
	brne display_triang
	sbi portb, 2
	rjmp display_done
display_triang:
	sbi portb, 3 ;if all fails, triang
display_done:	
	
	pop r25
	ret
;-----------------------------------------------------------------------------------------------------------------------------
LEDdriver:
	push r27
	push r26
	push r25
	push r16
	cbi portd, 7
	ldi r16, 0x00
	out portc, r16
	cpi r25, 1
	brne LED_other_signal
;following part testes how many diodes should be turn on
	subi r27, 10
	sbi portd, 7 ;10% 
	subi r27, 15 ;if duty cycle is less than 25%, than result is negative
	brmi LED_freq1
	sbi portc, 0
	subi r27, 15 ;if duty cycle is less than 40%, than result is negative 
	brmi LED_freq1
	sbi portc, 1
	subi r27, 10 ;if duty cycle is less than 50%, than result is negative 
	brmi LED_freq1
	sbi portc, 2
	subi r27, 10 ;if duty cycle is less than 60%, than result is negative 
	brmi LED_freq1
	sbi portc, 3
	subi r27, 15 ;if duty cycle is less than 75%, than result is negative 
	brmi LED_freq1
	sbi portc, 4
	subi r27, 15 ;if duty cycle is less than 90%, than result is negative 
	brmi LED_freq1
	sbi portc, 5
	
LED_freq1:
	cpi r26, 1 ;check if frequency is 1
	brne LED_freq2 ; 
	ldi r16, 0b00000110 ;red only 
	out porte, r16
	rjmp LED_done
LED_freq2:
	cpi r26, 2 ;check if frequency is 2
	brne LED_freq3 ; 
	ldi r16, 0b00000101 ;green only 
	out porte, r16
	rjmp LED_done
LED_freq3:
	cpi r26, 3 ;check if frequency is 3
	brne LED_freq4 ; 
	ldi r16, 0b00000011 ;blue only 
	out porte, r16
	rjmp LED_done
LED_freq4:
	cpi r26, 4 ;check if frequency is 4
	brne LED_freq5 ; 
	ldi r16, 0b00000001 ;blue+green
	out porte, r16
	rjmp LED_done
LED_freq5:
	cpi r26, 5 ;check if frequency is 5
	brne LED_freq5 ; 
	ldi r16, 0b00000010 ;blue+red
	out porte, r16
	rjmp LED_done
LED_other_signal:
	ldi r16, 0b11000000 ; we have to prevent reseting (PC6)
	out portc, r16
	cbi portd, 7 ;Led10%
	ldi r16, 0
	out porte, r16 ; white
	rjmp LED_done
LED_done:
	pop r16
	pop r25
	pop r26
	pop r27
	ret

;-----------------------------------------------------------------------------------------------------------------------------

delay_1s: ;assumption clock 1MHz
	push r17
	push r18
	push r19
	ldi r17, 255
loop1s1: ldi r18, 255
loop1s2: ldi r19,15
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
delay_sleep_triang: 
	
	push r17
	ldi r17, 5 ;120Hz sine
	;ldi r17, 219 ;48Hz sine
loop20mstr1: 
	dec r17
	brne loop20mstr1
	pop r17
	ret

delay_sleep: 
	
	push r17
	ldi r17, 81 ;120Hz sine
	;ldi r17, 219 ;48Hz sine
loop20ms1: 
	dec r17
	brne loop20ms1
	pop r17
	ret
;-----------------------------------------------------------------------------------------------------------------------------
delay_200ms: ;assumption clock 1MHz
	push r17
	push r18
	
	ldi r17, 255
loop200ms1: ldi r18, 255
loop200ms2: dec r18
	brne loop200ms2
	dec r17
	brne loop200ms1
	
	
	pop r18
	pop r17
	ret

;-----------------------------------------------------------------------------------------------------------------------------