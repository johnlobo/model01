;;-------------------------------------------------------------------------------
.module map_system

.include "common.h.s"

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
.globl current_room     ;; current room index (0=map01, 1=map02); entities with e_room!=current_room are skipped
