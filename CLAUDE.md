# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is an Amstrad CPC game built with the **CPCtelera** engine, written entirely in **Z80 assembly** (`.s` files). It targets the Amstrad CPC hardware (Mode 0, 16 colors) and compiles to `.cdt`, `.dsk`, and `.sna` output formats.

The project name is `model01`, code starts at Z80 address `0x4000`.

## Build Commands

```bash
make            # Build all targets (CDT, DSK, SNA)
make clean      # Remove compiled object files
make cleanall   # Remove all generated files
```

The `CPCT_PATH` environment variable must be set to the CPCtelera installation directory before building.

To run in an emulator (after building):
```bash
cpct_winape -as -f    # Linux/Windows (WinAPE emulator via CPCtelera)
cpct_rvm -as -f       # macOS (RetroVirtualMachine)
```

VSCode tasks for `make`, `clean`, `cleanall`, and `run` are configured in [.vscode/tasks.json](.vscode/tasks.json).

## Architecture

### Game Loop (`src/main.s`)

Entry point is `_main::`. Initialization sequence:
1. Disable CPC firmware (`sys_system_disable_firmware`)
2. Set video mode 0
3. Call `man_game_init` → initializes entities, creates players, inits render, inits map and draws it once
4. Loop forever calling `man_game_update`

`man_game_update` (in `src/man/game.s`) runs each frame:
1. `sys_physics_update` — apply gravity/friction/movement
2. `man_game_check_transition` — check if player has reached a map edge and transition to adjacent room
3. `sys_input_update` — read keyboard, dispatch to handlers (IX = active entity)
4. `sys_ai_update` — AI bounce/gravity for AI-controlled entities
5. `sys_beh_update` — bytecode behavior state machine for `c_cmp_ai` entities with `e_beh != 0`
6. `sys_collision_update` — AABB collision detection between collider/collisionable entities
7. `sys_anim_update` — advance animation frames for animated entities
8. `cpct_waitVSYNC_asm` — wait for vertical sync
9. `sys_render_update` — two-pass tile restore + redraw of all entities

### Coordinate System

**Entities use world coordinates** (origin = map top-left corner):
- `e_x` = horizontal position in bytes from map left edge (0 = leftmost column)
- `e_y` = vertical position in pixels from map top edge (0 = top of tile row 0)

**Screen position** = world position + map origin:
```
screen_x = e_x + map_origin_x
screen_y = e_y + map_origin_y
```

`map_origin_x` and `map_origin_y` are exported variables in `map.s` (default 0 and `MAP_PIXEL_START` respectively). All map collision functions (`sys_map_is_solid_at`, `sys_map_is_landable_at`, `sys_map_restore_tiles_at`) take world coordinates as input and add the origin internally. `GROUND_LEVEL = MAP_HEIGHT * 8 - 1 = 159` acts as a hard floor fallback in world space (tile collision handles landing before this is reached in normal play).

### Entity Component System

Entities are stored in a flat array (`entities` in `src/man/entity.s`). Each entity has a component bitmask (`e_cmps`) that controls which systems process it:

| Flag | Value | Meaning |
|------|-------|---------|
| `c_cmp_render` | 0x01 | Rendered each frame |
| `c_cmp_movable` | 0x02 | Physics applied |
| `c_cmp_input` | 0x04 | Player-controlled |
| `c_cmp_ai` | 0x08 | AI-controlled |
| `c_cmp_animated` | 0x10 | Animated sprite |
| `c_cmp_collider` | 0x20 | Active collider (outer loop, initiates checks) |
| `c_cmp_collisionable` | 0x40 | Passive collision target (inner loop, receives checks) |

The entity struct (`e`) is defined via `BeginStruct`/`Field`/`EndStruct` macros in `src/man/entity.h.s`. Fields (in order): `e_cmps`, `e_status`, `e_x`, `e_y`, `e_p_x` (2B — world x at last draw, used by tile restore), `e_p_y` (2B — world y at last draw), `e_address` (2B), `e_p_address` (2B — non-zero sentinel once drawn), `e_speed_x` (2B), `e_speed_y` (2B), `e_on_air`, `e_width`, `e_height`, `e_color`, `e_sprite` (2B), `e_moved`, `e_anim` (2B, pointer to animation descriptor or null), `e_anim_frame`, `e_anim_timer`, `e_beh` (2B), `e_beh_timer`, `e_room` (room ID — entity is only rendered/restored when `e_room == current_room`).

