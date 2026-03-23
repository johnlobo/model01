;;-------------------------------------------------------------------------------
.module map_system

.include "sys/map.h.s"
.include "cpctelera.h.s"
.include "common.h.s"
.include "sys/render.h.s"

;;
;; Start of _DATA area
;;
.area _DATA

;; Map draw origin: screen position of map tile (0,0).
;; Moving these moves the entire map and all entities together.
map_origin_x:: .db 8              ;; screen x of map left edge (bytes): (80-64)/2 = 8
;; IMPORTANT: map_origin_y MUST be a multiple of 8 (character-row boundary).
;; smrsa_draw_one_tile uses an SP-trick that manipulates H bits 3-5 to navigate
;; CPC scanlines. It only works correctly when the tile starts at scanline 0 of a
;; character row, i.e. screen_y % 8 == 0.  Values 16 and 24 are the two nearest
;; multiples of 8 to the ideal (200-160)/2 = 20 centering point.
map_origin_y:: .db 16             ;; screen y of map top edge (pixels): nearest mult of 8 to (200-160)/2

;; Pointer to the active tilemap data array (g_map01 or g_map02).
;; Change with sys_map_set to switch maps.
current_map_data:: .dw _g_map01

;; Current room index (0 = map01, 1 = map02, ...).
;; Updated by sys_map_set. Entities with e_room != current_room are skipped
;; by all systems (render, physics, ai, anim, beh, collision).
current_room:: .db 0

;; Room connection table.
;; Each entry is a room_info struct: four 2-byte pointers (N, S, E, W).
;; 0x0000 = no connection in that direction.
;; Index by: room_connections + room_index * sizeof_room_info + room_info_[n|s|e|w]
room_connections::
    ;;                   N     N_id   S     S_id   E          E_id   W          W_id
    DefineRoomConnections 0, 0xff, 0, 0xff, _g_map02,   1,    0,         0xff  ;; room 0 (map01)
    DefineRoomConnections 0, 0xff, 0, 0xff, _g_map03,   2,    _g_map01,  0     ;; room 1 (map02)
    DefineRoomConnections 0, 0xff, 0, 0xff, _g_map04,   3,    _g_map02,  1     ;; room 2 (map03)
    DefineRoomConnections 0, 0xff, 0, 0xff, 0,          0xff, _g_map03,  2     ;; room 3 (map04)
    DefineRoomConnections 0, 0xff, 0, 0xff, 0,          0xff, 0,         0xff  ;; room 4 (inside01, no connections)

;; Working storage for sys_map_restore_tiles_at
smrsa_x_left:   .db 0
smrsa_x_right:  .db 0
smrsa_y_top:    .db 0
smrsa_y_bottom: .db 0
smrsa_save_sp:  .dw 0   ;; SP saved during gray-code tile draw

tile_solid_table:
    .db 0   ;; tile  0: passable (blank)
    .db 2   ;; tile  1: jumpable (one-way platform)
    .db 1   ;; tile  2: solid
    .db 1   ;; tile  3: solid
    .db 1   ;; tile  4: solid
    .db 1   ;; tile  5: solid
    .db 1   ;; tile  6: solid
    .db 1   ;; tile  7: solid
    .db 1   ;; tile  8: solid
    .db 1   ;; tile  9: solid
    .db 0   ;; tile 10: passable (decoration)
    .db 0   ;; tile 11: passable (decoration)
    .db 1   ;; tile 12: solid
    .db 0   ;; tile 13: passable
    .db 0   ;; tile 14: passable
    .db 0   ;; tile 15: passable
    .db 0   ;; tile 16: passable (decoration)
    .db 0   ;; tile 17: passable (decoration)
    .db 0   ;; tile 18: passable (decoration)

;;
;; Start of _CODE area
;;
.area _CODE

