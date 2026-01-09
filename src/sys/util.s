;;-----------------------------LICENSE NOTICE------------------------------------
;;  This program is free software: you can redistribute it and/or modify
;;  it under the terms of the GNU Lesser General Public License as published by
;;  the Free Software Foundation, either version 3 of the License, or
;;  (at your option) any later version.
;;
;;  This program is distributed in the hope that it will be useful,
;;  but WITHOUT ANY WARRANTY; without even the implied warranty of
;;  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;;  GNU Lesser General Public License for more details.
;;
;;  You should have received a copy of the GNU Lesser General Public License
;;  along with this program.  If not, see <http://www.gnu.org/licenses/>.
;;-------------------------------------------------------------------------------

.module sys_util

.include "cpctelera.h.s"
.include "sys/util.h.s"
.include "../common.h.s"
;;
;; Start of _DATA area 
;;  SDCC requires at least _DATA and _CODE areas to be declared, but you may use
;;  any one of them for any purpose. Usually, compiler puts _DATA area contents
;;  right after _CODE area contents.
;;
.area _DATA


string_buffer:: .asciz "          "
;; Registros
H_CHARACTERS = 01
H_ADJUST     = 02
V_ADJUST     = 05
V_LINES      = 06
V_SYNC       = 07


;;
;; Start of _CODE area
;; 
.area _CODE

