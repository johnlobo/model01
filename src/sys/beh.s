;;-------------------------------------------------------------------------------
.module beh_system

.include "sys/beh.h.s"
.include "sys/array.h.s"
.include "globals.inc"
.include "sys/entity.h.s"
.include "sys/map.h.s"
.include "sys/anim.h.s"

;;
;; Start of _DATA area
;;
.area _DATA

sys_beh_actions_left:: .db 0

;;
;; Start of _CODE area
;;
.area _CODE

;;-----------------------------------------------------------------
;;
;; sys_beh_init
;;
;;  Initializes the behavior system (currently a no-op).
;;  Input:
;;  Output:
;;  Modified: None
;;
sys_beh_init::
    ret

;;-----------------------------------------------------------------
;;
;; sys_beh_call_hl
;;
;;  Indirect call helper: `call sys_beh_call_hl` with HL = fn
;;  effectively does `call fn`. The called function returns to
;;  the instruction after the `call sys_beh_call_hl`.
;;
;;  Input:  HL = address of function to call
;;  Output: (whatever the called function returns)
;;  Modified: (whatever the called function modifies)
;;
sys_beh_call_hl::
    jp (hl)

;;-----------------------------------------------------------------
;;
;; sys_beh_update_one_entity
;;
;;  Dispatch entry point called by sys_array_execute_each_ix_matching.
;;  Loads e_beh from the entity and starts the engine if non-null.
;;
;;  Input:  IX = entity pointer
;;  Output:
;;  Modified: AF, DE, HL
;;
sys_beh_update_one_entity::
    ld a, (current_room)
    cp e_room(ix)
    ret nz              ;; wrong room: skip

    ld e, e_beh(ix)
    ld d, e_beh+1(ix)
    ld a, d
    or e
    ret z               ;; e_beh == 0 → no behavior, skip
    ld a, #BEH_MAX_ACTIONS_PER_TICK
    ld (sys_beh_actions_left), a
    jp sys_beh_run

;;-----------------------------------------------------------------
;;
;; sys_beh_run
;;
;;  Consume one dispatch-budget unit, read the action pointer at DE, advance
;;  DE past it and jump to the action. When the per-tick budget is exhausted,
;;  return immediately; sys_beh_next has already saved DE as the resume point.
;;  action. The action receives IX = entity and DE = its first
;;  inline argument byte (or condition table for blocking actions).
;;
;;  All jumps between engine functions are JP (not CALL) to keep
;;  the Z80 stack flat. The only stack growth comes from
;;  `call sys_beh_call_hl` inside sys_beh_check_conditions.
;;
;;  Input:  IX = entity, DE = current behavior position
;;  Output:
;;  Modified: AF, HL
;;
sys_beh_run::
    ld a, (sys_beh_actions_left)
    or a
    ret z
    dec a
    ld (sys_beh_actions_left), a
    ld a, (de)
    ld l, a
    inc de
    ld a, (de)
    ld h, a             ;; HL = action function address
    inc de              ;; DE now points past the action ptr (inline args)
    jp (hl)

;;-----------------------------------------------------------------
;;
;; sys_beh_next
;;
;;  Called by non-blocking actions when complete. Saves DE as the
;;  new e_beh and immediately chains to the next action.
;;  If DE == DESTROY_ENTITY (0x0000), marks entity invalid instead.
;;
;;  Input:  IX = entity, DE = new position in behavior program
;;  Output:
;;  Modified: AF
;;
sys_beh_next::
    ld a, d
    or e
    jr z, sbhn_destroy

    ld e_beh(ix), e
    ld e_beh+1(ix), d
    jp sys_beh_run

;;-----------------------------------------------------------------
;;
;; sbhn_destroy
;;
;;  Invalidates the current entity when a behavior targets DESTROY_ENTITY.
;;  Input: IX = entity
;;  Output:
;;  Modified: AF
;;
sbhn_destroy::
    ld e_cmps(ix), #c_cmp_invalid
    ret

;;-----------------------------------------------------------------
;;
;; sys_beh_check_conditions
;;
;;  Called by blocking actions (IDLE, WAIT) after their per-frame
;;  work. Iterates the condition table at DE:
;;    .dw condition_fn   ; NULL (0) = end of table
;;    .dw target_addr
;;  If condition_fn returns Z=1 (true), loads target_addr into DE
;;  and calls sys_beh_next to advance.
;;  If no condition fires, returns without updating e_beh (entity
;;  will re-run the same blocking action next frame).
;;
;;  Input:  IX = entity, DE = pointer to first condition table entry
;;  Output:
;;  Modified: AF, HL
;;
sys_beh_check_conditions::
    ;; Read condition function address
    ld a, (de)
    ld l, a
    inc de
    ld a, (de)
    ld h, a             ;; HL = condition fn (or 0 = end)
    or l
    ret z               ;; NULL → end of table, entity stays put

    inc de              ;; DE now points to this entry's target address

    call sys_beh_call_hl    ;; call condition fn; Z=1 → true, Z=0 → false

    jr z, sbhcc_true

    ;; False: skip target address (2 bytes), try next entry
    inc de
    inc de
    jp sys_beh_check_conditions

