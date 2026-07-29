;;-------------------------------------------------------------------------------
;; Behavior content owned by model01. The bytecode interpreter and its generic
;; actions/conditions live in sys/beh; a different game can replace this file.
.module game_behaviors

.include "game/behaviors.h.s"
.include "globals.inc"
.include "game/config.h.s"
.include "sys/entity.h.s"
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

;; Continuously follows the player horizontally. Physics applies the selected
;; velocity on the following frame and handles terrain/world limits.
game_beh_chase_player::
    GAME_CHASE_PLAYER #1, #2
    CONDITIONS_END

;; Patrols between two world-X positions instead of relying on platform edges.
game_beh_patrol_positions::
    GAME_PATROL_X #12, #48, #1, #3
    CONDITIONS_END

;; Vertical flying patrol. It moves directly and therefore needs no physics.
game_beh_flying_enemy::
    GAME_FLY_Y #24, #96, #1, #2
    CONDITIONS_END

game_beh_shoot_speed: .db 0
game_beh_speed: .db 0
game_beh_stride: .db 0
game_beh_limit_min: .db 0
game_beh_limit_max: .db 0

.area _CODE

;; Non-blocking custom action. IX=current entity; DE=inline signed speed.
;;-----------------------------------------------------------------
;;
;; game_beh_action_shoot
;;
;;  Creates an enemy projectile and advances to the next behavior action.
;;  Input: IX = entity; DE = inline signed projectile speed
;;  Output: Does not return directly; continues through sys_beh_next
;;  Modified: AF, BC, DE, HL, IX
;;
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

;; Apply signed C as horizontal speed using game_beh_stride. IX=entity.
;; Returns to the caller when velocity has been selected for this tick.
;;-----------------------------------------------------------------
;;
;; game_beh_apply_horizontal_stride
;;
;;  Applies or delays a selected horizontal speed using the active behavior stride.
;;  Input: IX = entity; C = signed X speed
;;  Output:
;;  Modified: AF, B
;;
game_beh_apply_horizontal_stride:
    ld a, (game_beh_stride)
    or a
    jr z, gbahs_apply
    dec a
    jr z, gbahs_apply
    ld b, a
    ld a, e_beh_timer(ix)
    or a
    jr nz, gbahs_wait
    ld e_beh_timer(ix), b
gbahs_apply:
    ld e_speed_x(ix), c
    ld e_anim_timer(ix), #0
    ld e_moved(ix), #1
    ret
gbahs_wait:
    dec a
    ld e_beh_timer(ix), a
    ld e_speed_x(ix), #0
    ret

;; Blocking action: move horizontally toward the first entity (the player).
;; Inline args: positive speed magnitude, stride.
;;-----------------------------------------------------------------
;;
;; game_beh_action_chase_player
;;
;;  Selects horizontal velocity toward the player, respecting the inline stride.
;;  Input: IX = entity; DE = inline speed and stride bytes
;;  Output: Does not return directly; continues through sys_beh_check_conditions
;;  Modified: AF, BC, DE, HL
;;
game_beh_action_chase_player::
    ld a, (de)
    ld (game_beh_speed), a
    inc de
    ld a, (de)
    ld (game_beh_stride), a
    inc de

    push ix
    ld ix, #entity_array
    ld b, e_x(ix)
    pop ix
    ld a, e_x(ix)
    cp b
    jr c, gbacp_right
    jr z, gbacp_stop
gbacp_left:
    ld a, (game_beh_speed)
    neg
    ld c, a
    push de
    ld hl, #game_monk_walk_left_anim
    call sys_anim_set
    pop de
    jr gbacp_apply
gbacp_right:
    ld a, (game_beh_speed)
    ld c, a
    push de
    ld hl, #game_monk_walk_right_anim
    call sys_anim_set
    pop de
    jr gbacp_apply
gbacp_stop:
    ld c, #0
gbacp_apply:
    call game_beh_apply_horizontal_stride
    jp sys_beh_check_conditions

