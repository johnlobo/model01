# model01 game layer

This directory contains rules and content that define **model01**, rather than
reusable engine mechanisms.

- `behaviors.s`: concrete enemy bytecode and the game-specific shoot action.
- `collision.s`: status-pair responses, portal activation and hit feedback.

Code under `src/sys/` may expose callbacks and generic actions used here, but
must not reference symbols from `src/game/`. A new game should be able to
replace this directory without editing the corresponding system internals.

`src/man/` is currently transitional: its managers and entity templates still
contain model01 orchestration/content, and a few old `sys -> man` callbacks
remain. They will move behind this boundary in later incremental changes.
