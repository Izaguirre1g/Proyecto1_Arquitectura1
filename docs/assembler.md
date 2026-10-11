# Ensamblador

Requiere Python 3.10 o posterior, sin paquetes externos. Cada línea contiene
un bundle de 128 bits:

```asm
sumai x4,x0,7 | nop | nop | nop
nop
nop
nop | guardap x0,x4,256 | nop | nop
```

Orden: **ALU | LSU | BRU | CRIPTO**. `nop` solo en una línea ocupa los cuatro
slots. Se aceptan comentarios `#`, `;` y `//`, registros `x0`–`x31` e inmediatos
decimales, hexadecimales (`0x`) y binarios (`0b`).

```bash
python3 tools/assembler.py --input examples/mixto.asm \
  --output build/mixto.mem --binary build/mixto.bin --listing build/mixto.lst
make test-assembler
```

`.mem` contiene 32 dígitos hexadecimales por bundle, con CRIPTO en los bits
altos y ALU en los bajos. Es el archivo para `$readmemh` en `IMEM.memory`.
`.bin` conserva ese valor en 16 bytes little-endian por bundle. El listado
muestra PC, línea fuente y slots. La IMEM admite `IMEM_BUNDLES` bundles (1024,
definido en `rtl/isa_defs.sv`); el último es el manejador de excepciones (`TRAP_VECTOR`).
`load_file.py` genera palabras de 32 bits o bytes para memoria de datos;
no se debe usar su salida de 32 bits directamente como bundles de IMEM.

## Instrucciones

- ALU de tres registros: `suma`, `resta`, `cader`, `cizq`, `and`, `or`, `xor`,
  `cder`, `mrq`, `myq`; sintaxis `operación destino, fuente1, fuente2`.
- ALU inmediata: `sumai`, `restai`, `cizqi`, `cderi`, `caderi`, `xori`, `andi`,
  `ori`; sintaxis `operación destino, fuente, inmediato`. Rango con signo:
  −1024 a 1023. Los desplazamientos admiten 0 a 2047; la ALU usa los 5 bits bajos.
- Cargas: `cargai destino, base, offset` y `cargabai destino, base, offset`.
  La carga de byte extiende el signo.
- Almacenamientos: `guardap base, dato, offset` y `guardab base, dato, offset`.
  Offset de memoria: −1024 a 1023, en bytes.
- Control: `igualsi fuente1, fuente2, destino`, `igualno`, `menora`,
  `mayoroigual`; `sye registro_enlace, destino`; `syer registro_enlace, base, offset`
  salta a `base + offset` (offset de −1024 a 1023 bytes; el hardware pone en 0 los
  4 bits bajos del destino). Ambos guardan PC + 16, el bundle siguiente.
- Cripto: `fsl rd, r1, LK, RK`, `fsli rd, r1, LK, RK`,
  `ell LK, off, rs1, rs2`, `vcr dirección`, `camcon dirección, rotación`,
  `setpwd registro`. `camcom` se admite como alias de `camcon`.
- Pseudoinstrucciones: `mov rd, rs`, `not rd, rs`, `nop` y `ret`
  (`syer x0, ra, 0`, vuelve de una subrutina).

En cripto también se admiten los campos nombrados de la especificación,
por ejemplo `fsl rd=6, r1=2, LK=0, RK=1`. Los pares de Feistel empiezan en un
registro par de x2 a x30. LK/RK van de 0 a 3; ELL exige registros pares y
offset 0 o 2. Direcciones cripto: 0 a 65535; rotación: 0 a 31.
El ensamblador valida campos; autenticación, INIT y permisos se comprueban
al ejecutar en la unidad criptográfica.

## Etiquetas y dependencias

```asm
inicio: nop
nop | nop | igualno x4,x5,inicio | nop
```

El destino puede ser etiqueta o desplazamiento con signo **en bytes desde
el PC del bundle del salto**. Debe caer en un bundle del programa. Los saltos
condicionales usan 11 bits; `sye`, 16 bits. Se exige alineación de 16 bytes.
`syer` no usa etiquetas: su destino sale de un registro. Para el chequeo de
dependencias no tiene sucesor, porque después de un salto tomado los 2 bundles
anulados ya cubren la latencia del banco de registros.

El ensamblador rechaza slots incorrectos, dos escrituras al mismo registro y
lecturas de resultados producidos en otro slot del mismo bundle. Entre un
productor y un consumidor exige dos bundles intermedios. Revisa ambas rutas
de los saltos y los ciclos, sin descontar la penalización de flush; por eso
puede pedir NOP adicionales en destinos de saltos. No inserta ni reordena código.
La revisión cubre registros, no alias de memoria ni latencias de la bóveda.

Los alias siguen el ABI de `ISA_Proyecto.md`: `ra=x1`, `sp=x2`, `gp=x3`,
`t0..t11=x4..x15`, `s0..s15=x16..x31`.

## Referencias

La referencia es [ISA_Proyecto.md](../ISA_Proyecto.md) de este repositorio. 
`make test-programs` ejecuta los ejemplos sobre el RTL, cripto incluida, y
`make archivo` verifica el cifrado de un archivo contra la referencia.
