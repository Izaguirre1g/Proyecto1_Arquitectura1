# Simulación

Este documento describe cómo se simula el procesador VLIW, el formato estándar de los testbenches y
el modelo del banco de registros, del writeback y de la ALU.

## Contenido

1. [Herramientas](#1-herramientas)
2. [Estructura del repositorio](#2-estructura-del-repositorio)
3. [Cómo ejecutar las simulaciones](#3-cómo-ejecutar-las-simulaciones)
4. [Flujo de compilación](#4-flujo-de-compilación)
5. [Formato estándar de testbench](#5-formato-estándar-de-testbench)
6. [Banco de registros (`regfile`)](#6-banco-de-registros-regfile)
7. [Writeback (`wb`)](#7-writeback-wb)
8. [ALU (`alu`)](#8-alu-alu)
9. [Testbenches y cobertura](#9-testbenches-y-cobertura)
10. [Pendientes](#10-pendientes)

## 1. Herramientas

| Herramienta | Versión probada | Uso |
|:---|:---|:---|
| Icarus Verilog (`iverilog`, `vvp`) | 12.0 | Simulador del proyecto (SystemVerilog con `-g2012`). |
| GTKWave | 3.3.116 | Visualización de los `.vcd`. |
| GNU make | 4.3 | `make sim` y un target por testbench. |
| bash | 5 | Shell que usa el Makefile. |

Instalación en Ubuntu o WSL:

```bash
sudo apt install iverilog gtkwave make
```

Verilator todavía no está soportado (ver [Pendientes](#10-pendientes)).

## 2. Estructura del repositorio

```
rtl/                 módulos SystemVerilog del procesador
tb/                  testbenches (tb_<modulo>.sv) y tb_utils.svh
docs/                documentación (este archivo)
build/               generado por make (.gitignore)
  <testbench>/
    sim.vvp          ejecutable de Icarus
    compile.log      salida de iverilog (sólo con make sim)
    sim.log          salida de la simulación
    *.vcd            ondas para GTKWave
Makefile
```

## 3. Cómo ejecutar las simulaciones

Desde la raíz del repositorio:

| Comando | Qué hace |
|:---|:---|
| `make sim` | Compila y ejecuta todos los `tb/tb_*.sv` y muestra un resumen. |
| `make tb_alu` | Compila (sólo si cambió algo) y ejecuta un testbench, mostrando su salida. |
| `make waves TB=tb_alu` | Abre en GTKWave el `.vcd` de ese testbench. |
| `make list` | Lista los testbenches disponibles. |
| `make clean` | Borra `build/`. |
| `make help` | Muestra la ayuda. |


Ejemplo de salida de `make sim`:

```
Simulando 14 testbenches con Icarus Verilog version 12.0 (stable) ()
  PASS         tb_alu
  SIN-CHEQUEO  tb_cpu_alu_path
  ...
  PASS         tb_regfile
  PASS         tb_regfile_pipeline
  PASS         tb_wb
Resumen: 4 PASS, 0 FAIL, 0 NO-COMPILA, 10 SIN-CHEQUEO
Logs y ondas en build/<testbench>/
```

Estados posibles:

| Estado | Significado |
|:---|:---|
| `PASS` | El testbench imprimió `[PASS]` y terminó con código 0. |
| `FAIL` | Imprimió `[FAIL]` o terminó con código distinto de 0 (por ejemplo, por `$fatal`). |
| `SIN-CHEQUEO` | Corrió sin errores, pero no se autoverifica: hay que revisar su salida a mano. |
| `NO-COMPILA` | Error de compilación; el detalle queda en `build/<tb>/compile.log`. |

`make sim` termina con código distinto de 0 si algún testbench queda en `FAIL` o `NO-COMPILA`.

## 4. Flujo de compilación

Para cada testbench, el Makefile ejecuta:

```bash
iverilog -g2012 -Wall -Wno-timescale -I rtl -I tb -s tb_x -o build/tb_x/sim.vvp rtl/*.sv tb/tb_x.sv
cd build/tb_x && vvp -n sim.vvp
```

- Todos los módulos de `rtl/` se compilan juntos con cada testbench. Agregar un módulo nuevo en
  `rtl/` o un testbench nuevo `tb/tb_*.sv` no requiere tocar el Makefile.
- `-s tb_x` fija el testbench como módulo superior, así que los módulos que no se usan no afectan.
- `-I rtl -I tb` resuelve los `` `include `` de `isa_defs.sv` y `tb_utils.svh`. `isa_defs.sv` tiene
  guardas `` `ifndef ``, por lo que incluirlo en varios archivos no lo duplica.
- `-Wno-timescale` evita una advertencia por cada módulo sin `` `timescale ``. El RTL no usa retardos,
  así que la unidad de tiempo sólo importa en los testbenches, que declaran `` `timescale 1ns/1ps ``.
- `vvp` corre dentro de `build/tb_x/`, de modo que el `.vcd` que abra el testbench queda ahí y no en
  la raíz del repositorio.
- `-n` hace que un `$stop` termine la simulación en lugar de quedarse esperando en modo interactivo.

## 5. Formato estándar de testbench

Todos los testbenches nuevos deben seguir este formato para que `make sim` pueda decidir solo si
pasaron.

1. Archivo `tb/tb_<modulo>.sv` con un módulo del mismo nombre.
2. `` `timescale 1ns/1ps `` en la primera línea.
3. Encabezado con la descripción y la lista de casos que cubre.
4. `` `include "tb_utils.svh" `` dentro del módulo.
5. `$dumpfile("tb_<modulo>.vcd")` y `$dumpvars(0, tb_<modulo>)` al inicio.
6. El estímulo cambia en el flanco negativo y el diseño captura en el positivo, para evitar
   carreras entre el testbench y el RTL.
7. Cada resultado se verifica con `check` o `check_true`. Un `$display` solo no detecta errores.
8. Los vectores aleatorios usan `$random(seed)` con una semilla configurable por `+seed=N`.
9. El testbench termina con `tb_finish("tb_<modulo>")`.

Utilidades de `tb/tb_utils.svh`:

| Elemento | Descripción |
|:---|:---|
| `check(nombre, obtenido, esperado)` | Compara hasta 32 bits con `!==`, así que un `X` o `Z` también es fallo. Imprime `[FAIL]` con ambos valores. |
| `check_true(nombre, condicion)` | Verifica que la condición sea 1. |
| `tb_section(nombre)` | Imprime el encabezado de un grupo de pruebas. |
| `tb_finish(nombre)` | Imprime `[PASS] nombre: N verificaciones` y llama a `$finish`, o `[FAIL] ...` y llama a `$fatal` (código de salida 1). |
| `tb_checks`, `tb_errors` | Contadores. |
| Watchdog | Si la simulación supera `` `TB_TIMEOUT `` (1 000 000 unidades de tiempo por defecto), termina con `[FAIL]`. Se cambia definiendo la macro antes del `` `include ``. |

## 6. Banco de registros (`regfile`)

Archivo: `rtl/regfile.sv`.

### Parámetros

| Parámetro | Valor por defecto | Descripción |
|:---|:---|:---|
| `NUM_REGS` | 32 | Registros x0–x31 del ISA. |
| `XLEN` | 32 | Ancho de cada registro. |
| `NUM_READ_PORTS` | 8 | Dos lecturas por slot. |
| `NUM_WRITE_PORTS` | 5 | Una escritura por unidad, dos para la cripto. |
| `ADDR_W` | `$clog2(NUM_REGS)` | Ancho de las direcciones. |

### Puertos

| Puerto | Ancho | Descripción |
|:---|:---|:---|
| `clk`, `reset` | 1 | Reloj y reset síncrono (todos los registros a 0). |
| `raddr` | `[NUM_READ_PORTS-1:0][ADDR_W-1:0]` | Dirección de cada puerto de lectura. |
| `rdata` | `[NUM_READ_PORTS-1:0][XLEN-1:0]` | Dato leído (combinacional). |
| `we` | `[NUM_WRITE_PORTS-1:0]` | Habilitador de cada puerto de escritura. |
| `waddr` | `[NUM_WRITE_PORTS-1:0][ADDR_W-1:0]` | Destino de cada escritura. |
| `wdata` | `[NUM_WRITE_PORTS-1:0][XLEN-1:0]` | Dato de cada escritura. |

Asignación de puertos en la configuración completa:

| Puerto de lectura | Slot | Uso |
|:---|:---|:---|
| 0, 1 | 0 ALU | `rf1`, `rf2` |
| 2, 3 | 1 LSU | `rf1` (base), `rf2` (dato de `guardap`/`guardab`) |
| 4, 5 | 2 BRU | `rf1`, `rf2` de las instrucciones de control |
| 6, 7 | 3 CRIPTO | par fuente `(r1, r1+1)` de `fsl`/`fsli`, o `(rs1, rs2)` de `ell` |

| Puerto de escritura | Slot | Instrucciones |
|:---|:---|:---|
| 0 | 0 ALU | tipo registro y tipo inmediato |
| 1 | 1 LSU | `cargai`, `cargabai` |
| 2 | 2 BRU | `sye` (dirección de retorno) |
| 3 | 3 CRIPTO | `fsl`/`fsli`: `L_out` hacia `rd` |
| 4 | 3 CRIPTO | `fsl`/`fsli`: `R_out` hacia `rd+1` |

### Comportamiento

- **x0:** se lee siempre como 0 y las escrituras hacia x0 se descartan en cualquier puerto.
- **Reset:** síncrono; deja los 32 registros en 0. El banco no trae valores iniciales en el RTL: los
  valores que necesite un programa los carga el propio programa o el testbench.
- **Lectura:** combinacional, en la etapa ID.
- **Escritura:** en el flanco positivo al final de la etapa WB.
- **Sin bypass:** una lectura en el mismo ciclo de la escritura entrega el valor anterior. El banco
  no reenvía el dato que se está escribiendo, porque el enunciado prohíbe el forwarding automático
  entre bundles.
- **Conflictos:** si dos puertos habilitados escriben el mismo registro en el mismo ciclo, gana el
  puerto de índice mayor (CRIPTO > BRU > LSU > ALU). Es un error de calendarización del software;
  `wb` lo señala con su salida `conflict` y el banco se comporta de forma determinista.

### Regla de dependencias de datos

Con el pipeline IF / ID / EX / WB, el bundle N lee sus operandos en ID y escribe su resultado al
final de WB, dos ciclos después:

```
ciclo          c      c+1    c+2    c+3
bundle N       ID     EX     WB          <- escribe en el flanco al final de c+2
bundle N+1            ID     EX     WB
bundle N+2                   ID          <- lee en c+2: todavía el valor anterior
bundle N+3                          ID   <- lee en c+3: valor nuevo
```

> **El valor que escribe el bundle N lo puede usar el bundle N+3 o uno posterior.** Entre el
> productor y el consumidor debe haber al menos dos bundles, independientes o NOP.

Además, dentro de un bundle todos los slots leen sus operandos antes de que se escriba cualquier
resultado del mismo bundle. Por ejemplo, `sumai x2, x2, 1` lee el valor anterior de x2.

Esta regla no está escrita en el ISA de la Entrega 1 y es parte del contrato con el ensamblador y
con el compilador de CE1108. `tb_regfile_pipeline` la verifica sobre `cpu_top`.

### Integración actual

El banco vive en `cpu_top` (instancia `REGFILE`) con la configuración por defecto (8 lecturas y
5 escrituras), compartido entre los cuatro slots. Las cinco escrituras están conectadas
directamente a las salidas de `wb`. De las lecturas, sólo las 0 y 1 (slot ALU) están conectadas a
`id_stage`, que entrega `rs1`/`rs2` y recibe `rs1_data`/`rs2_data`; las lecturas 2–7 (LSU, BRU y
CRIPTO) quedan en x0 hasta que se integren esas unidades: cada decoder debe reemplazar su par de
direcciones en `reg_raddr` y tomar sus datos de `reg_rdata`.

## 7. Writeback (`wb`)

Archivo: `rtl/wb.sv`. Es combinacional y se ubica entre el registro EX/WB y el banco de registros.

Entradas por unidad funcional:

| Señal | Descripción |
|:---|:---|
| `<fu>_we` | La instrucción del slot es válida y escribe un registro. Debe ser 0 si el slot es NOP, si el bundle fue anulado por un salto o si la instrucción no produce resultado (`guardap`, `guardab`, saltos condicionales, `ell`, `vcr`, `camcom`, `setpwd`). |
| `<fu>_rd` | Registro destino. |
| `<fu>_data` | Dato a escribir. La cripto entrega `crypto_data_l` y `crypto_data_r`. |

con `<fu>` en `alu`, `lsu`, `bru` y `crypto`.

Salidas:

| Señal | Descripción |
|:---|:---|
| `we[4:0]`, `waddr[4:0]`, `wdata[4:0]` | Los cinco puertos de escritura del banco, en el orden de la tabla de la sección 6. |
| `conflict` | 1 si dos puertos habilitados tienen el mismo destino en el mismo ciclo. |

Reglas:

- Un destino x0 no habilita su puerto.
- La cripto escribe `rd` y `rd+1`. El ISA exige `rd` par; si `rd = x31`, `rd+1` vale x0 y esa
  escritura se descarta.
- Las cuatro unidades pueden escribir en el mismo ciclo; la única restricción es que los destinos
  sean distintos.

## 8. ALU (`alu`)

Archivo: `rtl/alu.sv`. Es combinacional; recibe el código interno `alu_op` que genera
`decoder_alu` (definido en `rtl/isa_defs.sv`).

| `alu_op` | Instrucciones del ISA | Operación |
|:---|:---|:---|
| `ALU_ADD` | `suma`, `sumai` | `a + b` módulo 2^32 |
| `ALU_SUB` | `resta`, `restai` | `a - b` módulo 2^32 |
| `ALU_SLL` | `cizq`, `cizqi` | `a << b[4:0]` |
| `ALU_SRL` | `cder`, `cderi` | `a >> b[4:0]`, rellena con ceros |
| `ALU_SRA` | `cader`, `caderi` | `a >>> b[4:0]`, replica el bit de signo |
| `ALU_XOR` | `xor`, `xori` | `a ^ b` |
| `ALU_AND` | `and`, `andi` | `a & b` |
| `ALU_OR` | `or`, `ori` | `a \| b` |
| `ALU_LT` | `mrq` | 1 si `a < b` con signo, 0 si no |
| `ALU_GT` | `myq` | 1 si `a > b` con signo, 0 si no |
| otro | — | 0 |

Convenciones (sección "Convención de comparaciones y de signo" del ISA):

- Las comparaciones interpretan los operandos en complemento a dos.
- La cantidad de desplazamiento es una magnitud sin signo y se toma de `b[4:0]` (0–31). Un
  desplazamiento de 32 o más posiciones se reduce módulo 32.
- El inmediato de 11 bits se extiende con signo en `id_stage` antes de llegar a la ALU. Por eso
  `xori rg, rf1, -1` (pseudo `not`) invierte todos los bits.
- Suma y resta descartan el acarreo y el desborde; el ISA no define banderas.

## 9. Testbenches y cobertura

Testbenches autoverificables:

| Testbench | Qué verifica |
|:---|:---|
| `tb_alu` | Parte 1: cada operación con los ejemplos del ISA y casos de borde (acarreo, desborde con signo, desplazamientos de 0, 31 y 32 o más, relleno aritmético, comparaciones con INT_MIN, INT_MAX y -1, códigos no definidos); barrido 13 × 13 de valores especiales y 1000 vectores aleatorios por operación contra un modelo de referencia independiente. Parte 2: las 18 instrucciones ALU del ISA, `mov` y `not`, codificadas en binario y pasando por `id_stage` (decoder y extensión de signo, con el banco conectado aparte) hasta la ALU. |
| `tb_regfile` | Reset, escritura y lectura de los 31 registros por todos los puertos, x0, `we = 0`, ausencia de bypass, 5 escrituras y 8 lecturas simultáneas, conflictos de escritura, reset en medio de la ejecución, 2000 ciclos aleatorios contra un modelo y la configuración de 2 lecturas y 1 escritura. |
| `tb_wb` | Cada unidad sola, `we = 0`, destino x0, bordes del par de la cripto, bundle completo con 5 escrituras, detección de conflictos, 2000 combinaciones aleatorias contra un modelo y `wb` conectado al banco. |
| `tb_regfile_pipeline` | Regla de dependencias sobre `cpu_top`: lectura a distancias 1, 2, 3 y 4 del productor, inmediato negativo, escritura a x0 y ausencia de conflictos. |

Los demás testbenches de `tb/` muestran resultados con `$display` y aparecen como `SIN-CHEQUEO` hasta
que se migren al formato de la sección 5.

## 10. Pendientes

- Migrar los testbenches `SIN-CHEQUEO` al formato estándar.
- Conectar las lecturas 2–7 del banco y las entradas `lsu_*`, `bru_*` y `crypto_*` de `wb` cuando
  se integren LSU, BRU y CRIPTO (ver [Integración actual](#integración-actual)).
- Comunicar la regla de dependencias de la sección 6 al ensamblador y al grupo de CE1108.
- Soporte opcional de Verilator en el Makefile.