### Array System (`src/sys/array.s`, `src/sys/array.h.s`)

Generic dynamic array with a header struct (`a`): `a_count`, `a_component_size`, `a_pend`, `a_array`.

Key functions:
- `sys_array_create_element` — copies a template struct into the array (uses `ldir`)
- `sys_array_execute_each_ix_matching` — calls a routine for each entity whose `e_cmps` AND-matches a bitmask (`b` register); IX points to current entity during callback

### Source Layout

```
src/
  main.s              # Entry point, _main::
  common.h.s          # Global constants, component flags, struct macros
  man/
    game.s / game.h.s     # Game manager: init + update loop orchestration
    entity.s / entity.h.s # Entity array, player template, DefineEntity macro
  sys/
    array.s / array.h.s   # Generic array + iteration system
    render.s / render.h.s     # Two-pass sprite rendering (restore + draw)
    physics.s / physics.h.s   # Gravity, friction, tile collision (world coords)
    input.s / input.h.s       # Keyboard scan, key→action dispatch table
    ai.s / ai.h.s             # AI gravity bounce behavior
    collision.s / collision.h.s # AABB collision detection
    anim.s / anim.h.s         # Frame animation: descriptor-driven, updates e_sprite
    map.s / map.h.s           # Tilemap draw, tile collision, per-tile erase
    system.s / system.h.s     # Firmware disable
    text.s / text.h.s         # Text drawing
    util.s / util.h.s         # Math utilities
    messages.s / messages.h.s # Message system
  assets/sprites/         # Generated C files from PNG assets (monk, font, palette, small_numbers)
```

### Animation Descriptor Format (`src/sys/anim.h.s`)

An animation descriptor is a contiguous block in `.area _DATA`:
```
.db frame_count    ; total frames
.db speed          ; ticks between frame advances (0 = advance every tick)
.dw sprite_ptr_0   ; pointer to frame 0 sprite data
.dw sprite_ptr_1   ; pointer to frame 1 sprite data
...
```
Set `e_anim` to point to this descriptor and add `c_cmp_animated` to the entity's `e_cmps`. The system advances `e_anim_frame`, wraps at `frame_count`, and updates `e_sprite` + sets `e_moved` each tick. When `e_speed_x == 0` and `e_on_air == 0` the entity is idle and animation is skipped entirely.

### Behavior System (`src/sys/beh.s`, `src/sys/beh.h.s`)

A bytecode-driven per-entity state machine. Runs after `sys_ai_update` for all `c_cmp_ai` entities with `e_beh != 0`.

**Engine flow — all cross-function jumps are `jp`, not `call`, so the Z80 stack stays flat:**

```
sys_beh_update_one_entity → sys_beh_run → jp(action)
  non-blocking action → sys_beh_next → saves DE to e_beh → sys_beh_run (chains)
  blocking action     → sys_beh_check_conditions
    condition true    → sys_beh_next (advance to target)
    condition false   → skip, try next entry
    CONDITIONS_END    → ret (entity stays at this blocking action next frame)
```

**DSL macros** (defined in `beh.h.s`): `IDLE`, `WAIT ticks, target`, `SET_TIMER n`, `SET_VX vx`, `SET_VY vy`, `DRIVE_VX accel, max_speed`, `SET_ANIMATION addr`, `GOTO target`, `CONDITION cond, target`, `CONDITIONS_END`.

**Condition convention:** return `Z=1` for true, `Z=0` for false. Built-in: `beh_cond_true`, `beh_cond_timeout`, `beh_cond_on_ground`, `beh_cond_not_on_ground`, `edge_ahead` (no ground tile under the leading foot — use for platform patrol).

