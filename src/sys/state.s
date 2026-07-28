;; Compact flags and counters shared by adventure-style game rules.
.module state_system

.include "globals.inc"
.include "sys/state.h.s"

.area _DATA

sys_state_flags::
    .ds SYS_STATE_FLAG_BYTES

sys_state_counters::
    .ds SYS_STATE_COUNTER_COUNT

state_flag_masks:
    .db 0x01, 0x02, 0x04, 0x08, 0x10, 0x20, 0x40, 0x80

.area _CODE

;; Clear the contiguous flag and counter storage.
sys_state_init::
    xor a
    ld hl, #sys_state_flags
    ld de, #sys_state_flags + 1
    ld bc, #(SYS_STATE_FLAG_BYTES + SYS_STATE_COUNTER_COUNT - 1)
    ld (hl), a
    ldir
    ret

;; A=flag id -> HL=owning byte, C=bit mask. Modified: AF, B, C, DE, HL.
state_flag_address:
    ld b, a
    and #0x07
    ld e, a
    ld d, #0
    ld hl, #state_flag_masks
    add hl, de
    ld c, (hl)

    ld a, b
    rrca
    rrca
    rrca
    and #0x1f
    ld e, a
    ld d, #0
    ld hl, #sys_state_flags
    add hl, de
    ret

sys_state_set_flag::
    call state_flag_address
    ld a, (hl)
    or c
    ld (hl), a
    ret

sys_state_clear_flag::
    call state_flag_address
    ld a, c
    cpl
    and (hl)
    ld (hl), a
    ret

;; Z=true mirrors the condition callback convention used by sys/beh.
sys_state_test_flag::
    call state_flag_address
    ld a, (hl)
    and c
    jr z, state_flag_is_clear
    xor a
    ret
state_flag_is_clear:
    ld a, #1
    or a
    ret

;; A=counter id -> HL=&counter. Modified: DE, HL.
state_counter_address:
    ld e, a
    ld d, #0
    ld hl, #sys_state_counters
    add hl, de
    ret

sys_state_get_counter::
    call state_counter_address
    ld a, (hl)
    ret

sys_state_set_counter::
    call state_counter_address
    ld (hl), b
    ld a, b
    ret

sys_state_add_counter::
    call state_counter_address
    ld a, (hl)
    add a, b
    jr nc, state_counter_store
    ld a, #0xff
state_counter_store:
    ld (hl), a
    ret

sys_state_sub_counter::
    call state_counter_address
    ld a, (hl)
    sub b
    jr nc, state_counter_store
    xor a
    jr state_counter_store
