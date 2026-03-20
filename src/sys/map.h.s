;;-------------------------------------------------------------------------------
.module map_system

.include "common.h.s"

;;===============================================================================
;; ROOM CONNECTION STRUCT
;;===============================================================================
;;
;; Each entry in room_connections is a room_info struct: four 2-byte pointers
;; (N, S, E, W) to the tilemap data of the adjacent room in that direction.
;; A pointer of 0x0000 means no connection exists in that direction.
;;
;; Access: room_connections + room_index * sizeof_room_info + room_info_[n|s|e|w]
;;
BeginStruct room_info
Field room_info, n,    2   ;; 2B: tilemap ptr for N neighbor (0 = no connection)
Field room_info, n_id, 1   ;; 1B: room index of N neighbor
Field room_info, s,    2   ;; 2B: tilemap ptr for S neighbor
Field room_info, s_id, 1   ;; 1B: room index of S neighbor
Field room_info, e,    2   ;; 2B: tilemap ptr for E neighbor
Field room_info, e_id, 1   ;; 1B: room index of E neighbor
Field room_info, w,    2   ;; 2B: tilemap ptr for W neighbor
Field room_info, w_id, 1   ;; 1B: room index of W neighbor
EndStruct room_info        ;; sizeof_room_info = 12

.mdelete DefineRoomConnections
.macro DefineRoomConnections n_map, n_id, s_map, s_id, e_map, e_id, w_map, w_id
    .dw n_map
    .db n_id
    .dw s_map
    .db s_id
    .dw e_map
    .db e_id
    .dw w_map
    .db w_id
.endm

.globl room_connections ;; table of room_info structs, indexed by room index

;;===============================================================================
;; PUBLIC METHODS
;;===============================================================================
.globl sys_map_init    ;; configure etm engine (call once at game init)
.globl sys_map_draw    ;; draw full tilemap to FRONT_BUFFER (call every render frame)
.globl sys_map_set     ;; HL=tilemap ptr → switch active map and redraw
.globl sys_map_is_solid_at    ;; B=world_y, C=world_x_bytes → NZ if fully solid (ceiling/sides)
.globl sys_map_is_landable_at ;; B=world_y, C=world_x_bytes → NZ if solid or jumpable (floor)
.globl sys_map_restore_tiles_at ;; B=world_y, C=world_x, D=height, E=width → redraws tiles under entity
.globl map_origin_x    ;; map draw origin x on screen (bytes, default 0)
.globl map_origin_y    ;; map draw origin y on screen (pixels)
.globl current_map_data ;; 2-byte pointer to active tilemap data (_g_map01 or _g_map02)
.globl current_room     ;; current room index (0=map01, 1=map02, 2=map03); entities with e_room!=current_room are skipped
