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

.include "sys/messages.h.s"
.include "cpctelera.h.s"
.include "globals.inc"
.include "sys/util.h.s"
.include "sys/text.h.s"
.include "sys/input.h.s"
.include "sys/render.h.s"


.module messages_system

;;
;; Start of _DATA area 
;;  SDCC requires at least _DATA and _CODE areas to be declared, but you may use
;;  any one of them for any purpose. Usually, compiler puts _DATA area contents
;;  right after _CODE area contents.
;;
.area _DATA

_window_data::
_window_address: .dw #00
_window_x: .db #00
_window_y: .db #00
_window_w: .db #00
_window_h: .db #00
_window_message: .dw #0000
_window_wait_for_key: .db #01
_window_background_color: .db #00
_window_valid: .db #00

_press_any_key_string: .asciz "PRESS ANY KEY"


;; Constants to reach window data
w_address = 0
w_x = 2
w_y = 3
w_w = 4
w_h = 5
w_message = 6
w_wait_for_key = 8
w_b_color = 9
w_valid = 10


;;
;; Start of _CODE area
;; 
.area _CODE

;;-----------------------------------------------------------------
;;
;; sys_messages_load_window_data
;;
;;  Loads the window structure with the data in registers
;;  Input:  a : wait for key flag
;;          a': background color
;;          de: x and y coord
;;          bc: h and w of the window
;;          hl: message to show 
;;  Output:
;;  Modified: af, hl, de, bc
;;

sys_messages_load_window_data::
    ld iy, #_window_data
    ld w_valid(iy), #0                ;; invalid until every bound is checked
    ex af, af'                      ;;
    ld w_b_color(iy), a             ;; bring background color froam a'
    ex af, af'                      ;;
    ld w_message(iy), l
    ld w_message+1(iy), h
    ld w_h(iy), b
    ld w_y(iy), d
    ld w_wait_for_key(iy), a

    ;; Height must be drawable and fit the optional PRESS ANY KEY line.
    ld a, b
    cp #MINIMUM_WINDOW_HEIGHT
    jr c, _smlwd_invalid
    cp #(MAXIMUM_WINDOW_HEIGHT + 1)
    jr nc, _smlwd_invalid
    ld a, w_wait_for_key(iy)
    cp #1
    jr nz, _smlwd_height_ok
    ld a, w_h(iy)
    cp #WAIT_WINDOW_MIN_HEIGHT
    jr c, _smlwd_invalid
_smlwd_height_ok:

    ;; Reject y + height > 200, including 8-bit addition overflow.
    ld a, w_y(iy)
    add a, w_h(iy)
    jr c, _smlwd_invalid
    cp #(MAXIMUM_WINDOW_HEIGHT + 1)
    jr nc, _smlwd_invalid

    ;; Bounded scan prevents width overflow and unterminated strings.
    ld h, w_message+1(iy)
    ld l, w_message(iy)
    ld b, #(MAXIMUM_MESSAGE_CHARS + 1)
    ld c, #0
_smlwd_strlen:
    ld a, (hl)
    or a
    jr z, _smlwd_strlen_done
    inc hl
    inc c
    djnz _smlwd_strlen
    jr _smlwd_invalid
_smlwd_strlen_done:
    ld a, c
    sla a                            ;; two screen bytes per character
    add a, #5                        ;; border and horizontal padding
    cp #(MINIMUM_WINDOW_WIDTH + 3)   ;; preserve previous effective minimum
    jr nc, _smlwd_width_min_ok
    ld a, #(MINIMUM_WINDOW_WIDTH + 3)
_smlwd_width_min_ok:
    cp #(MAXIMUM_WINDOW_WIDTH + 1)
    jr nc, _smlwd_invalid
    ld w_w(iy), a

    ;; Captured background is width*height bytes in the fixed buffer.
    ld e, w_w(iy)
    ld h, w_h(iy)
    call sys_util_h_times_e          ;; HL = width * height
    ld de, #(MESSAGE_BUFFER_SIZE + 1)
    or a
    sbc hl, de
    jr nc, _smlwd_invalid            ;; product >= 3001

    ;; Horizontal centering guarantees x + width <= 80.
    ld a, #MAXIMUM_WINDOW_WIDTH
    sub w_w(iy)
    srl a
    ld w_x(iy), a
    
    ld c, w_x(iy)                   ;; c = x
    ld b, w_y(iy)                   ;; b = y
    
    ;;ld de, #CPCT_VMEM_START_ASM   ;; DE = Pointer to start of the screen
    
    ;;ld_de_backbuffer                ;; Calculate video memory location and return it in HL
    ld_de_frontbuffer                ;; Calculate video memory location and return it in HL
    call cpct_getScreenPtr_asm      ;; Calculate video memory location and return it in HL
    
    ld w_address(iy), l             ;; keep address in memory
    ld w_address+1(iy), h           ;;
    ld a, #1
    ld w_valid(iy), a
    or a                             ;; clear carry: valid
    ret

