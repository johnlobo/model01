;; Generic fixed-capacity inventory. The game owns item ids and their effects.
.module inventory_system

.include "globals.inc"
.include "sys/inventory.h.s"

.area _DATA

sys_inventory_count:: .db 0
sys_inventory_items:: .ds SYS_INVENTORY_CAPACITY

.area _CODE

sys_inventory_init::
    xor a
    ld (sys_inventory_count), a
    ld hl, #sys_inventory_items
    ld de, #sys_inventory_items + 1
    ld bc, #(SYS_INVENTORY_CAPACITY - 1)
    ld (hl), a
    ldir
    ret

;; A=item -> Z=present, HL=matching slot or first free slot, B=items remaining
;; from the match (including it). C preserves the requested item id.
inventory_find:
    ld c, a
    ld a, (sys_inventory_count)
    ld b, a
    ld hl, #sys_inventory_items
    or a
    jr z, inventory_not_found
inventory_find_loop:
    ld a, (hl)
    cp c
    ret z
    inc hl
    djnz inventory_find_loop
inventory_not_found:
    ld a, #1
    or a
    ret

sys_inventory_add::
    or a
    jr z, inventory_fail
    call inventory_find
    jr z, inventory_fail
    ld a, (sys_inventory_count)
    cp #SYS_INVENTORY_CAPACITY
    jr nc, inventory_fail
    ld (hl), c
    inc a
    ld (sys_inventory_count), a
    or a
    ret

sys_inventory_remove::
    or a
    jr z, inventory_fail
    call inventory_find
    jr nz, inventory_fail

    ;; B includes the matching item. Copy every following item one slot left.
    push hl
    pop de
    dec b
    jr z, inventory_remove_clear_last
    inc hl
    ld c, b
    ld b, #0
    ldir
inventory_remove_clear_last:
    xor a
    ld (de), a
    ld a, (sys_inventory_count)
    dec a
    ld (sys_inventory_count), a
    or a
    ret

sys_inventory_contains::
    or a
    jr z, inventory_absent
    call inventory_find
    jr nz, inventory_absent
    xor a
    ret
inventory_absent:
    ld a, #1
    or a
    ret

sys_inventory_get::
    ld e, a
    ld a, (sys_inventory_count)
    cp e
    jr z, inventory_get_invalid
    jr c, inventory_get_invalid
    ld d, #0
    ld hl, #sys_inventory_items
    add hl, de
    ld a, (hl)
    or a
    ret
inventory_get_invalid:
    xor a
inventory_fail:
    scf
    ret
