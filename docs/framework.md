# El framework de Model01

## 1. Objetivo y alcance

El framework de Model01 proporciona una base compacta para juegos 2D en
Amstrad CPC. Está escrito en ensamblador Z80, usa CPCtelera para acceder al
hardware y está diseñado para que el coste de abstracción sea predecible en una
máquina con 64 KB de espacio de direcciones.

No pretende ser un motor genérico con configuración dinámica. Su enfoque es:

- datos y políticas resueltos durante el ensamblado;
- entidades de tamaño fijo almacenadas en un pool;
- sistemas sencillos que recorren ese pool mediante máscaras de componentes;
- callbacks y tablas de funciones para conectar reglas de juego;
- una dependencia estricta en una sola dirección: `game -> sys`.

Model01 es una implementación concreta que demuestra plataformas, animaciones,
habitaciones conectadas, proyectiles, colisiones, IA dirigida por bytecode,
mensajes y un menú.

## 2. Arquitectura

```text
src/main.s
    |
    | game_app_init / game_app_update
    v
src/game/                         reglas y contenido reemplazables
    |
    | llamadas, datos y callbacks registrados
    v
src/sys/                          mecanismos reutilizables
    |
    v
CPCtelera y hardware del CPC
```

`src/main.s` desactiva el firmware, instala la tabla de transparencia, configura
el modo de vídeo y entrega el control al juego. No conoce menús, habitaciones,
jugadores ni enemigos.

La frontera se comprueba automáticamente: ningún módulo de `src/sys/` puede
importar símbolos de `src/game/`. Cuando un sistema necesita una regla concreta,
expone un callback. Por ejemplo, el sistema de colisiones detecta el solapamiento
y el juego decide qué significa el impacto.

### Organización del código

| Ruta | Responsabilidad |
|---|---|
| `src/main.s` | Arranque mínimo y bucle principal |
| `src/config.h.s` | Geometría y política física del proyecto |
| `src/globals.inc` | Registro único de todos los símbolos visibles al enlazador |
| `src/sys/` | Entidades, física, render, mapas, entrada, IA y utilidades |
| `src/game/` | Estados, contenido, reglas y orden del frame de Model01 |
| `assets/` | PNG, tilesets y mapas TMX editables |
| `cfg/` | Conversión de recursos y configuración de compilación |
| `tests/` | Pruebas de arquitectura, memoria y ejecución Z80 |

Los ficheros `.h.s` se reservan para constantes, estructuras y macros. Las
declaraciones `.globl` no se duplican en cabeceras: todas viven exactamente una
vez en `src/globals.inc`.

## 3. Modelo de entidades y componentes

`src/sys/entity.s` mantiene un pool plano de hasta `MAX_ENTITIES` (20 por
defecto). `sys_entity_create` copia una plantilla completa al primer hueco libre
y devuelve:

- `IX`: dirección de la entidad creada;
- carry limpio: éxito;
- carry activo: pool lleno.

El primer byte, `e_cmps`, indica qué sistemas procesan la entidad:

| Componente | Valor | Sistema o significado |
|---|---:|---|
| `c_cmp_render` | `0x01` | Renderizado |
| `c_cmp_movable` | `0x02` | Física y colisión con mapa |
| `c_cmp_input` | `0x04` | Control por entrada; también recibe fricción por defecto |
| `c_cmp_behavior` | `0x08` | Intérprete de comportamientos |
| `c_cmp_animated` | `0x10` | Animación |
| `c_cmp_collider` | `0x20` | Parte activa de una colisión AABB |
| `c_cmp_collisionable` | `0x40` | Parte pasiva de una colisión AABB |
| `c_cmp_projectile` | `0x80` | Movimiento especializado de proyectil |

Una máscara `0` significa entidad libre. Las máscaras se combinan con OR. Una
entidad puede ser, por ejemplo, renderizable, móvil, animada y controlada por el
jugador a la vez.

La estructura `e` está declarada en `src/sys/entity.h.s`. Sus campos principales
son posición, posición anterior, punteros de vídeo, velocidades, dimensiones,
sprite, animación, comportamiento, estado de juego y habitación. Todos los
sistemas ignoran entidades cuya `e_room` sea distinta de `current_room`.

Las plantillas se consideran inmutables. El patrón esperado es copiarlas con
`sys_entity_create` y personalizar la copia a través de `IX`.

## 4. Coordenadas, mapa y física

El framework usa coordenadas de mundo relativas a la esquina superior izquierda
del mapa:

- `e_x`: bytes de vídeo, no píxeles; en modo 0 cada byte contiene dos píxeles;
- `e_y`: píxeles verticales;
- posición de pantalla: mundo + `map_origin_x` / `map_origin_y`.

Cada tile mide 4 bytes por 8 píxeles. `MAP_WIDTH` puede estar entre 1 y 20 y
`MAP_HEIGHT` entre 1 y 25. El ancho 16 tiene un indexador especializado; los
demás anchos generan sumas durante el ensamblado, sin multiplicación en tiempo
de ejecución.

