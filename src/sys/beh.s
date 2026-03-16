;;-------------------------------------------------------------------------------
.module beh_system

.include "sys/beh.h.s"
.include "sys/array.h.s"
.include "common.h.s"
.include "man/entity.h.s"
.include "sys/map.h.s"

;;
;; Start of _DATA area
;;
.area _DATA

;;-----------------------------------------------------------------
;; beh_bounce_behavior
;;
;; A simple patrol: move right for ~60 frames, then left, repeat.
;; Entities must have c_cmp_movable for physics to apply speed.
;;-----------------------------------------------------------------
beh_bounce_behavior::
    SET_VX #2
beh_bounce_wait_right::
    WAIT 60, beh_bounce_go_left
    CONDITIONS_END
beh_bounce_go_left::
    SET_VX #-2
    WAIT 60, beh_bounce_behavior
    CONDITIONS_END

;;-----------------------------------------------------------------
;; beh_patrol_behavior
;;
;; Platform patrol: move right until the tile below the leading foot
;; becomes passable (edge detected), then reverse direction and
;; switch to the matching walk animation. Repeats indefinitely.
;; Requires c_cmp_movable and c_cmp_animated on the entity.
;;-----------------------------------------------------------------
beh_patrol_behavior::
    SET_ANIMATION monk_walk_right_anim
beh_patrol_moving_right::
    DRIVE_VX #1, #4
    CONDITION edge_ahead, beh_patrol_turn_left
    CONDITIONS_END

beh_patrol_turn_left::
    SET_ANIMATION monk_walk_left_anim
    ;; fall through to beh_patrol_moving_left
beh_patrol_moving_left::
    DRIVE_VX #-1, #4
    CONDITION edge_ahead, beh_patrol_turn_right
    CONDITIONS_END

beh_patrol_turn_right::
    SET_ANIMATION monk_walk_right_anim
    GOTO beh_patrol_moving_right

;;
;; Start of _CODE area
;;
.area _CODE

;;-----------------------------------------------------------------
;;
;; sys_beh_init
;;
;;  Initializes the behavior system (currently a no-op).
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
    ld e, e_beh(ix)
    ld d, e_beh+1(ix)
    ld a, d
    or e
    ret z               ;; e_beh == 0 → no behavior, skip
    jp sys_beh_run

;;-----------------------------------------------------------------
;;
;; sys_beh_run
;;
;;  Read the action pointer at DE, advance DE past it, jump to the
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
;;  Iterate all entities with c_cmp_ai and run their behavior.
;;  Entities with e_beh == 0 are skipped inside
;;  sys_beh_update_one_entity.
;;
;;  Input:
;;  Output:
;;  Modified: AF, BC, DE, HL, IX
;;
sys_beh_update::
    ld ix, #entities
    ld b, #c_cmp_ai
    ld hl, #sys_beh_update_one_entity
    call sys_array_execute_each_ix_matching
    ret

;;===============================================================================
;; ACTIONS
;;===============================================================================

;;-----------------------------------------------------------------
;; beh_action_idle
;;
;;  Blocking: immediately check conditions.
;;  DE points to the condition table on entry.
;;
beh_action_idle::
    jp sys_beh_check_conditions

;;-----------------------------------------------------------------
;; beh_action_wait
;;
;;  Blocking: decrement e_beh_timer, then check conditions.
;;  If the timer hits 0 the `timeout` condition will fire.
;;
beh_action_wait::
    dec e_beh_timer(ix)
    jp sys_beh_check_conditions

;;-----------------------------------------------------------------
;; beh_action_set_timer
;;
;;  Non-blocking: set e_beh_timer = inline byte arg.
;;
beh_action_set_timer::
    ld a, (de)
    inc de
    ld e_beh_timer(ix), a
    jp sys_beh_next

