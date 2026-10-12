# Integración con CE1108

Este documento describe la integración evaluada en Arquitectura CE4301.
El proyecto de Compiladores CE1108 tiene su propio enunciado y entregables.
El ensamblador de Arquitectura funciona de forma independiente del compilador,
como exige la sección 5.3 del enunciado de CE4301.

## Contrato de entrada

La codificación y el ABI están en [isa.md](isa.md);
la sintaxis completa está en [assembler.md](assembler.md).

- Bundle de 128 bits y avance de PC de 16 bytes.
- Orden del fuente: `ALU | LSU | BRU | CRIPTO`. ALU ocupa los bits bajos.
- NOP: palabra cero en cualquier slot; una línea `nop` ocupa el bundle completo.
- Registros: x0 constante cero, x1/ra, x2/sp y x3/gp. Temporales x4–x15;
  preservados x16–x31. La preservación corresponde al código generado.
- Un valor escrito en el bundle N se lee desde N+3. El software coloca dos
  bundles independientes o NOP entre productor y consumidor.
- `sye` y `syer` guardan PC+16. `ret` equivale a `syer x0, ra, 0`.
  Los saltos relativos se expresan en bytes desde el PC del bundle.
- `.mem`: una línea de 32 dígitos hexadecimales por bundle para IMEM.
  `.bin`: 16 bytes little-endian por bundle.

La referencia debe compartirse con CE1108 junto con los cambios de codificación,
ABI y calendarización. Estar en el repositorio permite consultarla; la entrega
al grupo de contraparte debe quedar registrada en el issue #20.

## Subconjunto integrado

El módulo `generacion_basica.c` emite instrucciones ALU y accesos
`cargai/guardap`, utilizando temporales x4–x7 y referencias suministradas por
un resolvedor. `bundle_linear.py` conserva el orden, coloca cada instrucción
en ALU o LSU e inserta dos bundles NOP entre instrucciones. No acepta etiquetas,
control ni cripto; esa limitación pertenece al adaptador lineal, no al ensamblador,
que sí codifica las 34 instrucciones actuales.

El chequeo estático del ensamblador revisa dependencias entre registros. No
verifica la disponibilidad de AUTH. Los programas cripto deben planificar sus
operaciones según los tiempos descritos en [simulation.md](simulation.md).
El RTL comprueba los permisos y genera una excepción ante un acceso indebido.

## Reproducir la prueba de CE1108

En el repositorio del compilador, rama `feat/generacion-basica`:

```bash
make tests/test_generacion
./tests/test_generacion --ejemplo > ejemplo.linear
```

Copiar `ejemplo.linear` a la raíz de Arquitectura y ejecutar:

```bash
python3 tools/run_ce1108.py --input ejemplo.linear
```

El comando adapta las instrucciones, genera `.asm`, `.mem`, `.bin` y `.lst`,
carga la memoria de instrucciones y ejecuta `top` con Icarus Verilog.
Los archivos y logs quedan en `build/ce1108/`. Un resultado incorrecto
termina con código distinto de cero.

También puede repetirse con la copia de referencia:

```bash
python3 tools/run_ce1108.py --input examples/ce1108.linear
```