_smlwd_invalid:
    scf                              ;; caller must not capture or draw
    ret

;;-----------------------------------------------------------------
;;
;; sys_messages_draw_window
;;
;;  shows a message
;;  Input: 
;;  Output:
;;  Modified: af, hl, de, bc
;;

sys_messages_draw_window::

    ld a, w_valid(iy)
    or a
    ret z

    ;; Draw Back window
    ld e, w_address(iy)                 ;; keep background information in message_buffer
    ld d, w_address+1(iy)               ;; 
    ld c, w_w(iy)
    ld b, w_h(iy)
    
    ld a,#0xff                          ;; Patern of solid box
    call cpct_drawSolidBox_asm

    ;; Draw Front Window
    ;;ld de, #CPCT_VMEM_START_ASM   ;; DE = Pointer to start of the screen
    
    ;;ld_de_backbuffer              ;; Calculate video memory location and return it in HL
    ld_de_frontbuffer              ;; Calculate video memory location and return it in HL
    
    ld c, w_x(iy)                   ;;
    inc c                           ;; C = x coordinate + 1
    ld b, w_y(iy)                   ;;
    inc b                           ;; B = y coordinate + 2
    inc b                           ;;
    call cpct_getScreenPtr_asm      ;; Calculate video memory location and return it in HL
    ex de, hl                       ;; move screen address to de
    
    ld c, w_w(iy)                   ;;
    dec c                           ;; C = w - 2
    dec c                           ;;   
    
    ld b, w_h(iy)                   ;;
    dec b                           ;; B = h - 4
    dec b                           ;;
    dec b                           ;;
    dec b                           ;;
    
    ;;ld a, #0x00                     ;; Patern of solid box
    ld a, w_b_color(iy)               ;; Patern for solid box  
    call cpct_drawSolidBox_asm

    ret



;;-----------------------------------------------------------------
;;
;; sys_messages_restore_message_background
;;
;;  restores de background of the message
;;  Input:  a : wait for key flag
;;          de: x and y coord
;;          bc: h and w of the window
;;          hl: message to show 
;;  Output:
;;  Modified: af, hl, de, bc
;;
sys_messages_restore_message_background::
    ld a, w_valid(iy)
    or a
    ret z
    ld e, w_address(iy)                 ;; keep background information in message_buffer
    ld d, w_address+1(iy)               ;;
    ld hl, #message_buffer              ;;
    ld c, w_w(iy)                       ;;
    ld b, w_h(iy)                       ;;
    call cpct_drawSprite_asm            ;;
    ret

sys_messages_close::
    ld iy, #_window_data
    jp sys_messages_restore_message_background


;;-----------------------------------------------------------------
;;
;; sys_messages_show
;;
;;  shows a message
;;  Input:  a : wait for key flag
;;          de: x and y coord
;;          bc: h and w of the window
;;          hl: message to show 
;;          af'; window background
;;  Output:
;;  Modified: af, hl, de, bc
;;

sys_messages_show::

    call sys_messages_load_window_data
    ret c                               ;; invalid geometry/string: safe no-op

    ld l, w_address(iy)                 ;; restore background information from message_buffer
    ld h, w_address+1(iy)               ;;
    ld de, #message_buffer              ;;
    ld c, w_w(iy)                       ;;
    ld b, w_h(iy)                       ;;
    call cpct_getScreenToSprite_asm     ;;


    call sys_messages_draw_window

    ;; Draw message
    
    ;;ld de, #CPCT_VMEM_START_ASM   ;; DE = Pointer to start of the screen
    ;;ld_de_backbuffer                ;; Calculate video memory location and return it in HL
    ld_de_frontbuffer                ;; Calculate video memory location and return it in HL
    
    ld c, w_x(iy)                   ;;
    inc c                           ;; 
    inc c                           ;; C = x + 1
    inc c                           ;; 
    
    ld b, w_y(iy)                   ;;

    ld a, w_wait_for_key(iy)        ;; check if we have to show the message press any key
    cp #1                           ;;
    jr nz, no_wait4key               ;; 
    ld a, #10                       ;; B = y + 10
    jr y_coord
no_wait4key:
    ld a, #7                        ;; centered in a 22px single-line window
y_coord:
    add b                           ;;
    ld b, a                         ;;
    
    call cpct_getScreenPtr_asm      ;; Calculate video memory location and return it in HL
    ex de, hl                       ;; move screen address to de

    ld c, #0
    ld h, w_message+1(iy)
    ld l, w_message(iy)
    call sys_text_draw_string

    ;; Draw Press Any Key
    ld a, w_wait_for_key(iy)        ;; check if we have to wait for a key
    cp #1                           ;;
    jr  z, wait_for_key             ;;

    ld a, w_wait_for_key(iy)        ;; check if we have to wait for a key
    cp #2                           ;;
    jr  nz, _sms_exit               ;;

