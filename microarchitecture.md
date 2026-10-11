# Organización interna (microarquitectura) — Proyecto Grupal 1

> Archivo: microarchitecture.md  
> Curso: CE4301 – Arquitectura de Computadores I, II Semestre 2026  
> Profesor: Dr.-Ing. Jeferson González Gómez  
> Entrega: Implementación Funcional (Entrega 2, 14 de octubre de 2026).
> Equipo: Dylan Guerrero González, José García Izaguirre, Javier Hernández Castillo, Alejandro Vásquez Oviedo, Fabricio Mena Mejia
> Alcance: Este archivo describe cómo se implementa la ISA documentada en `isa.md` en términos de:
>
> - diagrama de bloques del procesador,
> - datapath segmentado (pipeline IF / ID / EX / WB),
> - dispatch paralelo de los slots del bundle hacia sus unidades funcionales,
> - interfaces hardware de cada unidad funcional (ALU, LSU, BRU, unidad criptográfica, bóveda de llaves),
> - banco de registros y memoria,
> - política de hazards estructurales (no hay forwarding ni scoreboarding; los únicos stalls posibles son los estructurales, documentados caso por caso).
>
> Las decisiones de qué ejecuta cada instrucción (tipo, IDs, operandos, semántica) viven en `isa.md`. Las decisiones de cómo se ejecutan en hardware viven aquí.

---

## Diagrama de organización de la arquitectura

![Diagrama de organización de la arquitectura](img/diagrama_organizacion.png)



### Descripción narrativa del pipeline

El procesador VLIW propio se organiza como un pipeline clásico de cuatro etapas — *Fetch → Decode/Dispatch → Execute → Writeback* — con registros de segmentación (`pipeline_if_id`, `pipeline_id_ex`, `pipeline_ex_wb`) que permiten que bundles distintos se encuentren simultáneamente en etapas distintas. Cada bundle de 128 bits (4 slots de 32 bits) viaja de forma atómica por las cuatro etapas; los slots se despachan en paralelo dentro de cada etapa hacia su unidad funcional asignada.

#### Etapa IF (Instruction Fetch)

- El PC (32 bits, alineado a 16 bytes) apunta al bundle actual en la memoria de instrucciones.
- Se traen los 128 bits del bundle completo (`bundle[127:0]`) más el `PC` actualizado (`PC + 16`).
- Esta es la única etapa que toca la memoria de instrucciones.

#### Etapa ID (Decode / Dispatch)

Los cuatro slots se decodifican en paralelo, uno por decodificador fijo:

- Slot 0 → `Dec ALU`
- Slot 1 → `Dec LSU`
- Slot 2 → `Dec BRU`
- Slot 3 → `Dec CRIPTO`

Cada decodificador reconoce el TIPO de 7 bits y el ID de 4 bits, y produce las señales de control internas para su unidad funcional. Si `TIPO = 0000000` (no utilizado por ninguna unidad activa), el decodificador lo marca como NOP y la unidad funcional no se invoca. El mismo patrón funciona en los cuatro slots: no hay campo de selección de unidad funcional porque la asignación slot→FU es fija por construcción.

A continuación se hace la lectura de registros. El banco de registros expone 8 puertos de lectura (4 slots × 2 lecturas por slot) para que cada slot pueda leer sus operandos fuente `rf1` y `rf2` en un solo ciclo, sin contención con los demás slots.

> Resultado del bypass intra-ciclo: un valor calculado por la ALU/LSU/BRU en EX puede re-entrar al banco de registros en el mismo ciclo (registro WB) y ser leído por un slot posterior del siguiente bundle. Esto cubre dependencias "read-after-write" entre bundles consecutivos, no dentro del mismo bundle (donde la calendarización estática debe insertar un bundle de separación).

#### Etapa EX (Execute)

Las cuatro unidades funcionales operan en paralelo sobre los operandos leídos en ID:

- ALU: suma, resta, AND, OR, XOR, desplazamientos, comparaciones.
- LSU: `cargai`, `cargabai`, `guardap`, `guardab` — accede a la memoria de datos de 64 KB. Una señal `valid_lsu` por slot evita accesos espurios cuando ese slot trae un NOP.
- BRU: `igualsi`, `igualno`, `menora`, `mayoroigual` — genera la decisión de salto y el próximo PC (`PC_nuevo`). La estrategia frente a saltos se documenta en `isa.md`, sección *Estrategia frente a saltos*.
- Unidad criptográfica: `fsl`, `fsli`, `ell`, `vcr`, `camcon`, `setpwd` — realiza una ronda de Feistel4 o una operación sobre la bóveda de llaves, según el ID.

La unidad criptográfica es la única con acceso a la bóveda de llaves (4 llaves × 128 bits + contraseña de 32 bits). La bóveda mantiene una palabra de estado interno (`AUTH`, `INIT`) que la unidad criptográfica consulta antes de ejecutar operaciones privilegiadas; las no autorizadas generan excepción de acceso. Ningún slot de otra unidad funcional puede leer ni escribir la bóveda.

