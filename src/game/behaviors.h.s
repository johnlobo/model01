;;-------------------------------------------------------------------------------
.module game_behaviors

.include "sys/beh.h.s"

;; model01 behavior programs

;; model01 action: fire an enemy projectile at signed horizontal speed.

.macro GAME_SHOOT _speed
    ACTION game_beh_action_shoot
    .db _speed
.endm

;; Blocking actions. Follow each one with conditions or CONDITIONS_END.
.macro GAME_CHASE_PLAYER _speed, _stride
    ACTION game_beh_action_chase_player
    .db _speed, _stride
.endm

.macro GAME_PATROL_X _left, _right, _speed, _stride
    ACTION game_beh_action_patrol_x
    .db _left, _right, _speed, _stride
.endm

.macro GAME_FLY_Y _top, _bottom, _speed, _stride
    ACTION game_beh_action_fly_y
    .db _top, _bottom, _speed, _stride
.endm
