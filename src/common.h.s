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

.module main


;;===============================================================================
;; SPRITES
;;===============================================================================
.globl _g_palette0
.globl _s_font_0
.globl _s_small_numbers_00
.globl _s_small_numbers_01
.globl _s_small_numbers_02
.globl _s_small_numbers_03
.globl _s_small_numbers_04
.globl _s_small_numbers_05
.globl _s_small_numbers_06
.globl _s_small_numbers_07
.globl _s_small_numbers_08
.globl _s_small_numbers_09

.globl transparency_table

;;===============================================================================
;; PUBLIC VARIBLES
;;===============================================================================



;;===============================================================================
;; CPCTELERA FUNCTIONS
;;===============================================================================
.globl cpct_disableFirmware_asm
.globl cpct_getScreenPtr_asm
.globl cpct_drawSprite_asm
.globl cpct_setVideoMode_asm
.globl cpct_setPalette_asm
.globl cpct_scanKeyboard_if_asm
.globl cpct_isKeyPressed_asm
.globl cpct_waitHalts_asm
.globl cpct_drawSolidBox_asm
.globl cpct_setSeed_mxor_asm
.globl cpct_isAnyKeyPressed_asm
.globl cpct_setInterruptHandler_asm
.globl cpct_waitVSYNC_asm
.globl _cpct_keyboardStatusBuffer
.globl cpct_waitVSYNCStart_asm
.globl cpct_getScreenToSprite_asm
.globl cpct_drawSpriteMaskedAlignedTable_asm
.globl cpct_pens2pixelPatternPairM0_asm
.globl sys_render_drawSpriteMaskedAlignedColorizeM0_asm
.globl cpct_getRandom_mxor_u8_asm

;;===============================================================================
;; DEFINED CONSTANTS
;;===============================================================================

null_ptr = 0x0000

;; game status
g_status_fight              = 0x00
g_status_dead               = 0xff


;;tipos de componentes
c_cmp_invalid = 0x00    ;; Type invalid
c_cmp_render = 0x01     ;;entidad renderizable
c_cmp_movable = 0x02    ;;entidad que se puede mover
c_cmp_input = 0x04      ;;entidad controlable por input  
c_cmp_ia = 0x08         ;;entidad controlable con ia
c_cmp_animated = 0x10   ;;entidad animada
c_cmp_collider = 0x20   ;;entidad que puede colisionar
c_cmp_default = c_cmp_render | c_cmp_movable | c_cmp_collider  ;;componente por defecto

x_cmps = 0


;; Keyboard constants
BUFFER_SIZE = 10
ZERO_KEYS_ACTIVATED = #0xFF

;; Score constants
SCORE_NUM_BYTES = 4

;; Sprites sizes
S_SMALL_NUMBERS_WIDTH = 2
S_SMALL_NUMBERS_HEIGHT = 5



;; Font constants
FONT_WIDTH = 2
FONT_HEIGHT = 9



;;===============================================================================
;; DEFINED MACROS
;;===============================================================================
.mdelete BeginStruct
.macro BeginStruct struct
    struct'_offset = 0
.endm

.mdelete Field
.macro Field struct, field, size
    struct'_'field = struct'_offset
    struct'_offset = struct'_offset + size
.endm

.mdelete EndStruct
.macro EndStruct struct
    sizeof_'struct = struct'_offset
.endm

.mdelete ld__hl__hl_with_a
.macro ld__hl__hl_with_a
    ld a,(hl)
    inc hl
    ld h,(hl)
    ld l,a
.endm

.mdelete test_hl_0
.macro test_hl_0
    ld a, l
    or h
.endm

.mdelete m_msg_w_background
.macro m_msg_w_background bk
    ld h, #(bk)                         ;;
    ld l, #(bk)                         ;;
    call cpct_px2byteM0_asm             ;;
    ex af, af'                          ;;
    ld a, l                             ;;
    ex af, af'                          ;;
.endm
