;; Generic fixed-capacity entity pool.
.module entity_system

.include "sys/entity.h.s"
.include "cpctelera.h.s"
.include "sys/array.h.s"

.area _DATA

entities::
DefineArrayStructure entity, MAX_ENTITIES, sizeof_e
.db 0

.area _CODE

;;-----------------------------------------------------------------
;;
;; sys_entity_init
;;
;;  Initializes the fixed-capacity entity pool.
;;  Input:
;;  Output:
;;  Modified: AF, BC, DE, HL, IX
;;
sys_entity_init::
    ld ix, #entities
    jp sys_array_init

;;-----------------------------------------------------------------
;;
;; sys_entity_create
;;
;;  Allocates or recycles an entity slot and copies the supplied template into it.
;;  Input: HL = entity template
;;  Output: IX = entity and carry clear on success; carry set when the pool is full
;;  Modified: AF, BC, DE, HL, IX
;;
sys_entity_create::
    ld ix, #entities
    call sys_array_create_reusable_element
    ret c
    ld__ix_hl
    or a
    ret
