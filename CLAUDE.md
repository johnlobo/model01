# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is an Amstrad CPC game called `model01`, written entirely in **Z80 assembly** (`.s` files) using the CPCtelera engine. It targets Mode 0 (160×200, 16 colors).

## Memory Map

`Z80CODELOC` (in `cfg/build_config.mk`) is `0x4000`. The binary's load address is `0x0100` — the lowest emitted record, which is the transparency table's `.area _ABS`, not the code. That is expected; don't "fix" it.

| Range | Contents |
|-------|----------|
| `0x0000–0x003F` | RST vectors. `0x0038` = IM1 interrupt entry |
| `0x0100–0x01FF` | `transparency_table` (`main.s`, `.area _ABS`). Must stay 256-byte aligned |
| `0x0200–0x3FFF` | Free low RAM. `sys_mem_init` copies the 19-byte banking stub to `0x0200` |
| `0x4000–0x7FFF` | `_CODE`, then `_DATA` — **and the 128K banking window** |
| `0x8000–0xBFFF` | Back buffer (declared, unused) + the firmware stack (~`0xBFxx`) |
| `0xC000–0xFFFF` | Front buffer — everything currently draws here |

**Code and data live inside the banking window.** That is the single most important fact about this layout, and it is what makes `sys/mem.s` delicate — see the Extended Memory System section. SP is left where the firmware put it (~`0xBFxx`), which is outside the window; if you ever relocate it, keep it out of `0x4000–0x7FFF`.

If double-buffering is ever enabled, `sys_render_clear_back_buffer` `ldir`s 16K over `0x8000–0xBFFF` — which would wipe that firmware stack. Move SP first.

## Build Commands

```bash
make            # Build → .cdt, .dsk, .sna
make clean      # Remove object files
make cleanall   # Remove all generated files

# Run in emulator after building:
cpct_winape -as -f    # Linux/Windows
cpct_rvm -as -f       # macOS
```

`CPCT_PATH` must be set to the CPCtelera installation directory. VSCode tasks for `make`, `clean`, `cleanall`, and `run` are in [.vscode/tasks.json](.vscode/tasks.json).

## Version String

`_welcome_string` in `src/sys/render.s` (e.g. `"WELCOME - V.023"`) is displayed at startup. **Bump this after every significant change.**

There is also `_game_loaded_string` in `src/main.s` — keep it in sync.

## Architecture

### Game Loop

Entry point is `_main::` in `src/main.s`. After firmware disable and video init, calls `man_game_init` then loops forever calling `man_game_update`.

`man_game_update` runs each frame in this order:
1. `sys_physics_update` — gravity, friction, tile collision
2. `sys_shoot_update` — advance bullets, destroy them off map bounds
3. `man_game_check_transition` — room-edge transitions
4. `sys_input_update` — keyboard dispatch (IX = player entity)
5. `sys_ai_update` — AI gravity/bounce
6. `sys_beh_update` — bytecode behavior state machine
7. `sys_collision_update` — AABB detection
8. `sys_anim_update` — advance animation frames
9. `sys_render_prepare` — build the Y-sorted render queue before vsync
10. `cpct_waitVSYNC_asm` — wait for vsync
11. `sys_render_update` — restore bottom-to-top, then redraw top-to-bottom

### Coordinate System

Entities use **world coordinates** (origin = map top-left):
- `e_x` = horizontal in bytes from map left edge
- `e_y` = vertical in pixels from map top edge
- Screen position = world + `map_origin_x` / `map_origin_y` (defaults: x=8 bytes, y=16 px)

**`map_origin_y` must be a multiple of 8** — the SP-hijack tile draw only works correctly at character-row boundaries.

`GROUND_LEVEL = MAP_HEIGHT * 8 - 1 = 159` is the hard-floor fallback in world space.

### Entity Component System

Entities live in a flat array (`entities` in `src/man/entity.s`, max 10). Each has a bitmask `e_cmps`:

