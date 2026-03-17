;;-------------------------------------------------------------------------------
.module map_system

.include "common.h.s"

;;===============================================================================
;; PUBLIC METHODS
;;===============================================================================
.globl sys_map_init    ;; configure etm engine (call once at game init)
.globl sys_map_draw    ;; draw full tilemap to FRONT_BUFFER (call every render frame)
.globl sys_map_is_solid_at    ;; B=world_y, C=world_x_bytes → NZ if fully solid (ceiling/sides)
.globl sys_map_is_landable_at ;; B=world_y, C=world_x_bytes → NZ if solid or jumpable (floor)
.globl sys_map_restore_tiles_at ;; B=world_y, C=world_x, D=height, E=width → redraws tiles under entity
.globl map_origin_x    ;; map draw origin x on screen (bytes, default 0)
.globl map_origin_y    ;; map draw origin y on screen (pixels, default MAP_PIXEL_START)
