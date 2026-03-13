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
.module entity_manager

.include "man/entity.h.s"
.include "cpctelera.h.s"
.include "common.h.s"
.include "sys/array.h.s"
.include "sys/util.h.s"

;;
;; Start of _DATA area 
;;  SDCC requires at least _DATA and _CODE areas to be declared, but you may use
;;  any one of them for any purpose. Usually, compiler puts _DATA area contents
;;  right after _CODE area contents.
;;
.area _DATA

entities::
DefineArrayStructure entity, MAX_ENTITIES, sizeof_e
.db 0   ;;ponemos este aqui como trampita para que siempre haya un tipo invalido al final

monk_walk_anim::
    .db 4               ;; 4 frames
    .db 8               ;; 8 ticks per frame
    .dw _s_monk_0
    .dw _s_monk_1
    .dw _s_monk_2
    .dw _s_monk_3

monk_idle_anim::
    .db 1               ;; 1 frame
    .db 0               ;; speed (unused with 1 frame)
    .dw _s_monk_0

monk_walk_right_anim::
    .db 4               ;; 4 frames: 1-2-3-2
    .db 8               ;; 8 ticks per frame
    .dw _s_monk_1
    .dw _s_monk_2
    .dw _s_monk_3
    .dw _s_monk_2

monk_walk_left_anim::
    .db 4               ;; 4 frames: 4-5-6-5
    .db 8               ;; 8 ticks per frame
    .dw _s_monk_4
    .dw _s_monk_5
    .dw _s_monk_6
    .dw _s_monk_5

player_template::
DefineEntity c_cmp_invalid, 0, 10, 184, 0xE3CA, 0xE3CA, 0, 0, 0, S_MONK_WIDTH, S_MONK_HEIGHT, 15, _s_monk_0
.db 0   ;;ponemos este aqui como trampita para que siempre haya un tipo invalido al final

;;
;; Start of _CODE area
;; 
.area _CODE

;;-----------------------------------------------------------------
;;
;; man_entity_init
;;
;;  Initilizes an array of entities
;;  Input: ix points to the array
;;  Output: 
;;  Modified: AF, HL
;;
man_entity_init::

    ret

;;-----------------------------------------------------------------
;;
;; man_entity_create_player_player
;;
;;  Creates the user paddle
;;  Input: 
;;  Output: 
;;  Modified: AF, HL
;;
man_entity_create_player_player::
    ;; Player 1
    ld ix, #entities                    ;; create entity in entity array
    ld hl, #player_template             ;;
    call sys_array_create_element       ;;
    ld__ix_hl
    ld e_cmps(ix), #(c_cmp_render | c_cmp_movable | c_cmp_collider | c_cmp_input | c_cmp_animated)
    ld e_moved(ix), #1                  ;; moved = 1 to be drawn
    ld hl, #monk_idle_anim
    ld e_anim(ix), l
    ld e_anim+1(ix), h

    ;; Player 2
    ld ix, #entities                    ;; create entity in entity array
    ld hl, #player_template             ;;
    call sys_array_create_element       ;;
    ld__ix_hl
    ld e_cmps(ix), #(c_cmp_render | c_cmp_movable | c_cmp_collider | c_cmp_ai | c_cmp_animated)
    ld e_x(ix), #30
    ld e_moved(ix), #1                  ;; moved = 1 to be drawn
    ld hl, #monk_walk_anim
    ld e_anim(ix), l
    ld e_anim+1(ix), h

    ;; Player 3
    ld ix, #entities                    ;; create entity in entity array
    ld hl, #player_template             ;;
    call sys_array_create_element       ;;
    ld__ix_hl
    ld e_cmps(ix), #(c_cmp_render | c_cmp_movable | c_cmp_collider | c_cmp_ai | c_cmp_animated)
    ld e_x(ix), #50
    ld e_moved(ix), #1                  ;; moved = 1 to be drawn
    ld hl, #monk_walk_anim
    ld e_anim(ix), l
    ld e_anim+1(ix), h

    ret

