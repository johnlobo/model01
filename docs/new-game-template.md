# New game template

This project is both a game and an example of the framework under `src/sys/`.
A new game replaces the content under `src/game/`, keeps the framework, and
provides the two entry points consumed by `src/main.s`:

```asm
game_app_init::
game_app_update::
```

All link-visible symbols must be declared exactly once in `src/globals.inc`.
Running `make test` verifies that declarations are unique and that framework
code never imports the game layer.

## Recommended game files

| File | Responsibility |
|---|---|
| `game/app.s` | Application states and the two bootstrap entry points |
| `game/config.h.s` | Status values, sprite dimensions and game constants |
| `game/game.s` | Lifecycle and per-frame system order |
| `game/entities.s` | Templates, animations and entity factories |
| `game/input.s` | Key/action table and player actions |
| `game/behaviors.s` | Behaviour bytecode and custom AI callbacks |
| `game/collision.s` | Collision-pair rules registered with the framework |
| `game/map.s` | Tileset, collision table, rooms and transitions |

Only create a `.h.s` when it contains constants, layouts or macros. Public
symbol declarations belong in `globals.inc`.

## 1. Application adapter

A game with a single state can use tail jumps and pay no extra call depth:

```asm
.module game_app
.include "globals.inc"

.area _CODE

game_app_init::
    jp game_init

game_app_update::
    jp game_update
```

Games with menus can store an `app_state` byte and dispatch from
`game_app_update`, as Model01 does in `src/game/app.s`.

## 2. Project configuration

Set world and physics policy in `src/config.h.s`. These values are resolved at
assembly time and introduce no runtime indirection:

```asm
MAP_WIDTH        = 16
MAP_HEIGHT       = 20
GROUND_LEVEL     = MAP_HEIGHT * 8 - 1
PHYSICS_GRAVITY  = 1
PHYSICS_MAX_FALL_SPEED = 8
PHYSICS_FRICTION_COMPONENT_BIT = 2
```

Map width may range from 1 to 20 columns (four Mode 0 bytes per tile), and map
height from 1 to 25 rows. Width 16 uses a specialized four-shift indexer; other
widths are expanded at assembly time and require no runtime multiplier.

Keep game-only status values and asset dimensions in `game/config.h.s`.

## 3. Lifecycle and frame order

Initialize only the systems the game uses. A typical lifecycle is:

```asm
game_init::
    call sys_mem_init
    call sys_entity_init
    call sys_input_init
    call sys_collision_init
    call game_collision_init
    call game_entity_create_player
    call game_map_init
    call sys_shoot_init
    call sys_map_draw
    ret
```

Prepare rendering before VSYNC and draw after it:

```asm
game_update::
    call sys_physics_update
    call sys_shoot_update
    call game_input_update
    call sys_beh_update
    call sys_collision_update
    call sys_anim_update
    call sys_render_prepare
    call cpct_waitVSYNC_asm
    jp sys_render_update
```

## 4. Entity template and factory

Templates are immutable defaults copied into the reusable entity pool:

```asm
player_template:
DefineEntity c_cmp_invalid, 0, 8, 16, 0, 0, 0, 0, 0, 5, 16, 15, _player_sprite, 0

game_entity_create_player::
    ld hl, #player_template
    call sys_entity_create       ;; IX=new entity; carry set when pool is full
    ret c
    ld e_cmps(ix), #(c_cmp_render | c_cmp_movable | c_cmp_input | c_cmp_animated)
    ld e_moved(ix), #1
    or a
    ret
```

Always handle carry from `sys_entity_create`. Dynamic factories should leave
templates unchanged and configure only the returned entity.

## 5. Animation

An animation descriptor contains frame count, tick speed and sprite pointers:

```asm
player_walk_anim:
    .db 2, 6
    .dw _player_walk_0, _player_walk_1
```

Assign it with `sys_anim_set` or store its address in `e_anim`, then add
`c_cmp_animated`.

## 6. Input

Use a null-terminated table of CPC key constants and callbacks:

```asm
game_key_actions:
    .dw Key_O, game_input_left
    .dw Key_P, game_input_right
    .dw 0

game_input_update::
    ld iy, #game_key_actions
    jp sys_input_generic_update  ;; callbacks receive IX=current player
```

## 7. Behaviour and AI

Behaviour programs are game data interpreted by `sys_beh_update`:

```asm
enemy_patrol_right:
    DRIVE_VX #1, #2
      CONDITION edge_ahead, enemy_patrol_left
      CONDITIONS_END
enemy_patrol_left:
    DRIVE_VX #-1, #2
      CONDITION edge_ahead, enemy_patrol_right
      CONDITIONS_END
```

Use `ACTION callback` and `CONDITION_FN callback, target` for game-specific
extensions. Register callbacks in `globals.inc`; the framework needs no AI
registry or game import.

## 8. Collision rules

Register one game callback; the framework retains AABB detection:

```asm
game_collision_init::
    ld hl, #game_collision_on_hit
    jp sys_collision_set_handler

game_collision_on_hit::          ;; IX=active, IY=passive
    ;; Inspect game status values and apply the rule.
    ret
```

## 9. Map content

`game_map_init` supplies the tileset, initial map and tile-property table:

```asm
game_map_init::
    ld hl, #_tileset
    ld de, #_room_0
    ld ix, #game_tile_solid_table
    jp sys_map_init
```

Tile properties are `0` passable, `1` fully solid and `2` one-way platform.
Room graphs and transition policy stay in the game layer.

## 10. Completion checklist

1. Replace the files under `src/game/` and configure assets under `cfg/`.
2. Set world and physics constants in `src/config.h.s`.
3. Register every public function, data symbol and generated asset once in
   `src/globals.inc`.
4. Keep dependencies one-way: `game -> sys`.
5. Run `make test`; all architecture and Z80 tests must pass.
6. Check `obj/<project>.bin.log` for the highest occupied address.

The test suite performs the last check automatically for Model01 and rejects a
highest address above `0x7FFF`, because code beyond the banking window would be
unsafe when extra RAM is switched in.
