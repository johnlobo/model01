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
3. Call `man_game_init` → initializes entities, creates players, inits render
4. Loop forever calling `man_game_update`

`man_game_update` (in `src/man/game.s`) runs each frame:
1. `sys_physics_update` — apply gravity/friction/movement
2. `sys_input_update` — read keyboard, dispatch to handlers (IX = active entity)
3. `sys_ai_update` — AI bounce/gravity for AI-controlled entities
4. `sys_beh_update` — bytecode behavior state machine for `c_cmp_ai` entities with `e_beh != 0`
5. `sys_collision_update` — AABB collision detection between collider/collisionable entities
6. `sys_anim_update` — advance animation frames for animated entities
7. `cpct_waitVSYNC_asm` — wait for vertical sync
8. `sys_render_update` — draw all dirty entities

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

The entity struct (`e`) is defined via `BeginStruct`/`Field`/`EndStruct` macros in `src/man/entity.h.s`. Fields (in order): `e_cmps`, `e_status`, `e_x`, `e_y`, `e_coord_x` (2B), `e_coord_y` (2B), `e_address` (2B), `e_p_address` (2B), `e_speed_x` (2B), `e_speed_y` (2B), `e_on_air`, `e_width`, `e_height`, `e_color`, `e_sprite` (2B), `e_moved`, `e_anim` (2B, pointer to animation descriptor or null), `e_anim_frame`, `e_anim_timer`.

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
    render.s / render.h.s     # Sprite drawing, double-buffer management
    physics.s / physics.h.s   # Gravity, friction, ground collision
    input.s / input.h.s       # Keyboard scan, key→action dispatch table
    ai.s / ai.h.s             # AI gravity bounce behavior
    collision.s / collision.h.s # AABB collision detection
    anim.s / anim.h.s         # Frame animation: descriptor-driven, updates e_sprite
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
Set `e_anim` to point to this descriptor and add `c_cmp_animated` to the entity's `e_cmps`. The system advances `e_anim_frame`, wraps at `frame_count`, and updates `e_sprite` + sets `e_moved` each tick.

### Behavior System (`src/sys/beh.s`, `src/sys/beh.h.s`)

A bytecode-driven per-entity state machine, similar in design to *The Abduction of Oscar Z*. Runs after `sys_ai_update` in the game loop for all `c_cmp_ai` entities that have `e_beh != 0` (entities without a behavior pointer are left to the old AI bounce logic in `sys/ai.s`).

**Engine flow — all cross-function jumps are `jp`, not `call`, so the Z80 stack stays flat:**

```
sys_beh_update_one_entity → sys_beh_run → jp(action)
  non-blocking action → sys_beh_next → saves DE to e_beh → sys_beh_run (chains)
  blocking action     → sys_beh_check_conditions
    condition true    → sys_beh_next (advance to target)
    condition false   → skip, try next entry
    CONDITIONS_END    → ret (entity stays at this blocking action next frame)
```

**Behavior program format** (static data in `.area _DATA`):
```asm
my_behavior::
    SET_VX #2                        ;; non-blocking action + 1-byte arg
    WAIT 60, my_next_state           ;; SET_TIMER + WAIT + CONDITION timeout
    CONDITIONS_END                   ;; end condition table
my_next_state:
    SET_VX #-2
    GOTO my_behavior                 ;; unconditional jump (IDLE + CONDITION true)
```

**DSL macros** (defined in `beh.h.s`): `IDLE`, `WAIT ticks, target`, `SET_TIMER n`, `SET_VX vx`, `SET_VY vy`, `SET_ANIMATION addr`, `GOTO target`, `CONDITION cond, target`, `CONDITIONS_END`.

**Condition convention:** return `Z=1` for true (take branch), `Z=0` for false.

**Built-in conditions:** `beh_cond_true`, `beh_cond_timeout`, `beh_cond_on_ground`, `beh_cond_not_on_ground`.

**Entity fields added:** `e_beh` (2B — current position in program, 0 = no behavior), `e_beh_timer` (1B — countdown for `WAIT`).

**Shared behavior:** `beh_bounce_behavior` — simple left-right patrol (SET_VX ±2, WAIT 60 frames each direction). Wire an entity by setting `e_beh(ix)` to `#beh_bounce_behavior` after creation. The entity must also have `c_cmp_movable` for physics to apply the velocity.

**`DESTROY_ENTITY` (= 0x0000):** use as the target of a `CONDITION` to remove the entity (sets `e_cmps = c_cmp_invalid`).

### File Naming Convention

- `.s` — Z80 assembly source
- `.h.s` — Assembly "header" (`.globl` declarations, struct definitions, macros)
- Each module has a paired `.s` and `.h.s`; consumers `.include` only the `.h.s`

### Key Constants (in `src/common.h.s`)

- `GROUND_LEVEL = 199` — defined in `common.h.s`; `FRONT_BUFFER`, `BACK_BUFFER` — screen buffer addresses defined in `sys/render.h.s`
- `S_MONK_WIDTH = 5`, `S_MONK_HEIGHT = 16` (sprite dimensions in bytes/pixels)
- `MAX_ENTITIES = 10`
- `transparency_table` at `0x0100` — 256-byte aligned mask table for masked sprite drawing

### Map System (`src/sys/map.s`, `src/sys/map.h.s`)

Draws a static 16×20 tile background using CPCtelera's ETM 4×8 engine (`cpct_etm_drawTilemap4x8_agf_asm`). The full tilemap is redrawn every frame (naturally erasing previous entity sprites), so no separate entity-erase step is needed.

**Critical: ETM ASM register convention** — the `.asm` documentation header lists parameters in C order, but the ASM variant requires:
- `cpct_etm_setDrawTilemap4x8_agf_asm`: `C` = map width, `B` = map height, `DE` = tilemap width, `HL` = tileset base pointer
- `cpct_etm_drawTilemap4x8_agf_asm`: **`HL` = tilemap data pointer**, **`DE` = video memory pointer** (NOT HL=video, DE=tilemap — that's backwards and will silently corrupt both buffers)

The ETM draw function uses self-modifying code and hijacks the Z80 stack pointer (saves/restores SP per row) to fast-copy tile data via `pop bc`. It destroys AF, BC, DE, HL, IX, IY — safe because `sys_array_execute_each_ix_matching` uses self-modifying code for its loop state, not IX/IY as persistent registers.

**Tileset format:** Tiles are converted with `zgtiles` format in `cfg/image_conversion.mk`, which outputs bytes in gray-code row order (0,1,3,2,6,7,5,4) as required by the ETM engine. Generated arrays `s_tileset_00`…`s_tileset_NN` are `const u8[32]` in the same C translation unit — SDCC places them consecutively in `_CODE` with no padding, so `_s_tileset_00` serves as the flat tileset base. Tile 0 (`s_tileset_00`) is the blank tile; map data uses 0-based IDs.

**Render flow:** `sys_render_update` calls `sys_map_draw` first, then `sys_render_entities`. Entities always draw every frame (no `e_moved` check) since the map redraw erases the previous frame.

### Assets

PNG images in `assets/` are converted to C source files in `src/assets/sprites/` by the CPCtelera image conversion tools (`cfg/image_conversion.mk`). Tilemap `.tmx` files are converted via `cfg/tilemap_conversion.mk`. Do not edit the generated `.c`/`.h` files in `src/assets/sprites/` directly — regenerate from source images.