| Flag | Value | Meaning |
|------|-------|---------|
| `c_cmp_render` | 0x01 | Rendered each frame |
| `c_cmp_movable` | 0x02 | Physics applied |
| `c_cmp_input` | 0x04 | Player-controlled |
| `c_cmp_ai` | 0x08 | AI-controlled |
| `c_cmp_animated` | 0x10 | Animated sprite |
| `c_cmp_collider` | 0x20 | Active collider (outer loop) |
| `c_cmp_collisionable` | 0x40 | Passive collision target (inner loop) |
| `c_cmp_projectile` | 0x80 | Bullet — moved by `sys_shoot_update`, not physics |

The entity struct (`e`) is defined with `BeginStruct`/`Field`/`EndStruct` in `src/man/entity.h.s`. Fields in order: `e_cmps`, `e_status`, `e_x`, `e_y`, `e_p_x` (2B), `e_p_y` (2B), `e_address` (2B), `e_p_address` (2B), `e_speed_x` (2B), `e_speed_y` (2B), `e_on_air`, `e_width`, `e_height`, `e_color`, `e_sprite` (2B), `e_moved`, `e_anim` (2B), `e_anim_frame`, `e_anim_timer`, `e_beh` (2B), `e_beh_timer`, `e_room`.

**All systems skip entities whose `e_room != current_room`.**

### Input System (`src/sys/input.s`)

`sys_input_update` resets the player to idle animation each frame, then scans `sys_input_key_actions` — a null-terminated table of `(key_constant, handler_address)` 4-byte pairs dispatched via `sys_input_generic_update`. All handlers receive IX = player entity.

Current key bindings:
| Key | Handler | Action |
|-----|---------|--------|
| O | `sys_input_selected_left` | Move left at speed −2, switch to walk-left anim |
| P | `sys_input_selected_right` | Move right at speed +2, switch to walk-right anim |
| Q | `sys_input_action` | Variable-height jump (see below) |
| Space | `sys_input_shoot` | Fire a player bullet (see Shooting System below) |

**Jump mechanics** (`sys_input_action`): on ground → set `e_speed_y = -6`, arm `jump_boost_left = 6`. Each subsequent frame Q is held while rising and boost frames remain: decrement speed_y by 1 (cap at −12). Tap = small hop; full hold = max jump.

To add a new key binding: append a `.dw Key_Xxx, handler_label` pair before the terminating `.dw 0` in `sys_input_key_actions`.

### Map System (`src/sys/map.s`)

Five rooms: `_g_map01`–`_g_map04` (rooms 0–3, linked left-to-right) + `_g_inside01` (room 4, portal-only access).

`sys_map_draw` draws the map once at init via CPCtelera ETM 4×8 engine. During play only tiles under moved entities are redrawn via `sys_map_restore_tiles_at`. Use `sys_map_set` (HL = tilemap ptr) to switch rooms — it redraws the full map and updates `current_room` and `current_map_data`.

**Room connections** are declared in `room_connections` (map.s) with `DefineRoomConnections`. `man_game_check_transition` checks all four edges and calls `mgct_do_horizontal` / `mgct_do_vertical` when the player crosses a boundary; the player is repositioned one step from the opposite edge to prevent instant re-trigger.

**Tile collision types** (`tile_solid_table` in map.s):
| Value | Meaning |
|-------|---------|
| 0 | Passable |
| 1 | Fully solid — blocks all directions |
| 2 | Jumpable (one-way platform) — solid from above/sides, passable from below |

Two query functions (both take world coordinates B=world_y, C=world_x_bytes):
- `sys_map_is_solid_at` — NZ for type==1 only (used for ceiling checks; platforms are passable when jumping up)
- `sys_map_is_landable_at` — NZ for type==1 or 2 (used for floor and horizontal checks)

**Critical ETM ASM register order** (opposite of C docs):
- `cpct_etm_setDrawTilemap4x8_agf_asm`: C=width, B=height, DE=tilemap_width, HL=tileset_base
- `cpct_etm_drawTilemap4x8_agf_asm`: **HL=tilemap_data, DE=video_memory** (NOT swapped)

Tileset sprites are in ETM gray-code row order — not compatible with `cpct_drawSprite_asm`. Individual tile draws use an SP-hijack trick (`di`, save SP, `ld sp, ix`, pop rows via `pop bc` with H-bit manipulation for CPC scanline zig-zag, restore SP, `ei`).

### Animation (`src/sys/anim.s`)

