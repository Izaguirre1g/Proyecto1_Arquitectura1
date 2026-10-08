# Mapa de memoria — Procesador VLIW

> Documento mantenido por **Alejandro (CE-4301, II Semestre 2026)**.
> Última revisión: 7 de octubre de 2026.

Este mapa aplica a los dos espacios direccionables del procesador:

- **Memoria de instrucciones** (`rtl/instruction_memory.sv`) — tamaño **32 paquetes**
  (128 instrucciones / 512 bytes) por defecto. Es modificable por parámetro.
  La usa el módulo `fetch` para traer el bundle de 128 bits cada ciclo.
- **Memoria de datos** (`rtl/memory.sv`) — tamaño **64 KB** (16 384 palabras de
  32 bits, byte-addressable, little-endian). Es donde opera la LSU.

El PC se incrementa de a 16 (un bundle por ciclo) y se mide en bytes, así
que las direcciones del diagrama son direcciones **byte** aunque el bus de
instrucciones sea de 128 bits por bundle.

## 1. Mapa propuesto

| Rango              | Tamaño  | Uso propuesto                                          | Notas |
|-------------------|---------|--------------------------------------------------------|-------|
| `0x0000 – 0x00FF` | 256 B   | Vector de arranque / código de boot                    | Convención de la familia RISC-V; útil al portar un BIOS mínimo. |
| `0x0100 – 0x3FFF` | ~16 KB  | Programa principal                                     | Donde va el cuerpo del programa. |
| `0x4000 – 0x7FFF` | 16 KB   | Datos globales (`gp = 0x4000`)                         | Direccionamiento relativo a `gp`. |
| `0x8000 – 0xFFFF` | 32 KB   | Stack (`sp`) y heap                                    | El stack crece hacia abajo; el heap hacia arriba. |

> **Decisión del equipo (a confirmar)**: estos rangos se eligieron para
> seguir la convención RISC-V de puntero global. Si el ensamblador del equipo
> usa otra distribución, sobreescribir este archivo.

## 2. Mapa de registros

| Registro | Uso                                       | Notas                              |
|----------|-------------------------------------------|------------------------------------|
| `x0`     | Cero cableado                             | Cualquier escritura se ignora.     |
| `x1`     | `ra` — link register (`sye`)             | También libre si no hay saltos.    |
| `x2`     | `sp` — stack pointer                    | Crece hacia abajo.                 |
| `x3`     | `gp` — global pointer (`= 0x4000`)      | Base para direccionamiento.        |
| `x4..x7` | Temporales                               |                                    |
| `x8..x15`| Salvos por convención                    | El software debe preservarlos.    |
| `x16..x31`| Temporales del programador              |                                    |

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

- `bundle N`: produce `x3` con `sumai x3 = x1 + 4`
- `bundle N+1`: NOP (o independiente de `x3`)
- `bundle N+2`: NOP (o independiente de `x3`)
- `bundle N+3`: puede consumir `x3` con cualquier instrucción

Las instrucciones LSU son un poco más lentas: el dato leído en EX pasa
por el registro interno de la LSU en `lsu.sv` y se escribe en WB en el
siguiente ciclo. **Por consistencia se las trata como cualquier otra**:
el dato escrito lo puede leer el bundle N+3.

## 4. Saltos y estrategia de flush

- Los saltos condicionales (`igualsi`, `igualno`, `menora`, `mayoroigual`)
  evalúan en **EX** y, cuando se toman, invalidan los dos bundles que
  están en **IF** e **ID**. Penalización: 2 ciclos (no hay delay slot).
- El jump `sye` siempre flushea IF e ID y carga el PC con el offset
  firmado de 16 bits.
- Sin forwarding: el `rg = PC + 4` de `sye` se escribe en WB junto con
  el bundle siguiente a la instrucción.

Más detalles en [`docs/interfaces.md`](./interfaces.md) (cuando esté
disponible) y en el comentario de `rtl/bru.sv`.

## 5. Formato del archivo `.mem`

`tools/load_file.py` produce archivos `.mem` compatibles con
`$readmemh` de Verilog. Cada línea contiene:

- **palabra de 32 bits** (default) little-endian: 8 caracteres hex,
  uno por bundle de 4 bytes.
- **byte individual** (`--word-width 8`): 2 caracteres hex, uno por
  byte.

Ejemplo — un programa mínimo que escribe 0xDEADBEEF en la dirección
`0x4000`:

```
# Comentario
0xCAFEBABE 0x12345678 0x11223344 0x55667788
```

Cargado con:

```
python tools/load_file.py programa.hex --base 0x1000 --size 65536 \
       --output build/prog.mem
```

## 6. Herramientas asociadas

- **`tools/load_file.py`**: convierte `.bin` o `.hex` a `.mem`.
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
  a byte, pero `memory.sv` espera palabras de 32 bits con byte-enable.
  Si se carga con `--word-width 8`, el banco de 32 bits sigue
  funcionando porque `memory.sv` decodifica con `addr[9:2]`.
- El límite mínimo de tamaño es **64 KB** según el enunciado. El
  `memory.sv` lo respeta por default (`SIZE_WORDS = 16384`). Si se
  quiere reducir para acelerar la verificación, hay un parámetro
  `SIZE_WORDS` que se puede sobreescribir desde `cpu_top`.