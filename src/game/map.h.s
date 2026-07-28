;; Model01 world data and map configuration.
.module game_map

.include "sys/map.h.s"

.globl game_map_init
.globl game_map_update_transition
.globl game_map_do_portal_transition ;; IY=portal entity
.globl room_connections
.globl game_tile_solid_table
