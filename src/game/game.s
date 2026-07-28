;; Model01 lifecycle and system orchestration.
.module model01_game

.include "game/game.h.s"
.include "cpctelera.h.s"
.include "common.h.s"
.include "game/config.h.s"
.include "sys/entity.h.s"
.include "sys/render.h.s"
.include "sys/physics.h.s"
.include "sys/input.h.s"
.include "sys/collision.h.s"
.include "sys/anim.h.s"
.include "sys/beh.h.s"
.include "sys/mem.h.s"
.include "sys/shoot.h.s"
.include "sys/messages.h.s"
.include "sys/text.h.s"
.include "game/collision.h.s"
.include "game/entities.h.s"
.include "game/input.h.s"
.include "game/map.h.s"
.include "game/menu.h.s"


.area _DATA

game_quit_dialog_active: .db 0
game_quit_dialog_response: .db 0
game_quit_message: .asciz "QUIT TO MAIN MENU?  Y / N"

.area _CODE

game_init::
    xor a
    ld (game_quit_dialog_active), a
    ld (game_quit_dialog_response), a
    call sys_mem_init
    call sys_entity_init
    call sys_input_init
    call game_input_init
    call sys_collision_init
    call game_collision_init
    call game_entity_create_player
    call game_entity_create_patrol_enemy
    ld hl, #_s_font_0
    ld de, #_s_small_numbers_00
    call sys_text_init
    ld hl, #_g_palette0
    call sys_render_init
    call game_map_init
    call sys_shoot_init
    call sys_map_draw
    ret

game_update::
    ld a, (game_quit_dialog_active)
    or a
    jp nz, game_update_quit_dialog
    call sys_physics_update
    call sys_shoot_update
    call game_map_update_transition
    ld ix, #entity_array
    call game_input_update
    call sys_beh_update
    call game_collision_update_effects
    call sys_collision_update
    call sys_anim_update
    call sys_render_prepare
    call cpct_waitVSYNC_asm
    call sys_render_update
    ld a, (game_quit_dialog_active)
    or a
    call nz, game_draw_quit_dialog
    ret

game_update_quit_dialog:
    call game_input_quit_dialog_update
    ld a, (game_quit_dialog_response)
    cp #1
    jr z, game_apply_quit_cancel
    cp #2
    jr z, game_apply_quit_confirm
    call cpct_waitVSYNC_asm
    ret

game_apply_quit_cancel:
    xor a
    ld (game_quit_dialog_active), a
    ld (game_quit_dialog_response), a
    call sys_messages_close
    call cpct_waitVSYNC_asm
    ret

game_apply_quit_confirm:
    call sys_input_clean_buffer
    call game_menu_init
    call cpct_waitVSYNC_asm
    ret

game_request_quit::
    ld a, #1
    ld (game_quit_dialog_active), a
    xor a
    ld (game_quit_dialog_response), a
    ret

game_draw_quit_dialog:
    xor a
    ex af, af'
    xor a
    ex af, af'
    ld de, #70 * 256
    ld bc, #48 * 256
    ld hl, #game_quit_message
    jp sys_messages_show

game_cancel_quit::
    ld a, #1
    ld (game_quit_dialog_response), a
    ret

game_confirm_quit::
    ld a, #2
    ld (game_quit_dialog_response), a
    ret
