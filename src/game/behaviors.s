;;-------------------------------------------------------------------------------
;; Behavior content owned by model01. The bytecode interpreter and its generic
;; actions/conditions live in sys/beh; a different game can replace this file.
.module game_behaviors

.include "game/behaviors.h.s"
.include "game/entities.h.s"
.include "common.h.s"
.include "man/entity.h.s"
.include "sys/shoot.h.s"

.area _DATA

;; Simple timed patrol example.
game_beh_bounce::
    SET_VX #2
game_beh_bounce_wait_right:
    WAIT 60, game_beh_bounce_go_left
    CONDITIONS_END
game_beh_bounce_go_left:
    SET_VX #-2
    WAIT 60, game_beh_bounce
    CONDITIONS_END

;; Platform patrol used by the monk enemy in model01.
game_beh_patrol::
    SET_ANIMATION game_monk_walk_right_anim
game_beh_patrol_moving_right:
    DRIVE_VX #1, #4
    CONDITION edge_ahead, game_beh_patrol_turn_left
    CONDITIONS_END

game_beh_patrol_turn_left:
    SET_ANIMATION game_monk_walk_left_anim
    GAME_SHOOT #-2
game_beh_patrol_moving_left:
    DRIVE_VX #-1, #4
    CONDITION edge_ahead, game_beh_patrol_turn_right
    CONDITIONS_END

game_beh_patrol_turn_right:
    SET_ANIMATION game_monk_walk_right_anim
    GAME_SHOOT #2
    GOTO game_beh_patrol_moving_right

game_beh_shoot_speed: .db 0

.area _CODE

;; Non-blocking custom action. IX=current entity; DE=inline signed speed.
game_beh_action_shoot::
    ld a, (de)
    ld (game_beh_shoot_speed), a
    inc de
    push de
    push ix

    pop ix
    push ix
    ld a, (game_beh_shoot_speed)
    bit 7, a
    jr nz, gbas_left

    ld a, e_x(ix)
    add a, e_width(ix)
    ld b, a
    jr gbas_spawn_y

gbas_left:
    ld a, e_x(ix)
    sub #S_BULLET_WIDTH
    ld b, a

gbas_spawn_y:
    ld c, e_y(ix)
    ld a, e_room(ix)
    ld d, a
    ld a, (game_beh_shoot_speed)
    ld e, a
    call game_entity_create_enemy_bullet

    pop ix
    pop de
    jp sys_beh_next
