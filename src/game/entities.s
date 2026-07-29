;; Entity types, templates and factories owned by Model01.
.module game_entities

.include "game/behaviors.h.s"
.include "sys/entity.h.s"
.include "sys/shoot.h.s"
.include "globals.inc"
.include "../config.h.s"
.include "game/config.h.s"

.area _DATA

game_monk_idle_anim::
    .db 1
    .db 0
    .dw _s_monk_0

game_monk_walk_right_anim::
    .db 4
    .db 8
    .dw _s_monk_1
    .dw _s_monk_2
    .dw _s_monk_3
    .dw _s_monk_2

game_monk_walk_left_anim::
    .db 4
    .db 8
    .dw _s_monk_4
    .dw _s_monk_5
    .dw _s_monk_6
    .dw _s_monk_5

game_player_template:
DefineEntity c_cmp_invalid, 0, 10, 16, 0, 0, 0, 0, 1, S_MONK_WIDTH, S_MONK_HEIGHT, 15, _s_monk_0, 0

game_patrol_enemy_template:
DefineEntity c_cmp_invalid, 0, 32, 24, 0, 0, 0, 0, 0, S_MONK_WIDTH, S_MONK_HEIGHT, 15, _s_monk_1, 0

game_object_template::
DefineEntity c_cmp_invalid, 0, 0, 0, 0, 0, 0, 0, 0, S_MONK_WIDTH, S_MONK_HEIGHT, 15, _s_monk_0, 0

game_portal_template::
DefineEntity c_cmp_invalid, 0, 0, 0, 0, 0, 0, 0, 0, S_MONK_WIDTH, S_MONK_HEIGHT, 15, _s_monk_6, 0

game_player_bullet_template::
DefineEntity c_cmp_invalid, 0, 0, 0, 0, 0, 0, 0, 0, S_BULLET_WIDTH, S_BULLET_HEIGHT, 15, _s_obj_1, 0

game_enemy_bullet_template:
DefineEntity c_cmp_invalid, 0, 0, 0, 0, 0, 0, 0, 0, S_BULLET_WIDTH, S_BULLET_HEIGHT, 15, _s_obj_2, 0

.area _CODE

;;-----------------------------------------------------------------
;;
;; game_entity_create_player
;;
;;  Creates the initial player entity from its template.
;;  Input:
;;  Output: IX = entity and carry clear on success; carry set when the pool is full
;;  Modified: AF, BC, DE, HL, IX
;;
game_entity_create_player::
    ld hl, #game_player_template
    call sys_entity_create
    ret c
    ld e_cmps(ix), #(c_cmp_render | c_cmp_movable | c_cmp_collider | c_cmp_collisionable | c_cmp_input | c_cmp_animated)
    ld e_status(ix), #STATUS_PLAYER
    ld e_moved(ix), #1
    ld hl, #game_monk_idle_anim
    ld e_anim(ix), l
    ld e_anim+1(ix), h
    or a
    ret

;;-----------------------------------------------------------------
;;
;; game_entity_create_patrol_enemy
;;
;;  Creates the default edge-patrolling enemy.
;;  Input:
;;  Output: IX = entity and carry clear on success; carry set when the pool is full
;;  Modified: AF, BC, DE, HL, IX
;;
game_entity_create_patrol_enemy::
    ld hl, #game_patrol_enemy_template
    call sys_entity_create
    ret c
    ld e_cmps(ix), #(c_cmp_render | c_cmp_movable | c_cmp_behavior | c_cmp_animated | c_cmp_collisionable)
    ld e_status(ix), #STATUS_ENEMY
    ld e_moved(ix), #1
    ld hl, #game_monk_walk_right_anim
    ld e_anim(ix), l
    ld e_anim+1(ix), h
    ld hl, #game_beh_patrol
    ld e_beh(ix), l
    ld e_beh+1(ix), h
    or a
    ret

