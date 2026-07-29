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

;;-----------------------------------------------------------------
;;
;; sys_interaction_init
;;
;;  Restores the accept-all filter and no-op interaction handler.
;;  Input:
;;  Output:
;;  Modified: HL
;;
sys_interaction_init::
    ld hl, #interaction_accept_all
    ld (interaction_filter), hl
    ld hl, #interaction_noop
    ld (interaction_handler), hl
    ret

;;-----------------------------------------------------------------
;;
;; sys_interaction_set_filter
;;
;;  Registers the candidate filter; a null pointer restores the accept-all filter.
;;  Input: HL = filter address or 0
;;  Output:
;;  Modified: AF, HL
;;
sys_interaction_set_filter::
    ld a, h
    or l
    jr nz, interaction_store_filter
    ld hl, #interaction_accept_all
interaction_store_filter:
    ld (interaction_filter), hl
    ret

;;-----------------------------------------------------------------
;;
;; sys_interaction_set_handler
;;
;;  Registers the interaction handler; a null pointer restores the no-op handler.
;;  Input: HL = handler address or 0
;;  Output:
;;  Modified: AF, HL
;;
sys_interaction_set_handler::
    ld a, h
    or l
    jr nz, interaction_store_handler
    ld hl, #interaction_noop
interaction_store_handler:
    ld (interaction_handler), hl
    ret

;; Build a narrow AABB immediately to the left or right of IX=actor.
;;-----------------------------------------------------------------
;;
;; interaction_build_zone
;;
;;  Builds the narrow interaction AABB immediately in front of an actor.
;;  Input: IX = actor; A = facing (0 right, nonzero left)
;;  Output:
;;  Modified: AF
;;
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

;;-----------------------------------------------------------------
;;
;; sys_interaction_find
;;
;;  Finds the first eligible entity overlapping the forward interaction zone.
;;  Input: IX = actor; A = facing (0 right, nonzero left)
;;  Output: IY = target and carry clear when found; carry set when no target is found
;;  Modified: AF, BC, DE, HL, IY
;;
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

;;-----------------------------------------------------------------
;;
;; sys_interaction_try
;;
;;  Finds a forward target and dispatches the registered interaction handler.
;;  Input: IX = actor; A = facing (0 right, nonzero left)
;;  Output: IY = target and carry clear on success; carry set when no target is found
;;  Modified: AF, BC, DE, HL, IY
;;
sys_interaction_try::
    call sys_interaction_find
    ret c
    call interaction_call_handler
    or a
    ret

;;-----------------------------------------------------------------
;;
;; interaction_call_filter
;;
;;  Calls the registered candidate filter while preserving both entity pointers.
;;  Input: IX = actor; IY = candidate
;;  Output: Filter result in AF; Z = 1 accepts, Z = 0 rejects
;;  Modified: AF, BC, DE, HL as modified by the callback; IX and IY preserved
;;
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

;;-----------------------------------------------------------------
;;
;; interaction_call_handler
;;
;;  Calls the registered interaction handler while preserving both entity pointers.
;;  Input: IX = actor; IY = target
;;  Output: Callback-defined
;;  Modified: AF, BC, DE, HL as modified by the callback; IX and IY preserved
;;
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

;;-----------------------------------------------------------------
;;
;; interaction_accept_all
;;
;;  Default filter that accepts every interaction candidate.
;;  Input: IX = actor; IY = candidate
;;  Output: Z = 1; A = 0
;;  Modified: AF
;;
interaction_accept_all:
    xor a
    ret

;;-----------------------------------------------------------------
;;
;; interaction_noop
;;
;;  Default interaction handler that performs no action.
;;  Input: IX = actor; IY = target
;;  Output:
;;  Modified: None
;;
interaction_noop:
    ret
