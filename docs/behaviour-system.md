# Behaviour System

The behaviour system (`src/sys/beh.s`, `src/sys/beh.h.s`) gives entities a
scriptable, frame-driven state machine.  Each AI-controlled entity holds a
pointer (`e_beh`) to its **current position** inside a behaviour program — a
flat table of action function pointers and inline data living in `.area _DATA`.
Every frame, `sys_beh_update` advances the program for every
`c_cmp_behavior` entity that has `e_beh != 0`. `c_cmp_ai` remains available as
a compatibility alias.

---

## Concepts

### Behaviour program

A behaviour program is a sequence of **actions** written with assembler macros:

```
.dw action_fn        ; 2 bytes — function pointer
[inline args]        ; 0–N bytes — consumed by the action
```

Actions come in two kinds:

| Kind | What it does | Ends by calling |
|---|---|---|
| **Non-blocking** | Does work, advances immediately | `sys_beh_next` (chains to next action in the same frame) |
| **Blocking** | Does per-frame work, then yields | `sys_beh_check_conditions` (returns; entity re-runs action next frame) |

Multiple non-blocking actions chain in a single frame tick.  Execution stops
when a blocking action finds no matching condition, or at `CONDITIONS_END`.

### Condition table

Blocking actions (`IDLE`, `WAIT`) are followed by a **condition table**:

```
.dw condition_fn     ; 2 bytes (0x0000 = CONDITIONS_END)
.dw target_label     ; 2 bytes — jump-to when condition is true
...
.dw 0                ; CONDITIONS_END
```

Conditions are small functions that inspect the entity (via `IX`) and return:

- **Z = 1** → condition is **true** → engine jumps to `target_label`
- **Z = 0** → condition is **false** → engine tries the next entry

When no condition fires the entity stays at the same blocking action and the
condition table is re-evaluated next frame.

### `DESTROY_ENTITY`

Using `DESTROY_ENTITY` (= `0x0000`) as a target sets the entity's `e_cmps` to
`c_cmp_invalid`, removing it from all system loops.

---

## Engine internals

All cross-function transitions inside the engine use `jp` (not `call`), so the
Z80 stack depth never grows during a behaviour run.  The only place the stack
grows is the single `call sys_beh_call_hl` used to invoke condition functions.

```
sys_beh_update_one_entity
  └─ jp sys_beh_run              ← reads action ptr at DE, jp (hl) to action

non-blocking action
  └─ jp sys_beh_next             ← saves DE to e_beh, jp sys_beh_run (chains)

blocking action
  └─ jp sys_beh_check_conditions ← iterates condition table
       condition true  → jp sys_beh_next (advance to target)
       condition false → loop to next entry
       CONDITIONS_END  → ret    (entity stays; same action re-runs next frame)
```

---

## Entity fields

| Field | Size | Description |
|---|---|---|
| `e_beh` | 2 B | Pointer to current position in behaviour program. `0` = no behaviour. |
| `e_beh_timer` | 1 B | Countdown used by `WAIT` / `beh_cond_timeout`. |

---

## DSL macro reference (`beh.h.s`)

### Actions

| Macro | Args | Description |
|---|---|---|
| `IDLE` | — | Blocking: check conditions immediately each frame. |
| `WAIT ticks, next` | — | Set timer, then block until `timeout`, then jump to `next`. Add extra `CONDITION` entries or `CONDITIONS_END` after. |
| `SET_TIMER n` | — | Set `e_beh_timer = n` (1-byte value, 1–255). |
| `SET_VX vx` | — | Set `e_speed_x` low byte. Marks entity dirty. |
| `SET_VY vy` | — | Set `e_speed_y` low byte. Marks entity dirty. |
| `SET_ANIMATION addr` | — | Point `e_anim` at an animation descriptor; resets frame/timer. |
| `GOTO target` | — | Unconditional jump to `target` label. Do **not** follow with `CONDITIONS_END`. |

### Condition table

| Macro | Description |
|---|---|
| `CONDITION cond, target` | Entry: calls `beh_cond_cond`; jumps to `target` if true. |
| `CONDITIONS_END` | Terminates the condition table (`.dw 0`). |

### Built-in conditions

| Symbol | True when |
|---|---|
| `beh_cond_true` | Always |
| `beh_cond_timeout` | `e_beh_timer == 0` |
| `beh_cond_on_ground` | `e_on_air == 0` |
| `beh_cond_not_on_ground` | `e_on_air != 0` |
| `beh_cond_edge_ahead` | No existe superficie bajo el pie delantero |

## Model01 enemy examples

Model01 adds three blocking actions in `src/game/behaviors.s`. They demonstrate
how a game can extend the interpreter without adding game imports to `sys/beh`:

| Macro | Inline configuration | Result |
|---|---|---|
| `GAME_CHASE_PLAYER speed, stride` | speed magnitude and frame stride | Recomputes left/right direction toward the player every tick |
| `GAME_PATROL_X left, right, speed, stride` | absolute world-X limits | Reverses at configured positions, independently of platform edges |
| `GAME_FLY_Y top, bottom, speed, stride` | absolute world-Y limits | Moves directly between two heights without gravity |

Corresponding complete programs are `game_beh_chase_player`,
`game_beh_patrol_positions` and `game_beh_flying_enemy`. Their factories accept
`B=x`, `C=y`, `D=room`:

```asm
call game_entity_create_chaser_enemy
call game_entity_create_position_patrol_enemy
call game_entity_create_flying_enemy
```

The flying factory intentionally omits `c_cmp_movable`; its behavior owns
vertical motion, so generic gravity and terrain physics do not affect it.

---

## Writing a new condition

A condition function receives `IX = entity` and must return `Z=1` for true,
`Z=0` for false. Register its `.globl` once in `src/globals.inc` and define it
in the game module that owns the rule.

```asm
;; True when entity's x position is past the right screen edge (x >= 160)
beh_cond_off_screen_right::
    ld a, e_x(ix)
    cp #160        ;; Z=1 if x==160, C=0 if x>=160
    ret c          ;; x < 160 → false (Z=0, carry set → not taken)
    xor a          ;; x >= 160 → A=0, Z=1 → true
    ret
```

Add `beh_cond_off_screen_right` to `src/globals.inc` and use it
in any condition table:

```asm
    IDLE
      CONDITION off_screen_right, my_reset_label
      CONDITIONS_END
```

---

## Example — a sentry entity

The following creates a sentry that patrols left and right, freezes for a
moment when it reaches each end, and can be destroyed by marking it invalid.

### Behaviour program (`src/game/sentry.s`)

```asm
.include "sys/beh.h.s"
.include "sys/entity.h.s"
.include "globals.inc"

.module sentry

.area _DATA

sentry_behavior::
    SET_VX #3                       ;; walk right
sentry_walk_right::
    IDLE
      CONDITION off_right_edge, sentry_pause_right
      CONDITIONS_END
sentry_pause_right::
    SET_VX #0                       ;; stop
    WAIT 30, sentry_walk_left       ;; pause 30 frames
    CONDITIONS_END
sentry_walk_left::
    SET_VX #-3                      ;; walk left
    IDLE
      CONDITION off_left_edge, sentry_pause_left
      CONDITIONS_END
sentry_pause_left::
    SET_VX #0
    WAIT 30, sentry_behavior        ;; pause and loop back
    CONDITIONS_END
```

### Custom conditions (`src/game/sentry.s`, continued)

```asm
.area _CODE

;; True when entity x >= 155 (near right edge of play area)
beh_cond_off_right_edge::
    ld a, e_x(ix)
    cp #155
    ret c          ;; x < 155 → false
    xor a          ;; x >= 155 → Z=1, true
    ret

;; True when entity x <= 5 (near left edge)
beh_cond_off_left_edge::
    ld a, e_x(ix)
    cp #6
    ret nc         ;; x >= 6 → false
    xor a          ;; x < 6 → Z=1, true
    ret
```

> **Important:** register `sentry_behavior` and both condition callbacks once
> in `src/globals.inc` before using them from another assembly module.

### Spawning the sentry (`src/game/entities.s` or similar)

```asm
.include "sys/beh.h.s"
.include "sys/entity.h.s"
.include "globals.inc"

;; Create a sentry using a game-owned template as a base.
game_entity_create_sentry::
    ld hl, #game_object_template
    call sys_entity_create          ;; returns IX=new entity, carry set on failure
    ret c

    ;; Configure components
    ld e_cmps(ix), #(c_cmp_render | c_cmp_movable | c_cmp_collisionable | c_cmp_behavior)
    ld e_x(ix),   #10
    ld e_y(ix),   #120
    ld e_room(ix), #0
    ld e_moved(ix), #1

    ;; Wire up the behaviour
    ld e_beh(ix),   #<sentry_behavior
    ld e_beh+1(ix), #>sentry_behavior

    or a                           ;; carry clear: success
    ret
```

### Result

Each frame the game loop calls:

1. `sys_physics_update` — applies `e_speed_x` / `e_speed_y` to position
2. **`sys_beh_update`** — runs the sentry's behaviour step:
   - If walking right and not yet at edge: `IDLE` re-checks conditions, none fire, entity stays
   - Once `beh_cond_off_right_edge` returns true: `SET_VX #0`, `WAIT 30`, then `SET_VX #-3`
3. `sys_render_update` — redraws the entity because `e_moved` was set by `SET_VX`