;; B=x, C=y, D=room. Creates a grounded enemy with behavior HL.
;;-----------------------------------------------------------------
;;
;; game_entity_create_ground_behavior_enemy
;;
;;  Creates a grounded enemy using a supplied behavior program.
;;  Input: B = world X; C = world Y; D = room id; HL = behavior address
;;  Output: IX = entity and carry clear on success; carry set when the pool is full
;;  Modified: AF, BC, DE, HL, IX
;;
game_entity_create_ground_behavior_enemy:
    push bc
    push de
    push hl
    ld hl, #game_patrol_enemy_template
    call sys_entity_create
    jr c, gece_ground_full
    pop hl
    pop de
    pop bc
    ld e_cmps(ix), #(c_cmp_render | c_cmp_movable | c_cmp_behavior | c_cmp_animated | c_cmp_collisionable)
    ld e_status(ix), #STATUS_ENEMY
    ld e_x(ix), b
    ld e_y(ix), c
    ld e_room(ix), d
    ld e_moved(ix), #1
    push hl
    ld hl, #game_monk_walk_right_anim
    ld e_anim(ix), l
    ld e_anim+1(ix), h
    pop hl
    ld e_beh(ix), l
    ld e_beh+1(ix), h
    or a
    ret
gece_ground_full:
    pop hl
    pop de
    pop bc
    scf
    ret

;;-----------------------------------------------------------------
;;
;; game_entity_create_chaser_enemy
;;
;;  Creates a grounded enemy that follows the player horizontally.
;;  Input: B = world X; C = world Y; D = room id
;;  Output: IX = entity and carry clear on success; carry set when the pool is full
;;  Modified: AF, BC, DE, HL, IX
;;
game_entity_create_chaser_enemy::
    ld hl, #game_beh_chase_player
    jp game_entity_create_ground_behavior_enemy

;;-----------------------------------------------------------------
;;
;; game_entity_create_position_patrol_enemy
;;
;;  Creates a grounded enemy that patrols between configured X limits.
;;  Input: B = world X; C = world Y; D = room id
;;  Output: IX = entity and carry clear on success; carry set when the pool is full
;;  Modified: AF, BC, DE, HL, IX
;;
game_entity_create_position_patrol_enemy::
    ld hl, #game_beh_patrol_positions
    jp game_entity_create_ground_behavior_enemy

;; B=x, C=y, D=room. No c_cmp_movable: behavior owns vertical motion.
;;-----------------------------------------------------------------
;;
;; game_entity_create_flying_enemy
;;
;;  Creates a behavior-driven flying enemy without the movable component.
;;  Input: B = world X; C = world Y; D = room id
;;  Output: IX = entity and carry clear on success; carry set when the pool is full
;;  Modified: AF, BC, DE, HL, IX
;;
game_entity_create_flying_enemy::
    push bc
    push de
    ld hl, #game_patrol_enemy_template
    call sys_entity_create
    jr c, gece_flying_full
    pop de
    pop bc
    ld e_cmps(ix), #(c_cmp_render | c_cmp_behavior | c_cmp_animated | c_cmp_collisionable)
    ld e_status(ix), #STATUS_ENEMY
    ld e_x(ix), b
    ld e_y(ix), c
    ld e_room(ix), d
    ld e_on_air(ix), #1
    ld e_moved(ix), #1
    ld hl, #game_monk_walk_right_anim
    ld e_anim(ix), l
    ld e_anim+1(ix), h
    ld hl, #game_beh_flying_enemy
    ld e_beh(ix), l
    ld e_beh+1(ix), h
    or a
    ret
gece_flying_full:
    pop de
    pop bc
    scf
    ret

;;-----------------------------------------------------------------
;;
;; game_entity_create_object
;;
;;  Creates a renderable collision target at a world position.
;;  Input: B = world X; C = world Y; D = room id
;;  Output: IX = entity and carry clear on success; carry set when the pool is full
;;  Modified: AF, BC, DE, HL, IX
;;
game_entity_create_object::
    push bc
    push de
    ld hl, #game_object_template
    call sys_entity_create
    jr c, gec_object_full
    pop de
    pop bc
    ld e_cmps(ix), #(c_cmp_render | c_cmp_collisionable)
    ld e_x(ix), b
    ld e_y(ix), c
    ld e_room(ix), d
    ld e_moved(ix), #1
    or a
    ret
