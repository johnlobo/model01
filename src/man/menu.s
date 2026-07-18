.module menu_manager

.include "cpctelera.h.s"
.include "common.h.s"
.include "sys/render.h.s"
.include "sys/text.h.s"
.include "sys/input.h.s"
.include "sys/menu_input.h.s"
.include "man/game.h.s"

.area _DATA

MENU_OPTION_HELP  = 0
MENU_OPTION_START = 1

menu_selected: .db MENU_OPTION_START
menu_start_requested: .db 0
menu_title:    .asciz "MODEL 01"
menu_help:     .asciz "HELP"
menu_start:    .asciz "START"

.area _CODE

man_menu_init::
    xor a
    ld (app_state), a
    ld a, #MENU_OPTION_START
    ld (menu_selected), a
    xor a
    ld (menu_start_requested), a
    call sys_render_init
    call sys_menu_input_init
    call man_menu_draw
    ret

man_menu_update::
    call cpct_waitVSYNC_asm
    call sys_menu_input_update
    ld a, (menu_start_requested)
    or a
    ret z
    call sys_input_clean_buffer
    xor a
    ld (menu_start_requested), a
    call man_game_init
    ld a, #APP_STATE_GAME
    ld (app_state), a
    ret

man_menu_select_previous::
    xor a
    ld (menu_selected), a
    call sys_menu_input_lock
    jp man_menu_draw_options

man_menu_select_next::
    ld a, #MENU_OPTION_START
    ld (menu_selected), a
    call sys_menu_input_lock
    jp man_menu_draw_options

man_menu_activate::
    call sys_menu_input_lock
    ld a, (menu_selected)
    or a
    ret z                           ;; HELP: intentionally no action yet
    ld a, #1
    ld (menu_start_requested), a
    ret

man_menu_draw:
    call sys_render_clear_front_buffer

    ld c, #0
    ld hl, #menu_title
    cpctm_screenPtr_asm DE, FRONT_BUFFER, 31, 40
    call sys_text_draw_string

    ld c, #0
    ld hl, #_welcome_string
    cpctm_screenPtr_asm DE, FRONT_BUFFER, 25, 184
    call sys_text_draw_string

    jp man_menu_draw_options

;; Redraw only the two option labels. Colour 1 is bright yellow in the text
;; colour table; colour 0 is the normal bright white.
man_menu_draw_options:
    ld a, (menu_selected)
    or a
    jr nz, mmdo_start_selected

    ld c, #1
    ld hl, #menu_help
    cpctm_screenPtr_asm DE, FRONT_BUFFER, 34, 88
    call sys_text_draw_string

    ld c, #0
    ld hl, #menu_start
    cpctm_screenPtr_asm DE, FRONT_BUFFER, 34, 112
    call sys_text_draw_string
    ret

mmdo_start_selected:
    ld c, #0
    ld hl, #menu_help
    cpctm_screenPtr_asm DE, FRONT_BUFFER, 34, 88
    call sys_text_draw_string

    ld c, #1
    ld hl, #menu_start
    cpctm_screenPtr_asm DE, FRONT_BUFFER, 34, 112
    call sys_text_draw_string
    ret