El sistema de mapas recibe del juego:

- un tileset ETM 4x8 en orden zigzag/Gray-code;
- el array del mapa inicial;
- una tabla de propiedades por identificador de tile.

Las propiedades actuales son `0` (atravesable), `1` (sólido) y `2` (plataforma
de un solo sentido). `sys_map_is_solid_at` no considera sólida una plataforma
al ascender; `sys_map_is_landable_at` sí la considera superficie al caer.

La física aplica velocidad, gravedad, velocidad terminal, fricción, límites del
mundo y colisión con tiles. Estas políticas son constantes de
`src/config.h.s`, por lo que no añaden indirección por frame. Las conexiones
entre habitaciones, portales y reglas de transición pertenecen al juego.

`map_origin_y` debe ser múltiplo de 8: la restauración rápida de tiles depende
de comenzar en una fila de carácter del CPC.

## 5. Renderizado y animación

El render actual dibuja sobre la pantalla frontal en `0xC000`. Antes del VSYNC,
`sys_render_prepare` construye una cola ordenada por Y. Después del VSYNC,
`sys_render_update` restaura el fondo de abajo arriba y dibuja los sprites de
arriba abajo para respetar el solapamiento.

El flag `e_moved` marca que una entidad necesita restauración/redibujado. El
render mantiene en la propia entidad las posiciones y direcciones anteriores.

Una animación es un descriptor:

```asm
.db numero_de_frames
.db ticks_por_frame
.dw sprite_0, sprite_1, ...
```

`sys_anim_set` recibe `IX=entidad` y `HL=descriptor`. Reinicia la animación sólo
si el descriptor cambia. `sys_anim_update` avanza todas las entidades que tengan
`c_cmp_animated`.

Aunque existe una dirección reservada para un back buffer en `0x8000`, Model01
no utiliza doble buffer. Esa zona contiene además la pila heredada del firmware;
no debe limpiarse ni activarse sin mover primero `SP` a una zona segura.

## 6. Entrada

`sys_input_generic_update` interpreta una tabla terminada en cero:

```asm
.dw Key_O, callback_izquierda
.dw Key_P, callback_derecha
.dw 0
```

El juego coloca la tabla en `IY`. Cada callback se ejecuta con `IX` apuntando a
la entidad controlada. La asignación de teclas y la semántica de cada acción
pertenecen por tanto a `src/game/`.

Si una acción cambia `IY`, destruye entidades o cambia de estado de aplicación,
conviene limitar el callback a registrar una petición y aplicarla después de que
el dispatcher termine. Model01 usa esta técnica en el menú y el diálogo de salida.

## 7. Comportamientos e IA

El sistema de comportamientos interpreta pequeños programas almacenados como
datos. `e_beh` apunta a la instrucción actual y `e_beh_timer` proporciona un
contador por entidad.

El DSL incluye acciones como `SET_VX`, `SET_VY`, `SET_ANIMATION`, `DRIVE_VX`,
`WAIT` y `GOTO`, además de condiciones como `timeout`, `on_ground` y
`edge_ahead`. El juego puede añadir acciones y condiciones mediante punteros de
función sin modificar el intérprete.

Para evitar que un ciclo de acciones inmediatas congele la máquina, el motor
limita cada entidad a `BEH_MAX_ACTIONS_PER_TICK` despachos por actualización.
La referencia completa está en [behaviour-system.md](behaviour-system.md).

## 8. Colisiones y proyectiles

`sys_collision_update` realiza detección AABB entre entidades
`c_cmp_collider` y `c_cmp_collisionable`. El juego registra una única función
con `sys_collision_set_handler`; ésta recibe `IX=collider` e `IY=collisionable`
y decide la respuesta según `e_status` u otros datos.

Los proyectiles usan `c_cmp_projectile` y `sys_shoot_update`. Su velocidad es un
paso horizontal entero y un stride en frames. El sistema elimina proyectiles al
salir del mundo o encontrar tiles sólidos. La fábrica y el significado de cada
tipo de proyectil siguen siendo reglas del juego.

La detección entre entidades y la respuesta están separadas deliberadamente:
otro juego puede implementar daño, coleccionables, puertas o conversaciones sin
tocar `src/sys/collision.s`.

## 9. Estado, texto, mensajes y memoria extendida

### Estado global

`sys/state` ofrece 256 flags compactados en 32 bytes y 32 contadores de 8 bits.
El juego asigna significado a sus identificadores; el framework sólo almacena y
consulta valores. `sys_state_test_flag` devuelve `Z=1` cuando el flag está
activo, de modo que puede usarse con la misma convención que una condición de
IA. La suma y resta de contadores saturan en 255 y 0 respectivamente.

Este estado está pensado para puertas, objetos recogidos, enemigos derrotados,
salud, monedas o progreso persistente entre habitaciones. Requiere una llamada a
`sys_state_init` al comenzar una partida nueva.

