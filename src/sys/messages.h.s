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

.module messages_system

;;------------------------------------------------------------------------------
;; Global constants
;;------------------------------------------------------------------------------

MINIMUM_WINDOW_WIDTH = 30

;;------------------------------------------------------------------------------
;; Global variables
;;------------------------------------------------------------------------------

;;------------------------------------------------------------------------------
;; Global routines
;;------------------------------------------------------------------------------

.globl sys_messages_load_window_data
.globl sys_messages_draw_window
.globl sys_messages_show
.globl sys_messages_draw_box
.globl sys_messages_restore_message_background
