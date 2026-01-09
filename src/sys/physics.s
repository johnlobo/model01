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
.module physics_system

.include "man/array.h.s"
.include "cpctelera.h.s"
.include "common.h.s"
.include "sys/physics.h.s"
.include "sys/util.h.s"
.include "man/entity.h.s"

;;
;; Start of _DATA area 
;;
.area _DATA


;;
;; Start of _CODE area
;; 
.area _CODE

;;-----------------------------------------------------------------
;;
;; man_physics_init
;;
;;  Initilizes the game
;;  Input: 
;;  Output: 
;;  Modified: AF, HL
;;
sys_physics_init::

    ret

;;-----------------------------------------------------------------
;;
;; sys_physics_entities
;;
;;  Render all the entities
;;  Input: 
;;  Output: 
;;  Modified: AF, BC, DE, HL
;;
sys_physics_update_one_entity::
    ;; Horizontal movement
    ld a, e_speed_x(ix)             ;; load horizontal speed
    or a                            ;; check if horizontal speed is zero
    jr z, spuoe_vertical_movement   ;; jump if horizontal speed is zero

    ;; Friction application
    call sys_utiL_reduce_a          ;; apply friction to horizontal speed
    ld e_speed_x(ix), a             ;; update horizontal speed

    add a, e_x(ix)                  ;; update x position
    ld e_x(ix), a                   ;; store new x position
    ld e_moved(ix), #1              ;; set moved flag

    ;; Vertical movement
spuoe_vertical_movement:
cpctm_WINAPE_BRK
    ld a, e_speed_y(ix)         ;; load vertical speed
    or a                        ;;
    ret z                       ;; return if vertical speed is zero

    add a, e_y(ix)              ;; Add vertical speed to vertical position

    ;; check ground collision
    ld b, a                     ;; load bottom position on b
    ld a, #GROUND_LEVEL         ;; ground level
    sub e_height(ix)         ;; calculate bottom position
    cp b
    ld a, b
    jr nc, spuoe_not_ground      ;; if not collided with ground, continue vertical movement
    ld a, #184

spuoe_not_ground:
    ld e_y(ix), a               ;; update y position
    ld e_moved(ix), #1          ;; set moved flag
   ret

;;-----------------------------------------------------------------
;;
;; man_physics_update
;;
;;  Initilizes the game
;;  Input: 
;;  Output: 
;;  Modified: AF, HL
;;
sys_physics_update::
    ld ix, #entities
    ld b, #c_cmp_movable
    ld hl, #sys_physics_update_one_entity
    call man_array_execute_each_ix_matching
    ret