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
    ld ix, #entities
    call sys_array_init
    ret

;; Creates a reusable entity by copying the template supplied by the game.
man_entity_create::
    ld ix, #entities
    call sys_array_create_reusable_element
    ret c
    ld__ix_hl
    or a
    ret
