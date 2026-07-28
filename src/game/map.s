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
