;; Model01-specific assets, states and entity dimensions.

.globl _s_monk_0
.globl _s_monk_1
.globl _s_monk_2
.globl _s_monk_3
.globl _s_monk_4
.globl _s_monk_5
.globl _s_monk_6
.globl _s_obj_0
.globl _s_obj_1
.globl _s_obj_2
.globl _s_tileset_00
.globl _g_map01
.globl _g_map02
.globl _g_map03
.globl _g_map04
.globl _g_inside01

APP_STATE_MENU = 0x00
APP_STATE_GAME = 0x01
.globl app_state

STATUS_NORMAL        = 0x00
STATUS_PORTAL        = 0x01
STATUS_PLAYER        = 0x02
STATUS_ENEMY         = 0x03
STATUS_PLAYER_BULLET = 0x04
STATUS_ENEMY_BULLET  = 0x05

g_status_fight = 0x00
g_status_dead  = 0xff

S_MONK_WIDTH  = 5
S_MONK_HEIGHT = 16

S_BULLET_WIDTH  = 4
S_BULLET_HEIGHT = 8

