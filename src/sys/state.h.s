;; Compact global state for persistent game rules.
.module state_system

SYS_STATE_FLAG_COUNT    = 256
SYS_STATE_FLAG_BYTES    = SYS_STATE_FLAG_COUNT / 8
SYS_STATE_COUNTER_COUNT = 32

;; API contracts:
;;
;; sys_state_init
;;   Clears every flag and counter.
;;
;; sys_state_set_flag / sys_state_clear_flag
;;   Input: A = flag id (0..255)
;;
;; sys_state_test_flag
;;   Input:  A = flag id (0..255)
;;   Output: Z=1 when set, Z=0 when clear
;;           A=0 when set, A=1 when clear
;;
;; sys_state_get_counter
;;   Input:  A = counter id (0..31)
;;   Output: A = value
;;
;; sys_state_set_counter
;;   Input: A = counter id (0..31), B = value
;;
;; sys_state_add_counter / sys_state_sub_counter
;;   Input:  A = counter id (0..31), B = unsigned amount
;;   Output: A = resulting value
;;   Addition saturates at 255; subtraction saturates at 0.
;;
;; IDs are intentionally unchecked at runtime. Games should define symbolic
;; constants inside the ranges above; avoiding bounds checks keeps this API
;; inexpensive enough for frequent Z80 use.
