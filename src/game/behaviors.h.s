;;-------------------------------------------------------------------------------
.module game_behaviors

.include "sys/beh.h.s"

;; model01 behavior programs

;; model01 action: fire an enemy projectile at signed horizontal speed.

.macro GAME_SHOOT _speed
    ACTION game_beh_action_shoot
    .db _speed
.endm