Animation descriptor format (in `.area _DATA`):
```asm
.db frame_count
.db speed          ;; ticks between advances (0 = every tick)
.dw sprite_ptr_0
.dw sprite_ptr_1
...
```
Set `e_anim` to the descriptor pointer and add `c_cmp_animated`. Animation is skipped when `e_speed_x == 0` and `e_on_air == 0` (idle). Player has three descriptors: `monk_idle_anim` (1 frame), `monk_walk_right_anim`, `monk_walk_left_anim` (4 frames each, 8 ticks/frame).

### Behavior System (`src/sys/beh.s`)

Bytecode state machine for `c_cmp_ai` entities with `e_beh != 0`. **All cross-function jumps use `jp` (not `call`) — the Z80 stack stays flat.**

DSL macros (in `beh.h.s`):
- Non-blocking (chain immediately): `SET_TIMER n`, `SET_VX vx`, `SET_VY vy`, `SET_ANIMATION addr`
- Blocking (check conditions each frame): `IDLE`, `WAIT ticks, target`, `DRIVE_VX vx, stride`
- Control: `GOTO target`, `CONDITION cond, target`, `CONDITIONS_END`

`DRIVE_VX vx, stride` — drives entity at `vx` bytes; `stride=1` moves every frame, `stride=N>1` moves one step every N frames via `e_beh_timer`.

Condition functions return Z=1 for true, Z=0 for false. Built-in: `beh_cond_true`, `beh_cond_timeout`, `beh_cond_on_ground`, `beh_cond_not_on_ground`, `edge_ahead` (no ground tile under the leading foot).

`DESTROY_ENTITY (= 0x0000)` — use as the `CONDITION` target to remove an entity.

Built-in behaviors: `beh_bounce_behavior` (timed left/right patrol), `beh_patrol_behavior` (edge-detecting patrol, reverses on `edge_ahead`, switches walk animation to match direction).

### Shooting System (`src/sys/shoot.s`)

Bullets are regular entities with `c_cmp_projectile` (0x80), moved by `sys_shoot_update` — a straight-line, no-gravity, no-tile-collision walk that destroys the entity (`e_cmps = c_cmp_invalid`) once it leaves `[0, MAP_WIDTH*4]` horizontally. They are **not** processed by `sys_physics_update` (no `c_cmp_movable`). Hit detection against other entities is not wired up — same "extension point" spirit as `sys_collision_on_hit`'s red-flash placeholder.

Two bullet templates in `src/man/entity.s`, using sprites `_s_obj_1` (player) / `_s_obj_2` (enemy) from `assets/model01-8x8obj.png` (`S_BULLET_WIDTH = 4` bytes, `S_BULLET_HEIGHT = 8` px):
- `man_entity_create_player_bullet` / `man_entity_create_enemy_bullet` — Input: B=world x (bytes), C=world y (pixels), D=room id, E=signed speed_x (bytes/step). Both return carry clear on success and carry set if the pool has no append capacity or recyclable slot.

**Player** fires via key Q (`sys_input_shoot` in `src/sys/input.s`), subject to `PLAYER_SHOOT_COOLDOWN` (10 frames, ticked in `sys_input_update`). Spawn edge and bullet direction follow `player_facing` (0=right/1=left), updated by `sys_input_selected_left`/`_right`.

**AI** fires via the `SHOOT speed` behavior DSL macro (`src/sys/beh.h.s` / `beh_action_shoot` in `beh.s`) — a non-blocking action that spawns an enemy bullet at the entity's current position, then chains to the next action. `beh_patrol_behavior` calls `SHOOT #-3` / `SHOOT #3` at each direction reversal as the reference example. Because the entity-creation call clobbers IX, `beh_action_shoot` saves/restores the shooter's IX around it before calling `sys_beh_next`.

**Entity pool capacity:** `DefineArrayStructure` now stores the array's capacity in `a_max_count` (was an unused `a_delta` byte). `sys_array_create_element` refuses to add past `a_max_count` (returns HL unchanged) — relevant here because bullets are created dynamically at runtime, unlike the other entities which are all created once at `man_game_init`.

### Render System (`src/sys/render.s`)

