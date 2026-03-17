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

.module system_system

;;.include "sys/audio.h.s"
.include "system.h.s"
.include "common.h.s"
.include "cpctelera.h.s"
.include "sys/render.h.s"

;;
;; Start of _DATA area 
;;
.area _DATA

nInterrupt:: .db 0

;;
;; Start of _CODE area
;; 
.area _CODE



;;-----------------------------------------------------------------
;;
;; set_int_handler
;;
;;  Installs int_handler1 at RST 38h and resets the interrupt counter.
;;  Input:
;;  Output:
;;  Modified: AF, BC, DE, HL
;;
set_int_handler:
	ld hl, #0x38
	ld (hl), #0xc3
	inc hl
	ld (hl), #<int_handler1
	inc hl
	ld (hl), #>int_handler1
	inc hl
	ld (hl), #0xc9
   m_reset_nInterrupt                           ;; reset number of interruption
	ret


;;-----------------------------------------------------------------
;;
;; int_handler1
;;
;;  First interrupt handler in the 6-interrupt cycle. Increments the
;;  interrupt counter and chains to int_handler2.
;;  Input:
;;  Output:
;;  Modified: AF, BC, DE, HL
;;
int_handler1:
   ;;cpctm_setBorder_asm HW_WHITE
   m_inc_nInterrupt                                ;;increment the number of interruption
	ld hl, #int_handler2
 	call cpct_setInterruptHandler_asm	
	ret

;;-----------------------------------------------------------------
;;
;; int_handler2
;;
;;  Second interrupt handler. Scans the keyboard and chains to int_handler3.
;;  Input:
;;  Output:
;;  Modified: AF, BC, DE, HL
;;
int_handler2:
   ;;cpctm_setBorder_asm HW_RED

   m_inc_nInterrupt                                ;;increment the number of interruption

	call cpct_scanKeyboard_if_asm


	ld hl, #int_handler3
   call cpct_setInterruptHandler_asm
	ret

;;-----------------------------------------------------------------
;;
;; int_handler3
;;
;;  Third interrupt handler. Increments the interrupt counter and chains to int_handler4.
;;  Input:
;;  Output:
;;  Modified: AF, BC, DE, HL
;;
int_handler3:
   ;;cpctm_setBorder_asm HW_GREEN

   m_inc_nInterrupt                                ;;increment the number of interruption

	ld hl, #int_handler4
   call cpct_setInterruptHandler_asm
	ret

;;-----------------------------------------------------------------
;;
;; int_handler4
;;
;;  Fourth interrupt handler. Increments the interrupt counter and chains to int_handler5.
;;  Input:
;;  Output:
;;  Modified: AF, BC, DE, HL
;;
int_handler4:
   ;;cpctm_setBorder_asm HW_BLUE

   m_inc_nInterrupt                                ;;increment the number of interruption

	ld hl, #int_handler5
   call cpct_setInterruptHandler_asm
	ret

;;-----------------------------------------------------------------
;;
;; int_handler5
;;
;;  Fifth interrupt handler. Placeholder for music playback (currently disabled).
;;  Chains to int_handler6.
;;  Input:
;;  Output:
;;  Modified: AF, BC, DE, HL
;;
int_handler5:
   ;;cpctm_setBorder_asm HW_ORANGE

   m_inc_nInterrupt

;;  ld a, (music_switch)
;;  or a
;;  jr z, int_handler5_exit
;;  exx
;;  ex af', af  
;;  push af
;;  push bc
;;  push de
;;  push hl
;;  call PLY_AKG_PLAY
;;  pop hl
;;  pop de
;;  pop bc
;;  pop af
;;  ex af', af  
;;  exx
int_handler5_exit:
	ld hl, #int_handler6
   call cpct_setInterruptHandler_asm
	ret

;;-----------------------------------------------------------------
;;
;; int_handler6
;;
;;  Sixth and final interrupt handler. Resets the interrupt counter
;;  and wraps the cycle back to int_handler1.
;;  Input:
;;  Output:
;;  Modified: AF, BC, DE, HL
;;
int_handler6:
   ;;cpctm_setBorder_asm HW_PURPLE

   m_reset_nInterrupt

	ld hl, #int_handler1
   call cpct_setInterruptHandler_asm
	ret



;;-----------------------------------------------------------------
;;
;; sys_system_disable_firmware
;;
;;  Disables the CPC firmware and installs the custom 6-interrupt
;;  handler chain (int_handler1..6). Must be called once at startup
;;  before any game code runs.
;;  Input:
;;  Output:
;;  Modified: AF, BC, DE, HL
;;
sys_system_disable_firmware::
   call cpct_disableFirmware_asm
   ld hl, #int_handler1
   call cpct_waitVSYNC_asm
   halt
   halt
   call cpct_waitVSYNC_asm
   call cpct_setInterruptHandler_asm
   
   ret


