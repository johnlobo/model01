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
    .dw _x              ;; x_coord
    .dw _y              ;; y_coord
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
    .endm

BeginStruct e
Field e, cmps, 1
Field e, status, 1
Field e, x, 1
Field e, y, 1
Field e, coord_x, 2
Field e, coord_y, 2
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
EndStruct e