**`DESTROY_ENTITY` (= 0x0000):** use as the target of a `CONDITION` to remove the entity.

**Built-in behavior programs** (in `src/sys/beh.s`):
- `beh_bounce_behavior` — simple timed patrol: move right for ~60 frames, then left, repeat
- `beh_patrol_behavior` — edge-detecting platform patrol: walks right/left, reverses on `edge_ahead`, switches walk animation to match direction. Requires `c_cmp_movable | c_cmp_animated`.

### File Naming Convention

- `.s` — Z80 assembly source
- `.h.s` — Assembly "header" (`.globl` declarations, struct definitions, macros)
- Each module has a paired `.s` and `.h.s`; consumers `.include` only the `.h.s`

### Key Constants (in `src/common.h.s`)

- `GROUND_LEVEL = MAP_HEIGHT * 8 - 1` (= 159) — hard floor in world space (fallback below map)
- `FRONT_BUFFER`, `BACK_BUFFER` — screen buffer addresses defined in `sys/render.h.s`
- `S_MONK_WIDTH = 5`, `S_MONK_HEIGHT = 16` (sprite dimensions in bytes/pixels)
- `MAP_WIDTH = 16`, `MAP_HEIGHT = 20`, `MAP_START_ROW = 5`, `MAP_PIXEL_START = 40`
- `MAX_ENTITIES = 10`
- `transparency_table` at `0x0100` — 256-byte aligned mask table for masked sprite drawing

### Map System (`src/sys/map.s`, `src/sys/map.h.s`)

Draws a static 16×20 tile background using CPCtelera's ETM 4×8 engine. **The map is drawn once at init** (`man_game_init` calls `sys_map_draw`). During gameplay, only the tiles under moved entities are redrawn — never the full map.

The game has three rooms (`_g_map01`, `_g_map02`, `_g_map03`) arranged left-to-right. `current_room` (0/1/2) and `current_map_data` (pointer to active tilemap) are exported from `map.s`. `sys_map_set` (input: HL = tilemap pointer) switches the active map, redraws it fully, and updates `current_map_data`. Render pass 1 and 2 both skip entities whose `e_room != current_room`. Map transitions are handled by `man_game_check_transition` in `game.s`: when the player walks off a left/right edge, it calls `sys_map_set`, updates `current_room`, repositions the player one step from the opposite edge (to prevent immediate re-trigger), and resets `e_p_address` to force a clean first-draw.