;;-----------------------------------------------------------------
;; beh_action_set_vx
;;
;;  Non-blocking: set e_speed_x (low byte) = inline byte arg.
;;
beh_action_set_vx::
    ld a, (de)
    inc de
    ld e_speed_x(ix), a
    ld e_moved(ix), #1
    jp sys_beh_next

;;-----------------------------------------------------------------
;; beh_action_set_vy
;;
;;  Non-blocking: set e_speed_y (low byte) = inline byte arg.
;;
beh_action_set_vy::
    ld a, (de)
    inc de
    ld e_speed_y(ix), a
    ld e_moved(ix), #1
    jp sys_beh_next

;;-----------------------------------------------------------------
;; beh_action_drive_vx
;;
;;  Blocking: re-apply e_speed_x = inline byte arg every frame, then
;;  check conditions. Because it is blocking, e_beh stays at this
;;  instruction so the speed is restored on each tick.
;;  This is the standard way for AI behaviors to move at a fixed speed:
;;    DRIVE_VX #2  → entity moves at exactly 2 bytes/frame (right)
;;    DRIVE_VX #-1 → entity moves at exactly 1 byte/frame  (left)
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
;; beh_action_set_animation
;;
;;  Non-blocking: set e_anim = inline .dw arg (descriptor pointer).
;;  Also resets e_anim_frame and e_anim_timer so the new animation
;;  starts from frame 0 on the next anim update.
;;
beh_action_set_animation::
    ld a, (de)
    inc de
    ld e_anim(ix), a
    ld a, (de)
    inc de
    ld e_anim+1(ix), a
    ld e_anim_frame(ix), #0
    ld e_anim_timer(ix), #0
    jp sys_beh_next

;;-----------------------------------------------------------------
;; beh_action_set_moved
;;
;;  Non-blocking: mark entity dirty so the renderer redraws it.
;;
beh_action_set_moved::
    ld e_moved(ix), #1
    jp sys_beh_next

;;===============================================================================
;; CONDITIONS
;;===============================================================================

;;-----------------------------------------------------------------
;; beh_cond_true — always returns Z=1 (true).
;;
beh_cond_true::
    xor a               ;; A=0 → Z=1
    ret

;;-----------------------------------------------------------------
;; beh_cond_timeout — Z=1 when e_beh_timer == 0.
;;
beh_cond_timeout::
    ld a, e_beh_timer(ix)
    or a                ;; Z=1 if zero
    ret

;;-----------------------------------------------------------------
;; beh_cond_on_ground — Z=1 when entity is on the ground.
;;  Uses e_on_air: 0 = on ground, non-zero = in the air.
;;
beh_cond_on_ground::
    ld a, e_on_air(ix)
    or a                ;; Z=1 if on_air == 0
    ret

;;-----------------------------------------------------------------
;; beh_cond_not_on_ground — Z=1 when entity is airborne.
;;
beh_cond_not_on_ground::
    ld a, e_on_air(ix)
    or a
    jr z, bcnog_false   ;; on ground → false
    xor a               ;; airborne → return Z=1
    ret
bcnog_false::
    ld a, #1            ;; Z=0 → false
    or a
    ret

;;-----------------------------------------------------------------
;; beh_cond_edge_ahead — Z=1 when the tile below the leading foot
;; is passable (i.e. entity is at a platform edge).
;;
;; Checks the tile at (e_y + e_height, leading_x):
;;   Moving right: leading_x = e_x + e_width  (one byte past right edge)
;;   Moving left:  leading_x = e_x - 1        (one byte past left edge)
;;   Not moving:   always false (Z=0)
;;
;; sys_map_is_solid_at returns Z=1 for passable, which is exactly
;; the "true" value we need (at edge → reverse).
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
    push de                     ;; sys_map_is_solid_at destroys DE; preserve it
    call sys_map_is_solid_at    ;; Z=1 if passable (at edge) → condition true
    pop de                      ;; restore DE (pop does not affect flags on Z80)
    ret

bcea_false:
    ld a, #1
    or a                        ;; Z=0 → false
    ret
