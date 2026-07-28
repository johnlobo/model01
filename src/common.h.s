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
.globl cpct_etm_setDrawTilemap4x8_agf_asm
.globl cpct_etm_drawTilemap4x8_agf_asm
.globl cpct_px2byteM0_asm

;;===============================================================================
;; DEFINED CONSTANTS
;;===============================================================================

;;tipos de componentes
c_cmp_invalid = 0x00    ;; Type invalid
c_cmp_render = 0x01     ;;entidad renderizable
c_cmp_movable = 0x02    ;;entidad que se puede mover
c_cmp_input = 0x04      ;;entidad controlable por input  
c_cmp_behavior = 0x08   ;; entity controlled by the behavior bytecode system
c_cmp_ai = c_cmp_behavior ;; backwards-compatible alias for existing games
c_cmp_animated = 0x10   ;;entidad animada
c_cmp_collider = 0x20       ;;entidad que puede colisionar (activo, inicia la comprobacion)
c_cmp_collisionable = 0x40  ;;entidad que puede ser colisionada (pasivo, receptor)
c_cmp_projectile = 0x80     ;;bala: movida en linea recta por sys_shoot_update (sin gravedad ni fisica)
c_cmp_default = c_cmp_render | c_cmp_movable | c_cmp_collider  ;;componente por defecto

x_cmps = 0

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
