<div align="center">

**Instituto Tecnológico de Costa Rica**<br>
**Escuela de Ingeniería en Computadores**

CE4301 – Arquitectura de Computadores I

# Avance 2 ISA

**Profesor:**<br>
Dr.-Ing. Jeferson González Gómez

**Estudiantes:**<br>
Dylan Guerrero González – 2022016016<br>
José García Izaguirre – 2022437991<br>
Javier Hernández Castillo – 2022321746<br>
Alejandro Vásquez Oviedo - 2019047658<br>
Fabricio Mena Mejia – 2019042722

**Fecha de Entrega:**<br>
18 de setiembre

**II Semestre, 2026**

</div>

---

## Contenido

- [Avance 2 ISA](#avance-2-isa)
  - [Contenido](#contenido)
  - [Justificación General](#justificación-general)
  - [Instrucciones tipo almacenar](#instrucciones-tipo-almacenar)
    - [Explicación de las instrucciones](#explicación-de-las-instrucciones)
    - [Justificación de diseño](#justificación-de-diseño)
  - [Instrucciones tipo inmediato](#instrucciones-tipo-inmediato)
    - [Explicación de las instrucciones](#explicación-de-las-instrucciones-1)
    - [Justificación de diseño](#justificación-de-diseño-1)
  - [Instrucciones tipo salto](#instrucciones-tipo-salto)
    - [Explicación de las instrucciones](#explicación-de-las-instrucciones-2)
      - [Tamaño máximo del salto](#tamaño-máximo-del-salto)
    - [Justificación de diseño](#justificación-de-diseño-2)
  - [Instrucciones tipo cripto](#instrucciones-tipo-cripto)
    - [Política de autenticación y control de acceso](#política-de-autenticación-y-control-de-acceso)
      - [Restricción de uso por instrucción](#restricción-de-uso-por-instrucción)
      - [Flujo de autenticación típico](#flujo-de-autenticación-típico)
    - [Justificación](#justificación)
    - [Explicación de las instrucciones](#explicación-de-las-instrucciones-3)
      - [`fsl`](#fsl)
      - [`fsli`](#fsli)
      - [`ell`](#ell)
      - [`vcr`](#vcr)
      - [`camcon`](#camcon)
      - [`setpwd`](#setpwd)
  - [Instrucciones tipo control](#instrucciones-tipo-control)
    - [Justificación](#justificación-1)
    - [Explicación de las instrucciones](#explicación-de-las-instrucciones-4)
      - [Instrucción `igualsi`:](#instrucción-igualsi)
      - [Instrucción `igualno`:](#instrucción-igualno)
      - [Instrucción menora:](#instrucción-menora)
      - [Instrucción `mayoroigual`](#instrucción-mayoroigual)
  - [Instrucciones tipo Registro](#instrucciones-tipo-registro)
    - [Explicación de las instrucciones](#explicación-de-las-instrucciones-5)
    - [Justificación](#justificación-2)
  - [Pseudoinstrucciones:](#pseudoinstrucciones)
  - [Registros de propósito general](#registros-de-propósito-general)
  - [Resumen de la arquitectura](#resumen-de-la-arquitectura)
  - [Diagrama de organización de la arquitectura](#diagrama-de-organización-de-la-arquitectura)
  - [Contribuciones](#contribuciones)

---

## Justificación General

Se estableció una longitud fija de **32 bits para las instrucciones**, buscando mantener una codificación uniforme en toda la arquitectura. Esta decisión permite que el procesador pueda identificar y procesar cada instrucción utilizando un formato de tamaño constante, independientemente de la unidad funcional que la ejecute.

Como estructura general, las instrucciones utilizan un prefijo compuesto por un **Tipo de operación de 7 bits** y un **ID de operación de 4 bits**. El campo de tipo permite identificar la categoría de la instrucción y asociarla con la unidad funcional correspondiente, mientras que el ID permite seleccionar la operación específica dentro de dicha categoría.

Los campos destinados a registros utilizan **5 bits**, permitiendo identificar hasta 32 registros diferentes. Aunque la arquitectura requiere como mínimo 15 registros de propósito general, se optó por un banco de registros mayor para proporcionar mayor flexibilidad al software.

Los bits restantes de cada formato se asignan de acuerdo con los operandos y parámetros requeridos por cada unidad funcional. Por esta razón, **no todos los tipos de instrucción utilizan exactamente los mismos campos.**

## Instrucciones tipo almacenar

| [31:25] | [24:21] | [20:16] | [15:11] | [10:0] |
|:---:|:---:|:---:|:---:|:---:|
| **Tipo de operación** | **ID operación** | **rf1** | **rf2** | **offset** |
| 7 bits | 4 bits | 5 bits | 5 bits | 11 bits |

La distribución de los campos es la siguiente:

- Tipo de operación: 7 bits.
- ID operación: 4 bits para identificar la operación específica.
- rf1: 5 bits para identificar el registro fuente.
- offset: 11 bits para representar el valor del offset que se le va a aplicar a la dirección de memoria.

| Tipo de operación | ID operación | Instrucción | Operación |
|:---:|:---:|:---:|:---:|
| 1001001 | 0000 | `guardap` | M(rf1+offset) = rf2 [31:0] |
| 1001001 | 0001 | `guardab` | M(rf1+offset) = rf2 [7:0] |
| 1001001 | 1000 | `cargai` | rg = Memoria[rf1 + inmediato] |
| 1001001 | 1001 | `cargabai` | rg = Memoria8[rf1 + inmediato] |

### Explicación de las instrucciones

La instrucción `guardap` toma una palabra (32 bits) y la guarda en la dirección de memoria que se calcula como la suma de la dirección almacenada en el registro fuente 1 (rf1) y el inmediato que se pasa a la instrucción.

Ejemplo en ensamblador:

```
guardap x3, x8, 5
```

realiza lo siguiente: suponiendo que en `x3` la dirección guardada sea `0x20` entonces toma `0x20`, le suma 5 y en `0x25` guarda el dato que se encuentra en `x8`.

Para `guardab` el proceso es el mismo solo que en este caso se guarda un byte (8 bits) en lugar de una palabra completa de 32 bits.

La instrucción `cargai` permite cargar un dato almacenado en memoria hacia un registro.

```
rg = Memoria[rf1 + inmediato]
```

Por ejemplo:

rf1 con la dirección 1000 y el valor inmediato es 20, la dirección: 1000+20 = 1020

Si la posición de memoria 1020 contiene el valor de 55, después ejecutar la instrucción el registro `rg` tendrá: rg55

Esta instrucción permite acceder a datos almacenados en memoria.

La instrucción `cargabai` funciona de manera similar a `cargai`, pero en lugar de cargar un dato completo, únicamente un byte desde la memoria. La dirección se calcula sumando el registro fuente con el inmediato. La operación realizada es:

```
rg = Memoria[rf1 + inmediato]
```

Por ejemplo:

Si rf1 tiene la dirección 2000 y el inmediato es 4, la dirección de lectura será: 2000+4=2004.

Si en la dirección 2004 se encuentra almacenado el byte 0x7F, entonces el registro destino tendrá:

rg = 0x7F

La instrucción se utiliza cuando se necesita trabajar con datos almacenados en memoria que tienen un tamaño de un byte.

### Justificación de diseño

Se decidió que la palabra fuera de 32 bits para que mantenga coherencia con la estructura general de la arquitectura. Los 5 bits para la identificación de los registros permiten acceder a los 17 registros de propósito general disponibles. Los 3 bits para identificar la operación dentro del tipo se mantienen a pesar de que este tipo concreto de instrucciones pueda operar con solo 2 bits, de esta forma los campos de tipo e ID se mantienen constantes en todos los tipos de operaciones soportadas. El offset ocupa 11 bits, esta cantidad asegura que se puedan alcanzar rangos extensos en la memoria sin preocupaciones.

## Instrucciones tipo inmediato

Formato:

| [31:25] | [24:21] | [20:16] | [15:11] | [10:0] |
|:---:|:---:|:---:|:---:|:---:|
| **Tipo de operación** | **ID operación** | **rf1** | **rg** | **Inmediato** |
| 7 bits | 4 bits | 5 bits | 5 bits | 11 bits |

La distribución de los campos es la siguiente:

- Tipo de operación: 7 bits.
- ID operación: 4 bits para identificar la operación específica.
- rf1: 5 bits para identificar el registro fuente.
- rg: 5 bits para identificar el registro destino.
- Inmediato: 11 bits para representar el valor inmediato.

Instrucciones:

| Tipo de operación | ID operºación | Instrucción | Operación |
|:---:|:---:|:---|:---|
| 1000000 | 0000 | `sumai` | rg = rf1 + inmediato |
| 1000000 | 0001 | `restai` | rg = rf1 - inmediato |
| 1000000 | 0010 | `cizqi` | rg = rf1 << inmediato |
| 1000000 | 0011 | `cderi` | rg = rf1 >> inmediato |
| 1000000 | 0100 | `caderi` | Corrimiento aritmético derecho |
| 1000000 | 0101 | `xori` | rg = rf1 XOR inmediato |
| 1000000 | 0110 | `andi` | rg = rf1 AND inmediato |
| 1000000 | 0111 | `ori` | rg = rf1 OR inmediato |

### Explicación de las instrucciones

La instrucción `sumai` realiza una suma entre el valor almacenado en un registro fuente (`rf1`) y un valor constante denominado inmediato. El resultado de esta operación se almacena en el registro destino (`rg`), sin modificar el valor original fuente.

Por ejemplo:

```
rg = rf1 + inmediato
```

El registro `rf1` contiene el valor 10 y el valor inmediato es 5, al ejecutar la instrucción `sumai` se realiza la operación:

```
rg = 10 +5
```

La instrucción `restai` realiza una resta entre el valor almacenado en un registro fuente `rf1` y un valor constante inmediato, este se almacena en el registro destino (`rg`)

Ejemplo:

```
rg + rf1 – inmediato

rg = 10 – 3
```

La instrucción `cizqi` realiza un corrimiento de bits hacia la izquierda del valor almacenado en el registro fuente rf1 una cantidad de posiciones indicada por el valor inmediato.

Ejemplo:

```
rg = rf1 << inmediato
00000101 << 2 = 00010100
```

Entonces el registro rg almacenará el valor 20 en decimal, la operación es equivalente a multiplicar el valor por una potencia de dos cuando no ocurre pérdida de bits.

La instrucción `cderi` realiza un corrimiento de bits hacia la derecha del valor almacenado en el registro fuente `rf1` utilizando la cantidad de posiciones indicada por el valor inmediato.

Ejemplo:

```
rg = fr1 >> inmediato
00010100 >> 2 = 00000101
```

El registro rg almacenará el valor 5. Esta instrucción permite reducir el valor de un número mediante desplazamientos de bits hacia la derecha.

La instrucción `caderi` realiza un corrimiento aritmético hacia la derecha del valor almacenado en el registro fuente `rf1`.

Ejemplo:

```
rg = rf1 >>> inmediato
```

Se tiene:

```
11110000
```

Y se realiza un desplazamiento aritmético hacia la derecha de 2 posiciones:

```
11110000 >>> 2 = 11111100
```

El registro rg almacenará el nuevo valor conservando el signo original

La instrucción `xori` realiza una operación lógica `xor` entre el valor almacenado en el registro `rf1` y un valor inmediato.

La operación es `rf1 xor inmediato`

Por ejemplo:

```
rf1 = 1010
inmediato: 1100
```

Por ejemplo:

```
La operación 1010 xor 1100 = 0110
```

La instrucción `andi` realiza una operación lógica `and` entre el contenido del registro fuente rf1 y un valor inmediato.

```
rg = rf1 and inmediato
```

Por ejemplo:

```
rf1 = 1010
inmediato = 1100
```

Por ejemplo:

```
1010 and 1100 = 1000
```

El registro rg almacenará 1000

Ejemplo:

1010 or 1100 = 1110

La instrucción `ori` realiza una operación lógica `or` entre el valor almacenado en el registro fuente rf1 y un valor inmediato.

```
rg = rf1 or inmediato
```

Por ejemplo:

```
rf1 = 1010 e inmediato = 1100
```

El registro rg almacenará 1110

### Justificación de diseño

Se eligió este diseño porque permite mantener las instrucciones en 32 bits y aprovechar el espacio de forma equilibrada entre identificación, registros e inmediato. Los campos de 5 bits permiten acceder a los 32 registros de la arquitectura, mientras que 4 bits son suficientes para distinguir las 10 operaciones definidas y dejar espacio para futuras extensiones. Los 11 bits restantes se destinan al inmediato, permitiendo ejecutar operaciones aritméticas, lógicas, desplazamientos y accesos a memoria sin requerir una segunda instrucción para cargar constantes.

## Instrucciones tipo salto

| [31:25] | [24:21] | [20:16] | [15:0] |
|:---|:---|:---|:---|
| **Tipo de operación** | **ID operación** | **Rg** | **offset** |
| 7 bits | 4 bits | 5 bits | 16 bits |

La distribución de los campos es la siguiente:

- Tipo de operación: 7 bits.
- ID operación: 4 bits para identificar la operación específica.
- rg: 5 bits para identificar el registro fuente.
- offset: 11 bits para representar el valor del offset que se le va a aplicar a la dirección de memoria.

| Tipo de operación | ID operación | Instrucción | Operación |
|:---:|:---:|:---:|:---:|
| 1001011 | 0000 | `sye` | rg=PC+4; PC=PC + offset |

### Explicación de las instrucciones

`sye` guarda en `rg` la dirección de la siguiente instrucción (PC + 4) y posteriormente modifica el PC sumándole el offset.

```
rg = PC + 4
PC = PC + offset
```

Ejemplo:

Si `PC = 1000` y `offset = 20`:

```
rg = 1000 + 4 = 1004
PC = 1000 + 20 = 1020
```

Por lo tanto, la ejecución continúa en la dirección 1020, mientras que `rg` conserva la dirección de retorno 1004.

#### Tamaño máximo del salto

Como el offset tiene 16 bits, si se interpreta como un número con signo en complemento a dos, su rango es:

$$
-2^{15} \leq \mathit{offset} \leq 2^{15} - 1
$$

$$
-32768 \leq \mathit{offset} \leq 32767
$$

Por lo tanto, el salto puede ser:

- Máximo hacia atrás: -32768
- Máximo hacia adelante: +32767

### Justificación de diseño

Tanto el campo de tipo de operación como el ID de esta se mantienen en el mismo lugar y con la misma cantidad de bits para que haya coherencia en toda la encodificación de la arquitectura. Los 5 bits de rg permiten acceder a los 17 posibles registros de uso general. El offset de 16 bits permite que el salto que se pueda dar sea lo más extenso posible.

## Instrucciones tipo cripto

### Política de autenticación y control de acceso

El procesador mantiene un **registro de estado `ESTADO`** de 32 bits. De ellos, sólo el bit menos significativo (`ESTADO[0]`, en adelante "bit AUTH") define si el procesador se encuentra autenticado frente a la bóveda de llaves:

| Bit | Nombre | Significado |
|:---|:---|:---|
| `ESTADO[0]` | AUTH | `1` = autenticado, `0` = no autenticado. |
| `ESTADO[31:1]` | — | Reservados (siempre `0`). |

El bit AUTH **no es accesible** mediante instrucciones de carga/almacenamiento a memoria ni mediante lectura a registros de propósito general; sólo puede ser alterado por las instrucciones privilegiadas de la unidad criptográfica que se describen más adelante. Esto refuerza el aislamiento de la bóveda (Sección 4.4.1).

#### Restricción de uso por instrucción

| Instrucción | ¿Requiere `AUTH = 1`? | Si falta AUTH |
|:---|:---:|:---|
| `vcr` | No (es la vía de autenticación) | n/a |
| `setpwd` | **Requiere `AUTH = 0`** (sólo en arranque, antes de autenticar) | Excepción |
| `ell` | Sí | Excepción (sin escribir en bóveda) |
| `camcom` | Sí | Excepción (sin rotar la contraseña) |
| `fsl`, `fsli` | Sí | Excepción (sin consumir subllave) |

Cualquier intento de ejecutar una instrucción que requiera autenticación sin tener `AUTH = 1` genera una **excepción de privilegio** (trap de seguridad). La excepción detiene la ejecución del bundle actual y transfiere el control a una dirección de manejo a definir en la microarquitectura.

#### Flujo de autenticación típico

1. **Arranque:** el procesador parte con `AUTH = 0`. El código de boot puede invocar `setpwd` una sola vez para cargar la contraseña maestra en la bóveda desde un registro (típicamente `x16`).
2. **Validación:** `vcr` compara la contraseña candidata en memoria contra la real de la bóveda. Si coinciden, pone `AUTH = 1`; si no, mantiene `AUTH = 0`. El resultado se actualiza únicamente en `ESTADO[0]`, **no** se escribe a memoria ni a registros.
3. **Uso:** una vez autenticado, el programa puede invocar `ell`, `camcom`, `fsl` y `fsli`. Cualquier intento de bypass produce excepción.
4. **Bloqueo:** si se desea revocar el acceso, basta con sobrescribir manualmente el bit `AUTH = 0` mediante una futura instrucción de logout (a definir en extensión).

Esta política garantiza que las subllaves nunca abandonen la bóveda por buses de propósito general y que sólo código autenticado puede consumirlas.



| [31:25] | [24:21] | [20:19] | [18:17] | [16:12] | [11:7] | [6:0] |
|:---:|:---:|:---:|:---:|:---:|:---:|:---:|
| **Tipo de operación** | **ID operación** | **LK** | **RK** | **rd** | **r1** | **RSV** |
| 7 bits | 4 bits | 2 bits | 2 bits | 5 bits | 5 bits | 7 bits |

La distribución de los campos es la siguiente:

- Tipo de operación: 7 bits.
- ID operación: 4 bits para identificar la operación específica.
- LK: 2 bits para identificar el índice de la llave en la bóveda (0–3).
- RK: 2 bits para identificar el índice de la ronda/subllave dentro de la llave (0–3).
- rd: 5 bits para identificar el registro destino del par de salida (L_out, R_out).
- r1: 5 bits para identificar el registro fuente del par de entrada (L_in, R_in).
- RSV: 7 bits reservados.

| Tipo de operación | ID operación | Instrucción | Operación |
|:---:|:---:|:---|:---|
| 0000010 | 0000 | `fsl` | (L_out, R_out) = feistel_round((L_in, R_in), LK, RK) |
| 0000010 | 0001 | `fsli` | (L_out, R_out) = feistel_round_inv((L_in, R_in), LK, RK) |
| 0000010 | 0010 | `ell` | bóveda[LK][off..off+1] = (rs1, rs2) |
| 0000010 | 0011 | `vcr` | actualiza ESTADO con (mem[dir_cand] == mem[dir_real]) |
| 0000010 | 0100 | `camcom` | mem[dir] = ROL(mem[dir], imm) |
| 0000010 | 0101 | `setpwd` | dir_contraseña_real = rf (solo en arranque, sin autenticar) |
| 0000010 | 0110–1111 | — | reservados |

### Justificación

El formato de las instrucciones cripto hereda del prefijo común del ISA (tipo 7 bits + ID operación 4 bits), dejando 21 bits para operandos. Esto mantiene coherencia con los demás tipos. Simplifica el decode del bundle y permite que el dispatcher identifique la FU cripto mirando únicamente el campo tipo.

Para `fsl` y `fsli` se eligió ejecutar una ronda por instrucción, no las cuatro juntas, para exponer paralelismo entre slots del bundle. El direccionamiento de la subllave se divide en `lk` (2 bits, índice de llave) y `rk` (2 bits, índice de subllave o ronda), porque 2 bits permiten indexar 4 elementos y facilita la legibilidad que un solo campo de 4 bits. Los registros `rd` y `rf1` apuntan a pares adyacentes (L, R) por convención, ahorrando 10 bits respecto a codificar los cuatro operandos por separado.

`ell` se eligió escribir 64 bits por invocación, dos palabras con rs1 y rs2, en lugar de 32 bits. Esto reduce el número de instrucciones necesarias para cargar una llave completa de 4 a 2, sin superar los 21 bits disponibles.

`vcr`, la validación de credenciales, compara la contraseña candidata (en memoria) directamente contra la contraseña real residente en la bóveda, **sin** pasar la contraseña real por buses de propósito general ni por registros: el dato sensible nunca abandona el hardware de la cripto FU. El resultado de la comparación sólo se refleja en el bit `AUTH` interno (`ESTADO[0]`), sin escribir a memoria de propósito general.

`camcom`, el cambio de contraseña recibe un inmediato de n bits con la cantidad de corrimientos a aplicar sobre la contraseña actual. Codificarlo como inmediato es práctico para una rotación lógica circular.

**Nota de aislamiento:** las subllaves únicamente salen de la bóveda de manera implícita al ejecutarse `fsl`/`fsli`; no existen instrucciones que copien contenido de la bóveda a registros de propósito general ni a memoria. 
### Explicación de las instrucciones

#### `fsl`

Descripción: Ejecuta una ronda directa de Feistel. Lee el par (L, R) desde los registros fuente, lee la subllave correspondiente de la bóveda y escribe el par cifrado en los registros destino.

Formato:

| 31:25 | 24:21 | 20:19 | 18:17 | 16:12 | 11:7 | 6:0 |
|:---:|:---:|:---:|:---:|:---:|:---:|:---:|
| **Tipo** | **ID** | **LK** | **RK** | **rd** | **r1** | **RSV** |
| 7 bits | 4 bits | 2 bits | 2 bits | 5 bits | 5 bits | 7 bits |

Descripción de campos:

| Campo | Bits | Significado |
|:---|:---|:---|
| Tipo | [31:25] | 0000010 — identifica la UF Cripto |
| ID | [24:21] | 0000 — opcode de FSL |
| LK | [20:19] | Índice de llave en la bóveda (0–3) |
| RK | [18:17] | Índice de subllave dentro de la llave (0–3) |
| rg | [16:12] | Registro destino L_out; R_out se escribe en rd+1 |
| rf1 | [11:7] | Registro fuente L_in; R_in se lee de r1+1 |
| RSV | [6:0] | 0000000 — reservados para extensión futura |

Ejemplo en ensamblador:

```
fsl rd=6, r1=2, LK=0, RK=1
```

Restricciones:

- Requiere `ESTADO[0] = AUTH = 1`; en caso contrario genera **excepción de privilegio**.
- `rg` y `rf1` deben estar en registros pared a partir de `x2` (registros de la cripto FU).
- `LK` ∈ {0,1,2,3} y `RK` ∈ {0,1,2,3}.
- La subllave se lee internamente de la bóveda; nunca abandona la bóveda.

#### `fsli`

Descripción: Ejecuta una ronda inversa de Feistel. Igual que `fsl` pero aplicando las subllaves en orden inverso. Se usa para descifrar.

Formato:

| 31:25 | 24:21 | 20:19 | 18:17 | 16:12 | 11:7 | 6:0 |
|:---:|:---:|:---:|:---:|:---:|:---:|:---:|
| **Tipo** | **ID** | **LK** | **RK** | **rd** | **r1** | **RSV** |
| 7 bits | 4 bits | 2 bits | 2 bits | 5 bits | 5 bits | 7 bits |

Descripción de campos:

| Campo | Bits | Significado |
|:---|:---|:---|
| Tipo | [31:25] | 0000010 |
| ID | [24:21] | 0001 — opcode de FSLI |
| LK | [20:19] | Índice de llave en la bóveda (0–3) |
| RK | [18:17] | Índice de subllave dentro de la llave (0–3) |
| rg | [16:12] | Registro destino L_out; R_out se escribe en rd+1 |
| rf1 | [11:7] | Registro fuente L_in; R_in se lee de r1+1 |
| RSV | [6:0] | 0000000 |

Ejemplo en ensamblador:

```
fsli  rd=6, r1=2, LK=0, RK=3
```

Restricciones:

- Requiere `ESTADO[0] = AUTH = 1`; en caso contrario genera **excepción de privilegio**.
- `rg` y `rf1` deben estar en registros pares.
- `LK` ∈ {0,1,2,3} y RK ∈ {0,1,2,3}.

#### `ell`

Descripción: Escribe 64 bits (dos palabras de 32 bits) desde dos registros fuente hacia la bóveda de llaves. Permite cargar una llave completa de 128 bits con 2 invocaciones.

Formato:

| 31:25 | 24:21 | 20:19 | 18:17 | 16:12 | 11:7 | 6:0 |
|:---:|:---:|:---:|:---:|:---:|:---:|:---:|
| **Tipo** | **ID** | **LK** | **off** | **rs1** | **rs2** | **RSV** |
| 7 bits | 4 bits | 2 bits | 2 bits | 5 bits | 5 bits | 7 bits |

Descripción de campos:

| Campo | Bits | Significado |
|:---|:---|:---|
| Tipo | [31:25] | 0000010 |
| ID | [24:21] | 0010 — opcode de ELL |
| LK | [20:19] | Índice de llave destino en la bóveda (0–3) |
| off | [18:17] | Offset dentro de la llave (0 = MSW, 3 = LSW) |
| rf1 | [16:12] | Registro fuente → vault[LK][off] |
| rf2 | [11:7] | Registro fuente → vault[LK][off+1] |
| RSV | [6:0] | 0000000 |

Ejemplo en ensamblador:

```
# Cargar la llave 2 con cuatro palabras desde x4, x6, x8, x10
ell    LK=2, off=0, rs1=4, rs2=6
ell    LK=2, off=2, rs1=8, rs2=10
```

Restricciones:

- Requiere `ESTADO[0] = AUTH = 1`; en caso contrario genera **excepción de privilegio**.
- `rf1` y `rf2` pueden ser cualquier registro par.
- `LK` ∈ {0,1,2,3} y `off` ∈ {0,2} para no desbordar la llave.

#### `vcr`

Descripción: Compara la contraseña candidata contra la contraseña real y actualiza el bit `AUTH` del registro `ESTADO` en consecuencia: `AUTH = 1` si coinciden, `AUTH = 0` en caso contrario. El resultado nunca se escribe a memoria de propósito general ni a registros; sólo modifica el bit interno `ESTADO[0]`.

Formato:

| 31:25 | 24:21 | 20:5 | 4:0 |
|:---:|:---:|:---:|:---:|
| **Tipo** | **ID** | **dir_cand** | **RSV** |
| 7 bits | 4 bits | 16 bits | 5 bits |

Descripción de campos:

| Campo | Bits | Significado |
|:---|:---|:---|
| Tipo | [31:25] | 0000010 |
| ID | [24:21] | 0011 — opcode de VCR |
| dir_cand | [20:5] | Dirección de memoria de la contraseña candidata (0–65535) |
| RSV | [4:0] | 00000 — reservados |
| contraseña real | — | implícita en la bóveda |

Ejemplo en ensamblador:

```
# Validar contraseña candidata en mem[0x2000]
# contra la real guardada en la bóveda
vcr    dir_cand=0x2000
```

Restricciones:

- `vcr` se puede invocar siempre, esté o no autenticado el procesador: es la única vía de autenticación.
- `dir_cand` ∈ [0, 65535] (cubre toda la memoria de 64 KB).

#### `camcon`

Descripción: Renueva la contraseña actual aplicando una rotación lógica circular a la izquierda. Requiere que el procesador esté autenticado.

Formato:

| 31:25 | 24:21 | 20:5 | 4:0 |
|:---:|:---:|:---:|:---:|
| **Tipo** | **ID** | **dir** | **imm** |
| 7 bits | 4 bits | 16 bits | 5 bits |

Descripción de campos:

| Campo | Bits | Significado |
|:---|:---|:---|
| Tipo | [31:25] | 0000010 |
| ID | [24:21] | 0100 — opcode de CAMCON |
| dir | [20:5] | Dirección de memoria de la contraseña actual (0–65535) |
| imm | [4:0] | Cantidad de corrimientos a la izquierda (0–31) |

Ejemplo en ensamblador:

```
# Renovar la contraseña en mem[0x0010] rotándola 7 bits
camcon   dir=0x0010, imm=7
```

Restricciones:

- Requiere `ESTADO[0] = AUTH = 1`; en caso contrario genera **excepción de privilegio**.
- `imm` ∈ [0, 31].

#### `setpwd`

Descripción: Inicializa la contraseña en la bóveda desde un registro fuente al arrancar el sistema. Es la única vía para depositar la contraseña maestra.

Formato:

| 31:25 | 24:21 | 20:5 | 4:0 |
|:---:|:---:|:---:|:---:|
| **Tipo** | **ID** | **dir** | **rs** |
| 7 bits | 4 bits | 16 bits | 5 bits |

Descripción de campos:

| Campo | Bits | Significado |
|:---|:---|:---|
| Tipo | [31:25] | 0000010 |
| ID | [24:21] | 0111 — opcode de SETPWD |
| dir | [20:5] | Dirección de memoria destino (0–65535) |
| rf | [4:0] | Registro fuente con la contraseña inicial (32 bits) |

Ejemplo en ensamblador:

```
# Inicializar contraseña: x5 → mem[0x0010]
setpwd   rs=5, dir=0x0010
movi     x16, 0x0010
```

Restricciones:

- Sólo se permite cuando `ESTADO[0] = AUTH = 0` (camino de inicialización en arranque). Si el procesador ya está autenticado genera **excepción de privilegio**.
- El campo `rf` se ignora a nivel arquitectónico; el valor se toma del registro `x16` por convención para reforzar el aislamiento.

## Instrucciones tipo control

| [31:25] | [24:21] | [20:16] | [15:11] | [10:0] |
|:---:|:---:|:---:|:---:|:---:|
| **Tipo de operación** | **ID operación** | **rf1** | **rf2** | **Inmediato** |
| 7 bits | 4 bits | 5 bits | 5 bits | 11 bits |

La distribución de los campos es la siguiente:

- Tipo de operación: 7 bits.
- ID operación: 4 bits para identificar la operación específica.
- rf1: 5 bits para identificar el registro fuente.
- rf2: 5 bits para identificar el registro con el que se compara rf1.
- Inmediato: 11 bits para representar el valor inmediato.

**Instrucciones:**

| Tipo de operación | ID operación | Instrucción | Operación |
|:---:|:---:|:---|:---|
| 1000001 | 0001 | `igualsi` | if (rf1 == rf2) PC += inmediato |
| 1000001 | 0010 | `igualno` | if (rf1 != rf2) PC += inmediato |
| 1000001 | 0100 | `menora` | if (rf1 < rf2) PC += inmediato |
| 1000001 | 1000 | `mayoroigual` | if (rf1 >= rf2) PC += inmediato |

### Justificación

Las instrucciones de control se diseñaron utilizando un formato de 32 bits, manteniendo la estructura general de la ISA. Se conservaron los 7 bits correspondientes al tipo de operación y los 4 bits del ID de operación, permitiendo identificar la unidad de control de flujo y diferenciar las distintas condiciones de salto.

Para las instrucciones de salto condicional se utilizan dos registros fuente de 5 bits (`rf1` y `rf2`), ya que las operaciones definidas requieren comparar directamente dos registros. Con 5 bits es posible identificar cualquiera de los registros disponibles en el banco de registros de la arquitectura, manteniendo la compatibilidad con los demás formatos.

Los 11 bits restantes se destinan al inmediato utilizado como `offset` del salto. Este valor se interpreta como un desplazamiento respecto al valor actual del Program Counter (PC), permitiendo modificar el flujo de ejecución sin necesidad de almacenar una dirección absoluta dentro de la instrucción.

Se definieron cuatro operaciones de salto condicional: `igualsi`, `igualno`, `menora` y `mayoroigual`. Estas permiten cubrir las comparaciones fundamentales entre dos registros y proporcionan las operaciones necesarias para implementar estructuras de decisión y repetición en programas de propósito general.

### Explicación de las instrucciones

**Formato:**

| [31:25] | [24:21] | [20:16] | [15:11] | [10:0] |
|:---|:---|:---|:---|:---|
| **Tipo** | **ID** | **rf1** | **rf2** | **Inmediato** |
| 7 bits | 4 bits | 5 bits | 5 bits | 11 bits |

**Descripción de campos:**

| Campo | Bits | Significado |
|:---|:---|:---|
| **Tipo** | [31:25] | 1000001 — identifica las instrucciones de control |
| **ID** | [24:21] | 0001 — código de la operación |
| **rf1** | [20:16] | Primer registro fuente de la comparación |
| **rf2** | [15:11] | Segundo registro fuente de la comparación |
| **Inmediato** | [10:0] | Desplazamiento relativo que se suma al PC cuando la condición se cumple |

#### Instrucción `igualsi`:

Descripción: Compara los valores almacenados en `rf1` y `rf2`. Si ambos valores son iguales, el Program Counter (PC) se modifica sumándole el valor del inmediato. Si la condición no se cumple, el flujo de ejecución continúa normalmente.

Operación:

```
if (rf1 == rf2) PC += inmediato
```

**Ejemplo en ensamblador:**

```
# Saltar con desplazamiento 4 si x3 es igual a x4
igualsi   rf1=3, rf2=4, inmediato=4
```

**Restricciones:**

- `rf1` y `rf2` pueden identificar cualquiera de los 32 registros (`x0–x31`).
- El inmediato debe codificarse utilizando los 11 bits disponibles del campo [10:0].
- La instrucción no escribe un registro de propósito general; únicamente puede modificar el flujo de ejecución.
- La condición evaluada es igualdad exacta entre los 32 bits de `rf1` y `rf2`.

#### Instrucción `igualno`:

Descripción: Compara los valores almacenados en `rf1` y `rf2`. Si los valores son diferentes, el Program Counter (PC) se modifica sumándole el valor del inmediato. Si ambos registros contienen el mismo valor, no se realiza el salto.

Operación:

```
if (rf1 != rf2) PC += inmediato
```

Ejemplo en ensamblador:

```
# Saltar con desplazamiento 6 si x5 es diferente de x6
igualno   rf1=5, rf2=6, inmediato=6
```

**Restricciones:**

- `rf1` y `rf2` pueden identificar cualquiera de los 32 registros (`x0–x31`).
- El inmediato debe codificarse utilizando los 11 bits disponibles del campo [10:0].
- La instrucción no escribe un registro de propósito general; únicamente puede modificar el flujo de ejecución.
- La condición se cumple cuando `rf1` y `rf2` contienen valores distintos.

#### Instrucción menora:

Descripción: Compara los valores contenidos en rf1 y rf2. Si el valor de rf1 es menor que el valor de rf2, el Program Counter (PC) se modifica sumándole el inmediato. En caso contrario, el salto no se realiza.

**Operación:**

```
if (rf1 < rf2) PC += inmediato
```

**Ejemplo en ensamblador:**

```
# Saltar con desplazamiento 3 si x7 es menor que x8
menora    rf1=7, rf2=8, inmediato=3
```

**Restricciones:**

- rf1 y rf2 pueden identificar cualquiera de los 32 registros (x0–x31).
- El inmediato debe codificarse utilizando los 11 bits disponibles del campo [10:0].
- La instrucción no escribe un registro de propósito general; únicamente puede modificar el flujo de ejecución.
- La versión actual del documento no especifica si la comparación se interpreta con signo o sin signo; esta convención debe fijarse en la especificación final.

#### Instrucción `mayoroigual`

Descripción: Compara los valores contenidos en `rf1` y `rf2`. Si el valor de `rf1` es mayor o igual que el valor de rf2, el Program Counter (PC) se modifica sumándole el inmediato. Si la condición es falsa, el salto no se realiza.

Operación:

```
if (rf1 >= rf2) PC += inmediato
```

Ejemplo en ensamblador:

```
# Saltar con desplazamiento 5 si x9 es mayor o igual que x10
mayoroigual   rf1=9, rf2=10, inmediato=5
```

Restricciones:

- `rf1` y `rf2` pueden identificar cualquiera de los 32 registros (`x0–x31`).
- El inmediato debe codificarse utilizando los 11 bits disponibles del campo [10:0].
- La instrucción no escribe un registro de propósito general; únicamente puede modificar el flujo de ejecución.
- La versión actual del documento no especifica si la comparación se interpreta con signo o sin signo; esta convención debe fijarse en la especificación final.

## Instrucciones tipo Registro

| [31:25] | [24:21] | [20:16] | [15:11] | [10:6] |
|:---:|:---:|:---:|:---:|:---:|
| **Tipo de operación** | **ID operación** | **rg** | **rf1** | **rf2** |
| 7 bits | 4 bits | 5 bits | 5 bits | 5 bits |

La distribución de los campos es la siguiente:

- Tipo de operación: 7 bits.
- ID operación: 4 bits para identificar la operación específica.
- rf1: 5 bits para identificar el registro fuente 1.
- rf2: 5 bits para identificar el registro fuente 2.
- rg: 5 bits para identificar el registro rg.

| Tipo de operación | ID operación | Instrucción | Operación |
|:---|:---|:---|:---|
| 1101010 | 1000 | `suma` | rg = rf1 + rf2 |
| 1101010 | 1001 | `resta` | rg = rf1 - rf2 |
| 1101010 | 1011 | `corrimiento izquierdo` | rg = rf1 << rf2 |
| 1101010 | 1111 | `corrimiento derecho` | rg = rf1 >> rf2 |
| 1101010 | 1010 | `corrimiento aritmetico derecho` | rg = rf1 >> rf2 |
| 1101010<br>1101010 | 1110 | `xor` | rg = rf1 XOR rf2 |
| 1101010 | 1100 | `and` | rg = rf1&rf2 |
| 1101010 | 1101 | `or` | rg = rf1\|rf2 |
| 1101010 | 0101 | `mrq` | rg = rf1<rf2 |
| 1101010 | 0110 | `myq` | rg = rf1>rf2 |

### Explicación de las instrucciones

`suma`: suma el contenido de los dos registros `rf1` y `rf2` de 32 bits y los guarda en el registro `rg`.

`resta`: resta el contenido de los dos registros `rf1` y `rf2` de 32 bits y los guarda en el registro `rg`.

Corrimiento izquierdo: desplaza los bits de `rf1` hacia la izquierda la cantidad de posiciones indicada por rf2, el resultado se almacena en rg.

Ejemplo:

```
Si rf1 = 5 (0101) y rf2 = 2:

rg = 0101 << 2 = 010100 = 20
```

Corrimiento derecho: desplaza los bits de `rf1` hacia la derecha, rellenando con ceros. La cantidad de posiciones es indicada por `rf2`.

Ejemplo:

```
Si rf1 = 20 (10100) y rf2 = 2:

rg = 10100 >> 2 = 00101 = 5
```

Corrimiento aritmetico derecho: desplaza los bits de `rf1` hacia la derecha, conservando el bit de signo. La cantidad de posiciones es indicada por `rf2`.

Ejemplo:

```
Si rf1 = -8 y rf2 = 2:

rg = -8 >>> 2 = -2
```

`xor`: realiza una operación `xor` bit a bit entre `rf1` y `rf2`, almacenando el resultado en `rg`.

Ejemplo:

```
rf1 = 1010
rf2 = 1100
      ----
rg  = 0110
```

`and`: realiza una operación `and` bit a bit entre `rf1` y `rf2`, almacenando el resultado en `rg`.

Ejemplo:

```
rf1 = 1010
rf2 = 1100
      ----
rg  = 1000

rg = 8
```

`or`: realiza una operación `or` bit a bit entre `rf1` y `rf2`, almacenando el resultado en `rg`.

Ejemplo:

```
rf1 = 1010
rf2 = 1100
      ----
rg  = 1110

rg = 14
```

`mrq`: Compara los valores de `rf1` y `rf2` y determina si `rf1` es menor que `rf2`.

```
rg = (rf1 < rf2)
```

Ejemplo:

```
Si rf1 = 5 y rf2 = 10:

rg = (5 < 10) = 1

Si la condición no se cumple, rg = 0
```

`myq`: Compara los valores de `rf1` y `rf2` y determina si `rf1` es mayor que `rf2`.

```
rg = (rf1 > rf2)
```

Ejemplo:

```
Si rf1 = 10 y rf2 = 5:

rg = (10 > 5) = 1

Si la condición no se cumple, rg = 0
```

### Justificación

La distribución de los campos se realizó tomando en cuenta la necesidad de identificar correctamente la operación y los registros involucrados dentro de una instrucción de 32 bits. Se asignaron 7 bits para el tipo de operación, ya que permite definir una cantidad suficiente de instrucciones disponibles dentro del procesador. Además, se utilizaron 4 bits para el identificador de operación, con el objetivo de diferenciar operaciones específicas que pertenecen a un mismo tipo.

Para los registros se asignaron campos de 5 bits debido a que permiten representar hasta 32 registros diferentes, lo cual brinda una cantidad adecuada de registros de propósito general. Los campos rg, rf1 y rf2 permiten identificar el registro destino y los registros fuente utilizados por la operación, facilitando la lectura y ejecución de la instrucción por parte del procesador.

## Pseudoinstrucciones:

| Pseudo | Expansión |
|:---|:---|
| `nop` | valor hexa: 0x00000000 |
| `mov rg, rf1` | suma rg, rf1, x0 |
| `not rg, rf1` | xori rg, rf1, -1 |

Las resuelve el ensamblador

## Registros de propósito general

32 registros de 32 bits, x0–x31.

| Registro | Nombre ABI | Convención |
|:---|:---|:---|
| `x0` | cero | Constante 0. Las escrituras se descartan. |
| `x1` | ra | Dirección de retorno (escrita por sye por convención). |
| `x2` | sp | Puntero de pila (crece hacia abajo). |
| `x3` | gp | Puntero global. |
| `x4–x15` | t0–t11 | Temporales (no se preservan entre llamadas). |
| `x16–x31` | s0–s15 | Preservados entre llamadas (el llamado los guarda si los usa). |

**gp**: base fija de la zona de datos (p. ej. 0x4000), inicializado una vez al arrancar. Importa porque cargai/guardap sólo tienen 11 bits de desplazamiento (±1 KB): con gp como base, cualquier dato global se alcanza en una sola instrucción (`cargai x8, gp, 16`) en vez de construir la dirección con calta + cbaja en dos bundles. Lo usan las instrucciones de carga y almacenamiento (`cargai`, `cargabai`, `guardap`, `guardab`) como registro base rf1.

## Resumen de la arquitectura

| Parámetro | Valor | Justificación breve |
|:---|:---|:---|
| Ancho de slot | 32 bits | Codificación uniforme; cabe en una palabra de memoria. |
| Slots por bundle | 4 (fijos) | Mínimo del enunciado; un slot por tipo de unidad funcional. |
| Ancho de bundle | 128 bits (16 bytes) | Potencia de 2: el PC avanza 16 bytes y el fetch lee una línea alineada. |
| Asignación de slots | Slot 0 = ALU · Slot 1 = LSU · Slot 2 = BRU · Slot 3 = CRIPTO | Esquema de slots fijos: el despacho no necesita campo de selección. |
| NOP | 0x00000000 en cualquier slot | El `TIPO = 0000000` no se usa por ninguna FU activa (ALU=1000000/1101010, LSU=1001001, BRU=1000001/1001011, Cripto=0000010), por lo que el decodificador lo reconoce como NOP en cualquier slot sin invocar ninguna unidad funcional. |
| Registros | 32 × 32 bits (x0–x31), x0 = 0 | Campos de 5 bits; x0 constante. |
| PC | 32 bits, alineado a 16 bytes | Direccionamiento por byte, bundle alineado. |
| Registro de estado | ESTADO (32 bits) | Autenticación. |
| Memoria | 64 KB mínimo, byte-direccionable, little-endian, direcciones de 32 bits | Requisito del enunciado. |
| Bóveda de llaves | 4 llaves × 128 bits (4 subllaves de 32 bits) + contraseña de 32 bits | Sólo accesible por la unidad criptográfica. |
| Calendarización | Estática. Sin forwarding, sin stalls. | Requisito del enunciado. |

## Diagrama de organización de la arquitectura

![Diagrama de organización de la arquitectura](img/diagrama_organizacion.png)

## Contribuciones

**Javier:**

Mi aporte se centró en las instrucciones tipo control, desarrollando la codificación y documentación de igualsi, igualno, menora y mayoroigual, incluyendo formato, campos, operación y restricciones.

También trabajé en la interpretación de la organización del procesador según la notación del libro, adaptándola a una representación segmentada de 5 etapas.

**Fabricio:**

Mi aporte fue la creación de la tabla **Resumen de la arquitectura** donde se detalla el parámetro seleccionado, su tamaño/valor, y una breve explicación de su selección.

Además de la selección de las pseudoinstrucciones soportadas (tabla **Pseudoinstrucciones**) según las instrucciones actuales del ISA.

También realicé la tabla **Registros de propósito general** con los registros disponibles y su convención de uso para nuestro ISA.

**Dylan:**

Mi aporte fue el desarrollo de la codificación de las instrucciones tipo almacenamiento con un campo de tipo de 7 bits, un ID de operación de 4 bits (estos siendo definidos en acuerdo con todo el equipo tanto en su tamaño como posición), dos registros fuente con un campo de 5 bits para representar los 32 registros posibles y un campo de offset de 11 bits. Además dejé ejemplos de cómo se vería un código en ensamblador de dichas instrucciones

También contribuí en la organización de la arquitectura del procesador junto con Javier con el objetivo de implementar un pipeline de 5 etapas y mostrar como se conectan los diferentes componentes de la arquitectura unos con otros

**Alejandro:**

Mi aporte fue la estructura del set de instrucciones de la unidad criptográfica. Principalmente fue definir la organización del slot (prefijo tipo 7 bits + ID operación de 4 bits, con 21 bits para operandos físicos) y proponer las instrucciones que lo componen: FSL y FSLI para las rondas Feistel (cifrado y descifrado de una ronda por invocación, exponiendo paralelismo entre slots), ELL para escribir llaves en la bóveda, VCR para validar credenciales comparando contra la contraseña maestra que reside en la bóveda, CAMCON para renovar dicha contraseña mediante rotación lógica circular, y SETPWD para inicializarla al arranque. Decidí también cómo se distribuyen los operandos en cada slot (por ejemplo, el inmediato de rotación en CAMCON o la dirección del candidato y el resultado implícito en `ESTADO[0]` para VCR), buscando que la cripto FU pueda operar **sin** pasar datos sensibles por buses de propósito general. También definí la política de control de acceso mediante `ESTADO[0]` (bit AUTH): sólo código autenticado puede ejecutar `fsl`/`fsli`/`ell`/`camcom`; el resto genera excepción de privilegio.

**José:**

Mi aporte se centró en la especificación de las instrucciones tipo registro-registro e inmediato del ISA. A partir del formato de 32 bits definido, desarrollé la documentación de las operaciones, detallando la codificación de cada instrucción.

Para cada instrucción se describí su operación, formato en ensamblador y ejemplos de funcionamiento, mostrando la interacción entre los registros fuente, registros destino y valores inmediatos. Además, se explicó la forma en que estas instrucciones modifican los datos almacenados en los registros o permiten acceder a posiciones específicas de memoria mediante cálculos de dirección. También realicé la de salto (sye).
