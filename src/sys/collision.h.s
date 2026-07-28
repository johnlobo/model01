;;-------------------------------------------------------------------------------
.module collision_system

.include "common.h.s"

;;===============================================================================
;; PUBLIC VARIABLES
;;===============================================================================


;;===============================================================================
;; PUBLIC METHODS
;;===============================================================================
.globl sys_collision_init
.globl sys_collision_set_handler
.globl sys_collision_on_hit
.globl sys_collision_destroy_entity
.globl sys_collision_update
