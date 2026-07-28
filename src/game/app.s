;; Model01 application adapter consumed by the generic bootstrap in main.s.
.module game_app

.include "globals.inc"
.include "game/config.h.s"

.area _DATA

_game_loaded_string: .asciz " GAME LOADED - V.073"
app_state:: .db APP_STATE_MENU

.area _CODE

game_app_init::
    jp game_menu_init

game_app_update::
    ld a, (app_state)
    or a
    jp z, game_menu_update
    jp game_update
