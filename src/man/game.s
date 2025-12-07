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
.module game_manager

.include "man/array.h.s"
.include "cpctelera.h.s"
.include "common.h.s"
.include "sys/render.h.s"
.include "sys/input.h.s"
.include "man/entity.h.s"

;;
;; Start of _DATA area 
;;
.area _DATA


;;
;; Start of _CODE area
;; 
.area _CODE

;;-----------------------------------------------------------------
;;
;; man_game_init
;;
;;  Initilizes the game
;;  Input: 
;;  Output: 
;;  Modified: AF, HL
;;
man_game_init::
    call man_entity_init
    call man_entity_create_player_paddle
    call sys_render_init
    ret

;;-----------------------------------------------------------------
;;
;; man_game_init
;;
;;  Initilizes the game
;;  Input: 
;;  Output: 
;;  Modified: AF, HL
;;
man_game_update::
    call sys_render_update
    ret