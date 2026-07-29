# Recetas para crear contenido

Esta guía reúne los patrones necesarios para añadir contenido a un juego basado
en Model01. Las reglas concretas viven en `src/game/`; `src/sys/` sólo aporta
los mecanismos reutilizables.

## Convenciones comunes

- X se expresa en bytes de modo 0; Y, en píxeles.
- Las coordenadas de entidades son relativas al mapa, no a la pantalla.
- Toda entidad pertenece a una habitación mediante `e_room`.
- `sys_entity_create` y las fábricas devuelven carry activo si no hay hueco.
- Una rutina o dato usado desde otro módulo debe declararse una sola vez en
  `src/globals.inc`.
- Las plantillas son inmutables: personaliza siempre la copia devuelta en `IX`.

## Crear un objeto visible

La fábrica de ejemplo recibe `B=X`, `C=Y` y `D=habitación`:

```asm
    ld b, #24
    ld c, #120
    ld d, #2
    call game_entity_create_object
    ret c                         ;; pool lleno

    ld e_status(ix), #STATUS_KEY
    ld hl, #_s_key_0
    ld e_sprite(ix), l
    ld e_sprite+1(ix), h
```

`game_entity_create_object` crea una entidad con `c_cmp_render` y
`c_cmp_collisionable`. Añade `c_cmp_collider` sólo si el objeto también debe
iniciar colisiones. Ajusta `e_width` y `e_height` si el sprite no coincide con
la plantilla.

Para un objeto recogible persistente:

1. define un `ITEM_*` entre 1 y 255 y un `FLAG_*`;
2. no lo crees si el flag ya está activo;
3. al interactuar, llama a `sys_inventory_add`;
4. sólo tras éxito activa el flag y destruye la entidad.

```asm
game_take_key:                    ;; IX=jugador, IY=llave
    ld a, #ITEM_KEY
    call sys_inventory_add
    ret c
    ld a, #FLAG_KEY_TAKEN
    call sys_state_set_flag
    push ix
    push iy
    pop ix
    call sys_collision_destroy_entity
    pop ix
    ret
```

## Crear un portal

Los portales de Model01 son volúmenes invisibles sobre una puerta dibujada en
el tilemap. Primero se crea el trigger:

```asm
    ld b, #52                     ;; X origen
    ld c, #136                    ;; Y origen
    ld d, #2                      ;; habitación origen
    call game_entity_create_portal
    ret c
```

La fábrica devuelve el portal en `IX`. Sus campos reutilizados codifican el
destino:

```asm
    ld hl, #_g_inside01
    ld e_beh(ix), l
    ld e_beh+1(ix), h             ;; mapa destino
    ld e_beh_timer(ix), #4        ;; id de habitación destino
    ld e_speed_x(ix), #1          ;; X destino, en bytes
    ld e_speed_x+1(ix), #144      ;; Y destino, en píxeles
    ld e_on_air(ix), #1           ;; portal activo
```

El callback de colisión debe comprobar `STATUS_PLAYER` contra `STATUS_PORTAL`
y saltar a `game_map_do_portal_transition`. Un portal con `e_on_air=0` está
desactivado. Como no tiene `c_cmp_render`, la apariencia de la puerta pertenece
al TMX; cambia sus tiles por separado si el portal se abre o se cierra.

No confundas un portal con una conexión de borde. Las conexiones N/S/E/O se
declaran en `room_connections` mediante `DefineRoomConnections`; los portales
son entidades y pueden llevar a cualquier mapa y posición.

## Crear habitaciones y conexiones

Convierte cada TMX y registra sus símbolos. Después declara una fila por
habitación:

```asm
room_connections::
    ;;                    N N_id  S S_id  E          E_id  W W_id
    DefineRoomConnections 0,0xff, 0,0xff, _g_room02, 1,   0,0xff
    DefineRoomConnections 0,0xff, 0,0xff, 0,0xff, _g_room01,0
```

El puntero nulo significa que no existe salida. Mantén sincronizados el índice
de fila, el id almacenado en la conexión, `current_room` y `e_room`.

Para tiles dinámicos usa coordenadas de celda:

```asm
    ld b, #12                     ;; fila
    ld c, #7                      ;; columna
    ld a, #TILE_OPEN_DOOR
    call sys_map_set_tile_and_redraw
```

Guarda un flag si el cambio debe reaplicarse al volver a la habitación.

## Crear un script de evento

Incluye `sys/script.h.s` y escribe el bytecode en `_DATA`:

```asm
.area _DATA

open_door_script:
    SCRIPT_REQUIRE_ITEM ITEM_KEY, open_door_failed
    SCRIPT_REMOVE_ITEM ITEM_KEY, open_door_failed
    SCRIPT_SET_FLAG FLAG_DOOR_OPEN
    SCRIPT_SET_TILE #12, #7, #TILE_OPEN_DOOR
    SCRIPT_CALL game_door_opened
    SCRIPT_END

open_door_failed:
    SCRIPT_CALL game_door_locked
    SCRIPT_END
```

Inícialo desde una interacción y actualiza el intérprete en cada frame:

```asm
    ld hl, #open_door_script
    call sys_script_start

    ;; en game_update
    call sys_script_update
```

Sólo hay un script activo. `SCRIPT_END`, un target nulo o
`sys_script_stop` lo terminan. Los requisitos saltan a su target si fallan.

Macros disponibles:

