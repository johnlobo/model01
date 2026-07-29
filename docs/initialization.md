# Proceso de inicialización

El arranque se divide en tres niveles: plataforma, aplicación y partida. Esta
separación permite volver al menú o iniciar una partida nueva sin repetir todo
el arranque del CPC.

## 1. Arranque de plataforma

`_main` en `src/main.s` se ejecuta una sola vez:

```text
sys_system_disable_firmware
  -> copiar tabla de transparencia a 0x0100
  -> configurar modo de vídeo 0
  -> configurar colores de texto de CPCtelera
  -> game_app_init
  -> bucle infinito game_app_update
```

En esta fase todavía no se crean habitaciones ni entidades. La pila heredada
permanece cerca de `0xBFxx`; no debe moverse a `0x4000–0x7FFF`, porque esa zona
desaparece temporalmente durante una copia bancaria.

## 2. Inicialización de aplicación

El bootstrap sólo conoce dos símbolos del juego:

```asm
game_app_init::
    jp game_menu_init

game_app_update::
    ld a, (app_state)
    or a
    jp z, game_menu_update
    jp game_update
```

Model01 comienza en el menú. `game_menu_init` prepara texto, paleta, pantalla y
estado de selección. Al activar START, `game_menu_update` limpia el buffer de
teclado, llama a `game_init` y sólo entonces cambia a `APP_STATE_GAME`.

Un juego sin menú puede hacer que `game_app_init` salte directamente a
`game_init`.

## 3. Detección de memoria

La primera operación de una partida que pueda usar bancos debe ser:

```asm
call sys_mem_init
jr z, game_init_64k              ;; A=0, Z=1
                                  ;; A=1, Z=0: 128K
```

`sys_mem_init` delega en `sys_mem_detect`, que realiza este proceso:

1. copia el stub bancario de 19 bytes a `0x0200`;
2. guarda el byte normal usado por la prueba;
3. conecta el banco 0 mediante el stub y guarda también su byte equivalente;
4. escribe patrones diferentes en RAM normal y banco 0;
5. comprueba si las dos memorias son independientes;
6. actualiza `sys_mem_is_128k`;
7. restaura los bytes normal y bancado;
8. retorna con carry limpio y el resultado en `A/Z`.

La rutina es repetible, pero normalmente basta con llamarla una vez al iniciar
la partida. Las copias bancarias comprueban además `sys_mem_is_128k` y devuelven
carry activo en 64 KB o ante un banco inválido.

## 4. Selección de contenido

Después de detectar la capacidad, ambas rutas deben producir el mismo formato
en `SYS_MEM_STREAM_START`:

```asm
game_content_init:
    call sys_mem_init
    jr z, game_content_init_64k

game_content_init_128k:
    call game_load_bank_packages
    ret nc
    ;; Si falla el medio de carga, degradar al contenido base.

game_content_init_64k:
    jp game_build_base_package
```

La ruta de 64 KB copia o construye el contenido base. La de 128 KB carga el
paquete ampliado desde uno de los cuatro bancos. Al terminar, mapas, sprites,
scripts y listas de entidades activos deben apuntar al workspace común, nunca
a una dirección que sólo exista mientras un banco está conectado.

El cargador de imágenes bancarias desde CDT/DSK/SNA es una fase futura. No se
debe copiar al banco contenido que siga enlazado en el núcleo esperando ahorrar
memoria: ese contenido continuaría ocupando `0x4000–0x7FFF`.

## 5. Inicialización de una partida

El orden actual de `game_init` es:

```text
sys_mem_init
  -> sys_entity_init
  -> sys_input_init
  -> game_input_init
  -> sys_collision_init
  -> game_collision_init
  -> crear jugador y entidades iniciales
  -> sys_text_init
  -> sys_render_init
  -> game_map_init
  -> sys_shoot_init
  -> sys_map_draw
```

Si se usan los sistemas de estado, inventario, interacción o scripts, deben
insertarse antes de crear contenido que dependa de ellos:

```asm
game_init::
    call game_content_init          ;; incluye sys_mem_init
    call sys_state_init
    call sys_inventory_init
    call sys_script_init
    call sys_entity_init
    call sys_input_init
    call sys_interaction_init
    call sys_collision_init

    ;; Registrar callbacks antes de crear contenido interactivo.
    call game_interaction_init
    call game_collision_init

    ;; El workspace y los sistemas ya están listos.
    call game_create_room_entities
    call game_map_init
    call sys_map_draw
    ret
```

No inicialices un sistema después de crear datos que éste vaya a borrar. Por
ejemplo, `sys_entity_init` vacía el pool y `sys_state_init` borra flags y
contadores.

## 6. Entrada en una habitación

Una transición de zona o habitación no reinicia la partida completa:

```text
finalizar iteradores del frame actual
  -> seleccionar contenido base o bancado
  -> copiarlo al workspace
  -> retirar entidades temporales de la habitación anterior
  -> activar mapa y current_room
  -> crear objetos, enemigos y portales
  -> reaplicar flags persistentes
  -> dibujar el mapa
```

No cambies de zona desde dentro de un callback que todavía necesite `IX` o
`IY`. Registra una petición y aplícala después de que entrada, comportamiento o
colisión hayan retornado.

## 7. Orden del frame

Model01 ejecuta:

```text
física -> proyectiles -> transición -> entrada -> comportamientos
-> efectos -> colisiones -> animación -> preparar render
-> VSYNC -> dibujar
```

Añade `sys_script_update` después de la interacción que pueda iniciar un script
y antes de preparar el render. Las cargas bancarias completas deben hacerse en
un estado de transición, no a mitad de los recorridos de entidades.

## 8. Reinicio y vuelta al menú

Volver al menú llama a `game_menu_init`; iniciar otra partida vuelve a ejecutar
`game_init`. Por ello toda inicialización de partida debe ser idempotente:

- vaciar pools y estados transitorios;
- registrar de nuevo callbacks;
- seleccionar otra vez contenido base o ampliado;
- no asumir que los bancos conservan datos salvo que el cargador lo garantice;
- reconstruir el mundo persistente desde flags y contadores.

Consulta [Memoria para 64 y 128 KB](memory-layout.md) para el mapa de memoria y
[Recetas para crear contenido](content-cookbook.md) para crear habitaciones,
objetos, portales, scripts y enemigos.