;; Blocking action: patrol between absolute world-X limits.
;; Inline args: left, right, positive speed magnitude, stride.
;; e_speed_x+1 stores direction: 0=right, 1=left.
;;-----------------------------------------------------------------
;;
;; game_beh_action_patrol_x
;;
;;  Patrols horizontally between inline world-X limits.
;;  Input: IX = entity; DE = inline left, right, speed and stride bytes
;;  Output: Does not return directly; continues through sys_beh_check_conditions
;;  Modified: AF, BC, DE, HL
;;
game_beh_action_patrol_x::
    ld a, (de)
    ld (game_beh_limit_min), a
    inc de
    ld a, (de)
    ld (game_beh_limit_max), a
    inc de
    ld a, (de)
    ld (game_beh_speed), a
    inc de
    ld a, (de)
    ld (game_beh_stride), a
    inc de

    ld a, e_x(ix)
    ld c, a
    ld a, (game_beh_limit_min)
    cp c
    jr nc, gbapx_face_right
    ld a, (game_beh_limit_max)
    cp c
    jr c, gbapx_face_left
    jr z, gbapx_face_left
    ld a, e_speed_x+1(ix)
    or a
    jr nz, gbapx_left
    jr gbapx_right

gbapx_face_right:
    ld e_speed_x+1(ix), #0
gbapx_right:
    ld a, (game_beh_speed)
    ld c, a
    push de
    ld hl, #game_monk_walk_right_anim
    call sys_anim_set
    pop de
    jr gbapx_apply
gbapx_face_left:
    ld e_speed_x+1(ix), #1
gbapx_left:
    ld a, (game_beh_speed)
    neg
    ld c, a
    push de
    ld hl, #game_monk_walk_left_anim
    call sys_anim_set
    pop de
gbapx_apply:
    call game_beh_apply_horizontal_stride
    jp sys_beh_check_conditions

;; Blocking action: direct vertical patrol, independent of gravity.
;; Inline args: top, bottom, positive step, stride.
;; e_speed_y+1 stores direction: 0=down, 1=up.
;;-----------------------------------------------------------------
;;
;; game_beh_action_fly_y
;;
;;  Moves a flying entity vertically between inline world-Y limits.
;;  Input: IX = entity; DE = inline top, bottom, speed and stride bytes
;;  Output: Does not return directly; continues through sys_beh_check_conditions
;;  Modified: AF, BC, DE, HL
;;
game_beh_action_fly_y::
    ld a, (de)
    ld (game_beh_limit_min), a
    inc de
    ld a, (de)
    ld (game_beh_limit_max), a
    inc de
    ld a, (de)
    ld (game_beh_speed), a
    inc de
    ld a, (de)
    ld (game_beh_stride), a
    inc de

    ld a, e_y(ix)
    ld c, a
    ld a, (game_beh_limit_min)
    cp c
    jr nc, gbafy_face_down
    ld a, (game_beh_limit_max)
    cp c
    jr c, gbafy_face_up
    jr z, gbafy_face_up
    jr gbafy_check_stride
gbafy_face_down:
    ld e_speed_y+1(ix), #0
    jr gbafy_check_stride
gbafy_face_up:
    ld e_speed_y+1(ix), #1

gbafy_check_stride:
    ld a, (game_beh_stride)
    or a
    jr z, gbafy_move
    dec a
    jr z, gbafy_move
    ld b, a
    ld a, e_beh_timer(ix)
    or a
    jr nz, gbafy_wait
    ld e_beh_timer(ix), b
gbafy_move:
    ld a, (game_beh_speed)
    ld c, a
    ld a, e_speed_y+1(ix)
    or a
    jr z, gbafy_down
    ld a, c
    neg
    ld c, a
gbafy_down:
    ld a, e_y(ix)
    add a, c
    ld e_y(ix), a
    ld e_speed_y(ix), c
    ld e_moved(ix), #1
    jp sys_beh_check_conditions
gbafy_wait:
    dec a
    ld e_beh_timer(ix), a
    ld e_speed_y(ix), #0
    jp sys_beh_check_conditions
