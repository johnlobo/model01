.module map_width_15_fixture

MAP_WIDTH = 15
.include "sys/map_index.inc"

.area _CODE

;;-----------------------------------------------------------------
;;
;; map_width_15_fixture
;;
;;  Exercises generic row-offset expansion for a 15-tile-wide map.
;;  Input:
;;  Output: HL = 45 (row 3 multiplied by MAP_WIDTH)
;;  Modified: AF, DE, HL
;;
map_width_15_fixture:
    ld hl, #3
    map_row_offset_hl
    ret