```asm
FLAG_CELLAR_OPEN = 0
COUNTER_COINS    = 0

ld a, #FLAG_CELLAR_OPEN
call sys_state_set_flag

ld a, #COUNTER_COINS
ld b, #1
call sys_state_add_counter
```

Los identificadores no se validan durante la ejecución para evitar coste en el
Z80: flags válidos `0..255`, contadores válidos `0..31`.

### Inventario

`sys/inventory` mantiene hasta 8 identificadores de objeto únicos. El ID `0`
representa un slot vacío; los IDs `1..255` pertenecen al juego. Añadir un objeto
duplicado, usar el ID cero o superar la capacidad devuelve carry activo. Al
eliminar un objeto se compactan los siguientes slots y se conserva el orden.

```asm
ITEM_CELLAR_KEY = 1

call sys_inventory_init

ld a, #ITEM_CELLAR_KEY
call sys_inventory_add          ;; carry=1 si no se pudo añadir

ld a, #ITEM_CELLAR_KEY
call sys_inventory_contains     ;; Z=1 si está presente
```

El inventario consume 9 bytes: un contador y ocho slots. No interpreta los
objetos ni aplica sus efectos; esas reglas permanecen en el juego. Los flags
pueden utilizarse además para recordar que el objeto ya desapareció del mundo.

### Interacción con entidades

`sys/interaction` busca entidades `c_cmp_collisionable` inmediatamente delante
de un actor. Recibe `IX=actor` y `A=INTERACTION_RIGHT` o `INTERACTION_LEFT`; sólo
considera candidatos de la misma habitación y nunca devuelve al propio actor.
El alcance predeterminado es de dos bytes de modo 0.

El juego puede registrar un filtro y un manejador. El filtro decide si una
entidad candidata es realmente utilizable (`Z=1`); el manejador aplica la regla.
Ambos reciben `IX=actor` e `IY=objetivo`, conservados por el dispatcher.

```asm
game_interaction_init:
    call sys_interaction_init
    ld hl, #game_can_interact
    call sys_interaction_set_filter
    ld hl, #game_use_entity
    jp sys_interaction_set_handler

game_input_use:                  ;; IX=jugador
    ld a, (game_player_facing)
    jp sys_interaction_try
```

`sys_interaction_find` permite localizar un objetivo sin ejecutar la acción;
`sys_interaction_try` localiza el primero aceptado y llama al manejador. Ambos
devuelven carry activo si no existe objetivo. Puertas, personajes, cofres y
objetos siguen identificándose mediante estados definidos por cada juego.

### Texto, mensajes y bancos

El subsistema de texto recibe del juego los recursos de fuente y números. El de
mensajes captura el fondo, dibuja una ventana y puede restaurarlo al cerrar. Su
buffer fijo ocupa `0x0300..0x0EB7`, fuera del binario enlazado.

En CPC 6128, `sys/mem` permite copiar datos hacia o desde cuatro bancos extra de
16 KB. Como la ventana bancaria es `0x4000..0x7FFF`, precisamente donde reside
el código, las copias se ejecutan mediante un stub instalado en `0x0200` y con
interrupciones deshabilitadas. El código y los datos enlazados no pueden superar
`0x7FFF` con este diseño.

Mapa de memoria relevante:

| Rango | Uso |
|---|---|
| `0x0100..0x01FF` | Tabla de transparencia |
| `0x0200..0x0213` | Stub bancario y byte de detección |
| `0x0300..0x0EB7` | Fondo de la ventana de mensajes |
| `0x4000..0x7FFF` | Código, datos y ventana bancaria |
| `0x8000..0xBFFF` | Back buffer reservado y pila actual |
| `0xC000..0xFFFF` | Pantalla frontal |

## 10. Ciclo de vida y orden del frame

El framework no impone un administrador de escenas. El juego inicializa sólo
los sistemas que utiliza y decide su orden. Model01 usa, de forma resumida:

```text
Inicialización
  memoria -> entidades -> entrada -> colisiones -> contenido
  -> texto -> render -> mapa -> proyectiles

Frame
  física -> proyectiles -> transición de habitación -> entrada
  -> IA -> efectos -> colisiones -> animación -> preparar render
  -> VSYNC -> render
```

El orden es parte de las reglas. Por ejemplo, mover antes de detectar colisiones
hace que éstas se evalúen con la posición nueva; preparar el render después de
animar garantiza que se dibuje el frame actualizado.

## 11. Contratos y pruebas

`make test` valida cuatro niveles sin añadir código de test al juego:

1. arquitectura: dependencia `game -> sys`, globals únicos y configuración;
2. compilación alternativa: indexador de mapas genérico y optimizado;
3. memoria: el binario enlazado termina como máximo en `0x7FFF`;
4. ejecución: reglas reales del binario Z80 mediante Z80Ex sin interfaz gráfica.

Los tests del host y sus fixtures nunca se enlazan en el juego. El tutorial de
[creación de un juego nuevo](new-game-template.md) explica cómo conservar estos
contratos al reemplazar Model01.
