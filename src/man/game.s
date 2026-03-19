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
.module game_manager

.include "sys/array.h.s"
.include "cpctelera.h.s"
.include "common.h.s"
.include "sys/render.h.s"
.include "sys/map.h.s"
.include "sys/ai.h.s"
.include "sys/physics.h.s"
.include "sys/input.h.s"
.include "sys/collision.h.s"
.include "sys/anim.h.s"
.include "sys/beh.h.s"
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
;; man_game_init
;;
;;  Initilizes the game
;;  Input: 
;;  Output: 
;;  Modified: AF, HL
;;
man_game_init::
    call man_entity_init
    call man_entity_create_player_player
    call man_entity_create_patrol_enemy
    call sys_render_init
    call sys_map_init
    call sys_map_draw           ;; draw map once at startup
    ret

;;-----------------------------------------------------------------
;;
;; man_game_init
;;
;;  Initilizes the game
;;  Input: 
;;  Output: 
;;  Modified: AF, HL
;;
man_game_update::
    call sys_physics_update
    call man_game_check_transition
    ld ix, #entity_array
    call sys_input_update
    call sys_ai_update
    call sys_beh_update
    cpctm_setBorder_asm HW_MAUVE
    call sys_collision_update
    call sys_anim_update
    call cpct_waitVSYNC_asm
    call sys_render_update
    ret

;;-----------------------------------------------------------------
;;
;; man_game_check_transition
;;
;;  Handles left/right map transitions for the player:
;;    map01 right edge -> map02, player enters at left edge (e_x=1)
;;    map02 left edge  -> map01, player enters at right edge (e_x=MAP_WIDTH*4-width-1)
;;
;;  Entry at e_x=1 / e_x=MAP_WIDTH*4-width-1 (one step from the boundary)
;;  prevents the player from immediately re-triggering the opposite transition
;;  on the very next frame.
;;
;;  Input:
;;  Output:
;;  Modified: AF, BC, DE, HL, IX, IY
;;
man_game_check_transition::
    ld ix, #entity_array

    ;; Check if on map01
    ld hl, (current_map_data)
    ld de, #_g_map01
    or a                        ;; clear carry
    sbc hl, de
    jr nz, mgct_check_map02     ;; not on map01: check map02

    ;; On map01: right edge -> map02
    ld a, e_x(ix)
    add a, e_width(ix)          ;; A = e_x + e_width
    cp #MAP_WIDTH*4             ;; A >= 64?
    ret c                       ;; not at right edge

    ld hl, #_g_map02
    call sys_map_set            ;; redraws map02, destroys IX
    ld a, #1
    ld (current_room), a        ;; now in room 1
    ld ix, #entity_array
    ld e_x(ix), #1              ;; one step from left edge (avoids instant left re-trigger)
    ld e_room(ix), #1           ;; player moves to room 1
    ld e_speed_x(ix), #0
    ld e_moved(ix), #1
    ld e_p_address(ix), #0
    ld e_p_address+1(ix), #0
    ret

mgct_check_map02:
    ;; Check if on map02
    ld hl, (current_map_data)
    ld de, #_g_map02
    or a
    sbc hl, de
    ret nz                      ;; not on map02: nothing to do

    ;; On map02: left edge -> map01
    ld a, e_x(ix)
    or a                        ;; A == 0?
    ret nz                      ;; not at left edge

    ld hl, #_g_map01
    call sys_map_set            ;; redraws map01, destroys IX
    ld a, #0
    ld (current_room), a        ;; now in room 0
    ld ix, #entity_array
    ld a, #MAP_WIDTH*4
    sub e_width(ix)
    dec a                       ;; A = MAP_WIDTH*4 - width - 1 (one step from right edge)
    ld e_x(ix), a
    ld e_room(ix), #0           ;; player moves to room 0
    ld e_speed_x(ix), #0
    ld e_moved(ix), #1
    ld e_p_address(ix), #0
    ld e_p_address+1(ix), #0
    ret