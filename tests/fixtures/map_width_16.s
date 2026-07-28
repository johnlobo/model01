.module map_width_16_fixture

MAP_WIDTH = 16
.include "sys/map_index.inc"

.area _CODE

map_width_16_fixture:
    ld hl, #3
    map_row_offset_hl
    ret
