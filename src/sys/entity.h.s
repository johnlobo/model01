;; Generic entity schema and pool interface.
.module entity_system

.include "globals.inc"
.include "sys/component.inc"
.include "sys/struct.inc"

MAX_ENTITIES = 20


.mdelete DefineEntity
.macro DefineEntity _cpms, _status, _x, _y, _a, _pa, _speed_x, _speed_y, _on_air, _width, _height, _color, _sprite, _room
    .db _cpms
    .db _status
    .db _x
    .db _y
    .dw 0
    .dw 0
    .dw _a
    .dw _pa
    .dw _speed_x
    .dw _speed_y
    .db _on_air
    .db _width
    .db _height
    .db _color
    .dw _sprite
    .db 0
    .dw 0
    .db 0
    .db 0
    .dw 0
    .db 0
    .db _room
    .endm

BeginStruct e
Field e, cmps, 1
Field e, status, 1
Field e, x, 1
Field e, y, 1
Field e, p_x, 2
Field e, p_y, 2
Field e, address, 2
Field e, p_address, 2
Field e, speed_x, 2
Field e, speed_y, 2
Field e, on_air, 1
Field e, width, 1
Field e, height, 1
Field e, color, 1
Field e, sprite, 2
Field e, moved, 1
Field e, anim, 2
Field e, anim_frame, 1
Field e, anim_timer, 1
Field e, beh, 2
Field e, beh_timer, 1
Field e, room, 1
EndStruct e
