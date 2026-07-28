# model01 game layer

This directory contains rules and content that define **model01**, rather than
reusable engine mechanisms.

- `behaviors.s`: concrete enemy bytecode and the game-specific shoot action.
- `collision.s`: status-pair responses, portal activation and hit feedback.
- `entities.s`: concrete animation tables, templates and factories for players,
  enemies, objects, portals and projectiles.
- `input.s`: key bindings and concrete player actions such as movement, variable
  jump, shooting and quit-dialog responses.
- `map.s`: tileset and initial map configuration, tile collision properties,
  room graph, edge transitions, portal placement and teleportation.
- `menu.s`: main-menu presentation, key bindings and actions.

Code under `src/sys/` may expose callbacks and generic actions used here, but
must not reference symbols from `src/game/`. A new game should be able to
replace this directory without editing the corresponding system internals.

`src/man/` is currently transitional and contains only game-loop orchestration.
The reusable entity schema/pool lives in `src/sys/entity.*`; concrete entity
content lives here in `src/game/`.
