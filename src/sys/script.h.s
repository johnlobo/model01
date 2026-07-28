;; Event-script bytecode for adventure rules.
.module script_system

SYS_SCRIPT_MAX_OPS_PER_TICK = 16

SCRIPT_OP_END             = 0
SCRIPT_OP_SET_FLAG        = 1
SCRIPT_OP_CLEAR_FLAG      = 2
SCRIPT_OP_REQUIRE_FLAG    = 3
SCRIPT_OP_ADD_ITEM        = 4
SCRIPT_OP_REMOVE_ITEM     = 5
SCRIPT_OP_REQUIRE_ITEM    = 6
SCRIPT_OP_SET_COUNTER     = 7
SCRIPT_OP_ADD_COUNTER     = 8
SCRIPT_OP_REQUIRE_COUNTER = 9
SCRIPT_OP_SET_TILE        = 10
SCRIPT_OP_CALL            = 11
SCRIPT_OP_GOTO            = 12

;; All failure targets are absolute addresses. A target of 0 ends the script.
.macro SCRIPT_END
    .db SCRIPT_OP_END
.endm

.macro SCRIPT_SET_FLAG _flag
    .db SCRIPT_OP_SET_FLAG, _flag
.endm

.macro SCRIPT_CLEAR_FLAG _flag
    .db SCRIPT_OP_CLEAR_FLAG, _flag
.endm

.macro SCRIPT_REQUIRE_FLAG _flag, _failure
    .db SCRIPT_OP_REQUIRE_FLAG, _flag
    .dw _failure
.endm

.macro SCRIPT_ADD_ITEM _item, _failure
    .db SCRIPT_OP_ADD_ITEM, _item
    .dw _failure
.endm

.macro SCRIPT_REMOVE_ITEM _item, _failure
    .db SCRIPT_OP_REMOVE_ITEM, _item
    .dw _failure
.endm

.macro SCRIPT_REQUIRE_ITEM _item, _failure
    .db SCRIPT_OP_REQUIRE_ITEM, _item
    .dw _failure
.endm

.macro SCRIPT_SET_COUNTER _counter, _value
    .db SCRIPT_OP_SET_COUNTER, _counter, _value
.endm

.macro SCRIPT_ADD_COUNTER _counter, _amount
    .db SCRIPT_OP_ADD_COUNTER, _counter, _amount
.endm

.macro SCRIPT_REQUIRE_COUNTER _counter, _minimum, _failure
    .db SCRIPT_OP_REQUIRE_COUNTER, _counter, _minimum
    .dw _failure
.endm

.macro SCRIPT_SET_TILE _row, _column, _tile
    .db SCRIPT_OP_SET_TILE, _row, _column, _tile
.endm

.macro SCRIPT_CALL _callback
    .db SCRIPT_OP_CALL
    .dw _callback
.endm

.macro SCRIPT_GOTO _target
    .db SCRIPT_OP_GOTO
    .dw _target
.endm

;; sys_script_init / sys_script_stop
;;   Stop the active script.
;;
;; sys_script_start
;;   Input: HL=bytecode address. A null pointer leaves the system stopped.
;;
;; sys_script_update
;;   Runs until END, a null branch, or SYS_SCRIPT_MAX_OPS_PER_TICK. Immediate
;;   loops therefore yield and resume next frame instead of freezing the CPC.
;;
;; sys_script_is_running
;;   Output: Z=1 and A=0 while running; Z=0 and A=1 while stopped.
