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
.module shoot_system

.include "sys/array.h.s"
.include "cpctelera.h.s"
.include "common.h.s"
.include "sys/shoot.h.s"
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
;; sys_shoot_init
;;
;;  Initializes the shooting system (currently a no-op).
;;
sys_shoot_init::
    ret

;;-----------------------------------------------------------------
;;
;; sys_shoot_update_one_bullet
;;
;;  Moves one projectile in a straight horizontal line and destroys
;;  it when it leaves the map's horizontal bounds. Bullets have no
;;  gravity and no tile/entity collision — they fly clean through
;;  tiles and other entities. Hit detection is left as an extension
;;  point (same spirit as sys_collision_on_hit's placeholder).
;;
;;  Input:  IX = entity pointer (c_cmp_projectile)
;;  Output:
;;  Modified: AF, BC
;;
sys_shoot_update_one_bullet::
    ld a, (current_room)
    cp e_room(ix)
    ret nz                          ;; wrong room: skip

    ld a, e_x(ix)
    add a, e_speed_x(ix)            ;; A = new_x (signed)

    bit 7, a                        ;; new_x < 0 (world x is always < 128)?
    jr nz, ssuob_destroy            ;; off the left edge of the map

    ld b, a                         ;; B = new_x
    add a, e_width(ix)
    cp #MAP_WIDTH*4 + 1             ;; new_x + width > MAP_WIDTH*4?
    jr nc, ssuob_destroy            ;; off the right edge of the map

    ld e_x(ix), b
    ld e_moved(ix), #1
    ret

ssuob_destroy:
    ld e_cmps(ix), #c_cmp_invalid
    ret

;;-----------------------------------------------------------------
;;
;; sys_shoot_update
;;
;;  Iterates all projectile entities (c_cmp_projectile) and advances
;;  them one step.
;;  Input:
;;  Output:
;;  Modified: AF, BC, DE, HL, IX
;;
sys_shoot_update::
    ld ix, #entities
    ld b, #c_cmp_projectile
    ld hl, #sys_shoot_update_one_bullet
    call sys_array_execute_each_ix_matching
    ret