**Critical: ETM ASM register convention** — the `.asm` documentation header lists parameters in C order, but the ASM variant requires:
- `cpct_etm_setDrawTilemap4x8_agf_asm`: `C` = map width, `B` = map height, `DE` = tilemap width, `HL` = tileset base pointer
- `cpct_etm_drawTilemap4x8_agf_asm`: **`HL` = tilemap data pointer**, **`DE` = video memory pointer** (NOT HL=video, DE=tilemap — that's backwards and will silently corrupt both buffers)

**Tileset format:** Tiles are converted with `zgtiles` format in `cfg/image_conversion.mk`, outputting bytes in gray-code row order (0,1,3,2,6,7,5,4) as required by the ETM engine. Generated arrays `s_tileset_00`…`s_tileset_NN` are consecutive in `_CODE` — `_s_tileset_00` is the flat tileset base.

**Important:** tile sprite data is in ETM gray-code row order and is **not** compatible with `cpct_drawSprite_asm` (which expects linear row order). `smrsa_draw_one_tile` uses the same SP-hijack trick as the ETM engine (`di`, save SP, `ld sp, ix` to point SP at tile data, read 8 rows via `pop bc` with H-bit manipulation for CPC scanline zig-zag, restore SP, `ei`) to draw individual tiles correctly.

**Render flow:** `sys_render_entities` runs two passes over all `c_cmp_render` entities:
- **Pass 1 (`sys_render_restore_one_entity`):** for each entity with `e_moved=1`, calls `sys_map_restore_tiles_at` to redraw the map tiles under the entity's *previous* bounding box (`e_p_x`, `e_p_y`). All restores happen before any entity is redrawn, preventing one entity's restore from clobbering another's freshly-drawn sprite.
- **Pass 2 (`sys_render_one_entity`):** draws every entity at its current world position, translated to screen via `map_origin_x`/`map_origin_y`. Uses `cpct_drawSpriteMaskedAlignedTable_asm` (BC=sprite, DE=screen_addr, IXH=height, IXL=width, HL=transparency_table) for transparent sprites. Saves `e_x`/`e_y` to `e_p_x`/`e_p_y` for next frame's restore. Sets `e_p_address` to a non-zero sentinel on first draw.

**Tile collision types** (`tile_solid_table` in `map.s`):

| Value | Meaning | Tiles |
|-------|---------|-------|
| `0` | Passable | 0, 10, 11, 13, 15 |
| `1` | Fully solid — blocks all directions | 2–9, 12 |
| `2` | Jumpable (one-way platform) — blocks floor/sides, passable from below | 1, 14 |

Two collision query functions (both take **world coordinates**: B=world_y, C=world_x_bytes):
- `sys_map_is_solid_at` — NZ only for type==1. Used for **ceiling** checks (entities can jump through type-2 platforms).
- `sys_map_is_landable_at` — NZ for type==1 or 2. Used for **floor**, **horizontal**, and ground-standing checks.

Both share the internal `smisa_get_type` routine and return Z if out of bounds. The SP-hijack tile draw also bounds-checks (tile_row ≥ MAP_HEIGHT or tile_col ≥ MAP_WIDTH → skip, safely handling entities near or above the map edge).

Physics constants in `src/sys/physics.s`: `GRAVITY = 1`, `MAX_FALL_SPEED = 8`. Fall speed is capped to prevent tunneling through tiles (speed can never exceed tile height of 8px).

### Entity Factory Functions (`src/man/entity.s`, `src/man/entity.h.s`)

`man_game_init` creates the player and the patrol enemy. To add more entities, call these from `man_game_init` before `sys_map_draw`:

| Function | Input | Output | Notes |
|----------|-------|--------|-------|
| `man_entity_create_player_player` | — | IX = entity | Single player; `c_cmp_input | c_cmp_movable | c_cmp_render | c_cmp_collider | c_cmp_animated` |
| `man_entity_create_patrol_enemy` | — | IX = entity | Uses `beh_patrol_behavior`; room 0 |
| `man_entity_create_object` | B=world_x, C=world_y, D=room_id | IX = entity | Static collisionable object |
| `man_entity_create_portal` | B=world_x, C=world_y, D=room_id | IX = entity | See portal destination below |

**Portal destination encoding** — portals have no physics/AI so their behavior fields are repurposed:
```asm
man_entity_create_portal     ; B=x, C=y, D=room_id
ld e_beh(ix),      #dest_room
ld e_beh+1(ix),    #dest_x
ld e_beh_timer(ix),#dest_y
```

### Messages System (`src/sys/messages.s`, `src/sys/messages.h.s`)

Draws centered dialog boxes directly to the front buffer. Main entry point:

```
sys_messages_show
  Input:  HL = pointer to null-terminated message string
          A  = wait_for_key flag (1 = wait for keypress, 2 = auto-dismiss after delay)
          A' = background color pattern
          DE = y coordinate (D=y, E=unused)
          BC = window height (B=h, C=unused — width is auto-calculated from string length)
  Output: HL = number of wait loops (when wait_for_key=1)
```

The function saves the background behind the window, draws the box, draws the string, optionally shows "PRESS ANY KEY", waits if requested, then restores the background. `sys_messages_restore_message_background` can be called separately to erase the window.

### Version String

`_welcome_string` in `src/sys/render.s` (e.g. `"WELCOME - V.017"`) is the build version displayed at startup. **Bump this string after every significant change.**

### Assets

PNG images in `assets/` are converted to C source files in `src/assets/sprites/` by the CPCtelera image conversion tools (`cfg/image_conversion.mk`). Tilemap `.tmx` files are converted via `cfg/tilemap_conversion.mk`. Do not edit the generated `.c`/`.h` files in `src/assets/sprites/` directly — regenerate from source images.
