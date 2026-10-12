# Mapa de memoria — Procesador VLIW

> Documento mantenido por **Alejandro (CE-4301, II Semestre 2026)**.
> Última revisión: 11 de octubre de 2026.

Este mapa aplica a los dos espacios direccionables del procesador:

- **Memoria de instrucciones** (`rtl/instruction_memory.sv`) — tamaño **1024 bundles**
  (16 KB, `IMEM_BUNDLES` en `rtl/isa_defs.sv`). El programa se carga con
  `+IMEM=programa.mem`. El último bundle (`0x3FF0`, `TRAP_VECTOR`) es el
  manejador de excepciones. La usa el módulo `fetch` para traer el bundle de
  128 bits cada ciclo.
- **Memoria de datos** (`rtl/memory.sv`) — tamaño **64 KB** (16 384 palabras de
  32 bits, byte-addressable, little-endian). Es donde opera la LSU.

El PC se incrementa de a 16 (un bundle por ciclo) y se mide en bytes, así
que las direcciones del diagrama son direcciones **byte** aunque el bus de
instrucciones sea de 128 bits por bundle.

Son dos espacios separados: el PC sólo direcciona la memoria de instrucciones
y la LSU (y `vcr`/`camcon`) sólo la memoria de datos, así que la misma
dirección numérica no se refiere a la misma memoria en los dos casos.

## 1. Mapa propuesto

Memoria de instrucciones:

| Rango              | Tamaño  | Uso                                                    |
|-------------------|---------|--------------------------------------------------------|
| `0x0000 – 0x3FE0` | 1023 bundles | Programa. Después del reset el PC empieza en `0x0000`. |
| `0x3FF0`          | 1 bundle | Manejador de excepciones (`TRAP_VECTOR`).             |

Memoria de datos:

| Rango              | Tamaño  | Uso propuesto                                          | Notas |
|-------------------|---------|--------------------------------------------------------|-------|
| `0x0000 – 0x3FFF` | 16 KB   | Libre                                                  | `make archivo` usa `0x100`–`0x11F` para la contraseña, la llave y el fin, y carga el archivo desde `0x200`. |
| `0x4000 – 0x7FFF` | 16 KB   | Datos globales (`gp = 0x4000`)                         | Direccionamiento relativo a `gp`. |
| `0x8000 – 0xFFFF` | 32 KB   | Stack (`sp`) y heap                                    | El stack crece hacia abajo; el heap hacia arriba. |

> **Decisión del equipo (a confirmar)**: estos rangos se eligieron para
> seguir la convención RISC-V de puntero global. Si el ensamblador del equipo
> usa otra distribución, sobreescribir este archivo.

## 2. Mapa de registros

Es el ABI de [`isa.md`](isa.md) (sección "Registros de propósito general"),
el mismo que usan los alias del ensamblador.

| Registro | Uso                                       | Notas                              |
|----------|-------------------------------------------|------------------------------------|
| `x0`     | Cero cableado                             | Cualquier escritura se ignora.     |
| `x1`     | `ra` — link register (`sye`, `ret`)      | También libre si no hay saltos.    |
| `x2`     | `sp` — stack pointer                    | Crece hacia abajo.                 |
| `x3`     | `gp` — global pointer (`= 0x4000`)      | Base para direccionamiento.        |
| `x4..x15` | `t0..t11` — temporales                  | No se preservan entre llamadas.    |
| `x16..x31`| `s0..s15` — preservados                 | El llamado los guarda si los usa.  |

## 3. Dependencias entre bundles

El banco de registros (`rtl/regfile.sv`) **no tiene bypass**. Sin
forwarding ni scoreboarding, la única forma de respetar las dependencias
es insertar **dos bundles independientes** (o NOPs) entre un productor y
un consumidor.

Concretamente:

> El valor que escribe el bundle **N** lo puede leer en ID el bundle
> **N+3** o uno posterior. Los bundles N+1 y N+2 todavía leen el valor
> anterior.

