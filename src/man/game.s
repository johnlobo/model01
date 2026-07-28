;;-----------------------------LICENSE NOTICE------------------------------------
;;
;;  This program is free software: you can redistribute it and/or modify
;;  it under the terms of the GNU Lesser General Public License as published by
;;  the Free Software Foundation, either version 3 of the License, or
;;  (at your option) any later version.
;;
;;  This program is distributed in the hope that it will be useful,
;;  but WITHOUT ANY WARRANTY; without even the implied warranty of
;;  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;;  GNU Lesser General Public License for more details.
;;
;;  You should have received a copy of the GNU Lesser General Public License
;;  along with this program.  If not, see <http://www.gnu.org/licenses/>.
;;-------------------------------------------------------------------------------
.module game_manager

.include "sys/array.h.s"
.include "cpctelera.h.s"
.include "common.h.s"
.include "sys/render.h.s"
.include "sys/physics.h.s"
.include "sys/input.h.s"
.include "sys/collision.h.s"
.include "sys/anim.h.s"
.include "sys/beh.h.s"
.include "sys/mem.h.s"
.include "sys/shoot.h.s"
.include "sys/messages.h.s"
.include "game/collision.h.s"
.include "game/entities.h.s"
.include "game/input.h.s"
.include "game/map.h.s"
.include "game/menu.h.s"
.include "man/entity.h.s"

.area _DATA

man_game_quit_dialog_active: .db 0
man_game_quit_dialog_response: .db 0
man_game_quit_message: .asciz "QUIT TO MAIN MENU?  Y / N"

.area _CODE

man_game_init::
    xor a
    ld (man_game_quit_dialog_active), a
    ld (man_game_quit_dialog_response), a
    call sys_mem_init
    call man_entity_init
    call sys_input_init
    call game_input_init
    call sys_collision_init
    call game_collision_init
    call game_entity_create_player
    call game_entity_create_patrol_enemy
    call sys_render_init
    call game_map_init
    call sys_shoot_init
    call sys_map_draw
    ret

man_game_update::
    ld a, (man_game_quit_dialog_active)
    or a
    jp nz, man_game_update_quit_dialog
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
    ld a, (man_game_quit_dialog_active)
    or a
    call nz, man_game_draw_quit_dialog
    ret

man_game_update_quit_dialog:
    call game_input_quit_dialog_update
    ld a, (man_game_quit_dialog_response)
    cp #1
    jr z, man_game_apply_quit_cancel
    cp #2
    jr z, man_game_apply_quit_confirm
    call cpct_waitVSYNC_asm
    ret

man_game_apply_quit_cancel:
    xor a
    ld (man_game_quit_dialog_active), a
    ld (man_game_quit_dialog_response), a
    call sys_messages_close
    call cpct_waitVSYNC_asm
    ret

man_game_apply_quit_confirm:
    call sys_input_clean_buffer
    call game_menu_init
    call cpct_waitVSYNC_asm
    ret

man_game_request_quit::
    ld a, #1
    ld (man_game_quit_dialog_active), a
    xor a
    ld (man_game_quit_dialog_response), a
    ret

man_game_draw_quit_dialog:
    xor a
    ex af, af'
    xor a
    ex af, af'
    ld de, #70 * 256
    ld bc, #48 * 256
    ld hl, #man_game_quit_message
    call sys_messages_show
    ret

man_game_cancel_quit::
    ld a, #1
    ld (man_game_quit_dialog_response), a
    ret

man_game_confirm_quit::
    ld a, #2
    ld (man_game_quit_dialog_response), a
    ret
