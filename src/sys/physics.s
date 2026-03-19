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
MAX_FALL_SPEED = 8
;; Jump speed constants are in sys/input.s (JUMP_SPEED_MIN / JUMP_SPEED_MAX)

.area _DATA


;;
;; Start of _CODE area
;;
.area _CODE

;;-----------------------------------------------------------------
;;
;; sys_physics_init
;;
;;  Initializes the physics system.
;;  Input:
;;  Output:
;;  Modified:
;;
sys_physics_init::

    ret

;;-----------------------------------------------------------------
;;
;; sys_physics_update_one_entity
;;
;;  Applies horizontal movement, friction, tile collision, gravity and
;;  floor/ceiling collision to one entity.
;;  Input:  IX = entity pointer
;;  Output:
;;  Modified: AF, BC, DE, HL
;;
sys_physics_update_one_entity::
    ld a, (current_room)
    cp e_room(ix)
    ret nz                          ;; wrong room: skip

    ;; Horizontal movement
    ld a, e_speed_x(ix)             ;; load horizontal speed
    or a                            ;; check if horizontal speed is zero
    jp z, spuoe_vertical_movement   ;; jump if horizontal speed is zero

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
    ld c, a                         ;; C = right_edge
    ld b, e_y(ix)
    call sys_map_is_landable_at
    jr nz, spuoe_h_clamp_right
    ld a, e_y(ix)
    add a, e_height(ix)
    dec a
    ld b, a
    call sys_map_is_landable_at
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
    call sys_map_is_landable_at
    jr nz, spuoe_h_clamp_left
    ld a, e_y(ix)
    add a, e_height(ix)
    dec a
    ld b, a
    call sys_map_is_landable_at
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
    ;; Clamp x within map horizontal bounds [0, MAP_WIDTH*4 - e_width]
    bit 7, a                    ;; x went negative (wrapped)?
    jr z, spuoe_h_right_bound
    xor a                       ;; clamp to 0
    ld e_speed_x(ix), #0
spuoe_h_right_bound:
    ld c, a                     ;; C = x
    add a, e_width(ix)
    cp #MAP_WIDTH*4 + 1         ;; x+width > 64?
    jr c, spuoe_h_write         ;; carry: x+width <= 64, in bounds
    ld a, #MAP_WIDTH*4
    sub e_width(ix)             ;; A = 64 - width
    ld e_speed_x(ix), #0
    jr spuoe_h_write2
spuoe_h_write:
    ld a, c                     ;; restore x
spuoe_h_write2:
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
    call sys_map_is_landable_at
    jr nz, spuoe_check_speed_y          ;; solid/jumpable below left: stay on ground

    ld a, e_x(ix)
    add a, e_width(ix)
    dec a
    ld c, a                             ;; check below right foot
    call sys_map_is_landable_at
    jr nz, spuoe_check_speed_y          ;; solid/jumpable below right: stay on ground

    ld e_on_air(ix), #1                 ;; no solid below: start falling

spuoe_apply_gravity:
    ld a, e_speed_y(ix)
    add a, #GRAVITY
    ;; Cap positive speed_y at MAX_FALL_SPEED to prevent tunneling through tiles
    bit 7, a                    ;; is new speed negative (moving up)?
    jr nz, spuoe_no_cap         ;; negative: don't cap
    cp #MAX_FALL_SPEED + 1      ;; A >= MAX_FALL_SPEED+1?
    jr c, spuoe_no_cap          ;; A < MAX_FALL_SPEED+1: no cap needed
    ld a, #MAX_FALL_SPEED       ;; cap at MAX_FALL_SPEED
spuoe_no_cap:
    ld e_speed_y(ix), a

