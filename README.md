# Model01

Model01 es un juego de plataformas para Amstrad CPC y, al mismo tiempo, un
ejemplo de un pequeño framework reutilizable escrito en ensamblador Z80 sobre
CPCtelera.

El repositorio separa deliberadamente dos capas:

- `src/sys/`: mecanismos reutilizables del framework.
- `src/game/`: reglas, contenido y flujo propios de Model01.

El arranque genérico sólo conoce `game_app_init` y `game_app_update`. Por ello,
un juego nuevo puede conservar `src/sys/` y reemplazar la capa `src/game/` sin
introducir dependencias del framework hacia el juego.

## Documentación

- [Guía del framework](docs/framework.md): arquitectura, sistemas, contratos,
  memoria y límites técnicos.
- [Tutorial para crear un juego](docs/new-game-template.md): recorrido práctico
  desde una copia del proyecto hasta entidades, mapas, controles, animación, IA
  y colisiones.
- [Recetas para crear contenido](docs/content-cookbook.md): cómo añadir objetos,
  portales, habitaciones, scripts, acciones, condiciones e interacciones.
- [Memoria para 64 y 128 KB](docs/memory-layout.md): mapa común, detección,
  bancos del 6128, fallback y carga de contenido por zonas.
- [Proceso de inicialización](docs/initialization.md): arranque del CPC,
  detección de memoria, nueva partida, carga de habitaciones y orden del frame.
- [Sistema de comportamientos](docs/behaviour-system.md): referencia detallada
  del bytecode utilizado para la IA.
- [Capa de Model01](src/game/README.md): qué contenido concreto implementa el
  juego de ejemplo.

## Compilar y probar

Es necesario tener CPCtelera y definir `CPCT_PATH` con la ruta de su
instalación:

```sh
make
make test
```

`make` genera los formatos CDT, DSK y SNA. `make test` comprueba la frontera
entre framework y juego, las declaraciones globales, configuraciones
alternativas, el límite de memoria y las reglas del motor ejecutando el código
Z80 del binario resultante en un emulador embebido de CPU.
