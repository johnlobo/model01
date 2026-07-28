;; Key bindings and player controls owned by Model01.
.module game_input

.include "cpctelera.h.s"
.include "globals.inc"
.include "game/config.h.s"
.include "sys/entity.h.s"
.include "sys/anim.h.s"

JUMP_SPEED_MIN = -6
JUMP_SPEED_MAX = -12
JUMP_BOOST_FRAMES = 6
PLAYER_BULLET_SPEED = 2
PLAYER_SHOOT_COOLDOWN = 10

.area _DATA

game_input_key_actions:
    .dw Key_O, game_input_left
    .dw Key_P, game_input_right
    .dw Key_Q, game_input_jump
    .dw Key_Space, game_input_shoot
    .dw Key_Esc, game_request_quit
    .dw 0

game_input_quit_actions:
    .dw Key_Y, game_confirm_quit
    .dw Key_N, game_cancel_quit
    .dw 0

game_input_jump_boost_left: .db 0
game_input_facing: .db 0             ;; 0=right, 1=left
game_input_shoot_cooldown: .db 0
game_input_direction_pressed: .db 0

.area _CODE

game_input_init::
    xor a
    ld (game_input_jump_boost_left), a
    ld (game_input_facing), a
    ld (game_input_shoot_cooldown), a
    ld (game_input_direction_pressed), a
    ret

game_input_left:
    ld e_speed_x(ix), #-2
    ld a, #1
    ld (game_input_facing), a
    ld (game_input_direction_pressed), a
    ld hl, #game_monk_walk_left_anim
    jp sys_anim_set

game_input_right:
    ld e_speed_x(ix), #2
    xor a
    ld (game_input_facing), a
    inc a
    ld (game_input_direction_pressed), a
    ld hl, #game_monk_walk_right_anim
    jp sys_anim_set

game_input_jump:
    ld a, e_on_air(ix)
    or a
    jr nz, game_input_jump_boost
    ld e_speed_y(ix), #JUMP_SPEED_MIN
    ld e_on_air(ix), #1
    ld a, #JUMP_BOOST_FRAMES
    ld (game_input_jump_boost_left), a
    ret

game_input_jump_boost:
    ld a, e_speed_y(ix)
    bit 7, a
    ret z
    ld a, (game_input_jump_boost_left)
    or a
    ret z
    ld a, e_speed_y(ix)
    cp #JUMP_SPEED_MAX
    ret c
    ret z
    dec a
    ld e_speed_y(ix), a
    ld a, (game_input_jump_boost_left)
    dec a
    ld (game_input_jump_boost_left), a
    ret

game_input_shoot:
    ld a, (game_input_shoot_cooldown)
    or a
    ret nz
    push ix
    ld a, e_y(ix)
    add a, #((S_MONK_HEIGHT - S_BULLET_HEIGHT) / 2)
    ld c, a
    ld a, e_room(ix)
    ld d, a
    ld a, (game_input_facing)
    or a
    jr nz, game_input_shoot_left
    ld a, e_x(ix)
    add a, e_width(ix)
    ld b, a
    ld e, #PLAYER_BULLET_SPEED
    jr game_input_shoot_create
game_input_shoot_left:
    ld a, e_x(ix)
    sub #S_BULLET_WIDTH
    ld b, a
    ld e, #-PLAYER_BULLET_SPEED
game_input_shoot_create:
    call game_entity_create_player_bullet
    jr c, game_input_shoot_done
    ld a, #PLAYER_SHOOT_COOLDOWN
    ld (game_input_shoot_cooldown), a
game_input_shoot_done:
    pop ix
    ret

game_input_update::
    ld a, (game_input_shoot_cooldown)
    or a
    jr z, game_input_no_cooldown
    dec a
    ld (game_input_shoot_cooldown), a
game_input_no_cooldown:
    xor a
    ld (game_input_direction_pressed), a
    ld iy, #game_input_key_actions
    call sys_input_generic_update
    ld a, (game_input_direction_pressed)
    or a
    ret nz
    ld hl, #game_monk_idle_anim
    jp sys_anim_set

game_input_quit_dialog_update::
    ld iy, #game_input_quit_actions
    jp sys_input_generic_update