| Grupo | Macros |
|---|---|
| Flags | `SCRIPT_SET_FLAG`, `SCRIPT_CLEAR_FLAG`, `SCRIPT_REQUIRE_FLAG` |
| Inventario | `SCRIPT_ADD_ITEM`, `SCRIPT_REMOVE_ITEM`, `SCRIPT_REQUIRE_ITEM` |
| Contadores | `SCRIPT_SET_COUNTER`, `SCRIPT_ADD_COUNTER`, `SCRIPT_REQUIRE_COUNTER` |
| Mundo | `SCRIPT_SET_TILE` |
| Flujo | `SCRIPT_CALL`, `SCRIPT_GOTO`, `SCRIPT_END` |

`SCRIPT_CALL` invoca una rutina de juego normal. El callback puede modificar
registros, pero debe retornar con `ret`; el intérprete conserva internamente la
posición de continuación.

## Crear un comportamiento

Una entidad con `c_cmp_behavior` ejecuta el programa apuntado por `e_beh`:

```asm
.area _DATA

guard_behavior:
    SET_ANIMATION guard_right_anim
guard_right:
    DRIVE_VX #1, #2
      CONDITION edge_ahead, guard_left
      CONDITIONS_END
guard_left:
    SET_ANIMATION guard_left_anim
    DRIVE_VX #-1, #2
      CONDITION edge_ahead, guard_right
      CONDITIONS_END
```

Asigna el programa al crear la entidad y llama a `sys_beh_update` en el frame:

```asm
    ld e_cmps(ix), #(c_cmp_render | c_cmp_movable | c_cmp_behavior)
    ld hl, #guard_behavior
    ld e_beh(ix), l
    ld e_beh+1(ix), h
```

Los comportamientos controlan entidades durante muchos frames; los scripts de
evento describen consecuencias inmediatas sobre el mundo. No son
intercambiables.

## Crear una acción de comportamiento

Una acción no bloqueante consume sus argumentos desde `DE`, deja `DE` apuntando
a la siguiente instrucción y termina con `jp sys_beh_next`:

```asm
.macro GAME_SET_STATUS _status
    ACTION game_beh_action_set_status
    .db _status
.endm

.area _CODE

game_beh_action_set_status::     ;; IX=entidad, DE=argumento inline
    ld a, (de)
    inc de
    ld e_status(ix), a
    jp sys_beh_next
```

Una acción bloqueante deja `e_beh` en la misma instrucción y termina con
`jp sys_beh_check_conditions`. Debe avanzar `DE` sobre todos sus argumentos
para que apunte a la tabla de condiciones:

```asm
.macro GAME_FACE_PLAYER
    ACTION game_beh_action_face_player
.endm

game_beh_action_face_player::
    ;; calcular orientación de IX...
    jp sys_beh_check_conditions
```

Registra la función en `src/globals.inc` si la macro se usa desde otro módulo.
Evita `call` entre acciones del motor: las transiciones del intérprete usan
`jp` para mantener plana la pila.

## Crear una condición de comportamiento

Una condición recibe `IX=entidad`, debe preservar `DE` y usa esta convención:

- `Z=1`: condición verdadera;
- `Z=0`: condición falsa.

```asm
game_cond_has_key::
    push de
    ld a, #ITEM_KEY
    call sys_inventory_contains  ;; ya devuelve Z=1 si existe
    pop de                       ;; POP no altera los flags
    ret
```

Emítela sin depender de una convención de nombres:

```asm
    IDLE
      CONDITION_FN game_cond_has_key, guard_open_door
      CONDITIONS_END
```

## Crear una acción de teclado o interacción

Añade pares `tecla, callback` antes del cero final de la tabla:

```asm
game_input_key_actions:
    .dw Key_E, game_input_use
    .dw 0

game_input_use:                  ;; IX=jugador
    ld a, (game_player_facing)   ;; 0=derecha, 1=izquierda
    jp sys_interaction_try
```

El filtro de interacción devuelve `Z=1` para aceptar al candidato; el handler
recibe `IX=actor` e `IY=objetivo`. Si el callback de teclado cambia de escena o
destruye `IY`, registra una petición y aplícala después de que
`sys_input_generic_update` retorne.

## Crear proyectiles

Las fábricas reciben `B=X`, `C=Y`, `D=habitación` y `E=velocidad X con signo`:

```asm
    ld b, #40
    ld c, #80
    ld a, (current_room)
    ld d, a
    ld e, #2
    call game_entity_create_player_bullet
    ret c
```

El sistema requiere `sys_shoot_update` en el frame. Los proyectiles no usan
gravedad; se destruyen al salir del mapa o tocar un tile bloqueante. La respuesta
al impacto con otra entidad sigue perteneciendo al callback de colisión.

## Integración y comprobación

Al añadir contenido nuevo, revisa siempre:

1. símbolos compartidos registrados en `src/globals.inc`;
2. componentes correctos y `e_room` asignado;
3. carry comprobado después de cada fábrica;
4. sistema inicializado y actualizado en `game_init`/`game_update`;
5. persistencia reconstruida mediante flags al cargar la habitación;
6. comentarios de rutina con descripción, `Input`, `Output` y `Modified`;
7. `make test` después del cambio.

Consulta además [la guía del framework](framework.md) para los contratos de
arquitectura y [el sistema de comportamientos](behaviour-system.md) para la
referencia completa del DSL. Para paquetes de zonas y contenido ampliado,
consulta [Memoria para 64 y 128 KB](memory-layout.md).
