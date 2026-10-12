# Proyecto1_Arquitectura1
Arquitectura VLIW Propia para Aplicaciones de Cifrado por Bloques

## Estructura del repositorio

```
rtl/                   módulos del procesador (SystemVerilog)
  alu.sv, decoder_alu.sv         — Slot 0 (Fabricio)
  lsu.sv, decoder_lsu.sv         — Slot 1 (Alejandro)
  bru.sv, decoder_bru.sv         — Slot 2 (Alejandro)
  crypto_unit.sv, key_vault.sv,
  decoder_crypto.sv              — Slot 3 (cripto y bóveda)
  top.sv, fetch.sv,
  pipeline_*.sv, wb.sv,
  regfile.sv, dispatch.sv        — compartidos
  isa_defs.sv                    — códigos del ISA y parámetros (bundle, memorias)
  instruction_memory.sv          — memoria de instrucciones (+IMEM=programa.mem)
  memory.sv, pc_branch.sv        — memoria de datos y PC
tb/                    testbenches de make sim (uno por módulo + integración)
tests/                 pruebas del ensamblador (Python) y testbenches que usan las herramientas (tests/rtl/)
tools/                 scripts auxiliares
  assembler.py, run_program.py   — ensamblador y ejecución de programas
  bundle_linear.py, run_ce1108.py — adaptador y prueba de la salida del compilador de CE1108
  load_file.py, extract_data.py — carga/descarga de memoria
examples/              programas de ejemplo (.asm) y archivos de prueba
docs/                  documentación
  isa.md                         — especificación del ISA y green card
  microarchitecture.md           — organización interna: diagrama de bloques y pipeline
  simulation.md                  — flujo de simulación (del equipo)
  assembler.md                   — sintaxis del ensamblador (Javier)
  compiler-integration.md        — integración con el compilador de CE1108 (Javier)
  mapa_memoria.md                — mapa de memoria 64 KB (Alejandro)
img/                   diagrama de organización (lo usa docs/microarchitecture.md)
```

## Bloque LSU / BRU / Memoria (Alejandro)

Slots 1 y 2 del bundle + la memoria de datos están documentados en
[`docs/mapa_memoria.md`](docs/mapa_memoria.md). Resumen de los módulos:

- `rtl/lsu.sv` — Load/Store Unit. Implementa `guardap`, `guardab`,
  `cargai` y `cargabai` (4 instrucciones). Soporta byte-enable, store
  con desplazamiento del byte y load con sign-extension. Incluye un
  registro interno para igualar la latencia de EX→WB con la ALU.
- `rtl/bru.sv` — Branch Unit. Implementa `igualsi`, `igualno`,
  `menora`, `mayoroigual` (signed), `sye` (jump-and-link con `rg = PC + 16`)
  y `syer` (salta a la dirección de un registro; `syer x0, ra, 0` vuelve de una subrutina).
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
`make sim` y son autoverificables (ver [docs/simulation.md](docs/simulation.md)).

## Herramientas de memoria (`tools/`)

### `load_file.py`

Carga un archivo de cualquier formato (texto, imágenes, binarios) en una
imagen de memoria compatible con `$readmemh` de Verilog. Sólo los `.hex`
se interpretan como texto hexadecimal. Se usa para la memoria de datos de 32 bits.
Para la IMEM de bundles de 128 bits se usa `tools/assembler.py`.

```bash
# Cargar datos a partir de la dirección 0x0
python3 tools/load_file.py --input datos.bin --address 0x0 --output build/datos.mem

# Cargar datos pre-inicializados en el segmento de datos (gp = 0x4000)
python3 tools/load_file.py --input datos.hex --address 0x4000 --output build/data.mem

# Imagen completa de 64 KB con un byte por línea (no sirve para memory.sv,
# que lee palabras de 32 bits)
python3 tools/load_file.py --input imagen.bin --output build/imagen.mem --address 0x0 --size 65536 --word-width 8
```

Luego, en el testbench (como hace `tests/rtl/tb_archivo.sv`; la ruta es relativa a
la carpeta donde corre `vvp`):

```systemverilog
initial $readmemh("datos.mem", DUT.DMEM.mem);
```

### `extract_data.py`

Saca un rango de la imagen de memoria (por ejemplo, el resultado de un
cifrado) en formato `.bin` o `.hex`.

```bash
# 256 bytes a partir de 0x4000, en binario
python3 tools/extract_data.py --memory build/data.mem --address 0x4000 --size 256 \
       --format bin --output out.bin

# Hex por stdout (default)
python3 tools/extract_data.py --memory build/data.mem --address 0x0 --size 16
```

## Simulación

### Requisitos

