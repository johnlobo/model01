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
- `menu.s`: main-menu presentation and version text, key bindings and actions.
- `game.s`: Model01 lifecycle, system order and quit-dialog flow.
- `config.h.s`: Model01 assets, application/entity states and sprite dimensions.

Code under `src/sys/` may expose callbacks and generic actions used here, but
must not reference symbols from `src/game/`. A new game should be able to
replace this directory without editing the corresponding system internals.
Project-wide geometry used by generic systems lives in `src/config.h.s`, so a
game can configure the framework without introducing a `sys` dependency on the
game layer.
The render system receives the active 16-colour palette from the game in `HL`;
it does not reference a concrete asset itself.
Likewise, `sys_text_init` receives the font in `HL` and the small-number sprite
set in `DE`, keeping concrete text assets in the game layer.
The renderer exposes only its current queue-based API; obsolete zone flags tied
to entities from an earlier game implementation have been removed.
System-private constants now live beside their implementation instead of being
exported transitively through `common.h.s`.
All framework, game, asset and CPCtelera declarations are registered once in
`src/globals.inc`, making duplicate declarations directly auditable.
Generic ECS masks and structure declaration helpers live separately in
`src/sys/component.inc` and `src/sys/struct.inc`; `common.h.s` currently acts
only as a compatibility facade that includes those focused definitions.

The former `src/man/` layer has been removed. The reusable entity schema/pool
lives in `src/sys/entity.*`; lifecycle and concrete content live here.
