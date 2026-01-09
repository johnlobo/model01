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
.module ai_system

.include "man/array.h.s"
.include "cpctelera.h.s"
.include "common.h.s"
.include "sys/ai.h.s"
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
;; man_ai_init
;;
;;  Initilizes the game
;;  Input: 
;;  Output: 
;;  Modified: AF, HL
;;
sys_ai_init::

    ret

;;-----------------------------------------------------------------
;;
;; sys_ai_entities
;;
;;  Render all the entities
;;  Input: 
;;  Output: 
;;  Modified: AF, BC, DE, HL
;;
sys_ai_update_one_entity::
    ;; Vertical movement
    inc e_speed_y(ix)           ;; gravity effect
    ld e_moved(ix), #1          ;; set moved flag

    ld a, e_y(ix)               ;; load vertical position
    add a, e_speed_y(ix)        ;; add vertical speed

    ld b, e_height(ix)          ;; load entity height
    add b                       ;; calculate bottom position
    cp #199                   ;; compare with ground level
    ret c                      ;; if not collided with ground, return

    ld e_speed_y(ix), #-16      ;; reset vertical speed
    ld e_y(ix), #184          ;; place entity on the ground          

   ret

;;-----------------------------------------------------------------
;;
;; man_ai_update
;;
;;  Initilizes the game
;;  Input: 
;;  Output: 
;;  Modified: AF, HL
;;
sys_ai_update::
    ld ix, #entities
    ld b, #c_cmp_ai
    ld hl, #sys_ai_update_one_entity
    call man_array_execute_each_ix_matching
    ret