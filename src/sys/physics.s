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
    inc e_speed_y(ix)
    ld e_moved(ix), #1

    ld a, e_y(ix)
    add a, e_speed_y(ix)
    ld e_y(ix), a

    add #(256-184)
    ret nc

    ld e_speed_y(ix), #-16
    ld e_y(ix), #184

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