`sys_render_prepare` builds a pointer queue ordered by world Y before VSYNC. Rendering then uses two ordered passes:
1. **Restore pass, bottom-to-top** — for each entity with `e_moved=1`, redraws map tiles under `e_p_x`/`e_p_y` (previous draw position). Reversing the queue makes the topmost erase happen immediately before drawing starts.
2. **Draw pass, top-to-bottom** — follows the CRT raster and draws every entity at its current world position using `cpct_drawSpriteMaskedAlignedTable_asm`. Saves current position and sets `e_p_address` as the "has been drawn" sentinel.

`sys_render_front_buffer = 0xC000`, `sys_render_back_buffer = 0x8000`.

### Collision System (`src/sys/collision.s`)

`sys_collision_update` iterates all `c_cmp_collider` entities (outer IX loop) against all `c_cmp_collisionable` entities (inner IY loop) doing AABB checks.

`sys_collision_on_hit` (IX=collider, IY=collisionable) is the extension point:
- If `e_status(iy) == STATUS_PORTAL` and `e_on_air(iy) == 1`: calls `man_game_do_portal_transition`
- Otherwise: red border flash (placeholder)

### Portal Teleportation

Portals repurpose unused entity fields. After `man_entity_create_portal` (B=x, C=y, D=room_id):
```asm
ld hl, #_g_inside01
ld e_beh(ix), l
ld e_beh+1(ix), h        ;; dest map pointer
ld e_beh_timer(ix), #4   ;; dest room id
ld e_speed_x(ix), #0     ;; dest x (world bytes)
ld e_speed_x+1(ix), #152 ;; dest y (world pixels)
ld e_on_air(ix), #1      ;; 1=active
```

### Array System (`src/sys/array.s`)

Generic dynamic array with header struct `a`: `a_count`, `a_component_size`, `a_pend`, `a_array`.

- `sys_array_create_element` — copies a template struct into an appended or recycled slot (`ldir`); returns carry clear on success and carry set when full
- `sys_array_execute_each_ix_matching` — calls a routine for each entity whose `e_cmps & B != 0`; IX points to the current entity

### Physics (`src/sys/physics.s`)

Constants: `GRAVITY = 1`, `MAX_FALL_SPEED = 8` (caps fall speed to prevent tunneling). Jump constants are in `sys/input.s`: `JUMP_SPEED_MIN = -6`, `JUMP_SPEED_MAX = -12`, `JUMP_BOOST_FRAMES = 6`.

Friction is applied only to `c_cmp_input` entities (not AI). Horizontal and vertical tile collisions clamp the entity to the tile boundary and zero the corresponding speed component.

### Extended Memory System (`src/sys/mem.s`)

Provides safe access to the 64KB of extra RAM available on CPC 6128 (128KB machines). The extra RAM is divided into four 16KB banks (extra banks 0–3) mapped into the `&4000–&7FFF` window via I/O port `&7F00`.

**The fundamental problem:** game code and data live at `&4000–&7FFF` — the same range as the banking window. Banking in an extra bank replaces that window with the extra bank's content, so *anything* the CPU needs from `&4000+` is gone for the duration of the swap. Two separate things get caught by this:

**1. The banking routine itself.** A routine that banked in from `&4000+` would vanish mid-execution. Hence the stub: `sys_mem_init` copies a 19-byte sequence to `&0200` (free low RAM above the transparency table) and all copy operations call it from there. Being outside the window, it survives the swap, completes the `ldir`, restores normal banking, then `ret`s.

**2. The interrupt path — and this one is not obvious.** `int_handler1` also lives in `_CODE` at `&4000+`. An interrupt taken while a bank is in vectors through `&0038` straight into whatever bytes the *extra bank* happens to hold at the handler's address: a jump into garbage, and the machine crashes or hangs. **The stub therefore runs the entire bank-in..bank-out span under `di`.** The `di`/`ei` pair in `_sys_mem_stub_src` is load-bearing — removing it produces an intermittent hang that looks like it comes from whatever system runs next, not from `mem.s`.

The stack (~`&BFxx`, left by the firmware) is outside the window, so the stub's `push`/`pop` around the bank switch is safe. If SP is ever relocated into `&4000–&7FFF`, the `pop bc` after `out (c),a` reads from the extra bank and the following `ldir` runs with a garbage byte count.

**API:**

