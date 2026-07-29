;;-------------------------------------------------------------------------------
;; Collision responses owned by model01. sys/collision only detects overlaps
;; and dispatches IX/IY to this registered callback.
.module game_collision

.include "game/collision.h.s"
.include "cpctelera.h.s"
.include "sys/collision.h.s"
.include "sys/entity.h.s"
.include "game/map.h.s"
.include "game/config.h.s"

COLLISION_BORDER_FLASH_FRAMES = 6

.area _DATA
game_collision_border_flash: .db 0

.area _CODE

;;-----------------------------------------------------------------
;;
;; game_collision_init
;;
;;  Clears collision feedback and registers the Model01 collision callback.
;;  Input:
;;  Output:
;;  Modified: AF, HL
;;
game_collision_init::
    xor a
    ld (game_collision_border_flash), a
    ld hl, #game_collision_on_hit
    jp sys_collision_set_handler

;; IX=collider, IY=collisionable. The engine dispatcher preserves both.
;;-----------------------------------------------------------------
;;
;; game_collision_on_hit
;;
;;  Applies projectile, player, enemy and portal collision rules.
;;  Input: IX = collider; IY = collisionable entity
;;  Output:
;;  Modified: AF, BC, DE, HL
;;
game_collision_on_hit::
    ld a, e_status(ix)
    cp #STATUS_PLAYER_BULLET
    jr nz, gcoh_check_enemy_bullet
    ld a, e_status(iy)
    cp #STATUS_ENEMY
    ret nz
    call sys_collision_destroy_entity
    push ix
    push iy
    pop ix
    call sys_collision_destroy_entity
    pop ix
    ret

gcoh_check_enemy_bullet:
    cp #STATUS_ENEMY_BULLET
    jr nz, gcoh_check_portal
    ld a, e_status(iy)
    cp #STATUS_PLAYER
    ret nz
    call sys_collision_destroy_entity
    ld a, #COLLISION_BORDER_FLASH_FRAMES
    ld (game_collision_border_flash), a
    cpctm_setBorder_asm HW_RED
    ret

gcoh_check_portal:
    ld a, e_status(ix)
    cp #STATUS_PLAYER
    ret nz
    ld a, e_status(iy)
    cp #STATUS_PORTAL
    ret nz
    ld a, e_on_air(iy)
    or a
    ret z
    jp game_map_do_portal_transition

;;-----------------------------------------------------------------
;;
;; game_collision_update_effects
;;
;;  Advances the timed red/black damage-border flash.
;;  Input:
;;  Output:
;;  Modified: AF, BC
;;
game_collision_update_effects::
    ld a, (game_collision_border_flash)
    or a
    ret z
    dec a
    ld (game_collision_border_flash), a
    jr z, gcue_black
    bit 0, a
    jr nz, gcue_black
    cpctm_setBorder_asm HW_RED
    ret
gcue_black:
    cpctm_setBorder_asm HW_BLACK
    ret
