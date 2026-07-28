;;-------------------------------------------------------------------------------
.module beh_system

.include "globals.inc"

;;===============================================================================
;; BEHAVIOR SYSTEM
;;===============================================================================
;;
;; Behavior programs are flat bytecode tables in .area _DATA.
;; Each entry is a .dw pointing to an action function, followed by 0 or more
;; inline argument bytes consumed by that action.
;;
;; Blocking actions (IDLE, WAIT) are followed by a condition table:
;;   .dw condition_fn   ; 2 bytes (NULL = end of table, entity stays put)
;;   .dw target_addr    ; 2 bytes (jump-to if condition returns true)
;;   ...
;;   .dw 0              ; CONDITIONS_END
;;
;; Condition functions are called with IX = current entity and must return:
;;   Z=1  ->  condition is TRUE  (take the branch to target_addr)
;;   Z=0  ->  condition is FALSE (skip this entry, check next)
;;
;; The entity field e_beh holds the CURRENT POSITION in the behavior program
;; (it advances as the entity progresses). Set e_beh=0 for no behavior.
;; Non-blocking actions call sys_beh_next which chains immediately.
;; Blocking actions leave e_beh unchanged until a condition fires.
;;
;; Special value for target_addr:
DESTROY_ENTITY = 0x0000   ;; mark entity invalid (remove from active set)

;; Maximum actions dispatched for one entity in one update. Blocking actions
;; normally consume one. Immediate action cycles yield after this many entries
;; and resume from e_beh on the next frame instead of freezing the machine.
BEH_MAX_ACTIONS_PER_TICK = 16

;;===============================================================================
;; PUBLIC METHODS
;;===============================================================================

;;===============================================================================
;; ACTIONS
;;===============================================================================

;;===============================================================================
;; CONDITIONS
;;===============================================================================

;;===============================================================================
;; DSL MACROS
;;===============================================================================

;; ACTION fn — emit a direct action function pointer. Custom non-blocking
;; actions receive IX=entity and DE=inline arguments; advance DE over their
;; arguments and finish with `jp sys_beh_next`. Blocking actions finish with
;; `jp sys_beh_check_conditions` and leave e_beh at the current instruction.
.macro ACTION _fn
    .dw _fn
.endm

;; CONDITION_FN fn, target — condition callback without a naming convention.
;; Custom conditions receive IX=entity and DE=target pointer, must preserve DE,
;; and return Z=1 for true or Z=0 for false.
.macro CONDITION_FN _fn, _target
    .dw _fn, _target
.endm

;; IDLE — blocking action: check conditions immediately each frame.
;; Follow with CONDITION / CONDITIONS_END.
.macro IDLE
    .dw beh_action_idle
.endm

;; CONDITIONS_END — terminates a condition table (entity stays at current action).
.macro CONDITIONS_END
    .dw #0
.endm

;; CONDITION cond, target — single condition entry in a condition table.
;;   cond   : bare name, e.g. "true", "timeout", "on_ground"
;;   target : label to jump to when condition is true
.macro CONDITION _cond, _target
    CONDITION_FN beh_cond_'_cond, _target
.endm

;; GOTO target — unconditional jump to another behavior label.
;; Do NOT add CONDITIONS_END after GOTO (beh_cond_true always fires).
.macro GOTO _target
    IDLE
    CONDITION true, _target
.endm

;; WAIT ticks, next — decrement timer each frame; branch to next when it hits 0.
;; Add extra CONDITION entries and/or CONDITIONS_END after this macro.
.macro WAIT _ticks, _next
    SET_TIMER _ticks
    .dw beh_action_wait
    CONDITION timeout, _next
.endm

;; SET_TIMER ticks — non-blocking: set e_beh_timer = ticks.
.macro SET_TIMER _ticks
    .dw beh_action_set_timer
    .db _ticks
.endm

;; SET_VX vx — non-blocking: set entity speed_x (low byte) = vx.
.macro SET_VX _vx
    .dw beh_action_set_vx
    .db _vx
.endm

;; SET_VY vy — non-blocking: set entity speed_y (low byte) = vy.
.macro SET_VY _vy
    .dw beh_action_set_vy
    .db _vy
.endm

;; SET_ANIMATION anim_addr — non-blocking: point e_anim at a descriptor.
.macro SET_ANIMATION _anim_addr
    .dw beh_action_set_animation
    .dw _anim_addr
.endm

;; DRIVE_VX vx, stride — blocking: drive entity at 'vx' bytes every 'stride' frames.
;;   stride 0 or 1: move every frame (e.g. DRIVE_VX #2, #1 = 2 bytes/frame)
;;   stride N>1:    move 1 step every N frames via e_beh_timer countdown
;;                  (e.g. DRIVE_VX #1, #4 = 1 byte every 4 frames = ~12 bytes/sec)
.macro DRIVE_VX _vx, _stride
    .dw beh_action_drive_vx
    .db _vx, _stride
.endm
