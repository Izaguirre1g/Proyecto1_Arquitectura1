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

Estado en `fix-Pipeline-Integracion`, 11 de octubre de 2026:

- `python3 tools/run_ce1108.py --input examples/ce1108.linear` termina con
  `[PASS]`: r = 10. Los errores de integración que daban r = `0xdeadbeef` en la
  revisión de `ba1b49e` (8 de octubre) están corregidos.
- `make sim` da 21 PASS, 0 FAIL y 0 SIN-CHEQUEO, y `make test-programs` ejecuta
  sobre el RTL los programas por unidad, `mixto.asm` (las cuatro unidades y las
  seis instrucciones cripto) y `subrutina.asm` (llamada y retorno).

Pendiente:

- Ejecutar al menos un programa completo generado por CE1108, con arranque y
  estructuras de control. Para eso `bundle_linear.py` tiene que aceptar el
  slot BRU: saltos condicionales, `sye` para llamar, `syer x0, ra, 0` (`ret`)
  para volver.
- Comunicar al grupo de CE1108 los cambios del ISA del 11 de octubre (enlace
  PC + 16 en `sye`, `syer` y `ret`) y la regla de dependencias: el valor que
  escribe el bundle N se lee desde el bundle N+3.
