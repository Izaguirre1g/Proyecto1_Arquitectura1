# Proyecto1_Arquitectura1
Arquitectura VLIW Propia para Aplicaciones de Cifrado por Bloques

## Estructura del repositorio

```
rtl/                   módulos del procesador (SystemVerilog)
  alu.sv, decoder_alu.sv         — Slot 0 (Fabricio)
  lsu.sv, decoder_lsu.sv         — Slot 1 (Alejandro)
  bru.sv, decoder_bru.sv         — Slot 2 (Alejandro)
  crypto_unit.sv (pendiente)    — Slot 3 (Dylan)
  top.sv, fetch.sv,
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
  Emite `branch_flush` y `target_pc` para que `top.sv` invalide IF/ID
  y actualice el PC.
- `rtl/memory.sv` — Memoria de datos de 64 KB (16 384 palabras de 32
  bits). Byte-addressable, little-endian, lectura combinacional.
- `rtl/pc_branch.sv` — PC con soporte para flush (carga `target_pc`
  cuando el BRU toma un branch).
- `rtl/decoder_lsu.sv`, `rtl/decoder_bru.sv` — decodificadores
  combinacionales de los slots 1 y 2.

Los 5 testbenches asociados (`tb_lsu.sv`, `tb_bru.sv`,
`tb_decoder_lsu.sv`, `tb_decoder_bru.sv`, `tb_memory.sv`) se ejecutan con
`make sim`. Ver el resultado actual en `docs/compiler-integration.md`.

## Herramientas de memoria (`tools/`)

### `load_file.py`

Carga un archivo `.bin` o `.hex` en una imagen de memoria compatible
con `$readmemh` de Verilog. Se usa para la memoria de datos de 32 bits.
Para la IMEM de bundles de 128 bits se usa `tools/assembler.py`.

```bash
# Cargar datos a partir de la dirección 0x0
python3 tools/load_file.py datos.bin --base 0x0 --output build/datos.mem

# Cargar datos pre-inicializados en el segmento de datos (gp = 0x4000)
python tools/load_file.py datos.hex --base 0x4000 --output build/data.mem

# Imagen completa de 64 KB con un byte por línea
python tools/load_file.py imagen.bin --size 65536 --word-width 8
```

Luego, en Verilog:

```systemverilog
initial $readmemh("build/datos.mem", DMEM.mem);
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

## Ensamblador y pruebas de programas (Javier)

Requiere Python 3.10 o posterior. Los bundles se escriben en orden
`ALU | LSU | BRU | CRIPTO`. Sintaxis y campos en [docs/assembler.md](docs/assembler.md).

```bash
make test-assembler
python3 tools/assembler.py --input examples/alu_isa.asm \
  --output build/alu.mem --binary build/alu.bin --listing build/alu.lst
python3 tools/run_program.py --input examples/alu_isa.asm \
  --expect examples/alu_isa.expected.json
python3 tools/run_program.py --input examples/lsu_isa.asm \
  --expect examples/lsu_isa.expected.json --expect-memory examples/lsu_isa.memory.json --cycles 80
python3 tools/run_program.py --input examples/bru_isa.asm \
  --expect examples/bru_isa.expected.json --cycles 80
```

El runner carga la IMEM, ejecuta `top` y compara registros/memoria.
Deja logs, dumps y ondas en `build/program_<nombre>/`. Admite hasta 28 bundles
para reservar el vaciado del pipeline. Los programas con saltos deben terminar
en un bucle estable; `--cycles` fija el momento de comprobar el resultado.

`examples/mixto.asm` incluye un bundle con ALU, LSU, BRU y cripto. El ensamblador
lo acepta, pero el runner rechaza cripto hasta que esté conectada en `top`.
Las pruebas de codificación pasan; **la ejecución de los programas todavía
falla en la rama base `ba1b49e`**. Los fallos y los comandos para probar la
salida real del generador CE1108 están en
[docs/compiler-integration.md](docs/compiler-integration.md).
