# Proyecto1_Arquitectura1
Arquitectura VLIW Propia para Aplicaciones de Cifrado por Bloques

## Simulación

### Requisitos

- [Icarus Verilog](https://steveicarus.github.io/iverilog/) 12 o superior (`iverilog` y `vvp`)
- GNU make y bash
- GTKWave (opcional, para ver las ondas)

En Ubuntu o WSL:

```bash
sudo apt install iverilog gtkwave make
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