;;-----------------------------------------------------------------
;;
;; sys_map_init
;;
;;  Configures the ETM 4x8 engine with the tileset and map dimensions.
;;  Must be called once before sys_map_draw.
;;  Input:
;;  Output:
;;  Modified: AF, DE
;;
sys_map_init::
    ld c, #MAP_WIDTH                        ;; view width in tiles
    ld b, #MAP_HEIGHT                       ;; view height in tiles
    ld de, #MAP_WIDTH                       ;; full tilemap width (= view width, no scrolling)
    ld hl, #_s_tileset_00                   ;; flat tileset base (tiles are contiguous in memory)
    call cpct_etm_setDrawTilemap4x8_agf_asm
    ret

;;-----------------------------------------------------------------
;;
;; sys_map_set
;;
;;  Sets the active tilemap and redraws it immediately.
;;  Input:  HL = pointer to tilemap data array (e.g. _g_map01 or _g_map02)
;;  Output:
;;  Modified: AF, BC, DE, HL, IX, IY
;;
sys_map_set::
    ld (current_map_data), hl
    jp sys_map_draw

;;-----------------------------------------------------------------
;;
;; sys_map_draw
;;
;;  Draws the full tilemap to FRONT_BUFFER.
;;  Call at the start of every render frame before drawing entities.
;;  Input:
;;  Output:
;;  Modified: AF, BC, DE, HL, IX, IY
;;
sys_map_draw::
    ld a, (map_origin_y)                    ;; B = screen y of map top
    ld b, a
    ld a, (map_origin_x)                    ;; C = screen x of map left (bytes)
    ld c, a
    ld de, #FRONT_BUFFER
    call cpct_getScreenPtr_asm              ;; HL = screen ptr at map origin
    ex de, hl                               ;; DE = video ptr (ETM requires DE=video, HL=tilemap)
    ld hl, (current_map_data)
    call cpct_etm_drawTilemap4x8_agf_asm
    ret

;;-----------------------------------------------------------------
;;
;; sys_map_is_solid_at / sys_map_is_landable_at
;;
;;  Returns whether the tile at the given screen position blocks movement.
;;  sys_map_is_solid_at:    NZ if fully solid (value=1). Jumpable tiles (value=2)
;;                          are passable — use for ceiling and horizontal checks.
;;  sys_map_is_landable_at: NZ if solid (1) or jumpable (2). Use for floor checks
;;                          so entities can land on one-way platforms.
;;  Input: B = pixel_y, C = pixel_x (in bytes, 0..79)
;;  Output: NZ if blocked, Z if passable or out of bounds
;;  Modified: AF, DE, HL
;;
sys_map_is_solid_at::
    call smisa_get_type         ;; A = tile type, Z set if 0 (passable/OOB)
    ret z                       ;; passable: return Z
    cp #1                       ;; Z if exactly solid (1), NZ if jumpable (2)
    jr nz, smisa_passable       ;; not exactly solid: treat as passable
    or a                        ;; A=1, set NZ
    ret

sys_map_is_landable_at::
    call smisa_get_type         ;; A = tile type: 0→Z, 1 or 2→NZ
    ret                         ;; return flags as-is

;; Internal: look up tile type at (B=pixel_y, C=pixel_x)
;;  Returns: A = tile_solid_table value (0/1/2), or A=0,Z via smisa_passable
smisa_get_type:
    ;; B = world pixel_y (0 = map top), C = world pixel_x (bytes, 0 = map left)
    ld a, b
    rrca
    rrca
    rrca
    and #0x1F                   ;; tile_row = world_y >> 3
    cp #MAP_HEIGHT
    jr nc, smisa_passable       ;; >= MAP_HEIGHT: below or outside map

    ld l, a
    ld h, #0
    add hl, hl                  ;; *2
    add hl, hl                  ;; *4
    add hl, hl                  ;; *8
    add hl, hl                  ;; *16 = MAP_WIDTH
    ld de, (current_map_data)
    add hl, de

    ld a, c
    rrca
    rrca
    and #0x3F                   ;; tile_col = world_x_bytes >> 2
    cp #MAP_WIDTH
    jr nc, smisa_passable       ;; out of horizontal bounds

    ld e, a
    ld d, #0
    add hl, de

    ld a, (hl)                  ;; A = tile_id
    ld hl, #tile_solid_table
    ld e, a
    ld d, #0
    add hl, de
    ld a, (hl)                  ;; A = tile type (0/1/2)
    or a                        ;; Z if 0 (passable), NZ if 1 or 2
    ret

