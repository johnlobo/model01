;;-------------------------------------------------------------------------------
.module game_behaviors

.include "sys/beh.h.s"

;; model01 behavior programs
.globl game_beh_bounce
.globl game_beh_patrol

;; model01 action: fire an enemy projectile at signed horizontal speed.
.globl game_beh_action_shoot

.macro GAME_SHOOT _speed
    ACTION game_beh_action_shoot
    .db _speed
.endm
