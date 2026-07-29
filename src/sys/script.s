;; Single active event-script interpreter.
.module script_system

.include "globals.inc"
.include "sys/script.h.s"

.area _DATA

sys_script_pc:: .dw 0
sys_script_ops_left:: .db 0
script_branch_target: .dw 0

.area _CODE

;;-----------------------------------------------------------------
;;
;; sys_script_init
;;
;;  Stops the event-script interpreter and clears its program counter.
;;  Input:
;;  Output:
;;  Modified: AF
;;
sys_script_init::
;;-----------------------------------------------------------------
;;
;; sys_script_stop
;;
;;  Stops the event-script interpreter and clears its program counter.
;;  Input:
;;  Output:
;;  Modified: AF
;;
sys_script_stop::
    xor a
    ld (sys_script_pc), a
    ld (sys_script_pc + 1), a
    ret

;;-----------------------------------------------------------------
;;
;; sys_script_start
;;
;;  Starts interpreting bytecode at the supplied address; zero leaves it stopped.
;;  Input: HL = script bytecode address or 0
;;  Output:
;;  Modified: None
;;
sys_script_start::
    ld (sys_script_pc), hl
    ret

;;-----------------------------------------------------------------
;;
;; sys_script_is_running
;;
;;  Tests whether an event script has a nonzero program counter.
;;  Input:
;;  Output: Z = 1 and A = 0 when running; Z = 0 and A = 1 when stopped
;;  Modified: AF, HL
;;
sys_script_is_running::
    ld hl, (sys_script_pc)
    ld a, h
    or l
    jr z, script_not_running
    xor a
    ret
script_not_running:
    ld a, #1
    or a
    ret

;;-----------------------------------------------------------------
;;
;; sys_script_update
;;
;;  Executes script opcodes until the script stops, branches to zero or exhausts its per-tick budget.
;;  Input:
;;  Output:
;;  Modified: AF, BC, DE, HL, IX, IY
;;
sys_script_update::
    ld a, #SYS_SCRIPT_MAX_OPS_PER_TICK
    ld (sys_script_ops_left), a

script_next:
    ld a, (sys_script_ops_left)
    or a
    ret z
    dec a
    ld (sys_script_ops_left), a

    ld hl, (sys_script_pc)
    ld a, h
    or l
    ret z
    ld a, (hl)
    inc hl
    ld (sys_script_pc), hl

    or a
    jp z, sys_script_stop
    cp #SCRIPT_OP_SET_FLAG
    jp z, script_set_flag
    cp #SCRIPT_OP_CLEAR_FLAG
    jp z, script_clear_flag
    cp #SCRIPT_OP_REQUIRE_FLAG
    jp z, script_require_flag
    cp #SCRIPT_OP_ADD_ITEM
    jp z, script_add_item
    cp #SCRIPT_OP_REMOVE_ITEM
    jp z, script_remove_item
    cp #SCRIPT_OP_REQUIRE_ITEM
    jp z, script_require_item
    cp #SCRIPT_OP_SET_COUNTER
    jp z, script_set_counter
    cp #SCRIPT_OP_ADD_COUNTER
    jp z, script_add_counter
    cp #SCRIPT_OP_REQUIRE_COUNTER
    jp z, script_require_counter
    cp #SCRIPT_OP_SET_TILE
    jp z, script_set_tile
    cp #SCRIPT_OP_CALL
    jp z, script_call
    cp #SCRIPT_OP_GOTO
    jp z, script_goto
    jp sys_script_stop             ;; unknown opcode: fail closed

script_set_flag:
    ld a, (hl)
    inc hl
    ld (sys_script_pc), hl
    call sys_state_set_flag
    jp script_next

script_clear_flag:
    ld a, (hl)
    inc hl
    ld (sys_script_pc), hl
    call sys_state_clear_flag
    jp script_next

;; Parse id + failure target. Returns A=id, DE=failure, PC=continuation.
;;-----------------------------------------------------------------
;;
;; script_parse_condition
;;
;;  Decodes an id and absolute failure target from the current script instruction.
;;  Input: HL = first operand byte
;;  Output: A = id; DE = failure target; script PC points to the continuation
;;  Modified: AF, DE, HL
;;
script_parse_condition:
    ld a, (hl)
    inc hl
    ld e, (hl)
    inc hl
    ld d, (hl)
    inc hl
    ld (sys_script_pc), hl
    ld (script_branch_target), de
    ret

script_branch_on_failure:
    ld hl, (script_branch_target)
    ld (sys_script_pc), hl
    jp script_next

script_require_flag:
    call script_parse_condition
    call sys_state_test_flag
    jp nz, script_branch_on_failure
    jp script_next

script_add_item:
    call script_parse_condition
    call sys_inventory_add
    jp c, script_branch_on_failure
    jp script_next

script_remove_item:
    call script_parse_condition
    call sys_inventory_remove
    jp c, script_branch_on_failure
    jp script_next

script_require_item:
    call script_parse_condition
    call sys_inventory_contains
    jp nz, script_branch_on_failure
    jp script_next

script_set_counter:
    ld a, (hl)
    inc hl
    ld b, (hl)
    inc hl
    ld (sys_script_pc), hl
    call sys_state_set_counter
    jp script_next

script_add_counter:
    ld a, (hl)
    inc hl
    ld b, (hl)
    inc hl
    ld (sys_script_pc), hl
    call sys_state_add_counter
    jp script_next

script_require_counter:
    ld a, (hl)
    inc hl
    ld b, (hl)                    ;; minimum
    inc hl
    ld e, (hl)
    inc hl
    ld d, (hl)
    inc hl
    ld (sys_script_pc), hl
    ld (script_branch_target), de
    call sys_state_get_counter
    cp b
    jp c, script_branch_on_failure
    jp script_next

script_set_tile:
    ld b, (hl)
    inc hl
    ld c, (hl)
    inc hl
    ld a, (hl)
    inc hl
    ld (sys_script_pc), hl
    call sys_map_set_tile_and_redraw
    jp script_next

script_call:
    ld e, (hl)
    inc hl
    ld d, (hl)
    inc hl
    ld (sys_script_pc), hl
    ex de, hl
    call script_call_hl
    jp script_next

;;-----------------------------------------------------------------
;;
;; script_call_hl
;;
;;  Indirect-call trampoline used by the SCRIPT_OP_CALL opcode.
;;  Input: HL = callback address
;;  Output: Callback-defined
;;  Modified: Callback-defined
;;
script_call_hl:
    jp (hl)

script_goto:
    ld e, (hl)
    inc hl
    ld d, (hl)
    ex de, hl
    ld (sys_script_pc), hl
    jp script_next
