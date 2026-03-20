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

mgct_new_pos: .db 0  ;; new player coordinate (e_x or e_y) during a room transition

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
;;  Data-driven room transition using room_connections (map.h.s).
;;  Checks all four edges; if the player has crossed an edge and
;;  room_connections[current_room] has a non-zero entry in that
;;  direction, loads the adjacent map and repositions the player
;;  one step from the opposite edge (prevents instant re-trigger).
;;
;;  To add a new room: add one DefineRoomConnections row to
;;  room_connections in map.s and update neighboring room entries.
;;
;;  Input:
;;  Output:
;;  Modified: AF, BC, DE, HL, IX
;;
man_game_check_transition::
    ld ix, #entity_array

    ;; HL = &room_connections[current_room]
    ;; sizeof_room_info = 12 → offset = index*8 + index*4
    ld a, (current_room)
    ld l, a
    ld h, #0
    add hl, hl              ;; *2
    add hl, hl              ;; *4
    ld d, h
    ld e, l                 ;; DE = index*4
    add hl, hl              ;; *8
    add hl, de              ;; *12
    ld de, #room_connections
    add hl, de              ;; HL = &room_connections[current_room]

    ;; ---- WEST (left edge: e_x == 0) ----
    ld a, e_x(ix)
    or a
    jr nz, mgct_check_east

    ld a, #room_info_w
    call mgct_load_connection
    jr z, mgct_check_east   ;; no W connection

    ld a, #MAP_WIDTH*4
    sub e_width(ix)
    dec a                   ;; new e_x = MAP_WIDTH*4 - width - 1
    ld c, a
    jp mgct_do_horizontal

mgct_check_east:
    ;; ---- EAST (right edge: e_x + e_width >= MAP_WIDTH*4) ----
    ld a, e_x(ix)
    add a, e_width(ix)
    cp #MAP_WIDTH*4
    jr c, mgct_check_north

    ld a, #room_info_e
    call mgct_load_connection
    jr z, mgct_check_north  ;; no E connection

    ld c, #1                ;; new e_x = 1
    jp mgct_do_horizontal

mgct_check_north:
    ;; ---- NORTH (top edge: e_y == 0) ----
    ld a, e_y(ix)
    or a
    jr nz, mgct_check_south

    ld a, #room_info_n
    call mgct_load_connection
    jr z, mgct_check_south  ;; no N connection

    ld a, #MAP_HEIGHT*8
    sub e_height(ix)
    dec a                   ;; new e_y = MAP_HEIGHT*8 - height - 1
    ld c, a
    jp mgct_do_vertical

mgct_check_south:
    ;; ---- SOUTH (bottom edge: e_y + e_height >= MAP_HEIGHT*8) ----
    ld a, e_y(ix)
    add a, e_height(ix)
    cp #MAP_HEIGHT*8
    ret c                   ;; not at bottom edge

    ld a, #room_info_s
    call mgct_load_connection
    ret z                   ;; no S connection

    ld c, #1                ;; new e_y = 1
    jp mgct_do_vertical

;;-----------------------------------------------------------------
;;
;; mgct_load_connection (internal)
;;
;;  Reads one direction entry from a room_info struct.
;;  Input:  HL = base address of current room's room_info entry
;;          A  = field offset (room_info_n / _s / _e / _w)
;;  Output: DE = tilemap pointer (0x0000 if no connection)
;;          B  = destination room id
;;          Z  = 1 if no connection (DE == 0)
;;          HL = preserved
;;  Modified: AF, BC, DE
;;
mgct_load_connection:
    push hl
    ld d, #0
    ld e, a
    add hl, de              ;; HL points to direction field
    ld e, (hl)
    inc hl
    ld d, (hl)              ;; DE = tilemap pointer
    inc hl
    ld b, (hl)              ;; B = destination room id
    pop hl
    ld a, d
    or e                    ;; Z if no connection
    ret

;;-----------------------------------------------------------------
;;
;; mgct_do_horizontal (internal)
;;
;;  Switches to a new room and repositions the player on the x axis.
;;  Input:  DE = new map tilemap pointer
;;          B  = new room index
;;          C  = new e_x for player
;;  Modified: AF, BC, DE, HL, IX
;;
mgct_do_horizontal:
    ld (mgct_new_pos), c    ;; preserve across sys_map_set (clobbers BC)
    ld a, b
    ld (current_room), a
    ex de, hl               ;; HL = new map ptr
    call sys_map_set        ;; draw new map (clobbers IX)
    ld ix, #entity_array
    ld a, (current_room)
    ld e_room(ix), a
    ld a, (mgct_new_pos)
    ld e_x(ix), a
    xor a
    ld e_speed_x(ix), a
    ld e_speed_x+1(ix), a
    ld e_moved(ix), #1
    ld e_p_address(ix), a
    ld e_p_address+1(ix), a
    ret

;;-----------------------------------------------------------------
;;
;; mgct_do_vertical (internal)
;;
;;  Switches to a new room and repositions the player on the y axis.
;;  Input:  DE = new map tilemap pointer
;;          B  = new room index
;;          C  = new e_y for player
;;  Modified: AF, BC, DE, HL, IX
;;
mgct_do_vertical:
    ld (mgct_new_pos), c    ;; preserve across sys_map_set (clobbers BC)
    ld a, b
    ld (current_room), a
    ex de, hl
    call sys_map_set
    ld ix, #entity_array
    ld a, (current_room)
    ld e_room(ix), a
    ld a, (mgct_new_pos)
    ld e_y(ix), a
    xor a
    ld e_speed_y(ix), a
    ld e_speed_y+1(ix), a
    ld e_moved(ix), #1
    ld e_p_address(ix), a
    ld e_p_address+1(ix), a
    ret