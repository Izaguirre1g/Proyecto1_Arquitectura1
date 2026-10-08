# Integración con CE1108

El compilador usa la ISA VLIW propia. El módulo `generacion_basica.c` emite
instrucciones ALU y accesos `cargai/guardap`, con temporales x4–x7. Aún necesita
el resolvedor semántico y la integración del generador de programas completos.

`tools/bundle_linear.py` adapta ese subconjunto a cuatro slots, colocando
cada instrucción en su unidad e insertando dos bundles NOP entre instrucciones.
Conserva el orden y no empaqueta operaciones en paralelo. Rechaza control y
cripto: esta adaptación es para bloques lineales del generador actual.

## Reproducir el ejemplo

En el repositorio del compilador, rama `feat/generacion-basica`:

```bash
make tests/test_generacion
./tests/test_generacion --ejemplo > ejemplo.linear
```

Copiar `ejemplo.linear` a la raíz de este repositorio y ejecutar:

```bash
python3 tools/bundle_linear.py --input ejemplo.linear --output build/ce1108.asm
python3 tools/assembler.py --input build/ce1108.asm \
  --output build/ce1108.mem --binary build/ce1108.bin --listing build/ce1108.lst
python3 tools/run_ce1108.py --input ejemplo.linear
```

La copia `examples/ce1108.linear` fue generada con
[el commit 4f225a0 del compilador](https://github.com/Izaguirre1g/Proyecto-Parte-1-Compiladores-e-Interpretes-Definici-n-de-Sintaxis-de-Lenguaje/commit/4f225a0f34bac7adf9934181ebc8d0772589b242).
Produce 6 instrucciones y 16 bundles para `r : (a gauss b) neumann 1;`.
El testbench inicializa gp=0x4000, a=8 y b=3; comprueba r=10 en 0x4008 y que
los operandos se conserven. Es una prueba de una expresión emitida por el
módulo, no de un programa completo compilado con arranque y símbolos propios.

El ejecutor carga el `.mem` en la IMEM real y conserva listado, binario y logs
en `build/ce1108/`. Un resultado incorrecto termina con código distinto de cero.

## Resultado y pendientes

Revisión de Arquitectura `ba1b49e`, 8 de octubre de 2026:

- Ensamblado y carga en IMEM: correctos. Ejecución CE1108: falla; r queda
  en `0xdeadbeef` en vez de 10.
- Las pruebas de programas ALU también fallan. `cpu_top.sv` mezcla el opcode
  registrado en ID/EX con operandos e inmediato de ID; sus salidas de operandos
  registrados están sin conectar. LSU y BRU también leen operandos de ID.
- En LSU se retrasa el destino de una carga, pero el dato de WB sigue siendo
  combinacional. Además, NOP decodifica op=0 y `valid_in` es el del bundle:
  hay que distinguir el slot inactivo de `guardap`.
- `make sim` informa 7 PASS, 2 FAIL y 10 SIN-CHEQUEO. Los fallos son
  `tb_memory` y `tb_regfile_pipeline`; deben revisarse RTL y testbench,
  sin asumir que ambos fallos provengan necesariamente del hardware.
- Cripto no está conectada. `examples/mixto.asm` cubre sus seis instrucciones
  y un bundle con las cuatro unidades; por ahora se valida su codificación.

Para cerrar la parte de Javier: acordar las diferencias de ISA descritas en
[assembler.md](assembler.md), repetir los programas por unidad y el mixto
cuando el procesador esté integrado, y ejecutar al menos un programa completo
generado por CE1108. La corrección del pipeline se coordina con José/Fabricio,
LSU/BRU con Alejandro y los formatos/autenticación cripto con Dylan.
