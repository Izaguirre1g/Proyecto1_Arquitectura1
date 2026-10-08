# Proyecto1_Arquitectura1
Arquitectura VLIW Propia para Aplicaciones de Cifrado por Bloques

## Estructura del repositorio

```
rtl/                   módulos del procesador (SystemVerilog)
  alu.sv, decoder_alu.sv         — Slot 0 (Fabricio)
  lsu.sv, decoder_lsu.sv         — Slot 1 (Alejandro)
  bru.sv, decoder_bru.sv         — Slot 2 (Alejandro)
  crypto_unit.sv (pendiente)    — Slot 3 (Dylan)
  cpu_top.sv, fetch.sv,
  pipeline_*.sv, wb.sv,
  regfile.sv, dispatch.sv        — compartidos
  instruction_memory.sv          — memoria de instrucciones
  memory.sv, pc.sv, pc_branch.sv — memoria de datos y PC
tb/                    testbenches (uno por módulo + integración)
tools/                 scripts auxiliares
  load_file.py, extract_data.py — carga/descarga de memoria
docs/                  documentación
  simulation.md                  — flujo de simulación (del equipo)
  mapa_memoria.md                — mapa de memoria 64 KB (Alejandro)
```

## Bloque LSU / BRU / Memoria (Alejandro)

Slots 1 y 2 del bundle + la memoria de datos están documentados en
[`docs/mapa_memoria.md`](docs/mapa_memoria.md). Resumen de los módulos:

- `rtl/lsu.sv` — Load/Store Unit. Implementa `guardap`, `guardab`,
  `cargai` y `cargabai` (4 instrucciones). Soporta byte-enable, store
  con desplazamiento del byte y load con sign-extension. Incluye un
  registro interno para igualar la latencia de EX→WB con la ALU.
- `rtl/bru.sv` — Branch Unit. Implementa `igualsi`, `igualno`,
  `menora`, `mayoroigual` (signed) y `sye` (jump-and-link con `rg = PC+4`).
  Emite `branch_flush` y `target_pc` para que `cpu_top.sv` invalide IF/ID
  y actualice el PC.
- `rtl/memory.sv` — Memoria de datos de 64 KB (16 384 palabras de 32
  bits). Byte-addressable, little-endian, lectura combinacional.
- `rtl/pc_branch.sv` — PC con soporte para flush (carga `target_pc`
  cuando el BRU toma un branch).
- `rtl/decoder_lsu.sv`, `rtl/decoder_bru.sv` — decodificadores
  combinacionales de los slots 1 y 2.

Los 5 testbenches asociados (`tb_lsu.sv`, `tb_bru.sv`,
`tb_decoder_lsu.sv`, `tb_decoder_bru.sv`, `tb_memory.sv`) están
autoverificados y pasan con `make sim`.

## Herramientas de memoria (`tools/`)

### `load_file.py`

Carga un archivo `.bin` o `.hex` en una imagen de memoria compatible
con `$readmemh` de Verilog. Útil para inicializar la memoria de
instrucciones o de datos antes de la simulación.

```bash
# Cargar un programa a partir de la dirección 0x0
python tools/load_file.py programa.bin --base 0x0 --output build/prog.mem

# Cargar datos pre-inicializados en el segmento de datos (gp = 0x4000)
python tools/load_file.py datos.hex --base 0x4000 --output build/data.mem

# Imagen completa de 64 KB con un byte por línea
python tools/load_file.py imagen.bin --size 65536 --word-width 8
```

Luego, en Verilog:

```systemverilog
initial $readmemh("build/prog.mem", memory);
```

### `extract_data.py`

Saca un rango de la imagen de memoria (por ejemplo, el resultado de un
cifrado) en formato `.bin` o `.hex`.

```bash
# 256 bytes a partir de 0x4000, en binario
python tools/extract_data.py build/data.mem --base 0x4000 --size 256 \
       --format bin --output out.bin

# Hex por stdout (default)
python tools/extract_data.py build/data.mem --base 0x0 --size 16
```

## Simulación

### Requisitos

- [Icarus Verilog](https://steveicarus.github.io/iverilog/) 12 o superior (`iverilog` y `vvp`)
- GNU make y bash
- GTKWave (opcional, para ver las ondas)

En Ubuntu o WSL:

```bash
sudo apt install iverilog gtkwave make
```

En Windows (winget):

```powershell
winget install Icarus.Verilog
```

### Uso

Desde la raíz del repositorio:

```bash
make sim                # compila y ejecuta todos los testbenches de tb/ y muestra un resumen
make tb_alu             # ejecuta un solo testbench
make waves TB=tb_alu    # abre en GTKWave el .vcd de ese testbench
make list               # lista los testbenches
make clean              # borra build/
```

Cada testbench genera su log y su `.vcd` en `build/<testbench>/`. Los testbenches autoverificables
terminan con `[PASS]` o `[FAIL]`, y `make sim` falla si alguno falla o no compila.

El detalle del flujo de simulación, el formato estándar de testbench y el modelo del banco de
registros están en [docs/simulation.md](docs/simulation.md).

### Ejemplo: programa mínimo

Un programa `.hex` que escribe `0xDEADBEEF` en la dirección `0x4000`:

```
# build/prog.hex
0x12345000 0x00400023   # sumai rg, gp, 0    (rg = 0x4000)
0x12345001 0xDEADBEEF   # sumai rg, rg, 1    (rg = 0xDEADBEEF, ojo al byte-enable)
...
```

```bash
python tools/load_file.py build/prog.hex --base 0x0 --output build/prog.mem
make sim TB=tb_cpu_top   # corre el programa
python tools/extract_data.py build/data.mem --base 0x4000 --size 4
```