;;-----------------------------------------------------------------
;;
;; sbhcc_true
;;
;;  Loads a satisfied condition target and continues behavior dispatch.
;;  Input: IX = entity; DE = pointer to target address
;;  Output: Does not return directly; continues through sys_beh_next
;;  Modified: DE, HL
;;
sbhcc_true::
    ;; True: read target address from DE into DE, then advance
    ex de, hl           ;; HL = ptr to target addr bytes, DE (stale)
    ld e, (hl)
    inc hl
    ld d, (hl)          ;; DE = target address
    jp sys_beh_next

;;-----------------------------------------------------------------
;;
;; sys_beh_update
;;
;;  Iterate all entities with c_cmp_behavior and run their behavior.
;;  Entities with e_beh == 0 are skipped inside
;;  sys_beh_update_one_entity.
;;
;;  Input:
;;  Output:
;;  Modified: AF, BC, DE, HL, IX
;;
sys_beh_update::
    ld ix, #entities
    ld b, #c_cmp_behavior
    ld hl, #sys_beh_update_one_entity
    call sys_array_execute_each_ix_matching
    ret

;;===============================================================================
;; ACTIONS
;;===============================================================================

;;-----------------------------------------------------------------
;;
;; beh_action_idle
;;
;;  Blocks at the current behavior action and immediately checks its conditions.
;;  Input: IX = entity; DE = condition table
;;  Output: Does not return directly; continues through sys_beh_check_conditions
;;  Modified: AF, DE, HL
;;
beh_action_idle::
    jp sys_beh_check_conditions

;;-----------------------------------------------------------------
;;
;; beh_action_wait
;;
;;  Decrements the entity behavior timer and checks the following conditions.
;;  Input: IX = entity; DE = condition table
;;  Output: Does not return directly; continues through sys_beh_check_conditions
;;  Modified: AF, DE, HL
;;
beh_action_wait::
    dec e_beh_timer(ix)
    jp sys_beh_check_conditions

;;-----------------------------------------------------------------
;;
;; beh_action_set_timer
;;
;;  Stores the inline byte in e_beh_timer and advances behavior dispatch.
;;  Input: IX = entity; DE = inline timer byte
;;  Output: Does not return directly; continues through sys_beh_next
;;  Modified: AF, DE, HL
;;
beh_action_set_timer::
    ld a, (de)
    inc de
    ld e_beh_timer(ix), a
    jp sys_beh_next

;;-----------------------------------------------------------------
;;
;; beh_action_set_vx
;;
;;  Stores the inline signed byte in e_speed_x, marks the entity moved and advances.
;;  Input: IX = entity; DE = inline signed X speed
;;  Output: Does not return directly; continues through sys_beh_next
;;  Modified: AF, DE, HL
;;
beh_action_set_vx::
    ld a, (de)
    inc de
    ld e_speed_x(ix), a
    ld e_moved(ix), #1
    jp sys_beh_next

;;-----------------------------------------------------------------
;;
;; beh_action_set_vy
;;
;;  Stores the inline signed byte in e_speed_y, marks the entity moved and advances.
;;  Input: IX = entity; DE = inline signed Y speed
;;  Output: Does not return directly; continues through sys_beh_next
;;  Modified: AF, DE, HL
;;
beh_action_set_vy::
    ld a, (de)
    inc de
    ld e_speed_y(ix), a
    ld e_moved(ix), #1
    jp sys_beh_next

;;-----------------------------------------------------------------
;;
;; beh_action_drive_vx
;;
;;  Applies an inline X speed at the requested stride, then checks conditions.
;;  Input: IX = entity; DE = inline signed speed followed by stride
;;  Output: Does not return directly; continues through sys_beh_check_conditions
;;  Modified: AF, BC, DE, HL
;;
beh_action_drive_vx::
    ld a, (de)              ;; A = speed
    inc de
    ld c, a                 ;; C = speed (saved)
    ld a, (de)              ;; A = stride (0/1 = every frame, N>1 = every N frames)
    inc de                  ;; DE now points to condition table

    ;; stride 0 or 1: move every frame
    or a
    jr z, bdvx_apply        ;; stride == 0
    dec a
    jr z, bdvx_apply        ;; stride == 1

    ;; stride > 1: use e_beh_timer as countdown
    ld b, a                 ;; B = stride - 1 (reload value)
    ld a, e_beh_timer(ix)
    or a
    jr nz, bdvx_tick        ;; timer > 0: still counting down

    ;; timer = 0: apply speed and reload
    ld e_beh_timer(ix), b