gec_object_full:
    pop de
    pop bc
    scf
    ret

;;-----------------------------------------------------------------
;;
;; game_entity_create_portal
;;
;;  Creates a non-rendered portal trigger volume.
;;  Input: B = world X; C = world Y; D = room id
;;  Output: IX = entity and carry clear on success; carry set when the pool is full
;;  Modified: AF, BC, DE, HL, IX
;;
game_entity_create_portal::
    push bc
    push de
    ld hl, #game_portal_template
    call sys_entity_create
    jr c, gec_portal_full
    pop de
    pop bc
    ;; Portals are trigger volumes placed over doors drawn by the tilemap.
    ;; Keeping them non-renderable also decouples their 4x16 hitbox from any
    ;; particular sprite dimensions.
    ld e_cmps(ix), #c_cmp_collisionable
    ld e_status(ix), #STATUS_PORTAL
    ld e_x(ix), b
    ld e_y(ix), c
    ld e_width(ix), #4
    ld e_height(ix), #16
    ld e_room(ix), d
    ld e_moved(ix), #1
    or a
    ret
gec_portal_full:
    pop de
    pop bc
    scf
    ret

;;-----------------------------------------------------------------
;;
;; game_entity_create_player_bullet
;;
;;  Creates a player projectile with the configured stride.
;;  Input: B = world X; C = world Y; D = room id; E = signed X speed
;;  Output: IX = entity and carry clear on success; carry set for invalid coordinates or a full pool
;;  Modified: AF, BC, DE, HL, IX
;;
game_entity_create_player_bullet::
    ld hl, #game_player_bullet_template
    call game_entity_create_bullet
    ret c
    ld e_status(ix), #STATUS_PLAYER_BULLET
    ld e_speed_x+1(ix), #PLAYER_BULLET_STRIDE
    ld e_beh_timer(ix), #(PLAYER_BULLET_STRIDE - 1)
    or a
    ret

;;-----------------------------------------------------------------
;;
;; game_entity_create_enemy_bullet
;;
;;  Creates an enemy projectile with the configured stride.
;;  Input: B = world X; C = world Y; D = room id; E = signed X speed
;;  Output: IX = entity and carry clear on success; carry set for invalid coordinates or a full pool
;;  Modified: AF, BC, DE, HL, IX
;;
game_entity_create_enemy_bullet::
    ld hl, #game_enemy_bullet_template
    call game_entity_create_bullet
    ret c
    ld e_status(ix), #STATUS_ENEMY_BULLET
    ld e_speed_x+1(ix), #ENEMY_BULLET_STRIDE
    ld e_beh_timer(ix), #(ENEMY_BULLET_STRIDE - 1)
    or a
    ret

;;-----------------------------------------------------------------
;;
;; game_entity_create_bullet
;;
;;  Validates coordinates and creates a generic projectile from a template.
;;  Input: HL = bullet template; B = world X; C = world Y; D = room id; E = signed X speed
;;  Output: IX = entity and carry clear on success; carry set for invalid coordinates or a full pool
;;  Modified: AF, BC, DE, HL, IX
;;
game_entity_create_bullet:
    ld a, b
    bit 7, a
    jr nz, gec_bullet_invalid
    add a, #S_BULLET_WIDTH
    cp #(MAP_WIDTH * 4 + 1)
    jr nc, gec_bullet_invalid

    push bc
    push de
    call sys_entity_create
    jr c, gec_bullet_full
    pop de
    pop bc
    ld e_cmps(ix), #(c_cmp_render | c_cmp_projectile | c_cmp_collider)
    ld e_x(ix), b
    ld e_y(ix), c
    ld e_room(ix), d
    ld e_speed_x(ix), e
    ld e_moved(ix), #1
    or a
    ret
gec_bullet_full:
    pop de
    pop bc
gec_bullet_invalid:
    scf
    ret
