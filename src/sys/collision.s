;;-------------------------------------------------------------------------------
.module collision_system

.include "sys/array.h.s"
.include "common.h.s"
.include "sys/collision.h.s"
.include "sys/map.h.s"
.include "sys/entity.h.s"

;;
;; Start of _DATA area
;;
.area _DATA

collision_handler: .dw sys_collision_noop

;;
;; Start of _CODE area
;;
.area _CODE

;;-----------------------------------------------------------------
;;
;; sys_collision_init
;;
;;  Initializes the collision system with a no-op response handler.
;;  Input:
;;  Output:
;;  Modified:
;;
sys_collision_init::
    ld hl, #sys_collision_noop
    ld (collision_handler), hl
    ret

;;-----------------------------------------------------------------
;; Register the game callback invoked for every detected collision.
;; Input: HL = handler (IX=collider, IY=collisionable), or 0 for no-op.
;; The dispatcher preserves IX and IY around the callback.
sys_collision_set_handler::
    ld a, h
    or l
    jr nz, scsh_store
    ld hl, #sys_collision_noop
scsh_store:
    ld (collision_handler), hl
    ret

;;-----------------------------------------------------------------
;; Erase an entity's last rendered sprite and invalidate its pool slot.
;; Input: IX = entity. IX is preserved.
sys_collision_destroy_entity::
    ld a, e_p_address(ix)
    or e_p_address+1(ix)
    jr z, scde_invalidate
    ld b, e_p_y(ix)
    ld c, e_p_x(ix)
    ld d, e_height(ix)
    ld e, e_width(ix)
    push ix
    call sys_map_restore_tiles_at
    pop ix
scde_invalidate:
    ld e_cmps(ix), #c_cmp_invalid
    ret

;;-----------------------------------------------------------------
;;
;; sys_collision_on_hit
;;
;;  Dispatches a detected collision to the registered game handler.
;;  Input:  IX = collider entity, IY = collisionable entity
;;  Output: IX and IY preserved
;;  Modified: AF, BC, DE, HL (as modified by the registered handler)
;;
sys_collision_on_hit::
    push ix
    push iy
    ld hl, #scoh_return
    push hl
    ld hl, (collision_handler)
    jp (hl)
scoh_return:
    pop iy
    pop ix
    ret

sys_collision_noop:
    ret

;;-----------------------------------------------------------------
;;
;; sys_collision_check_pair
;;
;;  AABB collision check between one collider and one collisionable.
;;  Input:  ix: collider entity
;;          iy: collisionable entity
;;  Output:
;;  Modified: AF, B
;;
sys_collision_check_pair::

    ;; --- X axis: ix_x + ix_width > iy_x ---
    ld a, e_x(ix)
    add a, e_width(ix)      ;; a = ix_right
    ld b, a
    ld a, e_x(iy)           ;; a = iy_left
    cp b
    ret nc                  ;; iy_left >= ix_right -> no overlap

    ;; --- X axis: ix_x < iy_x + iy_width ---
    ld a, e_x(iy)
    add a, e_width(iy)      ;; a = iy_right
    ld b, a
    ld a, e_x(ix)           ;; a = ix_left
    cp b
    ret nc                  ;; ix_left >= iy_right -> no overlap

    ;; --- Y axis: ix_y + ix_height > iy_y ---
    ld a, e_y(ix)
    add a, e_height(ix)     ;; a = ix_bottom
    ld b, a
    ld a, e_y(iy)           ;; a = iy_top
    cp b
    ret nc                  ;; iy_top >= ix_bottom -> no overlap

    ;; --- Y axis: ix_y < iy_y + iy_height ---
    ld a, e_y(iy)
    add a, e_height(iy)     ;; a = iy_bottom
    ld b, a
    ld a, e_y(ix)           ;; a = ix_top
    cp b
    ret nc                  ;; ix_top >= iy_bottom -> no overlap

    ;; Collision detected
    call sys_collision_on_hit
    ret

;;-----------------------------------------------------------------
;;
;; sys_collision_check_one_collider
;;
;;  For one collider (IX), iterates all collisionable entities (IY)
;;  and calls sys_collision_check_pair for each candidate.
;;
;;  NOTE: inner IY loop is written manually to avoid corrupting the
;;  shared comp_size/pattern variables used by the outer IX loop.
;;
;;  Input:  ix: collider entity
;;  Output:
;;  Modified: AF, B, DE, HL, IY
;;
sys_collision_check_one_collider::
    ld a, (current_room)
    cp e_room(ix)
    ret nz              ;; collider not in current room: skip

    ld iy, #entities
    ld a, a_count(iy)       ;; number of entities in array
    or a
    ret z

    ld b, a                 ;; b = loop counter

    push iy                 ;; advance IY from array header to first entity
    pop hl
    ld de, #a_array
    add hl, de
    push hl
    pop iy                  ;; IY = first entity

sccoc_loop:
    push bc

    ;; Check if entity has c_cmp_collisionable
    ld a, x_cmps(iy)
    and #c_cmp_collisionable
    cp #c_cmp_collisionable
    jr nz, sccoc_next

    ;; Skip if IX == IY (collider must not check against itself)
    push ix
    pop hl
    push iy
    pop de
    ld a, h
    cp d
    jr nz, sccoc_check
    ld a, l
    cp e
    jr z, sccoc_next

sccoc_check:
    ld a, (current_room)
    cp e_room(iy)
    jr nz, sccoc_next   ;; collisionable not in current room: skip

    call sys_collision_check_pair
    ld a, e_cmps(ix)
    or a
    jr z, sccoc_collider_destroyed

sccoc_next:
    ld de, #sizeof_e        ;; advance IY to next entity
    add iy, de
    pop bc
    djnz sccoc_loop

    ret

sccoc_collider_destroyed:
    pop bc
    ret

;;-----------------------------------------------------------------
;;
;; sys_collision_update
;;
;;  Iterates all collider entities (IX) and for each one checks
;;  against all collisionable entities (IY).
;;  Input:
;;  Output:
;;  Modified: AF, BC, DE, HL, IX, IY
;;
sys_collision_update::
    ld ix, #entities
    ld b, #c_cmp_collider
    ld hl, #sys_collision_check_one_collider
    call sys_array_execute_each_ix_matching
    ret
