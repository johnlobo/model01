.module menu_input_system

.include "cpctelera.h.s"
.include "common.h.s"
.include "sys/input.h.s"
.include "man/menu.h.s"

.area _DATA

menu_input_locked: .db 0

menu_key_actions:
    .dw Key_CursorUp,    man_menu_select_previous
    .dw Key_CursorLeft,  man_menu_select_previous
    .dw Key_CursorDown,  man_menu_select_next
    .dw Key_CursorRight, man_menu_select_next
    .dw Key_Return,      man_menu_activate
    .dw Key_Enter,       man_menu_activate
    .dw 0

.area _CODE

sys_menu_input_init::
    xor a
    ld (menu_input_locked), a
    ret

;; Use the game's generic key/action dispatcher. The release latch prevents a
;; held cursor key from cycling through the menu every frame.
sys_menu_input_update::
    ld a, (menu_input_locked)
    or a
    jr z, smiu_scan
    call cpct_isAnyKeyPressed_asm
    ret nz
    xor a
    ld (menu_input_locked), a
smiu_scan:
    ld iy, #menu_key_actions
    call sys_input_generic_update
    ret

sys_menu_input_lock::
    ld a, #1
    ld (menu_input_locked), a
    ret
