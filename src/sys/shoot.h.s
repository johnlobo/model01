;;-----------------------------LICENSE NOTICE------------------------------------
;;
;;  This program is free software: you can redistribute it and/or modify
;;  it under the terms of the GNU Lesser General Public License as published by
;;  the Free Software Foundation, either version 3 of the License, or
;;  (at your option) any later version.
;;
;;  This program is distributed in the hope that it will be useful,
;;  but WITHOUT ANY WARRANTY; without even the implied warranty of
;;  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;;  GNU Lesser General Public License for more details.
;;
;;  You should have received a copy of the GNU Lesser General Public License
;;  along with this program.  If not, see <http://www.gnu.org/licenses/>.
;;-------------------------------------------------------------------------------
.module shoot_system

.include "common.h.s"

;;===============================================================================
;; SPEED SYSTEM
;;
;;  Bullets move in whole-byte steps (the finest horizontal granularity the
;;  renderer supports — same as every other entity). A flat N-bytes/frame speed
;;  is therefore the fastest possible value; slower speeds can only be made by
;;  skipping frames between steps, the same "stride" idiom DRIVE_VX already
;;  uses for the patrol enemy's walk cycle.
;;
;;  Each bullet carries its own step size and stride, so different bullet
;;  types (or future ones) can move at different speeds without engine
;;  changes. Two otherwise-unused per-entity fields carry them, set once by
;;  the entity factory at creation:
;;    e_speed_x   (low byte)  — signed bytes moved per step (+right, -left)
;;    e_speed_x+1 (high byte) — frames between steps (reload value); always 0
;;                              on every other entity type, so this is safe
;;    e_beh_timer             — countdown to the next step; projectiles never
;;                              run a behavior program, so this is unused
;;  sys_shoot_update_one_bullet (shoot.s) holds position while the countdown
;;  is nonzero, and reloads it from e_speed_x+1 each time a step happens.
;;===============================================================================
PLAYER_BULLET_STRIDE = 2   ;; frames between steps
ENEMY_BULLET_STRIDE  = 2   ;; frames between steps

;;===============================================================================
;; PUBLIC METHODS
;;===============================================================================
.globl sys_shoot_init
.globl sys_shoot_update
