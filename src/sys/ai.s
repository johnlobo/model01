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

.include "sys/array.h.s"
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
;; sys_ai_init
;;
;;  Initializes the AI system.
;;  Input:
;;  Output:
;;  Modified:
;;
sys_ai_init::

    ret

;;-----------------------------------------------------------------
;;
;; sys_ai_update_one_entity
;;
;;  Legacy AI: applies gravity and bounces the entity off the ground.
;;  Skipped for entities that have a behavior program (e_beh != 0),
;;  which are handled by sys_beh_update instead.
;;  Input:  IX = entity pointer
;;  Output:
;;  Modified: AF
;;
sys_ai_update_one_entity::
    ;; Skip entities that have a behavior program — sys_beh_update handles those
    ld e, e_beh(ix)
    ld d, e_beh+1(ix)
    ld a, d
    or e
    ret nz

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
;; sys_ai_update
;;
;;  Iterates all AI entities (c_cmp_ai) and runs the legacy bounce behavior
;;  for those without a behavior program.
;;  Input:
;;  Output:
;;  Modified: AF, BC, DE, HL, IX
;;
sys_ai_update::
    ld ix, #entities
    ld b, #c_cmp_ai
    ld hl, #sys_ai_update_one_entity
    call sys_array_execute_each_ix_matching
    ret