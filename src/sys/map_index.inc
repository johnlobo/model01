;; Convert HL=row to HL=row*MAP_WIDTH. Width 16 keeps the original fast path;
;; other widths are expanded at assembly time without a runtime multiplier.
;; MAP_WIDTH must be defined before including this file.
.mdelete map_row_offset_hl
.macro map_row_offset_hl
    .if MAP_WIDTH-16
        ld e, l
        ld d, h
        ld hl, #0
        .rept MAP_WIDTH
            add hl, de
        .endm
    .else
        add hl, hl
        add hl, hl
        add hl, hl
        add hl, hl
    .endif
.endm