#### Etapa WB (Writeback)

- Se escriben simultáneamente los resultados en el banco de registros desde los cuatro orígenes posibles (ALU, LSU, BRU, unidad criptográfica).
- Para las instrucciones criptográficas que producen un par (L, R) de 64 bits, la escritura se reparte en dos registros consecutivos (`rd` y `rd+1`).
- La palabra ESTADO (32 bits) la mantiene principalmente la unidad criptográfica (banderas `AUTH`, `INIT`) y se expone al programador en la ISA.

#### Política de hazards y sincronización

- Sin forwarding. No hay camino de datos que lleve un resultado de EX hacia un operando de ID en el mismo bundle — la calendarización estática del compilador/ensamblador es quien evita los riesgos de datos.
- Sin scoreboarding. No hay detección dinámica de dependencias; el hardware no emite stalls por dependencias.
- Stalls estructurales únicamente. Pueden ocurrir cuando dos slots intentan tocar un mismo recurso físico en la misma etapa (por ejemplo, dos cargas que combaten por un puerto de memoria de datos). Cada uno debe documentarse y justificarse.
- Sin branch prediction ni delay slots escondidos. Los saltos consumen al menos un bundle de penalización; la métrica concreta está en `isa.md`.

### Banco de registros

- 32 registros de 32 bits, x0–x31.
- `x0` cableado a 0; las escrituras a `x0` se descartan.
- 8 puertos de lectura (4 slots × 2 operandos) y 4 puertos de escritura (uno por unidad funcional).
- Ver convención de uso (`x1`=ra, `x2`=sp, `x3`=gp, `x4–x15`=temporales, `x16–x31`=preservados) en `isa.md`, sección *Registros de propósito general*.

### Memoria

- Memoria de instrucciones (`instruction_memory.sv`): 64 KB mínimo, byte-direccionable, little-endian, cargada desde archivo `.mem` mediante `$readmemh`. Un bundle mide 16 bytes; se carga un bundle por dirección válida.
- Memoria de datos (`memory.sv`): 64 KB mínimo, byte-direccionable, accedida por la LSU y por las herramientas `tools/load_file.py` (carga de archivos a cifrar) y `tools/extract_data.py` (extracción de resultados).
- Ver mapa de memoria detallado en `mapa_memoria.md`.

### Bóveda de llaves (vista hardware)

- 4 entradas × 128 bits = 4 llaves de Feistel4 (cada una particionada en 4 subllaves de 32 bits).
- Contraseña de 32 bits en una palabra separada, accesible únicamente por la unidad criptográfica.
- Banderas internas: `AUTH` (autenticación), `INIT` (modo provisionamiento, sólo `setpwd`).
- Puertos hardware: exclusivamente lectura/escritura desde `crypto_unit.sv`. Sin ruta de escape hacia el banco de registros ni hacia la memoria de datos — el aislamiento entre bóveda y resto del sistema es estricto y se valida por testbench (`tb_key_vault.sv`, ver `simulation.md`).

### Módulos SystemVerilog asociados

| Bloque del diagrama | Archivo principal |
|---|---|
| Fetch (IF) | `rtl/fetch.sv`, `rtl/pc.sv`, `rtl/instruction_memory.sv`, `rtl/pipeline_if_id.sv` |
| Decode/Dispatch (ID) | `rtl/dispatch.sv`, `rtl/decoder_alu.sv`, `rtl/decoder_lsu.sv`, `rtl/decoder_bru.sv`, `rtl/decoder_crypto.sv`, `rtl/id_stage.sv`, `rtl/pipeline_id_ex.sv` |
| Execute (EX) | `rtl/alu.sv`, `rtl/lsu.sv`, `rtl/bru.sv`, `rtl/crypto_unit.sv`, `rtl/key_vault.sv`, `rtl/memory.sv`, `rtl/ex_stage.sv` |
| Writeback (WB) | `rtl/regfile.sv`, `rtl/wb.sv`, `rtl/pipeline_ex_wb.sv` |
| Integración | `rtl/top.sv` (módulo principal) + `rtl/cpu_top.sv` (versiones previas) |
| Banco de registros | `rtl/regfile.sv` (con `tb_regfile.sv` y `tb_regfile_pipeline.sv`) |
| Testbenches de unidad | `tb/tb_alu.sv`, `tb/tb_lsu.sv`, `tb/tb_bru.sv`, `tb/tb_crypto_unit.sv`, `tb/tb_key_vault.sv`, `tb/tb_memory.sv` |
| Testbench de integración | `tb/tb_top.sv`, `tb/tb_pipeline_integracion.sv` |

> Versión diagramada: el diagrama de bloques de esta página corresponde a la versión consolidada del procesador VLIW del equipo, desarrollada en las branches `feat-Pipeline-ALU-RegFile`, `feat-LSU-BRU-Mem`, `feat-Pipeline-Cripto`, e integradas en `fix-Pipeline-Integracion`. Las branches históricas tempranas (`Pipeline`) tienen una versión más simple que aún no incluye la unidad criptográfica ni la BRU/LSU completas.