| Routine | Input | Notes |
|---------|-------|-------|
| `sys_mem_init` | — | Call once at startup; detects 128K, installs stub |
| `sys_mem_is_128k` | — | Byte variable: 1=128K, 0=64K |
| `sys_mem_copy_from_bank` | A=bank(0-3), HL=src in bank, DE=dst, BC=count | Safe from anywhere. DE must not be in `&4000–&7FFF` |
| `sys_mem_copy_to_bank` | A=bank(0-3), HL=src, DE=dst in bank, BC=count | Safe from anywhere. HL must not be in `&4000–&7FFF` |
| `sys_mem_bank_in` | A=bank(0-3) | LOW-LEVEL. Only safe from code at `&8000+` |
| `sys_mem_bank_out` | — | LOW-LEVEL. Only safe from code at `&8000+` |

**Detection:** `sys_mem_init` detects 128K by writing `&AA` to `_smem_test_byte` in normal RAM, then using the stub to write `&55` to that same address with extra bank 0 mapped in. If the byte still reads `&AA` afterward, the banks are independent → 128K confirmed. The `&55` pattern byte is placed at `&0213` (just past the stub), outside the window, so it survives the bank switch.

`_smem_test_byte` sits in `_DATA`, which the linker places right after `_CODE` — i.e. **inside** `&4000–&7FFF`. That is load-bearing, not incidental: the test works precisely because writing there while a bank is in lands in the extra bank rather than in normal RAM. Move it below `&4000` and the write goes to normal RAM, the byte reads back as `&55`, and the machine always reports 64K.

**Usage example:**
```asm
;; Load level 2 data from extra bank 1 into a buffer in normal RAM
ld a, (sys_mem_is_128k)
or a
jr z, _fallback_level          ;; 64K machine: use different path

ld a, #1                       ;; extra bank 1
ld hl, #0x4000                 ;; data starts at beginning of bank window
ld de, #level_buffer           ;; destination in normal RAM (must be outside &4000-&7FFF)
ld bc, #level_data_size
call sys_mem_copy_from_bank
```

**What to store in extra banks:** level maps, large sprite sets, music data, cutscene data. Code cannot execute directly from extra banks — always copy to normal RAM first.

### CPCtelera Calling Conventions

- `cpct_getScreenPtr_asm`: DE=VMEM_START, C=X(bytes), B=Y(px) → HL=addr; clobbers AF,BC,HL
- `cpct_drawSpriteMaskedAlignedTable_asm`: DE=dst, BC=sprite_ptr, IXL=width, IXH=height, HL=transparency_table
- `cpct_drawSolidBox_asm`: DE=dst, B=height, C=width, A=pattern; clobbers DE
- `cpct_isKeyPressed_asm`: HL=key_constant → A≠0 if pressed; clobbers AF
- Macros: `ld__ixl n`, `ld__ixh n` — load IXL/IXH immediate; `cpctm_screenPtr_asm DE, BASE, X, Y` — compile-time fixed screen ptr

A 256-byte transparency table at absolute address `0x100` (in `main.s`) is used by all masked sprite drawing routines.

### Struct Macros (`src/common.h.s`)

```asm
BeginStruct Foo          ; Foo_offset = 0
Field Foo, bar, 2        ; Foo_bar = 0, advances offset by 2
Field Foo, baz, 1        ; Foo_baz = 2
EndStruct Foo            ; sizeof_Foo = 3
```

### Asset Pipeline

PNG images in `assets/` → C arrays in `src/assets/sprites/` via CPCtelera's `IMG2SP` (configured in `cfg/image_conversion.mk`). Tilemap `.tmx` files → via `cfg/tilemap_conversion.mk`. Do not edit generated files in `src/assets/` directly — regenerate from source images.

Monk sprite: 7 frames (`_s_monk_0`–`_s_monk_6`), `S_MONK_WIDTH = 5` bytes, `S_MONK_HEIGHT = 16` px.

Bullet sprites: `_s_obj_0`–`_s_obj_2` from `assets/model01-8x8obj.png` (`S_BULLET_WIDTH = 4` bytes, `S_BULLET_HEIGHT = 8` px). `_s_obj_1` = player bullet, `_s_obj_2` = enemy bullet (`_s_obj_0` unused so far).
