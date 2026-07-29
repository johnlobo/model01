.module map_width_16_fixture

MAP_WIDTH = 16
.include "sys/map_index.inc"

.area _CODE

;;-----------------------------------------------------------------
;;
;; map_width_16_fixture
;;
;;  Exercises the optimized row-offset path for a 16-tile-wide map.
;;  Input:
;;  Output: HL = 48 (row 3 multiplied by MAP_WIDTH)
;;  Modified: AF, HL
;;
map_width_16_fixture:
    ld hl, #3
    map_row_offset_hl
    ret
