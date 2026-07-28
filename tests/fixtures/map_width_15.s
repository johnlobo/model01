.module map_width_15_fixture

MAP_WIDTH = 15
.include "sys/map_index.inc"

.area _CODE

map_width_15_fixture:
    ld hl, #3
    map_row_offset_hl
    ret
