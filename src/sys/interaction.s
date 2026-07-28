;; Generic forward interaction detection. Game rules remain in callbacks.
.module interaction_system

.include "globals.inc"
.include "sys/array.h.s"
.include "sys/entity.h.s"
.include "sys/interaction.h.s"

.area _DATA

interaction_filter:  .dw interaction_accept_all
interaction_handler: .dw interaction_noop

interaction_zone_x:      .db 0
interaction_zone_y:      .db 0
interaction_zone_right:  .db 0
interaction_zone_bottom: .db 0

.area _CODE

sys_interaction_init::
    ld hl, #interaction_accept_all
    ld (interaction_filter), hl
    ld hl, #interaction_noop
    ld (interaction_handler), hl
    ret

sys_interaction_set_filter::
    ld a, h
    or l
    jr nz, interaction_store_filter
    ld hl, #interaction_accept_all
interaction_store_filter:
    ld (interaction_filter), hl
    ret

sys_interaction_set_handler::
    ld a, h
    or l
    jr nz, interaction_store_handler
    ld hl, #interaction_noop
interaction_store_handler:
    ld (interaction_handler), hl
    ret

;; Build a narrow AABB immediately to the left or right of IX=actor.
interaction_build_zone:
    or a
    jr nz, interaction_zone_left
    ld a, e_x(ix)
    add a, e_width(ix)
    jr interaction_zone_store_x
interaction_zone_left:
    ld a, e_x(ix)
    cp #INTERACTION_REACH
    jr nc, interaction_zone_left_sub
    xor a
    jr interaction_zone_store_x
interaction_zone_left_sub:
    sub #INTERACTION_REACH
interaction_zone_store_x:
    ld (interaction_zone_x), a
    add a, #INTERACTION_REACH
    ld (interaction_zone_right), a
    ld a, e_y(ix)
    ld (interaction_zone_y), a
    add a, e_height(ix)
    ld (interaction_zone_bottom), a
    ret

sys_interaction_find::
    call interaction_build_zone

    ld iy, #entities
    ld a, a_count(iy)
    or a
    jr z, interaction_not_found
    ld b, a
    push iy
    pop hl
    ld de, #a_array
    add hl, de
    push hl
    pop iy

interaction_find_loop:
    push bc

    ld a, e_cmps(iy)
    and #c_cmp_collisionable
    jr z, interaction_next

    ;; The actor cannot interact with itself.
    push ix
    pop hl
    push iy
    pop de
    ld a, h
    cp d
    jr nz, interaction_check_room
    ld a, l
    cp e
    jr z, interaction_next

interaction_check_room:
    ld a, e_room(ix)
    cp e_room(iy)
    jr nz, interaction_next

    ;; Zone right > candidate left.
    ld a, (interaction_zone_right)
    ld c, a
    ld a, e_x(iy)
    cp c
    jr nc, interaction_next

    ;; Zone left < candidate right.
    ld a, e_x(iy)
    add a, e_width(iy)
    ld c, a
    ld a, (interaction_zone_x)
    cp c
    jr nc, interaction_next

    ;; Zone bottom > candidate top.
    ld a, (interaction_zone_bottom)
    ld c, a
    ld a, e_y(iy)
    cp c
    jr nc, interaction_next

    ;; Zone top < candidate bottom.
    ld a, e_y(iy)
    add a, e_height(iy)
    ld c, a
    ld a, (interaction_zone_y)
    cp c
    jr nc, interaction_next

    call interaction_call_filter
    jr nz, interaction_next
    pop bc
    or a
    ret

interaction_next:
    ld de, #sizeof_e
    add iy, de
    pop bc
    djnz interaction_find_loop
interaction_not_found:
    scf
    ret

sys_interaction_try::
    call sys_interaction_find
    ret c
    call interaction_call_handler
    or a
    ret

interaction_call_filter:
    push ix
    push iy
    ld hl, #interaction_filter_return
    push hl
    ld hl, (interaction_filter)
    jp (hl)
interaction_filter_return:
    pop iy
    pop ix
    ret

interaction_call_handler:
    push ix
    push iy
    ld hl, #interaction_handler_return
    push hl
    ld hl, (interaction_handler)
    jp (hl)
interaction_handler_return:
    pop iy
    pop ix
    ret

interaction_accept_all:
    xor a
    ret

interaction_noop:
    ret
