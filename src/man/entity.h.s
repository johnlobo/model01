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
.module entity_manager

.include "common.h.s"

;;===============================================================================
;; PUBLIC VARIABLES
;;===============================================================================
MAX_ENTITIES = 10

.globl entities
.globl entity_array
.globl player_template
.globl monk_walk_anim
.globl monk_idle_anim
.globl monk_walk_right_anim
.globl monk_walk_left_anim

;;===============================================================================
;; PUBLIC METHODS
;;===============================================================================
.globl man_entity_init
.globl man_entity_create_player_player

;;===============================================================================
;; DATA ARRAY STRUCTURE CREATION
;;===============================================================================
.mdelete DefineEntity
.macro DefineEntity _cpms, _status, _x, _y, _a, _pa, _speed_x, _speed_y, _on_air, _width, _height, _color, _sprite
    .db _cpms           ;; cpms
    .db _status         ;; status
    .db _x              ;; x
    .db _y              ;; y
    .dw 0               ;; p_x (set on first render)
    .dw 0               ;; p_y (set on first render)
    .dw _a              ;; address
    .dw _pa             ;; previous address
    .dw _speed_x        ;; speed_x
    .dw _speed_x        ;; speed_y
    .db _on_air         ;; on_air
    .db _width          ;; width
    .db _height         ;; height
    .db _color          ;; color
    .dw _sprite         ;; sprite
    .db 0               ;; moved
    .dw 0               ;; anim (null = no animation)
    .db 0               ;; anim_frame
    .db 0               ;; anim_timer (0 = expired, update on first tick)
    .dw 0               ;; beh (null = no behavior program)
    .db 0               ;; beh_timer
    .endm

BeginStruct e
Field e, cmps, 1
Field e, status, 1
Field e, x, 1
Field e, y, 1
Field e, p_x, 2     ;; previous draw x (for tile restore on next render)
Field e, p_y, 2     ;; previous draw y (for tile restore on next render)
Field e, address, 2
Field e, p_address, 2
Field e, speed_x, 2
Field e, speed_y, 2
Field e, on_air, 1
Field e, width, 1
Field e, height, 1
Field e, color, 1
Field e, sprite, 2
Field e, moved, 1
Field e, anim, 2
Field e, anim_frame, 1
Field e, anim_timer, 1
Field e, beh, 2
Field e, beh_timer, 1
EndStruct e