_sms_wait_delay:
    ld b, #50
    call sys_util_delay
    call sys_messages_restore_message_background

_sms_exit:
    ret

wait_for_key:
    ;;ld de, #CPCT_VMEM_START_ASM   ;; DE = Pointer to start of the screen
    
    ;;ld_de_backbuffer              ;; Calculate video memory location and return it in HL
    ld_de_frontbuffer              ;; Calculate video memory location and return it in HL
    
    
    ld a, w_w(iy)                   ;;
    ld c, #26                       ;;
    sub c                           ;;
    sra a                           ;; c = x + ((w- length(str))/2)
    ld c, w_x(iy)                   ;;
    add c                           ;;
    ld c, a                         ;;

    ld b, w_y(iy)                   ;;
    ld a, #26                       ;; B = y + 10
    add b                           ;;
    ld b, a                         ;;
    
    call cpct_getScreenPtr_asm      ;; Calculate video memory location and return it in HL
    ex de, hl                       ;; move screen address to de
    ld c, #0
    ld hl, #_press_any_key_string
    call sys_text_draw_string

    call sys_input_wait4anykey
    push hl                         ;; store number of loops waited

    call sys_messages_restore_message_background

    pop hl                          ;; return number of loops waited

    ret

;;-----------------------------------------------------------------
;;
;; sys_messages_draw_box
;;
;;  draws an empty box
;;  Input:  (2B DE) memory	Video memory pointer to the upper left box corner byte
;;          (1B A ) colour_pattern	1-byte colour pattern (in screen pixel format) to fill the box with
;;          (1B C ) WIDTH	Box width in bytes [1-64] (Beware!  not in pixels!)
;;          (1B B ) HEIGHT	Box height in bytes (>0)
;;                  L : Fill or Empty
;;  Output:
;;  Modified: af, hl, de, bc
;;
;; Implementation partly copied form cpctelera drawSolidBox
;;
sys_messages_draw_box::
    push af
    ld a, l                             ;;
    or a                                ;; Check if box is empty
    jr z, smdb_empty                    ;;

    ;; Draw Back window
    cpctm_push de, bc
    ld a,#0x00                          ;; Patern of solid box
    call cpct_drawSolidBox_asm          ;;
    cpctm_pop bc, de

smdb_empty:
    pop af
    ld (#draw_border+1), a
    ld (#draw_border2+1), a
    ld (#draw_line+1), a
    ld a, c
    ld (width), a
 	ld h, d
	ld l, e	
    inc b                   ;; increment height in one 
	jr draw_line

next_line:
	ld a, b
	dec a
	or a
	ret z

	ld b, a
	ld a, (width)
	ld c,a

	ld a, b
	cp #1
	jr z, draw_line		;; Si estoy en la ultima linea salto a line
draw_border:
	ld (hl), #0xff
    ld a, c
    dec a
    add_hl_a
draw_border2:
	ld (hl), #0xff
	jr down_line

draw_line:
	ld (hl), #0xff
	inc hl
	;;djnz draw_line
    dec c
    ld a, c
    or a
    jr nz, draw_line

down_line:
	ld a, #8          	    ;; [2] / HL = DE = DE + 0x800
	add d
    ld h, a           	    ;; [1] | Adding 0x800 makes HL point to the start of
	ld d, a
	ld l, e
	
	and   #0x38        	    ;; [2] leave out only bits 13,12 and 11 from new memory address (00xxx000 00000000)
    jp    nz, next_line    	;; [3] If any bit from {13,12,11} is not 0, we are still inside 
                        	;; ... video memory boundaries, so proceed with next line
                            ;; Every 8 lines, we cross the 16K video memory boundaries and have to
                            ;; reposition destination pointer. That means our next line is 16K-0x50 bytes back
                            ;; which is the same as advancing 48K+0x50 = 0xC050 bytes, as memory is 64K 
                            ;; and our 16bit pointers cycle over it
    ld    hl, #0xC050       ;; [3] We advance destination pointer to next line
    add   hl, de            ;; [3] HL = DE + 0xC050
    ld     d, h             ;; [1] / DE = HL
    ld     e, l             ;; [1] \
    jp   next_line         	;; [3] Continue copying

    ret
width: .db #0
height: .db #0
;; Fixed low-RAM workspace. Keeping this out of _CODE recovers 3000 bytes in
;; the 0x4000-0x7FFF banking window. It does not overlap the transparency table
;; (0x0100-0x01FF) or the banking stub/detection byte (0x0200-0x0213).
message_buffer = MESSAGE_BUFFER_ADDRESS
