# Memoria común para juegos de 64 y 128 KB

El ejecutable utiliza siempre el mismo núcleo de 64 KB. En un CPC 6128, los
64 KB adicionales se tratan como almacenamiento de contenido y se copian a una
zona de trabajo común antes de utilizarlos. De esta forma, sistemas, entidades
y render no necesitan dos implementaciones.

## Mapa común de 64 KB

| Rango | Tamaño | Uso |
|---|---:|---|
| `0x0000–0x003F` | 64 B | Vectores RST e interrupción IM1 |
| `0x0040–0x00FF` | 192 B | Reservado |
| `0x0100–0x01FF` | 256 B | Tabla de transparencia |
| `0x0200–0x0212` | 19 B | Stub seguro de copia bancaria |
| `0x0213–0x0214` | 2 B | Patrón y copia temporal de detección |
| `0x0215–0x02FF` | 235 B | RAM baja libre |
| `0x0300–0x0EB7` | 3000 B | Fondo de ventanas de mensajes |
| `0x0EB8–0x3FFF` | 12 616 B | Workspace de contenido activo |
| `0x4000–0x7FFF` | 16 KB | Código/datos y ventana bancaria |
| `0x8000–0xBFFF` | 16 KB | Back buffer reservado y pila cerca de `0xBFxx` |
| `0xC000–0xFFFF` | 16 KB | Pantalla frontal |

Las constantes correspondientes están en `src/sys/mem.h.s`. El juego puede
subdividir `SYS_MEM_STREAM_START..SYS_MEM_STREAM_START+SYS_MEM_STREAM_SIZE`,
por ejemplo:

```text
0x0EB8  mapa activo
0x1100  descriptores y lista de entidades
0x1400  scripts de la zona
0x1800  sprites intercambiables
```

Las direcciones concretas dependen del tamaño máximo de cada paquete. Deben
declararse en un único fichero de configuración del juego y verificarse en
ensamblado para evitar solapamientos.

## Memoria adicional del 6128

El 6128 proporciona cuatro bancos extra de 16 KB. Cada uno aparece
temporalmente en `0x4000–0x7FFF`:

| Banco lógico | Configuración Gate Array | Dirección visible |
|---:|---:|---|
| 0 | `0xC4` | `0x4000–0x7FFF` |
| 1 | `0xC5` | `0x4000–0x7FFF` |
| 2 | `0xC6` | `0x4000–0x7FFF` |
| 3 | `0xC7` | `0x4000–0x7FFF` |

El código normal también reside en esa ventana. Por tanto, no se ejecutan
rutinas ni se consumen sprites directamente desde un banco conectado. El stub
de `0x0200` conecta el banco, copia y restaura la configuración normal bajo
`DI/EI`.

## Detectar la capacidad

Llama una vez durante el arranque:

```asm
call sys_mem_init              ;; instala el stub y detecta memoria
jr z, game_start_64k           ;; A=0, Z=1
                               ;; A=1, Z=0: 128K disponible
```

También se puede repetir sólo la detección:

```asm
call sys_mem_detect
jr z, game_use_base_assets
jr game_use_banked_assets
```

Ambas entradas actualizan `sys_mem_is_128k`:

```asm
ld a, (sys_mem_is_128k)
or a
jr z, game_use_base_assets
```

`sys_mem_detect` restaura tanto el byte normal como el byte de banco 0
utilizados por la prueba, por lo que puede llamarse más de una vez sin alterar
paquetes ya cargados. El resultado es:

| Máquina | A | Z | Carry |
|---|---:|---:|---:|
| 64 KB | 0 | 1 | 0 |
| 128 KB | 1 | 0 | 0 |

## Modelo de contenido con fallback

Cada zona debe tener una versión base accesible en 64 KB y, opcionalmente, un
paquete ampliado en banco:

```text
Descriptor de zona
  mapa base o generador base
  lista de entidades base
  banco del paquete ampliado
  offset y tamaño de mapa
  offset y tamaño de sprites
  offset y tamaño de scripts
```

Flujo recomendado:

```text
solicitar zona
  -> comprobar sys_mem_is_128k
  -> 64K: construir/copiar contenido base al workspace
  -> 128K: copiar paquete bancado al mismo workspace
  -> crear entidades y corregir punteros
  -> aplicar flags persistentes
  -> activar mapa y dibujar
```

Después de la carga, el resto del motor sólo conoce el workspace. Esta es la
propiedad que permite mantener un único código para ambas capacidades.

## Copias seguras

Desde un banco hacia RAM común:

```asm
ld a, #1                         ;; banco 1
ld hl, #0x4000                  ;; origen dentro del banco
ld de, #SYS_MEM_STREAM_START    ;; fuera de la ventana
ld bc, #ROOM_PACKAGE_SIZE
call sys_mem_copy_from_bank
jr c, game_use_base_assets      ;; 64K o banco inválido
```

Desde RAM común hacia un banco:

```asm
ld a, #1
ld hl, #SYS_MEM_STREAM_START
ld de, #0x4000
ld bc, #ROOM_PACKAGE_SIZE
call sys_mem_copy_to_bank
jr c, game_handle_no_bank
```

Las dos rutinas rechazan bancos fuera de `0..3` y máquinas de 64 KB. No llames
directamente a `sys_mem_bank_in` desde el código actual: al conectar el banco,
la propia rutina desaparece de `0x4000–0x7FFF`.

## Contenido apropiado para bancos

Buenos candidatos:

- tilemaps y listas de entidades;
- píxeles de sprites intercambiables;
- scripts de evento y diálogos;
- música, efectos y datos de cinemáticas.

Mantén en el núcleo común:

- código ejecutable y callbacks;
- estado persistente, inventario y pool de entidades;
- descriptores que necesiten punteros absolutos, o reconstrúyelos tras copiar;
- contenido mínimo requerido por la versión de 64 KB.

Los punteros almacenados dentro de un paquete no deben apuntar a direcciones del
banco después de desconectarlo. Usa offsets relativos o reconstruye las tablas
para que apunten al workspace.

## Carga desde CDT/DSK/SNA

El API resuelve la conmutación y las copias en ejecución, pero el proyecto aún
necesita una fase de empaquetado/carga para introducir datos externos en los
cuatro bancos. Copiar al inicio datos que ya están enlazados en el núcleo no
reduce el tamaño de éste.

La ampliación completa debe generar imágenes de banco, cargarlas desde disco o
incluirlas en el snapshot y producir una tabla `{banco, offset, tamaño}`. Esa
tabla será la entrada del futuro gestor de zonas.

El orden en que se detecta la capacidad, se selecciona el contenido y se
prepara cada sistema se describe en
[Proceso de inicialización](initialization.md).