smisa_passable:
    xor a                       ;; A=0, Z=1 (passable)
    ret

;;-----------------------------------------------------------------
;;
;; sys_map_restore_tiles_at
;;
;;  Redraws map tiles that overlap an entity bounding box.
;;  Call before drawing the entity at its new position to erase
;;  the previous sprite without leaving black holes.
;;
;;  Input: B = pixel_y, C = pixel_x (bytes), D = height, E = width
;;  Output:
;;  Modified: AF, BC, DE, HL, IX (IX is destroyed via cpct_drawSprite_asm)
;;
sys_map_restore_tiles_at::
    ;; tile_col_left = C >> 2
    ld a, c
    rrca
    rrca
    and #0x3F
    ld (smrsa_x_left), a

    ;; tile_col_right = (C + E - 1) >> 2
    ld a, c
    add a, e
    dec a
    rrca
    rrca
    and #0x3F
    ld (smrsa_x_right), a

    ;; tile_row_top = B >> 3  (B = world pixel_y, 0 = map top)
    ld a, b
    rrca
    rrca
    rrca
    and #0x1F
    ld (smrsa_y_top), a

    ;; tile_row_bottom = (B + D - 1) >> 3
    ld a, b
    add a, d
    dec a
    rrca
    rrca
    rrca
    and #0x1F
    ld (smrsa_y_bottom), a

    ;; Loop over every tile row from smrsa_y_top to smrsa_y_bottom (inclusive).
    ;; Height=16px can span up to 3 tile rows when y is not 8-aligned,
    ;; so we must not skip intermediate rows.
smrsa_row_loop:
    ld a, (smrsa_y_top)
    ld b, a                         ;; B = current tile row

    ;; Draw left column
    ld a, (smrsa_x_left)
    ld c, a
    call smrsa_draw_one_tile

    ;; Draw right column (only if different from left)
    ld a, (smrsa_x_left)
    ld d, a
    ld a, (smrsa_x_right)
    cp d
    jr z, smrsa_next_row
    ld a, (smrsa_y_top)
    ld b, a
    ld a, (smrsa_x_right)
    ld c, a
    call smrsa_draw_one_tile

smrsa_next_row:
    ;; Stop if we just drew the bottom row
    ld a, (smrsa_y_top)
    ld d, a
    ld a, (smrsa_y_bottom)
    cp d
    jr z, smrsa_done
    ;; Advance to next row
    inc d
    ld a, d
    ld (smrsa_y_top), a
    jr smrsa_row_loop

smrsa_done:
    ret