Reglas prácticas para el programador:

- `bundle N`: produce `x5` con `sumai x5, x4, 4`
- `bundle N+1`: NOP (o independiente de `x5`)
- `bundle N+2`: NOP (o independiente de `x5`)
- `bundle N+3`: puede consumir `x5` con cualquier instrucción

Las cargas siguen la misma regla: el dato leído en EX pasa por el registro
interno de `lsu.sv`, que cumple el papel del registro EX/WB, y se escribe en
el mismo ciclo que el resultado de la ALU. El valor cargado lo puede leer el
bundle N+3.

## 4. Saltos y estrategia de flush

- Los saltos condicionales (`igualsi`, `igualno`, `menora`, `mayoroigual`)
  evalúan en **EX** y, cuando se toman, invalidan los dos bundles que
  están en **IF** e **ID**. Penalización: 2 ciclos (no hay delay slot).
- El jump `sye` siempre flushea IF e ID y carga el PC con el offset
  firmado de 16 bits. `syer` hace lo mismo, pero el PC pasa a ser
  `rf1 + offset` con los 4 bits bajos en 0 (`syer x0, ra, 0` = `ret`).
- Sin forwarding: el enlace `rg = PC + 16` de `sye` y `syer` se escribe en
  WB; el bundle destino ya puede leerlo, porque los 2 bundles anulados
  cubren esa latencia.

Más detalles en [`docs/simulation.md`](./simulation.md) (sección 6) y en
el comentario de `rtl/bru.sv`.

## 5. Formato del archivo `.mem`

`tools/load_file.py` produce archivos `.mem` compatibles con
`$readmemh` de Verilog. Cada línea contiene:

- **palabra de 32 bits** (default) little-endian: 8 caracteres hex,
  una línea por palabra de 4 bytes. Es el formato de `memory.sv`.
- **byte individual** (`--word-width 8`): 2 caracteres hex, uno por
  byte.

Ejemplo: un archivo `datos.hex` con cuatro palabras, cargado en la
dirección `0x1000` de la memoria de datos:

```
# Comentario
0xCAFEBABE 0x12345678 0x11223344 0x55667788
```

```
python3 tools/load_file.py --input datos.hex --output build/datos.mem \
       --address 0x1000 --size 65536
```

En un `.hex`, un valor menor o igual a `0xFF` se toma como un solo byte y
uno mayor como una palabra de 4 bytes. Cualquier otro archivo (`.txt`,
`.bin`, imágenes) se carga byte por byte.

## 6. Herramientas asociadas

- **`tools/load_file.py`**: convierte cualquier archivo a `.mem` (los
  `.hex` se leen como texto hexadecimal).
- **`tools/extract_data.py`**: extrae un rango del `.mem` a `.bin` o
  `.hex`.
- **`rtl/memory.sv`**: la memoria de datos (lectura combinacional,
  64 KB).
- **`rtl/lsu.sv`**: la Load/Store Unit (4 instrucciones,
  guardap/guardab/cargai/cargabai).

## 7. Pendientes / Notas

- Confirmar con el equipo si la convención RISC-V (`gp = 0x4000`) se
  mantiene o se cambia por algo más simple (por ejemplo, todo el
  rango `0x0000 – 0xFFFF` como un único segmento plano).
- El `load_file.py` soporta `--word-width 8` para memorias orientadas
  a byte, pero `memory.sv` guarda palabras de 32 bits: `$readmemh` pondría
  cada byte en una palabra distinta. Para `memory.sv` hay que usar el
  formato de 32 bits (el default).
- El límite mínimo de tamaño es **64 KB** según el enunciado. `top`
  instancia `memory.sv` con `SIZE_WORDS = DMEM_BYTES / 4`, y `DMEM_BYTES`
  (65536) está en `rtl/isa_defs.sv`; para cambiar el tamaño se cambia ahí.