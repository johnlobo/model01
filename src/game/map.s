;; Tiles, room graph and map entities owned by Model01.
.module game_map

.include "game/map.h.s"
.include "game/entities.h.s"
.include "common.h.s"
.include "man/entity.h.s"

.area _DATA

room_connections::
    ;;                   N     N_id   S     S_id   E          E_id   W          W_id
    DefineRoomConnections 0, 0xff, 0, 0xff, _g_map02,   1,    0,         0xff
    DefineRoomConnections 0, 0xff, 0, 0xff, _g_map03,   2,    _g_map01,  0
    DefineRoomConnections 0, 0xff, 0, 0xff, _g_map04,   3,    _g_map02,  1
    DefineRoomConnections 0, 0xff, 0, 0xff, 0,          0xff, _g_map03,  2
    DefineRoomConnections 0, 0xff, 0, 0xff, 0,          0xff, _g_map03,  2

game_tile_solid_table::
    .db 0   ;;  0: passable
    .db 2   ;;  1: one-way platform
    .db 1   ;;  2: solid
    .db 1   ;;  3: solid
    .db 1   ;;  4: solid
    .db 1   ;;  5: solid
    .db 1   ;;  6: solid
    .db 1   ;;  7: solid
    .db 1   ;;  8: solid
    .db 1   ;;  9: solid
    .db 0   ;; 10: decoration
    .db 0   ;; 11: decoration
    .db 1   ;; 12: solid
    .db 0   ;; 13: passable
    .db 0   ;; 14: passable
    .db 0   ;; 15: passable
    .db 0   ;; 16: door decoration
    .db 0   ;; 17: door decoration
    .db 0   ;; 18: decoration

game_map_new_pos: .db 0
game_map_portal_dest_y: .db 0

.area _CODE

game_map_init::
    ;; Configure the generic tilemap engine with Model01 resources.
    ld hl, #_s_tileset_00
    ld de, #_g_map01
    ld ix, #game_tile_solid_table
    call sys_map_init
    xor a
    ld (current_room), a

    ;; Invisible trigger over map03's door (col 13, rows 17-18).
    ld b, #52
    ld c, #136
    ld d, #2
    call game_entity_create_portal
    ret c
    ld hl, #_g_inside01
    ld e_beh(ix), l
    ld e_beh+1(ix), h
    ld e_beh_timer(ix), #4
    ld e_speed_x(ix), #1
    ld e_speed_x+1(ix), #144
    ld e_on_air(ix), #1
    or a
    ret

;; Applies Model01's room graph when the player reaches a map edge.
game_map_update_transition::
    ld ix, #entity_array
    ld a, (current_room)
    ld l, a
    ld h, #0
    add hl, hl
    add hl, hl
    ld d, h
    ld e, l
    add hl, hl
    add hl, de
    ld de, #room_connections
    add hl, de

    ld a, e_x(ix)
    or a
    jr nz, gmut_check_east
    ld a, #room_info_w
    call gmut_load_connection
    jr z, gmut_check_east
    ld a, #MAP_WIDTH*4
    sub e_width(ix)
    dec a
    ld c, a
    jp gmut_do_horizontal

gmut_check_east:
    ld a, e_x(ix)
    add a, e_width(ix)
    cp #MAP_WIDTH*4
    jr c, gmut_check_north
    ld a, #room_info_e
    call gmut_load_connection
    jr z, gmut_check_north
    ld c, #1
    jp gmut_do_horizontal

gmut_check_north:
    ld a, e_y(ix)
    or a
    jr nz, gmut_check_south
    ld a, #room_info_n
    call gmut_load_connection
    jr z, gmut_check_south
    ld a, #MAP_HEIGHT*8
    sub e_height(ix)
    dec a
    ld c, a
    jp gmut_do_vertical

gmut_check_south:
    ld a, e_y(ix)
    add a, e_height(ix)
    cp #MAP_HEIGHT*8
    ret c
    ld a, #room_info_s
    call gmut_load_connection
    ret z
    ld c, #1
    jp gmut_do_vertical

;; HL=room row, A=direction offset -> DE=map, B=room id, Z=no map.
gmut_load_connection:
    push hl
    ld d, #0
    ld e, a
    add hl, de
    ld e, (hl)
    inc hl
    ld d, (hl)
    inc hl
    ld b, (hl)
    pop hl
    ld a, d
    or e
    ret

gmut_do_horizontal:
    ld a, c
    ld (game_map_new_pos), a
    ld a, b
    ld (current_room), a
    ex de, hl
    call sys_map_set
    ld ix, #entity_array
    ld a, (current_room)
    ld e_room(ix), a
    ld a, (game_map_new_pos)
    ld e_x(ix), a
    xor a
    ld e_speed_x(ix), a
    ld e_speed_x+1(ix), a
    ld e_moved(ix), #1
    ld e_p_address(ix), a
    ld e_p_address+1(ix), a
    ret

gmut_do_vertical:
    ld a, c
    ld (game_map_new_pos), a
    ld a, b
    ld (current_room), a
    ex de, hl
    call sys_map_set
    ld ix, #entity_array
    ld a, (current_room)
    ld e_room(ix), a
    ld a, (game_map_new_pos)
    ld e_y(ix), a
    xor a
    ld e_speed_y(ix), a
    ld e_speed_y+1(ix), a
    ld e_moved(ix), #1
    ld e_p_address(ix), a
    ld e_p_address+1(ix), a
    ret

;; Teleports the player using destination fields encoded in IY=portal.
game_map_do_portal_transition::
    ld a, e_speed_x(iy)
    ld (game_map_new_pos), a
    ld a, e_speed_x+1(iy)
    ld (game_map_portal_dest_y), a
    ld a, e_beh_timer(iy)
    ld (current_room), a
    ld l, e_beh(iy)
    ld h, e_beh+1(iy)
    call sys_map_set
    ld ix, #entity_array
    ld a, (current_room)
    ld e_room(ix), a
    ld a, (game_map_new_pos)
    ld e_x(ix), a
    ld a, (game_map_portal_dest_y)
    ld e_y(ix), a
    xor a
    ld e_speed_x(ix), a
    ld e_speed_x+1(ix), a
    ld e_speed_y(ix), a
    ld e_speed_y+1(ix), a
    ld e_moved(ix), #1
    ld e_p_address(ix), a
    ld e_p_address+1(ix), a
    ret