bdvx_apply:
    ld e_speed_x(ix), c
    ld e_anim_timer(ix), #0     ;; sync animation: advance frame this tick
    jr bdvx_done

bdvx_tick:
    dec a
    ld e_beh_timer(ix), a
    ld e_speed_x(ix), #0    ;; hold this frame

bdvx_done:
    ld e_moved(ix), #1
    jp sys_beh_check_conditions

;;-----------------------------------------------------------------
;;
;; beh_action_set_animation
;;
;;  Selects the inline animation descriptor and advances behavior dispatch.
;;  Input: IX = entity; DE = inline animation descriptor address
;;  Output: Does not return directly; continues through sys_beh_next
;;  Modified: AF, DE, HL
;;
beh_action_set_animation::
    ld a, (de)
    ld l, a
    inc de
    ld a, (de)
    ld h, a
    inc de
    push de
    call sys_anim_set
    pop de
    jp sys_beh_next

;;-----------------------------------------------------------------
;;
;; beh_action_set_moved
;;
;;  Marks the entity dirty so the renderer redraws it, then advances.
;;  Input: IX = entity; DE = next behavior position
;;  Output: Does not return directly; continues through sys_beh_next
;;  Modified: AF, DE, HL
;;
beh_action_set_moved::
    ld e_moved(ix), #1
    jp sys_beh_next

;;===============================================================================
;; CONDITIONS
;;===============================================================================

;;-----------------------------------------------------------------
;;
;; beh_cond_true
;;
;;  Implements an unconditional true behavior condition.
;;  Input: IX = entity; DE = condition target pointer
;;  Output: Z = 1; A = 0
;;  Modified: AF
;;
beh_cond_true::
    xor a               ;; A=0 → Z=1
    ret

;;-----------------------------------------------------------------
;;
;; beh_cond_timeout
;;
;;  Tests whether the entity behavior timer has expired.
;;  Input: IX = entity; DE = condition target pointer
;;  Output: Z = 1 when e_beh_timer is zero; Z = 0 otherwise
;;  Modified: AF
;;
beh_cond_timeout::
    ld a, e_beh_timer(ix)
    or a                ;; Z=1 if zero
    ret

;;-----------------------------------------------------------------
;;
;; beh_cond_on_ground
;;
;;  Tests whether the entity is on the ground.
;;  Input: IX = entity; DE = condition target pointer
;;  Output: Z = 1 when e_on_air is zero; Z = 0 otherwise
;;  Modified: AF
;;
beh_cond_on_ground::
    ld a, e_on_air(ix)
    or a                ;; Z=1 if on_air == 0
    ret

;;-----------------------------------------------------------------
;;
;; beh_cond_not_on_ground
;;
;;  Tests whether the entity is airborne.
;;  Input: IX = entity; DE = condition target pointer
;;  Output: Z = 1 and A = 0 when airborne; Z = 0 and A = 1 on ground
;;  Modified: AF
;;
beh_cond_not_on_ground::
    ld a, e_on_air(ix)
    or a
    jr z, bcnog_false   ;; on ground → false
    xor a               ;; airborne → return Z=1
    ret
;;-----------------------------------------------------------------
;;
;; bcnog_false
;;
;;  Returns the false result for the not-on-ground condition.
;;  Input:
;;  Output: Z = 0; A = 1
;;  Modified: AF
;;
bcnog_false::
    ld a, #1            ;; Z=0 → false
    or a
    ret

;;-----------------------------------------------------------------
;;
;; beh_cond_edge_ahead
;;
;;  Tests whether the tile below the leading foot is passable.
;;  Input: IX = entity; DE = condition target pointer
;;  Output: Z = 1 at an edge; Z = 0 over landable ground or when stationary
;;  Modified: AF, BC, HL; DE preserved
;;
beh_cond_edge_ahead::
    ld a, e_speed_x(ix)
    or a
    jr z, bcea_false        ;; not moving → never at edge

    ld a, e_y(ix)
    add a, e_height(ix)
    ld b, a                 ;; B = one pixel below entity feet

    bit 7, e_speed_x(ix)
    jr nz, bcea_moving_left

    ;; Moving right: check byte just past right edge
    ld a, e_x(ix)
    add a, e_width(ix)
    ld c, a
    jr bcea_check

bcea_moving_left:
    ;; Moving left: check byte just past left edge
    ld a, e_x(ix)
    dec a
    ld c, a

bcea_check:
    push de                     ;; sys_map_is_landable_at destroys DE; preserve it
    call sys_map_is_landable_at ;; Z=1 if passable (at edge) → condition true
    pop de                      ;; restore DE (pop does not affect flags on Z80)
    ret

bcea_false:
    ld a, #1
    or a                        ;; Z=0 → false
    ret