- [Icarus Verilog](https://steveicarus.github.io/iverilog/) 12 o superior (`iverilog` y `vvp`)
- GNU make y bash
- GTKWave (opcional, para ver las ondas)

En Ubuntu o WSL:

```bash
sudo apt install python3 iverilog gtkwave make
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
make archivo            # cifra y descifra examples/archivos/mensaje.txt en el procesador
make archivo ARCHIVO=foto.bmp   # lo mismo con cualquier archivo (hasta 65024 bytes)
make clean              # borra build/
```

Para ejecutar un programa `.asm` en el procesador se usa `tools/run_program.py`
(ver [Ensamblador y pruebas de programas](#ensamblador-y-pruebas-de-programas-javier)):
lo ensambla, lo carga en la memoria de instrucciones, lo simula y muestra los
registros. Por ejemplo, con el programa que usa las 4 unidades:

```bash
python3 tools/run_program.py --input examples/mixto.asm --cycles 60
```

`make archivo` ensambla `examples/cifrar_archivo.asm` y `examples/descifrar_archivo.asm`,
carga el archivo con `load_file.py`, lo cifra y lo descifra en el procesador
(`tests/rtl/tb_archivo.sv`) y deja en `build/archivo/` el `cifrado.bin` y el
`descifrado.bin` extraídos con `extract_data.py`. Termina con `[PASS]` si el
descifrado es idéntico al original.

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
python3 tools/run_program.py --input examples/subrutina.asm \
  --expect examples/subrutina.expected.json --cycles 60
python3 tools/run_program.py --input examples/mixto.asm --cycles 60
```

El runner carga la IMEM, ejecuta `top` y compara registros/memoria.
Imprime los registros distintos de 0 y, con `--expect` (y `--expect-memory`),
termina en error si algún valor no coincide. Para un programa propio basta
escribir su `.asm` (sintaxis en [docs/assembler.md](docs/assembler.md)) y, si se
quiere comprobar el resultado, un `.json` como `examples/alu_isa.expected.json`
con los registros esperados (`{"x5": 50}`).
Deja logs, dumps y ondas en `build/program_<nombre>/`. Admite hasta
`IMEM_BUNDLES - 4` bundles (1020) para reservar el vaciado del pipeline. Los programas con saltos deben terminar
en un bucle estable; `--cycles` fija el momento de comprobar el resultado.

`examples/mixto.asm` incluye un bundle con ALU, LSU, BRU y cripto y usa las 6
instrucciones cripto, y `examples/subrutina.asm` llama dos veces a una función
con `sye` y vuelve con `syer`; `make test-programs` ejecuta estos y los demás
ejemplos sobre el RTL. Los comandos para probar
la salida real del generador CE1108 están en
[docs/compiler-integration.md](docs/compiler-integration.md).

## Integración con CE1108 y resultados

El ensamblador de Arquitectura es autónomo; no requiere el compilador para
probar instrucciones ni ejecutar los programas de `examples/`.
La prueba del generador de CE1108 puede reproducirse con:

```bash
python3 tools/run_ce1108.py --input examples/ce1108.linear
```

Resultado: `[PASS] expresión CE1108: (8 + 3) - 1 = 10`. Se generan ensamblador,
binario, hexadecimal, listado y logs en `build/ce1108/`. El testbench inicializa
los datos de entrada: esta prueba corresponde a una expresión del generador,
no a un programa completo compilado mediante la CLI.

En Ubuntu con Icarus Verilog 12.0 se confirmaron el 11 de octubre de 2026:
`make test-assembler` (38 pruebas correctas), `make test-programs` (14 pruebas
correctas) y `make sim` (21 PASS, sin fallos ni testbenches sin comprobación).
El contrato, los pasos para regenerar la entrada con CE1108 y el alcance de
la evidencia están en [docs/compiler-integration.md](docs/compiler-integration.md).


### Programa de CE1108 desde fuente

Para ejecutar `examples/ce1108_programa.bal` desde su fuente, usando los módulos
del repositorio de Compiladores en `feat-analisis-semantico`:

```bash
sudo apt install build-essential flex uthash-dev
make ce1108-source CE1108_ROOT="../Proyecto-Parte-1-Compiladores-e-Interpretes-Definici-n-de-Sintaxis-de-Lenguaje"
make test-ce1108-source CE1108_ROOT="../Proyecto-Parte-1-Compiladores-e-Interpretes-Definici-n-de-Sintaxis-de-Lenguaje"
```

El programa inicializa gp y las variables, genera binario y se ejecuta sobre
el RTL. Debe terminar con PASS: a=8, b=3, r=10 y valido=1 en memoria.
Fuente, código generado, logs, evidencia y ondas quedan en `build/ce1108_fuente/`.
La prueba admite una función main lineal con declaraciones y asignaciones;
los límites se explican en `docs/compiler-integration.md`. Ajusta CE1108_ROOT
si tu copia de Compiladores tiene otra carpeta. Esta herramienta no modifica
los módulos ni la CLI del repositorio de Compiladores.
