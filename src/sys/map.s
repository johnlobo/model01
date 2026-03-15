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

;; Working storage for sys_map_restore_tiles_at
smrsa_x_left:   .db 0
smrsa_x_right:  .db 0
smrsa_y_top:    .db 0
smrsa_y_bottom: .db 0

tile_solid_table:
    .db 0   ;; tile  0: passable (blank)
    .db 1   ;; tile  1: solid
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
    .db 1   ;; tile 14: solid
    .db 0   ;; tile 15: passable

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
;; sys_map_draw
;;
;;  Draws the full tilemap to FRONT_BUFFER.
;;  Call at the start of every render frame before drawing entities.
;;  Input:
;;  Output:
;;  Modified: AF, BC, DE, HL, IX, IY
;;
sys_map_draw::
    ld hl, #_g_map01                        ;; HL = tilemap data (ASM variant: HL=tilemap)
    ld de, #(FRONT_BUFFER + MAP_START_ROW * 80) ;; DE = video memory offset by MAP_START_ROW character rows
    call cpct_etm_drawTilemap4x8_agf_asm
    ret

;;-----------------------------------------------------------------
;;
;; sys_map_is_solid_at
;;
;;  Returns whether the tile at the given screen position is solid.
;;  Input: B = pixel_y, C = pixel_x (in bytes, 0..79)
;;  Output: NZ if solid tile, Z if passable or out of bounds
;;  Modified: AF, DE, HL
;;
sys_map_is_solid_at::
    ;; Check within map vertical bounds
    ld a, b
    cp #MAP_PIXEL_START
    jr c, smisa_passable            ;; above map top: passable

    ;; tile_row = (B - MAP_PIXEL_START) / 8
    sub #MAP_PIXEL_START
    rrca
    rrca
    rrca
    and #0x1F                       ;; tile_row (0..31)
    cp #MAP_HEIGHT
    jr nc, smisa_passable           ;; below map: passable

    ;; HL = &g_map01[tile_row * MAP_WIDTH]
    ld l, a
    ld h, #0
    add hl, hl                      ;; *2
    add hl, hl                      ;; *4
    add hl, hl                      ;; *8
    add hl, hl                      ;; *16 = MAP_WIDTH
    ld de, #_g_map01
    add hl, de

    ;; tile_col = C / 4  (each tile is 4 bytes wide in mode 0)
    ld a, c
    rrca
    rrca
    and #0x3F
    cp #MAP_WIDTH
    jr nc, smisa_passable           ;; out of horizontal bounds

    ld e, a
    ld d, #0
    add hl, de

    ;; Look up tile in solid table
    ld a, (hl)                      ;; A = tile_id
    ld hl, #tile_solid_table
    ld e, a
    ld d, #0
    add hl, de
    ld a, (hl)
    or a                            ;; NZ if solid (1), Z if passable (0)
    ret

smisa_passable:
    xor a                           ;; Z=1 (passable)
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

    ;; tile_row_top = (B - MAP_PIXEL_START) >> 3
    ld a, b
    sub #MAP_PIXEL_START
    rrca
    rrca
    rrca
    and #0x1F
    ld (smrsa_y_top), a

    ;; tile_row_bottom = (B + D - 1 - MAP_PIXEL_START) >> 3
    ld a, b
    add a, d
    dec a
    sub #MAP_PIXEL_START
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
    ld de, #_g_map01
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

    ;; pixel_y = tile_row * 8 + MAP_PIXEL_START
    ld a, b
    sla a
    sla a
    sla a                   ;; A = tile_row * 8
    add a, #MAP_PIXEL_START
    ld b, a

    ;; pixel_x_bytes = tile_col * 4
    ld a, c
    sla a
    sla a                   ;; A = tile_col * 4
    ld c, a

    ;; get screen address for this tile
    ld de, #FRONT_BUFFER
    call cpct_getScreenPtr_asm  ;; HL = screen ptr

    ex de, hl               ;; DE = screen ptr
    pop hl                  ;; HL = sprite data
    ld c, #4                ;; tile width: 4 bytes
    ld b, #8                ;; tile height: 8 pixels
    call cpct_drawSprite_asm
    ret
