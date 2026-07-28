# Tutorial: crear un juego nuevo con el framework

Este tutorial parte de Model01 y termina con la estructura de un juego nuevo.
La estrategia más segura es mantener el framework funcionando y sustituir el
contenido en pasos pequeños, compilando después de cada uno.

## 1. Preparar la copia

Duplica el repositorio, cambia el nombre del proyecto en
`cfg/build_config.mk` y comprueba primero la base:

```make
PROJNAME := mijuego
Z80CODELOC := 0x4000
```

```sh
export CPCT_PATH=/ruta/a/cpctelera
make
make test
```

No cambies `Z80CODELOC` sin rediseñar el mapa de memoria y el sistema bancario.
Conserva inicialmente `src/sys/`, `src/main.s`, los tests y la infraestructura
de `cfg/`.

## 2. Definir la frontera del juego

Elimina o reemplaza el contenido de `src/game/`, pero conserva estas dos
funciones públicas, que son el único contrato del arranque:

```asm
.module game_app
.include "globals.inc"

.area _CODE

game_app_init::
    jp game_init

game_app_update::
    jp game_update
```

Si necesitas menú, pausa o pantalla final, añade un byte de estado y despacha
desde `game_app_update`, como hace `src/game/app.s`. Un juego de una sola escena
puede usar los dos saltos anteriores.

Registra `game_app_init`, `game_app_update`, `game_init` y `game_update` una sola
vez en `src/globals.inc`. Toda función o dato referenciado desde otro módulo debe
aparecer en ese registro; una etiqueta privada puede usar `:` en lugar de `::`.

## 3. Configurar mundo y física

Edita `src/config.h.s`:

```asm
MAP_WIDTH        = 16
MAP_HEIGHT       = 20
GROUND_LEVEL     = MAP_HEIGHT * 8 - 1

PHYSICS_GRAVITY                = 1
PHYSICS_MAX_FALL_SPEED         = 8
PHYSICS_FRICTION_COMPONENT_BIT = 2  ;; c_cmp_input
```

Cada tile mide 4 bytes x 8 píxeles. Los límites son 1..20 columnas y 1..25
filas. El ancho 16 es el más rápido; otros anchos siguen evitando una
multiplicación en runtime.

Crea `src/game/config.h.s` para valores exclusivos del juego:

```asm
STATUS_PLAYER = 1
STATUS_ENEMY  = 2
STATUS_EXIT   = 3

PLAYER_WIDTH  = 4       ;; bytes de pantalla: 8 píxeles en modo 0
PLAYER_HEIGHT = 16      ;; píxeles
```

## 4. Crear los recursos

Guarda los PNG y TMX editables en `assets/`. Declara su conversión en
`cfg/image_conversion.mk` y `cfg/tilemap_conversion.mk`. Por ejemplo:

```make
$(eval $(call IMG2SP, CONVERT, assets/player.png, 8, 16, s_player, ,))
$(eval $(call TMX2C,assets/map/room01.tmx,g_room01,src/assets/sprites/,))
```

Para el mapa, configura `IMG_FORMAT` como `zgtiles`: el render ETM necesita
orden zigzag y Gray-code. Un sprite normal no puede usarse directamente como
tile ETM ni viceversa.

Después de ejecutar `make`, CPCtelera genera símbolos como `_s_player_0` o
`_g_room01`. Añádelos a `src/globals.inc` si se usan desde ensamblador.

## 5. Construir el juego mínimo

Crea `src/game/game.s` con la inicialización y el orden del frame. Esta versión
utiliza entidades, entrada, física, mapa, animación y render:

```asm
.module my_game

.include "cpctelera.h.s"
.include "globals.inc"
.include "sys/entity.h.s"

.area _CODE

game_init::
    call sys_state_init
    call sys_inventory_init
    call sys_entity_init
    call sys_input_init
    call sys_collision_init
    call game_entity_create_player

    ld hl, #_g_palette0
    call sys_render_init
    call game_map_init
    call sys_map_draw
    ret

game_update::
    call sys_physics_update
    ld ix, #entity_array
    call game_input_update
    call sys_collision_update
    call sys_anim_update
    call sys_render_prepare
    call cpct_waitVSYNC_asm
    jp sys_render_update
```

No es obligatorio usar todos los sistemas. Si incorporas proyectiles o IA,
inicialízalos y añade `sys_shoot_update` o `sys_beh_update` en el lugar que
corresponda a tus reglas.

`sys_state_init` reserva una base limpia de 256 flags y 32 contadores para cada
partida. Define sus identificadores en `game/config.h.s` y utilízalos para
recordar cambios del mundo:

```asm
FLAG_EXIT_OPEN = 0
COUNTER_KEYS   = 0

    ld a, #FLAG_EXIT_OPEN
    call sys_state_test_flag    ;; Z=1 si la salida está abierta

    ld a, #COUNTER_KEYS
    ld b, #1
    call sys_state_add_counter  ;; saturación en 255
```

Para objetos transportables, reserva IDs entre 1 y 255 y utiliza el inventario
de ocho slots:

```asm
ITEM_KEY = 1

    ld a, #ITEM_KEY
    call sys_inventory_add       ;; carry=1 si está lleno o ya existe

    ld a, #ITEM_KEY
    call sys_inventory_contains  ;; Z=1 si el jugador tiene la llave

    ld a, #ITEM_KEY
    call sys_inventory_remove
```

El objeto visible sigue siendo una entidad del juego. Al recogerlo, añade su ID
al inventario, destruye la entidad sólo si la inserción tuvo éxito y activa un
flag para no recrearla al volver a entrar en la habitación.

## 6. Crear una entidad

En `src/game/entities.s`, define primero una animación y una plantilla:

```asm
.module game_entities
.include "globals.inc"
.include "sys/entity.h.s"
.include "game/config.h.s"

.area _DATA

player_idle_anim::
    .db 1, 0
    .dw _s_player_0

player_walk_anim::
    .db 2, 6
    .dw _s_player_1, _s_player_2

player_template:
DefineEntity c_cmp_invalid, STATUS_PLAYER, 8, 16, 0, 0, 0, 0, 1, PLAYER_WIDTH, PLAYER_HEIGHT, 15, _s_player_0, 0
```

La plantilla no está activa porque su máscara es `c_cmp_invalid`. La fábrica
copia la plantilla y configura la entidad resultante:

```asm
.area _CODE

game_entity_create_player::
    ld hl, #player_template
    call sys_entity_create
    ret c

    ld e_cmps(ix), #(c_cmp_render | c_cmp_movable | c_cmp_input | c_cmp_animated | c_cmp_collider)
    ld e_moved(ix), #1
    ld hl, #player_idle_anim
    ld e_anim(ix), l
    ld e_anim+1(ix), h
    or a
    ret
```

Comprueba siempre el carry de `sys_entity_create`. No escribas sobre la
plantilla para configurar una instancia: eso modificaría también las futuras.

## 7. Añadir controles

En `src/game/input.s`, declara una tabla de teclas terminada por cero:

```asm
.module game_input
.include "cpctelera.h.s"
.include "globals.inc"
.include "sys/entity.h.s"

.area _DATA

game_key_actions:
    .dw Key_O, game_input_left
    .dw Key_P, game_input_right
    .dw Key_Q, game_input_jump
    .dw 0

.area _CODE

game_input_update::
    ld iy, #game_key_actions
    jp sys_input_generic_update

game_input_left:
    ld e_speed_x(ix), #-2
    ret

game_input_right:
    ld e_speed_x(ix), #2
    ret

game_input_jump:
    ld a, e_on_air(ix)
    or a
    ret nz
    ld e_speed_y(ix), #-6
    ld e_on_air(ix), #1
    ret
```

Los callbacks reciben `IX=jugador`. Si una acción cambia de escena o utiliza
rutinas que destruyen `IY`, registra una petición y aplícala cuando
`sys_input_generic_update` haya retornado.

## 8. Inicializar el mapa

En `src/game/map.s`, asocia cada índice de tile con su propiedad y entrega los
recursos al sistema:

```asm
.module game_map
.include "globals.inc"

.area _DATA

game_tile_properties::
    .db 0  ;; tile 0: atravesable
    .db 1  ;; tile 1: sólido
    .db 2  ;; tile 2: plataforma de un solo sentido

.area _CODE

game_map_init::
    ld hl, #_s_tileset_00
    ld de, #_g_room01
    ld ix, #game_tile_properties
    jp sys_map_init
```

El mapa TMX debe tener exactamente `MAP_WIDTH x MAP_HEIGHT`. Las coordenadas de
entidad se expresan desde la esquina del mapa: X en bytes y Y en píxeles.

Para varias habitaciones, crea una tabla con `DefineRoomConnections` y conserva
la transición en la capa de juego. Cambia de mapa con `sys_map_set`, actualiza
`current_room` y asigna esa misma habitación a las entidades que deban aparecer.

## 9. Activar animaciones

Una entidad necesita `c_cmp_animated` y un puntero válido en `e_anim`. Para
cambiar de animación sin reiniciarla en cada frame:

