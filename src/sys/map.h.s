;;-------------------------------------------------------------------------------
.module map_system

.include "common.h.s"

;;===============================================================================
;; PUBLIC METHODS
;;===============================================================================
.globl sys_map_init    ;; configure etm engine (call once at game init)
.globl sys_map_draw    ;; draw full tilemap to FRONT_BUFFER (call every render frame)
.globl sys_map_is_solid_at ;; B=pixel_y, C=pixel_x_bytes → NZ if solid tile
.globl sys_map_restore_tiles_at ;; B=pixel_y, C=pixel_x, D=height, E=width → redraws tiles under entity