;;-----------------------------------------------------------------
;; smrsa_draw_one_tile (internal)
;;
;;  Draws one map tile at the given tile grid position to the screen.
;;  Input: B = tile_row (0-based), C = tile_col (0-based)
;;  Modified: AF, BC, DE, HL, IX
;;
smrsa_draw_one_tile:
    ;; Bounds check: skip if outside map grid (also catches underflow wrapping to 255+)
    ld a, b
    cp #MAP_HEIGHT
    ret nc                  ;; tile_row >= MAP_HEIGHT: out of bounds, skip
    ld a, c
    cp #MAP_WIDTH
    ret nc                  ;; tile_col >= MAP_WIDTH: out of bounds, skip

    ;; tile_id = g_map01[tile_row * MAP_WIDTH + tile_col]
    ld l, b
    ld h, #0
    add hl, hl              ;; HL = tile_row * 2
    add hl, hl              ;; HL = tile_row * 4
    add hl, hl              ;; HL = tile_row * 8
    add hl, hl              ;; HL = tile_row * 16 (MAP_WIDTH)
    ld e, c
    ld d, #0
    add hl, de              ;; HL = tile_row * MAP_WIDTH + tile_col
    ld de, (current_map_data)
    add hl, de
    ld a, (hl)              ;; A = tile_id

    ;; sprite_ptr = _s_tileset_00 + tile_id * 32
    ld l, a
    ld h, #0
    add hl, hl              ;; * 2
    add hl, hl              ;; * 4
    add hl, hl              ;; * 8
    add hl, hl              ;; * 16
    add hl, hl              ;; * 32
    ld de, #_s_tileset_00
    add hl, de              ;; HL = sprite data pointer

    push hl                 ;; save sprite ptr

    ;; screen_y = tile_row * 8 + map_origin_y
    ld a, b
    sla a
    sla a
    sla a                   ;; A = tile_row * 8
    ld b, a
    ld a, (map_origin_y)
    add a, b
    ld b, a                 ;; B = screen pixel_y

    ;; screen_x = tile_col * 4 + map_origin_x
    ld a, c
    sla a
    sla a                   ;; A = tile_col * 4
    ld c, a
    ld a, (map_origin_x)
    add a, c
    ld c, a                 ;; C = screen x_bytes

    ;; get screen address for this tile
    ld de, #FRONT_BUFFER
    call cpct_getScreenPtr_asm  ;; HL = screen ptr

    pop ix                  ;; IX = sprite data ptr

    ;; Draw tile using the same SP trick as the ETM engine.
    ;; Tile data is in gray-code row order (0,1,3,2,6,7,5,4) which matches
    ;; the sequential SP reads below. H-bit manipulation navigates CPC scanlines.
    ;; Rows alternate left-to-right (inc L) / right-to-left (dec L) for zig-zag.
    ;; SP is hijacked to read tile data via POP — interrupts must be disabled.
    di
    push hl                 ;; save screen ptr temporarily
    ld hl, #2
    add hl, sp              ;; HL = real SP (before the push above)
    ld (smrsa_save_sp), hl  ;; save real SP
    pop hl                  ;; restore screen ptr
    ld sp, ix               ;; SP = tile sprite data (ld sp,ix = DD F9, valid Z80)

    ;; Row 0 [left→right]
    pop bc
    ld (hl), c
    inc l
    ld (hl), b
    inc l
    pop bc
    ld (hl), c
    inc l
    ld (hl), b              ;; L = col+3
    set 3, h                ;; → scanline 1

    ;; Row 1 [right→left]
    pop bc
    ld (hl), c
    dec l
    ld (hl), b
    dec l
    pop bc
    ld (hl), c
    dec l
    ld (hl), b              ;; L = col
    set 4, h                ;; → scanline 3

    ;; Row 3 [left→right]
    pop bc
    ld (hl), c
    inc l
    ld (hl), b
    inc l
    pop bc
    ld (hl), c
    inc l
    ld (hl), b              ;; L = col+3
    res 3, h                ;; → scanline 2

    ;; Row 2 [right→left]
    pop bc
    ld (hl), c
    dec l
    ld (hl), b
    dec l
    pop bc
    ld (hl), c
    dec l
    ld (hl), b              ;; L = col
    set 5, h                ;; → scanline 6

    ;; Row 6 [left→right]
    pop bc
    ld (hl), c
    inc l
    ld (hl), b
    inc l
    pop bc
    ld (hl), c
    inc l
    ld (hl), b              ;; L = col+3
    set 3, h                ;; → scanline 7

    ;; Row 7 [right→left]
    pop bc
    ld (hl), c
    dec l
    ld (hl), b
    dec l
    pop bc
    ld (hl), c
    dec l
    ld (hl), b              ;; L = col
    res 4, h                ;; → scanline 5

    ;; Row 5 [left→right]
    pop bc
    ld (hl), c
    inc l
    ld (hl), b
    inc l
    pop bc
    ld (hl), c
    inc l
    ld (hl), b              ;; L = col+3
    res 3, h                ;; → scanline 4

    ;; Row 4 [right→left]
    pop bc
    ld (hl), c
    dec l
    ld (hl), b
    dec l
    pop bc
    ld (hl), c
    dec l
    ld (hl), b              ;; L = col
    res 5, h                ;; H restored to scanline 0

    ;; Restore SP and re-enable interrupts
    ld hl, (smrsa_save_sp)
    ld sp, hl
    ei
    ret
