;; Fixed-slot inventory for compact adventure games.
.module inventory_system

SYS_INVENTORY_CAPACITY = 8
SYS_INVENTORY_EMPTY    = 0

;; Item id 0 is reserved for an empty slot. Valid game item ids are 1..255.
;; Items are unique: adding an id already present fails instead of duplicating it.
;;
;; sys_inventory_init
;;   Clears all slots and resets the count.
;;
;; sys_inventory_add
;;   Input:  A = item id
;;   Output: carry clear on success, carry set for id 0, duplicate or full
;;
;; sys_inventory_remove
;;   Input:  A = item id
;;   Output: carry clear on success, carry set when absent/id 0
;;   Remaining items are compacted, preserving their order.
;;
;; sys_inventory_contains
;;   Input:  A = item id
;;   Output: Z=1 when present, Z=0 when absent
;;           A=0 when present, A=1 when absent
;;
;; sys_inventory_get
;;   Input:  A = zero-based slot
;;   Output: A = item id and carry clear, or A=0 and carry set when invalid
