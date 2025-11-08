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
.include "man/array.h.s"
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

entity_template::
DefineEntity c_cmp_invalid, 0, 10, 100, 10, 100, 00, 00, 4, 10
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
;; man_entity_create_player_paddle
;;
;;  Creates the user paddle
;;  Input: 
;;  Output: 
;;  Modified: AF, HL
;;
man_entity_create_player_paddle::
    ld ix, #entities                    ;; create entity in entity array
    ld hl, #entity_template             ;;
    call man_array_create_element       ;;
    ld__ix_hl
    ld e_cmps(ix), #(c_cmp_render | c_cmp_movable | c_cmp_collider | c_cmp_input)
    ld e_moved(ix), #1                  ;; moved = 1 to be drawn
    ret