```asm
    ld hl, #player_walk_anim
    jp sys_anim_set              ;; IX=entidad
```

El descriptor contiene número de frames, velocidad y una tabla de punteros. Una
velocidad `0` avanza en cada tick. Marca `e_moved` cuando una modificación visual
no lo haga automáticamente.

## 10. Añadir un enemigo con IA

Incluye `sys/beh.h.s`, define un programa en `_DATA` y asigna su dirección a
`e_beh`:

```asm
enemy_patrol::
    SET_ANIMATION enemy_right_anim
enemy_go_right:
    DRIVE_VX #1, #3
    CONDITION edge_ahead, enemy_turn_left
    CONDITIONS_END
enemy_turn_left:
    SET_ANIMATION enemy_left_anim
    DRIVE_VX #-1, #3
    CONDITION edge_ahead, enemy_patrol
    CONDITIONS_END
```

La entidad debe llevar `c_cmp_behavior`. Añade `sys_beh_update` al frame. Para
una acción propia, emite su puntero con `ACTION callback`; el callback recibe
`IX=entidad` y `DE=argumentos`, consume sus bytes y termina normalmente con
`jp sys_beh_next`. Consulta [behaviour-system.md](behaviour-system.md) para el
contrato completo.

## 11. Añadir colisiones entre entidades

Registra una respuesta manteniendo la detección en el framework:

```asm
game_collision_init::
    ld hl, #game_collision_on_hit
    jp sys_collision_set_handler

game_collision_on_hit::          ;; IX=collider, IY=collisionable
    ld a, e_status(ix)
    cp #STATUS_PLAYER
    ret nz
    ld a, e_status(iy)
    cp #STATUS_EXIT
    ret nz
    jp game_go_to_next_level
```

El actor activo necesita `c_cmp_collider` y el objetivo
`c_cmp_collisionable`. Si ambos deben iniciar colisiones, asigna las dos máscaras
según corresponda. La colisión con el escenario es responsabilidad de física y
mapa, no de este callback.

## 12. Añadir proyectiles

Una fábrica de proyectil sigue el mismo patrón que cualquier entidad, pero usa:

```asm
ld e_cmps(ix), #(c_cmp_render | c_cmp_projectile | c_cmp_collider)
ld e_speed_x(ix), #2             ;; bytes por paso, con signo
ld e_speed_x+1(ix), #2           ;; stride: frames entre pasos
ld e_beh_timer(ix), #1           ;; stride - 1
```

Añade `sys_shoot_init` a la inicialización y `sys_shoot_update` al frame. El
sistema destruye el proyectil en límites y tiles sólidos; el juego crea la
instancia y responde a sus colisiones con otras entidades.

## 13. Añadir mensajes o memoria extendida

Para usar texto llama primero a `sys_text_init` con `HL=fuente` y `DE=sprites de
números`. `sys_messages_show` puede guardar el fondo de una ventana y
`sys_messages_close` restaurarlo. El buffer está en memoria baja fija y no
aumenta el binario.

Llama a `sys_mem_init` si necesitas detectar 128 KB o copiar bancos. Utiliza las
rutinas de copia de alto nivel; no banques directamente desde código situado en
`0x4000..0x7FFF`.

## 14. Probar durante el desarrollo

Ejecuta tras cada paso:

```sh
make test
```

La suite detecta:

- imports del juego desde el framework;
- `.globl` duplicados o símbolos públicos no registrados;
- valores de mapa y física fuera de rango;
- roturas del indexador con ancho genérico o ancho 16;
- un binario que invada memoria por encima de `0x7FFF`;
- regresiones de entidades, arrays, colisiones, proyectiles, IA, animación y
  física ejecutando el Z80 real.

Los tests viven en el host y no consumen RAM del juego.

## 15. Lista final

Antes de considerar terminada una primera versión:

1. `game_app_init` y `game_app_update` existen y están registrados.
2. `src/sys/` no importa ningún símbolo de `src/game/`.
3. Cada símbolo público aparece una sola vez en `src/globals.inc`.
4. Cada llamada a `sys_entity_create` trata el carry.
5. Todos los mapas tienen las dimensiones configuradas y tabla de propiedades.
6. Todas las entidades tienen habitación, dimensiones y máscara coherentes.
7. El orden de sistemas del frame refleja las reglas del juego.
8. `make test` termina correctamente.
9. El mayor address de `obj/<juego>.bin.log` no supera `0x7FFF`.
10. El juego se prueba finalmente en emulador o hardware real para validar vídeo,
    temporización y controles.