Esa copia procede del
[commit 4f225a0 de CE1108](https://github.com/Izaguirre1g/Proyecto-Parte-1-Compiladores-e-Interpretes-Definici-n-de-Sintaxis-de-Lenguaje/commit/4f225a0f34bac7adf9934181ebc8d0772589b242).
Genera 6 instrucciones y 16 bundles para `r : (a gauss b) neumann 1;`.
El testbench inicializa gp=0x4000, a=8 y b=3; comprueba r=10 en 0x4008 y
que a y b se conserven. Este caso verifica una expresión emitida por el módulo;
no representa la compilación de un programa completo mediante la CLI.

## Resultados reproducidos

Pruebas confirmadas en Ubuntu con Icarus Verilog 12.0, el 11 de octubre de
2026, sobre la integración `42b05d4` de `fix-Pipeline-Integracion`:

| Comando | Resultado |
|---|---|
| `make test-assembler` | 38 pruebas correctas (21 + 13 + 4); cobertura de las 34 instrucciones |
| `make test-programs` | 14 pruebas correctas; programas tradicionales, mixto y subrutinas |
| `make tb_regfile_pipeline` | 10 verificaciones correctas de dependencias entre registros |
| `make tb_pipeline_cripto` | 71 verificaciones correctas de cifrado, descifrado, permisos y aislamiento |
| `make sim` | 21 PASS, 0 FAIL, 0 NO-COMPILA, 0 SIN-CHEQUEO |
| `python3 tools/run_ce1108.py --input ejemplo.linear` | PASS: (8 + 3) - 1 = 10 |

Las excepciones de privilegio mostradas por los casos negativos de
`tb_pipeline_cripto` son esperadas. Incluyen `ell` a dos bundles de `vcr`,
antes de que el estado esté disponible. `$finish` indica terminación normal.

## Programa desde un archivo fuente

`tools/run_ce1108_source.py` conecta los módulos de CE1108 sin modificar su
CLI, lexer, gramática ni interfaces. Usa Flex, el parser/AST de Bison, la tabla
de símbolos y `gb_generar` de la rama `feat-analisis-semantico` (probada en
`1e1b2f3`). El adaptador recorre una función `main` sin parámetros, asigna las
variables a palabras sucesivas desde 0x4000 y genera el arranque de gp.

El ejemplo `examples/ce1108_programa.bal` declara a=8 y b=3, calcula r=10 y
comprueba `valido = (r == 10)`. Todos esos valores se escriben desde el código
generado. El testbench sólo reinicia el procesador y carga sus instrucciones;
no precarga gp ni las variables. La memoria esperada es:

| Dirección | Variable | Valor |
|---|---|---|
| 0x4000 | a | 8 |
| 0x4004 | b | 3 |
| 0x4008 | r | 10 |
| 0x400c | valido | 1 |

En Ubuntu, además de las herramientas de simulación:

```bash
sudo apt install build-essential flex uthash-dev
```

La copia de Compiladores debe contener los módulos de `feat-analisis-semantico`.
Desde Arquitectura, indicar su ruta real:

```bash
make ce1108-source CE1108_ROOT="../Proyecto-Parte-1-Compiladores-e-Interpretes-Definici-n-de-Sintaxis-de-Lenguaje"
make test-ce1108-source CE1108_ROOT="../Proyecto-Parte-1-Compiladores-e-Interpretes-Definici-n-de-Sintaxis-de-Lenguaje"
```

Se conservan fuente, expectativas, salida lineal, bundles, binario, hexadecimal,
listado, registros, memoria, logs y ondas en `build/ce1108_fuente/`.
`evidence.json` registra el commit y las huellas de los módulos utilizados.
La prueba no informa PASS si gp o alguna palabra esperada difieren.
Flex genera su archivo C en `build/`, sin escribir en el repositorio externo.

Resultado reproducido: **PASS**, 59 bundles y los cuatro valores correctos.
Las cuatro pruebas adicionales también pasan: programa original, otro programa
con valores y asignación distintos, diez fuentes inválidos y un resultado
esperado incorrecto. Se mantienen las 38 pruebas anteriores del ensamblador y
las 14 de programas. Los módulos del repositorio externo permanecen intactos.

Esta es una demostración de un programa completo del subconjunto lineal:
una función `main` con enteros/booleanos, declaraciones inicializadas y
asignaciones admitidas por la generación básica. El adaptador rechaza ciclos,
condicionales, funciones adicionales, llamadas, colecciones y operaciones sin
traducción. No implica que la CLI de CE1108 compile todo el lenguaje.
El final del programa se convierte en un salto estable mientras el simulador
comprueba la memoria; no se agrega una instrucción HALT a la ISA.

## Pendientes de coordinación

- Reproducir la nueva demostración en el entorno del equipo y registrar sus
  resultados en #76; el caso anterior de expresión se conserva como regresión.
- Registrar la entrega del contrato actualizado al grupo de CE1108 en #20.

La sección 6.2 de CE4301 exige ejecutar al menos un programa generado por la
contraparte y verificar su resultado. No impone expresamente que esa
demostración tenga estructuras de control; los requisitos completos del
compilador corresponden al enunciado de CE1108.

## Operadores aritméticos con bucles internos

El generador de Compiladores admite `euclides` (división con signo), `euler`
(residuo) y `descartes` (potencia con exponente entero no negativo). Los bucles
son código generado para esas operaciones; no son la traducción general de
`whale`, `whether` ni funciones del lenguaje.

`run_ce1108_source.py` usa `bundle_control.py` para asignar ALU, LSU y saltos
directos a sus slots. El adaptador conserva dos NOP entre instrucciones y
coloca los destinos sobre dos NOP, también para saltos hacia atrás.
`bundle_linear.py` sigue disponible con su comportamiento anterior.

Desde Arquitectura, con ambos repositorios como carpetas hermanas:

```bash
python3 tools/run_ce1108_source.py \
  --compiler-root "../Proyecto-Parte-1-Compiladores-e-Interpretes-Definici-n-de-Sintaxis-de-Lenguaje" \
  --input "../Proyecto-Parte-1-Compiladores-e-Interpretes-Definici-n-de-Sintaxis-de-Lenguaje/examples/division_residuo_potencia.bal" \
  --expect-memory "../Proyecto-Parte-1-Compiladores-e-Interpretes-Definici-n-de-Sintaxis-de-Lenguaje/examples/division_residuo_potencia.memory.json" \
  --cycles 20000
```

El resultado esperado es q=-3, r=-2 y p=1024. `--cycles` fija el presupuesto de
simulación: un bucle ejecuta más instrucciones que las almacenadas una sola vez.
Sin esa opción, se conserva el presupuesto anterior para programas lineales.

Los operadores nuevos modifican x8–x15 además de los registros de expresión
x4–x7. El llamador debe preservar cualquier temporal vivo. Las etiquetas
`__gb_div_` y `__gb_pow_` pertenecen al generador, y el backend debe resolverlas
con el layout final de bundles.

División por cero y potencia con exponente negativo se rechazan si son
literales detectables. Para valores recibidos por variables, el código se
detiene en un salto estable sin escribir el resultado. Las pruebas negativas
verifican que se conserva el destino anterior y no se ejecuta lo que sigue;
eso no representa terminación normal del programa.

## Factorial con el generador de funciones

El modo `--functions` usa el analizador semántico, el asignador de memoria,
el adaptador de referencias y los generadores de funciones y control de
Compiladores. Requiere una copia que combine `feat/division-residuo` y
`feature/Ensamblador-ciclos-funciones`, con la multiplicación compacta.
Admite una sola main void sin parámetros; no integra módulos externos ni
llamadas a otras funciones. La CLI de producción de Compiladores se integra
por separado.

```bash
make compiladores-factorial CE1108_ROOT="../Proyecto-Parte-1-Compiladores-e-Interpretes-Definici-n-de-Sintaxis-de-Lenguaje"
make test-compiladores-funciones CE1108_ROOT="../Proyecto-Parte-1-Compiladores-e-Interpretes-Definici-n-de-Sintaxis-de-Lenguaje"
```

El código generado inicializa gp=0x4000 y sp=0x8000. `sye x1` llama a main y
fija ra; el prólogo lo guarda y el epílogo restaura ra/sp antes de retornar con
`syer`. Después del retorno, el arranque escribe 1 en 0x4000, dirección
reservada como señal de terminación de esta prueba. Si el programa queda
detenido por una operación inválida, esa señal no se escribe y la prueba falla.

El factorial usa un marco de 16 bytes: n queda en 0x7ff4, resultado en 0x7ff8 e
i en 0x7ffc. La RAM conserva esas palabras después de liberar el marco, lo que
permite comprobar el resultado. Se verifican también gp, sp y ra restaurados.
5! produce 120 y ocupa 163 bundles; 0!, 1!, 7! y 12! producen 1, 1, 5040 y
479001600. Los valores se inicializan por instrucciones, sin precarga del
banco de registros ni de la RAM del testbench.

El adaptador acepta retornos indirectos y transforma condiciones fuera del
rango de 11 bits en una condición inversa corta seguida de `sye x0` al destino.
Recalcula el layout hasta que todos los saltos condicionales caben. El
ensamblador conserva sus validaciones de rango, memoria y dependencias.
El modo lineal original sigue disponible. Si no se especifica `--cycles`,
los programas con bucles aritméticos internos o `--functions` reciben un
presupuesto de 100000 ciclos; los programas lineales mantienen el anterior.