;;-----------------------------------------------------------------;; 
;;  sys_util_h_times_e
;;
;; Inputs:
;;   H and E
;; Outputs:
;;   HL is the product
;;   D is 0
;;   A,E,B,C are preserved
;; 36 bytes
;; min: 190cc
;; max: 242cc
;; avg: 216cc
;; Credits:
;;  Z80Heaven (http://z80-heaven.wikidot.com/advanced-math#toc9)

sys_util_h_times_e::
  ld d,#0
  ld l,d
  sla h 
  jr nc,.+3 
  ld l,e
  add hl,hl 
  jr nc,.+3 
  add hl,de
  add hl,hl 
  jr nc,.+3 
  add hl,de
  add hl,hl 
  jr nc,.+3 
  add hl,de
  add hl,hl 
  jr nc,.+3 
  add hl,de
  add hl,hl 
  jr nc,.+3 
  add hl,de
  add hl,hl 
  jr nc,.+3 
  add hl,de
  add hl,hl 
  ret nc 
  add hl,de
  ret

;;-----------------------------------------------------------------;; 
;;  sys_util_h_times_e
;;
;;Inputs:
;;     HL is the numerator
;;     C is the denominator
;;Outputs:
;;     A is the remainder
;;     B is 0
;;     C is not changed
;;     DE is not changed
;;     HL is the quotient
;;
sys_util_hl_div_c::
       ld b,#16
       xor a
         add hl,hl
         rla
         cp c
         jr c,.+4
           inc l
           sub c
         djnz .-7
       ret

;;-----------------------------------------------------------------
;;
;; sys_util_BCD_GetEnd
;;
;;  
;;  Input:  b: number of bytes of the bcd number
;;          de: source for the first bcd bnumber
;;          hl: source for the second bcd number
;;  Output: 
;;  Destroyed: af, bc,de, hl
;;
;;  Chibi Akumas BCD code (https://www.chibiakumas.com/z80/advanced.php#LessonA1)
;;
sys_util_BCD_GetEnd::
;Some of our commands need to start from the most significant byte
;This will shift HL and DE along b bytes
	push bc
	ld c,b	;We want to add BC, but we need to add one less than the number of bytes
	dec c
	ld b,#0
	add hl,bc
	ex de, hl	;We've done HL, but we also want to do DE
	add hl,bc
	ex de, hl
	pop bc
	ret

;;-----------------------------------------------------------------
;;
;; BCD_Add
;;
;;   Add two BCD numbers
;;  Input:  hl: Number to add to de
;;          de: Number to store the sum 
;;  Output: 
;;  Destroyed: af, bc,de, hl
;;
;;  Chibi Akumas BCD code (https://www.chibiakumas.com/z80/advanced.php#LessonA1)
;;
sys_util_BCD_Add::
    or a
BCD_Add_Again:
    ld a, (de)
    adc (hl)
    daa
    ld (de), a
    inc de
    inc hl
    djnz BCD_Add_Again
    ret
  
;;-----------------------------------------------------------------
;;
;; sys_util_BCD_Compare
;;
;;  Compare two BCD numbers
;;  Input:  hl: BCD Number 1
;;          de: BCD Number 2
;;  Output: 
;;  Destroyed: af, bc,de, hl
;;
;;  Chibi Akumas BCD code (https://www.chibiakumas.com/z80/advanced.php#LessonA1)
;;
sys_util_BCD_Compare::
  ld b, #SCORE_NUM_BYTES
  call sys_util_BCD_GetEnd
BCD_cp_direct:
  ld a, (de)
  cp (hl)
  ret c
  ret nz
  dec de
  dec hl
  djnz BCD_cp_direct
  or a                    ;; Clear carry
  ret

;;-----------------------------------------------------------------
;;
;; sys_util_get_random_number
;;
;;  Returns a random number between 0 and <end>
;;  Input:  a: <end>
;;  Output: a: random number
;;  Destroyed: af, bc,de, hl

sys_util_get_random_number::
  inc a                               ;; Increment a to make the modulus calculation work
  ld (#random_max_number), a
  call cpct_getRandom_mxor_u8_asm
  ld a, l                             ;; Calculates a pseudo modulus of max number
  ld h,#0                             ;; Load hl with the random number
random_max_number = .+1
  ld c, #0                            ;; Load c with the max number
  ld b, #0
_random_mod_loop:
  or a                                ;; reset carry
  sbc hl,bc                           ;; hl = hl - bc
  jp p, _random_mod_loop              ;; Jump back if hl > 0
  add hl,bc                           ;; Adds max number to hl back to get back to positive values
  ld a,l                              ;; loads the normalized random number in a
ret

;;-----------------------------------------------------------------
;;
;; sys_util_delay
;;
;;  Waits a determined number of frames 
;;  Input:  b: number of frames
;;  Output: 
;;  Destroyed: af, bc
;;
sys_util_delay::
  push bc
  call cpct_waitVSYNCStart_asm
  pop bc
  djnz sys_util_delay
  ret

;;-----------------------------------------------------------------
;;
;; CRTC_V_auto
;;
;;  
;;  Input:  
;;  Output: 
;;  Destroyed: 
;;
CRTC_V_auto:
	ld bc, #0xBC00 + V_LINES
	out (c), c
	ld hl, #0xBD00
	add hl, de
	ld b, h
	ld c, l
	out (c), c
	ret

;;-----------------------------------------------------------------
;;
;; CRTC_H_auto
;;
;;  
;;  Input:  
;;  Output: 
;;  Destroyed: 
;;
CRTC_H_auto:
	ld bc, #0xBC00 + H_ADJUST
	out (c), c
	ld hl, #0xBD00
	add hl, de
	ld b, h
	ld c, l
	out (c), c
	ret

;;-----------------------------------------------------------------
;;
;; sys_util_fadeOut
;;
;;  
;;  Input:  
;;  Output: 
;;  Destroyed: 
;;
sys_util_fadeOut::
	ld de, #25
height_out:
    ld a, #12
	call crt_delay
	call CRTC_V_auto
	dec e
	jp nz, height_out
	call CRTC_V_auto
	ret

;;-----------------------------------------------------------------
;;
;; sys_util_fadeIn
;;
;;  
;;  Input:  
;;  Output: 
;;  Destroyed: 
;;
sys_util_fadeIn::
	ld de, #0
height_in:
    ld a, #12
	call crt_delay 
	call CRTC_V_auto
	inc e
	ld a, e
	cp #26
	jp nz, height_in
	ret

;;-----------------------------------------------------------------
;;
;; sys_util_temblor
;;
;;  
;;  Input:  
;;  Output: 
;;  Destroyed: 
;;
sys_util_temblor::
	ld de, #47
	call CRTC_H_auto
	ld de, #45
    ld a, #9
	call crt_delay
	call CRTC_H_auto
	ld de, #46
    ld a, #9
	call crt_delay 
	call CRTC_H_auto
	ret

;;-----------------------------------------------------------------
;;
;; crt_delay
;;
;;  
;;  Input:  
;;  Output: 
;;  Destroyed: 
;;
crt_delay:
	halt
	dec a
	jr nz, crt_delay
	ret

; Z80 Assembly Routine: Count Set Bits (1s)
;
; Description: Counts the number of '1' bits in an 8-bit binary number.
;
; Input:
;   Register A: The 8-bit number to be analyzed.
;
; Output:
;   Register B: Contains the count of '1's found in the input number.
;
; Affected Registers:
;   A, B, C, F (Flags)

sys_util_count_set_bits::
    XOR B           ; Initialize '1's counter (register B) to zero.
    LD C, #8         ; Initialize bit counter (register C) to 8 (for 8 bits).

BIT_LOOP:
    RLA             ; Rotate Accumulator A left. The Most Significant Bit (MSB)
                    ; moves into the Carry Flag (CF). The previous CF moves into the Least Significant Bit (LSB).
    JR NC, NEXT_BIT ; If Carry Flag is CLEAR (the bit was 0), jump to NEXT_BIT.
    INC B           ; If Carry Flag is SET (the bit was 1), increment the '1's counter.

NEXT_BIT:
    DEC C           ; Decrement the bit counter.
    JR NZ, BIT_LOOP ; If C is not zero, more bits to check, loop again.

    RET             ; Return from the routine. The result is in B.

;;-----------------------------------------------------------------
;;
;; crt_delay
;;
;;  
;;  Input: El valor a modificar está en el registro A
;;  Output: El registro A con su magnitud reducida en 1
;;  Destroyed: 
;;
sys_utiL_reduce_a:
  or a            ; 1. Actualiza las banderas (S y Z) sin cambiar el valor de A.
  ret z           ; 2. Si es CERO (Flag Z=1), no hacemos nada. Saltamos al final.
  jp M, es_neg    ; 3. Si es NEGATIVO (Flag S=1/Minus), saltamos a sumar.
; --- Caso Positivo ---
  dec a           ; Si es positivo (ej: 5), restamos 1 (queda 4).
  ret             ; Retornamos para no ejecutar la parte negativa.
es_neg:
; --- Caso Negativo ---
  inc A           ; Si es negativo (ej: -5), sumamos 1 (queda -4).
                  ; Al sumar 1 a un negativo, reducimos su magnitud.
	ret