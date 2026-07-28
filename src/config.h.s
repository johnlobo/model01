;; Project-level parameters consumed by reusable systems.
;; A new game may change these values without editing src/sys/.

MAP_WIDTH       = 16  ;; required by the current shift-based tile indexer
MAP_HEIGHT      = 20

;; World coordinates (0 = map top): MAP_HEIGHT * 8 - 1 = 159.
GROUND_LEVEL    = MAP_HEIGHT * 8 - 1

;; Generic physics policy. These are compile-time values, so configurability
;; adds no per-frame indirection on the Z80.
PHYSICS_GRAVITY               = 1
PHYSICS_MAX_FALL_SPEED        = 8
PHYSICS_FRICTION_COMPONENT_BIT = 2  ;; c_cmp_input
