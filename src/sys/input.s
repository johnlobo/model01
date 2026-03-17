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
.include "sys/util.h.s"
.include "sys/array.h.s"
.include "man/entity.h.s"

;;
;; Start of _DATA area 
;;  SDCC requires at least _DATA and _CODE areas to be declared, but you may use
;;  any one of them for any purpose. Usually, compiler puts _DATA area contents
;;  right after _CODE area contents.
;;
.area _DATA



sys_input_key_actions::
    .dw Key_O,      sys_input_selected_left
    .dw Key_P,      sys_input_selected_right
    ;;.dw Key_D,      sys_input_show_deck
    .dw Key_Space,  sys_input_action
    ;;.dw Key_Q,      sys_input_add_card
    ;;.dw Key_A,      sys_input_remove_card
    ;;.dw Key_Esc,    _score_cancel_entry
    ;;.dw Joy0_Left,  _score_move_left
    ;;.dw Joy0_Right, _score_move_right
    ;;.dw Joy0_Up,    _score_move_up
    ;;.dw Joy0_Down,  _score_move_down
    ;;.dw Joy0_Fire1, _score_fire
    .dw 0

jump_boost_left:: .db 0     ;; boost frames remaining (counts down while Space held)

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
;; Generic
;;
;;-----------------------------------------------------------------


JUMP_SPEED_MIN    = -6  ;; speed on tap (1 frame)
JUMP_SPEED_MAX    = -12 ;; maximum boosted speed
JUMP_BOOST_FRAMES = 6   ;; how many boost frames a full hold gives

;;-----------------------------------------------------------------
;;
;; sys_input_action
;;
;;  Variable-height jump with a fixed boost window.
;;  - On ground: starts jump at JUMP_SPEED_MIN, arms boost counter.
;;  - In air, rising, counter > 0: decrements speed_y by 1 each frame
;;    the button is held and consumes one boost frame. Capped at
;;    JUMP_SPEED_MAX. A tap uses 0-1 boost frames (small hop); a
;;    full hold uses all JUMP_BOOST_FRAMES (max jump). Once the
;;    counter is exhausted the player cannot boost further even if
;;    Space is still held.
;;  - In air but falling, counter zero, or at max speed: does nothing.
;;  Input:  IX = player entity
;;  Output:
;;  Modified: AF
;;
sys_input_action::
    ld a, e_on_air(ix)
    or a
    jr nz, sia_boost            ;; airborne: try to boost

    ;; On ground: start jump at minimum speed and arm boost counter
    ld e_speed_y(ix), #JUMP_SPEED_MIN
    ld e_on_air(ix), #1
    ld a, #JUMP_BOOST_FRAMES
    ld (jump_boost_left), a
    ret

sia_boost:
    ;; Boost only while still rising (speed_y negative = bit 7 set)
    ld a, e_speed_y(ix)
    bit 7, a
    ret z                       ;; falling or stopped: no boost

    ;; Boost only if frames remain in the boost window
    ld a, (jump_boost_left)
    or a
    ret z                       ;; boost window exhausted

    ;; Boost only if cap not yet reached
    ld a, e_speed_y(ix)
    cp #JUMP_SPEED_MAX          ;; carry if A < MAX (more negative than cap)
    ret c
    ret z                       ;; at cap: stop

    dec a                       ;; speed_y -= 1 (faster upward)
    ld e_speed_y(ix), a

    ld a, (jump_boost_left)
    dec a                       ;; consume one boost frame
    ld (jump_boost_left), a
    ret



;;-----------------------------------------------------------------
;;
;; sys_input_selected_left
;;
;;  Sets entity speed to move left and switches to walk-left animation.
;;  Input:  IX = player entity
;;  Output:
;;  Modified: AF, HL
;;
sys_input_selected_left::
    ld e_speed_x(ix), #-2
    ld hl, #monk_walk_left_anim
    ld e_anim(ix), l
    ld e_anim+1(ix), h
    ret

;;-----------------------------------------------------------------
;;
;; sys_input_selected_right
;;
;;  Sets entity speed to move right and switches to walk-right animation.
;;  Input:  IX = player entity
;;  Output:
;;  Modified: AF, HL
;;
sys_input_selected_right::
    ld e_speed_x(ix), #2
    ld hl, #monk_walk_right_anim
    ld e_anim(ix), l
    ld e_anim+1(ix), h
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



;;-----------------------------------------------------------------
;;
;; sys_input_update
;;
;;  Resets the player to idle animation, then scans the key action
;;  table and calls the handler for each key currently pressed.
;;  Input:  IX = active player entity
;;  Output:
;;  Modified: AF, BC, IY
;;
sys_input_update::
    ;; Reset player to idle each frame; key handlers override if a direction is pressed
    ld hl, #monk_idle_anim
    ld e_anim(ix), l
    ld e_anim+1(ix), h
    ld iy, #sys_input_key_actions
    call sys_input_generic_update
    ret