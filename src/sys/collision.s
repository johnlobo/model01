;;-------------------------------------------------------------------------------
.module collision_system

.include "sys/array.h.s"
.include "cpctelera.h.s"
.include "common.h.s"
.include "sys/collision.h.s"
.include "man/entity.h.s"

;;
;; Start of _DATA area
;;
.area _DATA


;;
;; Start of _CODE area
;;
.area _CODE

;;-----------------------------------------------------------------
;;
;; sys_collision_init
;;
;;  Initializes the collision system
;;  Input:
;;  Output:
;;  Modified:
;;
sys_collision_init::
    ret

;;-----------------------------------------------------------------
;;
;; sys_collision_on_hit
;;
;;  Called when a collision is detected between two entities.
;;  Stub: override behavior here.
;;  Input:  ix: collider entity
;;          iy: collisionable entity
;;  Output:
;;  Modified:
;;
sys_collision_on_hit::
    cpctm_setBorder_asm HW_RED
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
    call sys_collision_check_pair

sccoc_next:
    ld de, #sizeof_e        ;; advance IY to next entity
    add iy, de
    pop bc
    djnz sccoc_loop

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
