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

.include "sys/array.h.s"
.include "cpctelera.h.s"
.include "common.h.s"
.include "sys/physics.h.s"
.include "sys/util.h.s"
.include "sys/map.h.s"
.include "man/entity.h.s"

;;
;; Start of _DATA area 
;;
GRAVITY = 1
JUMP_SPEED = -8

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

    ;; Friction: only apply for player-controlled entities (c_cmp_input = 0x04)
    bit 2, e_cmps(ix)
    jr z, spuoe_h_no_friction       ;; AI/physics-driven: skip friction
    call sys_utiL_reduce_a          ;; apply friction to horizontal speed
    ld e_speed_x(ix), a             ;; update horizontal speed
spuoe_h_no_friction:
    add a, e_x(ix)                  ;; A = new_x

    ;; Horizontal tile collision
    bit 7, e_speed_x(ix)
    jr nz, spuoe_h_left             ;; negative speed: moving left

    ;; Moving right: check right edge (new_x + width - 1) at top and bottom
    push af                         ;; save new_x
    add a, e_width(ix)
    dec a                           ;; A = right_edge
    ld c, a                         ;; C = right_edge (preserved by sys_map_is_solid_at)
    ld b, e_y(ix)
    call sys_map_is_solid_at
    jr nz, spuoe_h_clamp_right
    ld a, e_y(ix)
    add a, e_height(ix)
    dec a
    ld b, a
    call sys_map_is_solid_at
    jr nz, spuoe_h_clamp_right
    pop af                          ;; no collision: restore new_x
    jr spuoe_h_done

spuoe_h_clamp_right:
    ld a, c
    and #0xFC
    sub e_width(ix)                 ;; new_x = tile_left - width
    ld e_speed_x(ix), #0
    pop de                          ;; clean stack
    jr spuoe_h_done

spuoe_h_left:
    ;; Moving left: check left edge (new_x) at top and bottom
    push af                         ;; save new_x
    ld c, a                         ;; C = left_edge = new_x
    ld b, e_y(ix)
    call sys_map_is_solid_at
    jr nz, spuoe_h_clamp_left
    ld a, e_y(ix)
    add a, e_height(ix)
    dec a
    ld b, a
    call sys_map_is_solid_at
    jr nz, spuoe_h_clamp_left
    pop af                          ;; no collision: restore new_x
    jr spuoe_h_done

spuoe_h_clamp_left:
    ld a, c
    and #0xFC
    add a, #4                       ;; new_x = tile_right + 1
    ld e_speed_x(ix), #0
    pop de                          ;; clean stack

spuoe_h_done:
    ld e_x(ix), a
    ld e_moved(ix), #1

    ;; Vertical movement
spuoe_vertical_movement:
    ld a, e_on_air(ix)
    or a
    jr nz, spuoe_apply_gravity          ;; already in air: apply gravity

    ;; On ground: check if solid tile still below entity feet
    ld a, e_y(ix)
    add a, e_height(ix)
    dec a                               ;; A = entity bottom pixel
    cp #GROUND_LEVEL
    jr nc, spuoe_check_speed_y          ;; at/below GROUND_LEVEL: keep on ground

    inc a                               ;; A = pixel just below entity
    ld b, a                             ;; B preserved by sys_map_is_solid_at

    ld c, e_x(ix)                       ;; check below left foot
    call sys_map_is_solid_at
    jr nz, spuoe_check_speed_y          ;; solid below left: stay on ground

    ld a, e_x(ix)
    add a, e_width(ix)
    dec a
    ld c, a                             ;; check below right foot
    call sys_map_is_solid_at
    jr nz, spuoe_check_speed_y          ;; solid below right: stay on ground

    ld e_on_air(ix), #1                 ;; no solid below: start falling

spuoe_apply_gravity:
    ld a, e_speed_y(ix)
    add a, #GRAVITY
    ld e_speed_y(ix), a

spuoe_check_speed_y:
    ld a, e_speed_y(ix)         ;; load vertical speed
    or a
    ret z                       ;; return if vertical speed is zero

    add a, e_y(ix)              ;; A = new_y

    ;; Tile collision: only when moving downward (speed_y > 0, bit7 = 0)
    bit 7, e_speed_y(ix)
    jr nz, spuoe_ground_check   ;; moving up: skip tile check

    push af                     ;; save new_y
    add a, e_height(ix)
    dec a                       ;; A = bottom_pixel = new_y + height - 1
    ld b, a                     ;; B = bottom_pixel (preserved by sys_map_is_solid_at)

    ld c, e_x(ix)               ;; check left foot
    call sys_map_is_solid_at
    jr nz, spuoe_tile_land

    ld a, e_x(ix)               ;; check right foot
    add a, e_width(ix)
    dec a
    ld c, a
    call sys_map_is_solid_at
    jr nz, spuoe_tile_land

    pop af                      ;; restore new_y

spuoe_ground_check:
    ;; check ground collision
    ld b, a                     ;; new y in b
    ld a, #GROUND_LEVEL
    sub e_height(ix)            ;; max y before ground = GROUND_LEVEL - height
    cp b
    ld a, b                     ;; restore new y in a
    jr nc, spuoe_not_ground     ;; max_y >= new_y: still airborne

    ;; ground hit: clamp, stop, land
    ld a, #184
    ld e_speed_y(ix), #0
    ld e_on_air(ix), #0
    ld e_y(ix), a
    ld e_moved(ix), #1
    ret

spuoe_tile_land:
    ;; Clamp entity to top of the tile just entered
    ;; B = bottom_pixel; tile_top = ((B - MAP_PIXEL_START) & 0xF8) + MAP_PIXEL_START
    ld a, b
    sub #MAP_PIXEL_START
    and #0xF8
    add a, #MAP_PIXEL_START
    sub e_height(ix)            ;; A = clamped new_y
    pop de                      ;; discard saved new_y (balance push af)
    ld e_y(ix), a
    ld e_speed_y(ix), #0
    ld e_on_air(ix), #0
    ld e_moved(ix), #1
    ret

spuoe_not_ground:
    ld e_on_air(ix), #1         ;; mark as airborne
    ld e_y(ix), a
    ld e_moved(ix), #1
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
    call sys_array_execute_each_ix_matching
    ret