;;-------------------------------------------------------------------------------
.module anim_system

.include "sys/array.h.s"
.include "cpctelera.h.s"
.include "common.h.s"
.include "sys/anim.h.s"
.include "man/entity.h.s"

;;
;; Start of _DATA area
;;
.area _DATA


;;
;; Start of _CODE area
;;
.area _CODE

;;-----------------------------------------------------------------
;;
;; sys_anim_init
;;
;;  Initializes the animation system
;;  Input:
;;  Output:
;;  Modified:
;;
sys_anim_init::
    ret

;;-----------------------------------------------------------------
;;
;; sys_anim_update_one_entity
;;
;;  Advances animation for one entity and updates e_sprite.
;;  IY is used to access the animation descriptor.
;;
;;  Input:  ix: entity
;;  Output:
;;  Modified: AF, B, C, DE, HL, IY
;;
sys_anim_update_one_entity::

    ;; Skip if entity is idle (on ground and no horizontal speed)
    ld a, e_speed_x(ix)
    or a
    jr nz, sauoe_check_anim     ;; has horizontal speed: animate
    ld a, e_on_air(ix)
    or a
    ret z                       ;; speed_x=0 and on_air=0: idle, skip

sauoe_check_anim:
    ;; Skip if no animation descriptor is set
    ld l, e_anim(ix)
    ld h, e_anim+1(ix)
    ld a, l
    or h
    ret z                       ;; e_anim == null_ptr, nothing to do

    push hl
    pop iy                      ;; IY = animation descriptor

    ;; If timer > 0, decrement and return (not yet time to advance)
    ld a, e_anim_timer(ix)
    or a
    jr z, sauoe_advance         ;; timer expired, advance frame now
    dec a
    ld e_anim_timer(ix), a
    ret

sauoe_advance:
    ;; Reset timer from descriptor speed
    ld a, anim_speed(iy)
    ld e_anim_timer(ix), a

    ;; Increment frame, wrapping at frame_count
    ld a, e_anim_frame(ix)
    inc a
    ld b, anim_frame_count(iy)
    cp b
    jr c, sauoe_store_frame
    xor a                       ;; wrap back to frame 0
sauoe_store_frame:
    ld e_anim_frame(ix), a

    ;; Compute pointer to frames[frame]: descriptor + anim_frames + frame*2
    sla a                       ;; a = frame index * 2 (each entry is a .dw)
    ld e, a
    ld d, #0
    push iy
    pop hl                      ;; HL = descriptor base
    ld bc, #anim_frames         ;; skip frame_count and speed bytes
    add hl, bc                  ;; HL = &frames[0]
    add hl, de                  ;; HL = &frames[frame]

    ;; Load the sprite pointer from the frame table
    ld e, (hl)
    inc hl
    ld d, (hl)                  ;; DE = sprite pointer for current frame

    ;; Update entity sprite and mark dirty for render
    ld e_sprite(ix), e
    ld e_sprite+1(ix), d
    ld e_moved(ix), #1
    ret

;;-----------------------------------------------------------------
;;
;; sys_anim_update
;;
;;  Iterates all animated entities and advances their animation.
;;  Input:
;;  Output:
;;  Modified: AF, BC, DE, HL, IX, IY
;;
sys_anim_update::
    ld ix, #entities
    ld b, #c_cmp_animated
    ld hl, #sys_anim_update_one_entity
    call sys_array_execute_each_ix_matching
    ret
