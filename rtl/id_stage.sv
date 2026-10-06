/*
================================================================================
 Módulo: id_stage

 Descripción:
 ------------------------------------------------------------------------------
 Etapa Instruction Decode (ID) del procesador.
 Esta etapa interpreta la instrucción recibida desde el pipeline IF/ID,
 obtiene los registros fuente desde el banco de registros y genera las señales
 necesarias para la etapa Execute.

 Componentes integrados:
 ------------------------------------------------------------------------------
 - Decoder ALU.
 (El Register File se encuentra en cpu_top.)

 Salidas:
 ------------------------------------------------------------------------------
 - Operación de la ALU.
 - Operandos provenientes del banco de registros.
 - Registro destino.
 - Inmediato.
 - Señales de control.

================================================================================
*/

`include "isa_defs.sv"
module id_stage(

    input logic [31:0] instruction,


    // Banco de registros (vive en cpu_top, compartido entre los 4 slots)

    output logic [4:0] rs1,
    output logic [4:0] rs2,

    input logic [31:0] rs1_data,
    input logic [31:0] rs2_data,


    // Salidas hacia ID/EX

    output logic [3:0] alu_op,

    output logic [31:0] operand_a,
    output logic [31:0] operand_b,

    output logic [4:0] rd,

    output logic [10:0] imm,

    output logic use_imm

);

// Decoder

decoder_alu decoder (

    .instruction(instruction),

    .alu_op(alu_op),

    .rd(rd),

    .rs1(rs1),

    .rs2(rs2),

    .imm(imm),

    .use_imm(use_imm)
);

// Register File
// El banco ya no vive en esta etapa: está en cpu_top con su configuración
// completa (8 lecturas / 5 escrituras) y se comparte entre los 4 slots. Esta
// etapa entrega los índices rs1/rs2 del slot ALU y recibe sus datos leídos.

assign operand_a = rs1_data;
assign operand_b = use_imm ? {{21{imm[10]}},imm} : rs2_data; //Aquí se hace el selector del segundo operando.


endmodule