;;-----------------------------LICENSE NOTICE------------------------------------

;;
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

.module input_system

.include "cpctelera.h.s"
.include "../common.h.s"

BUFFER_SIZE = 10
ZERO_KEYS_ACTIVATED = 0xFF


;;
;; Start of _DATA area 
;;  SDCC requires at least _DATA and _CODE areas to be declared, but you may use
;;  any one of them for any purpose. Usually, compiler puts _DATA area contents
;;  right after _CODE area contents.
;;
.area _DATA



;;
;; Start of _CODE area
;; 
.area _CODE


;;-----------------------------------------------------------------
;;
;; sys_input_clean_buffer
;;
;;  Waits until de key buffer is clean
;;  Input: 
;;  Output:
;;  Modified: 
;;
sys_input_clean_buffer::
    call cpct_isAnyKeyPressed_asm
    jr nz, sys_input_clean_buffer
    ret

;;-----------------------------------------------------------------
;;
;; sys_input_wait4anykey
;;
;;   Reads input and wait for any key press
;;  Input: 
;;  Output: hl: number of loops
;;  Modified: 
;;
sys_input_wait4anykey::
    ld hl, #0
_siw_loop:
    push hl
    call cpct_isAnyKeyPressed_asm
    or a
    pop hl
    inc hl
    jr z, _siw_loop
    ret

;;-----------------------------------------------------------------
;;
;; sys_input_getKeyPressed
;;
;;  Returns the first key currently pressed in the keyboard buffer.
;;  Routine taken from Promotion by Bite Studios.
;;  Input:
;;  Output: HL = key code if pressed, HL = 0 if no key pressed
;;  Modified: AF, HL
;;
sys_input_getKeyPressed::
    ld hl, #_cpct_keyboardStatusBuffer
    xor a                           ;; A = 0

_kp_loop:
    cp #BUFFER_SIZE
    jr z, _kp_endLoop               ;; Check counter value. End if its 0
    ld (_size_counter), a

    ld a, (hl)                      ;; Load byte from the buffer
    xor #ZERO_KEYS_ACTIVATED        ;; Inverts bytes
    jr z, _no_key_detected
        ld h, a                     ;; H is the mask
        ld a, (_size_counter)
        ld l, a                     ;; L is the offset
        ; ld (_current_key_pressed), hl
        ret
_no_key_detected:
    inc hl
_size_counter = .+1
    ld a, #0x00                     ;; AUTOMODIFIABLE, A = counter
    inc a
    jr _kp_loop
_kp_endLoop:
    ld hl, #0x00                    ;; Return 0 if no key is pressed
    ld a, #0
    ld (_key_released), a
    ret

_key_released:
    .db #0

;;-----------------------------------------------------------------
;;
;; sys_input_waitKeyPressed
;;
;;  Blocks until a key is pressed, then returns its code.
;;  WARNING: This is a blocking call. Routine taken from Promotion by Bite Studios.
;;  Input:
;;  Output: HL = key code of the key pressed
;;  Modified: AF, HL
;;
sys_input_waitKeyPressed::
    call sys_input_getKeyPressed
    ld a, (_key_released)
    or a
    jr nz, sys_input_waitKeyPressed
    xor a
    or h
    or l
    jr z, sys_input_waitKeyPressed
    ld a, #1
    ld (_key_released), a
    ret


;;-----------------------------------------------------------------
;;
;; sys_input_init
;;
;;   Initializes input
;;  Input: 
;;  Output:
;;  Modified: 
;;
sys_input_init::
    ret

;;-----------------------------------------------------------------
;;
;;  sys_input_generic_update
;;
;;  Initializes input
;;  Input:  iy: array of key, actions to check
;;          ix: pointer to the struct to be used in the actions
;;  Output:
;;  Modified: iy, bc
;;
sys_input_generic_update::
    jr first_key
keys_loop:
    ld bc, #4
    add iy, bc
first_key:
    ld l, 0(iy)                     ;; Lower part of the key pointer
    ld h, 1(iy)                     ;; Lower part of the key pointer
    ;; Check if key is null
    ld a, l
    or h
    ret z                           ;; Return if key is null
    ;; Check if key is pressed
    call cpct_isKeyPressed_asm      ;;
    jr z, keys_loop
    ;; Key pressed execute action
    ld hl, #keys_loop               ;;
    push hl                         ;; return addres from executed function
    ld l, 2(iy)                     ;;
    ld h, 3(iy)                     ;; retrieve function address    
    jp (hl)                         ;; jump to function
