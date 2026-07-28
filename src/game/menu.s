;; Main menu, bindings and actions owned by Model01.
.module game_menu

.include "game/menu.h.s"
.include "cpctelera.h.s"
.include "common.h.s"
.include "game/config.h.s"
.include "sys/render.h.s"
.include "sys/text.h.s"
.include "sys/input.h.s"
.include "game/game.h.s"

MENU_OPTION_HELP = 0
MENU_OPTION_START = 1

.area _DATA

game_menu_selected: .db MENU_OPTION_START
game_menu_start_requested: .db 0
game_menu_input_locked: .db 0
game_menu_title: .asciz "MODEL 01"
game_menu_version: .asciz "VERSION - V.063"
game_menu_help: .asciz "HELP"
game_menu_start: .asciz "START"

game_menu_key_actions:
    .dw Key_CursorUp, game_menu_select_previous
    .dw Key_CursorLeft, game_menu_select_previous
    .dw Key_CursorDown, game_menu_select_next
    .dw Key_CursorRight, game_menu_select_next
    .dw Key_Return, game_menu_activate
    .dw Key_Enter, game_menu_activate
    .dw 0

.area _CODE

game_menu_init::
    xor a
    ld (app_state), a
    ld (game_menu_start_requested), a
    ld (game_menu_input_locked), a
    ld a, #MENU_OPTION_START
    ld (game_menu_selected), a
    ld hl, #_g_palette0
    call sys_render_init
    call game_menu_draw
    ret

game_menu_update::
    call cpct_waitVSYNC_asm
    call game_menu_input_update
    ld a, (game_menu_start_requested)
    or a
    ret z
    call sys_input_clean_buffer
    xor a
    ld (game_menu_start_requested), a
    call game_init
    ld a, #APP_STATE_GAME
    ld (app_state), a
    ret

game_menu_input_update:
    ld a, (game_menu_input_locked)
    or a
    jr z, gmiu_scan
    call cpct_isAnyKeyPressed_asm
    ret nz
    xor a
    ld (game_menu_input_locked), a
gmiu_scan:
    ld iy, #game_menu_key_actions
    jp sys_input_generic_update

game_menu_input_lock:
    ld a, #1
    ld (game_menu_input_locked), a
    ret

game_menu_select_previous:
    xor a
    ld (game_menu_selected), a
    call game_menu_input_lock
    jp game_menu_draw_options

game_menu_select_next:
    ld a, #MENU_OPTION_START
    ld (game_menu_selected), a
    call game_menu_input_lock
    jp game_menu_draw_options

game_menu_activate:
    call game_menu_input_lock
    ld a, (game_menu_selected)
    or a
    ret z
    ld a, #1
    ld (game_menu_start_requested), a
    ret

game_menu_draw:
    call sys_render_clear_front_buffer
    ld c, #0
    ld hl, #game_menu_title
    cpctm_screenPtr_asm DE, FRONT_BUFFER, 31, 40
    call sys_text_draw_string
    ld c, #0
    ld hl, #game_menu_version
    cpctm_screenPtr_asm DE, FRONT_BUFFER, 25, 184
    call sys_text_draw_string
    jp game_menu_draw_options

game_menu_draw_options:
    ld a, (game_menu_selected)
    or a
    jr nz, gmdo_start_selected
    ld c, #1
    ld hl, #game_menu_help
    cpctm_screenPtr_asm DE, FRONT_BUFFER, 34, 88
    call sys_text_draw_string
    ld c, #0
    ld hl, #game_menu_start
    cpctm_screenPtr_asm DE, FRONT_BUFFER, 34, 112
    jp sys_text_draw_string

gmdo_start_selected:
    ld c, #0
    ld hl, #game_menu_help
    cpctm_screenPtr_asm DE, FRONT_BUFFER, 34, 88
    call sys_text_draw_string
    ld c, #1
    ld hl, #game_menu_start
    cpctm_screenPtr_asm DE, FRONT_BUFFER, 34, 112
    jp sys_text_draw_string
