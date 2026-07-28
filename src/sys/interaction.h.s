;; Forward interaction query for adventure-style entities.
.module interaction_system

INTERACTION_RIGHT = 0
INTERACTION_LEFT  = 1
INTERACTION_REACH = 2       ;; horizontal reach in Mode 0 screen bytes

;; sys_interaction_init
;;   Restores the accept-all filter and no-op handler.
;;
;; sys_interaction_set_filter
;;   Input: HL = callback or 0 for accept-all.
;;   Callback input: IX=actor, IY=candidate.
;;   Callback output: Z=1 to accept, Z=0 to reject.
;;   IX and IY are preserved by the dispatcher.
;;
;; sys_interaction_set_handler
;;   Input: HL = callback or 0 for no-op.
;;   Callback input: IX=actor, IY=accepted target.
;;   IX and IY are preserved by the dispatcher.
;;
;; sys_interaction_find
;;   Input: IX=actor, A=INTERACTION_RIGHT or INTERACTION_LEFT.
;;   Output: carry clear and IY=first accepted target; carry set if none.
;;   Only c_cmp_collisionable entities in the actor's room are considered.
;;
;; sys_interaction_try
;;   Same input/output as find, then invokes the registered handler on success.