spuoe_check_speed_y:
    ld a, e_speed_y(ix)         ;; load vertical speed
    or a
    ret z                       ;; return if vertical speed is zero

    add a, e_y(ix)              ;; A = new_y

    ;; Tile collision: check ceiling when moving up, floor when moving down
    bit 7, e_speed_y(ix)
    jr z, spuoe_tile_check_fall ;; speed_y >= 0: moving down, check floor

    ;; Moving up: clamp to world top (y=0 = map top).
    ;; Use carry from the ADD above: carry=1 means e_y + speed_y >= 256, i.e.
    ;; the true signed result is >= 0 (valid). carry=0 means the result wrapped
    ;; below 0.  bit7 of A is NOT reliable here — e.g. e_y=144, speed_y=-16
    ;; gives A=128 (bit7=1) which is a perfectly valid world_y.
    ;; BIT instruction does not modify carry, so it is still valid after the
    ;; direction check above.
    jr c, spuoe_ceiling_check   ;; carry set: new_y >= 0, still in map, proceed
    xor a                       ;; carry clear: new_y < 0, clamp to world y=0
    ld e_speed_y(ix), #0
    jr spuoe_update_y

spuoe_ceiling_check:
    ;; Moving up: check if new top edge enters a solid tile (ceiling collision)
    push af                     ;; save new_y
    ld b, a                     ;; B = new_y (top edge)

    ld c, e_x(ix)               ;; check top-left corner
    call sys_map_is_solid_at
    jr nz, spuoe_tile_ceiling

    ld a, e_x(ix)               ;; check top-right corner
    add a, e_width(ix)
    dec a
    ld c, a                     ;; C = right edge; B still = new_y (preserved by sys_map_is_solid_at)
    call sys_map_is_solid_at
    jr nz, spuoe_tile_ceiling

    pop af                      ;; no ceiling: restore new_y
    jr spuoe_ground_check

spuoe_tile_ceiling:
    ;; Clamp entity below the tile it hit (world coords)
    ;; tile_bottom = (B & 0xF8) + 8
    ld a, b
    and #0xF8
    add a, #8                   ;; A = first world pixel row below the tile
    ld e_speed_y(ix), #0        ;; stop vertical movement
    pop de                      ;; discard saved new_y (balance push af)
    jr spuoe_update_y

spuoe_tile_check_fall:
    push af                     ;; save new_y
    add a, e_height(ix)
    dec a                       ;; A = bottom_pixel = new_y + height - 1
    ld b, a                     ;; B = bottom_pixel (preserved by sys_map_is_solid_at)

    ld c, e_x(ix)               ;; check left foot
    call sys_map_is_landable_at
    jr nz, spuoe_tile_land

    ld a, e_x(ix)               ;; check right foot
    add a, e_width(ix)
    dec a
    ld c, a
    call sys_map_is_landable_at
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

    ;; ground hit: clamp y so entity feet land exactly at GROUND_LEVEL
    ld a, #GROUND_LEVEL
    sub e_height(ix)
    inc a                       ;; A = y where e_y + height - 1 = GROUND_LEVEL
    ld e_speed_y(ix), #0
    ld e_on_air(ix), #0
    ld e_y(ix), a
    ld e_moved(ix), #1
    ret

spuoe_tile_land:
    ;; Clamp entity to top of the tile just entered (world coords)
    ;; B = bottom_pixel; tile_top = B & 0xF8
    ld a, b
    and #0xF8
    sub e_height(ix)            ;; A = clamped new_y = tile_top - height
    pop de                      ;; discard saved new_y (balance push af)
    ld e_y(ix), a
    ld e_speed_y(ix), #0
    ld e_on_air(ix), #0
    ld e_moved(ix), #1
    ret

spuoe_not_ground:
    ld e_on_air(ix), #1         ;; mark as airborne
spuoe_update_y:
    ld e_y(ix), a
    ld e_moved(ix), #1
    ret

;;-----------------------------------------------------------------
;;
;; sys_physics_update
;;
;;  Iterates all movable entities (c_cmp_movable) and updates their physics.
;;  Input:
;;  Output:
;;  Modified: AF, BC, DE, HL, IX
;;
sys_physics_update::
    ld ix, #entities
    ld b, #c_cmp_movable
    ld hl, #sys_physics_update_one_entity
    call sys_array_execute_each_ix_matching
    ret