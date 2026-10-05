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
 - Register File.

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

    input logic clk,
    input logic reset,

    input logic [31:0] instruction,


    // Escritura desde WB

    input logic [4:0] wb_rd,
    input logic [31:0] wb_data,
    input logic wb_enable,


    // Salidas hacia ID/EX

    output logic [3:0] alu_op,

    output logic [31:0] operand_a,
    output logic [31:0] operand_b,

    output logic [4:0] rd,

    output logic [10:0] imm,

    output logic use_imm

);

logic [4:0] rs1;
logic [4:0] rs2;

logic [31:0] rs1_data;
logic [31:0] rs2_data;

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
// Mientras sólo exista el camino ALU se instancia con 2 lecturas y 1 escritura.
// Al integrar LSU, BRU y CRIPTO, el banco debe compartirse entre los 4 slots
// con su configuración por defecto (8 lecturas / 5 escrituras).
regfile #(

    .NUM_READ_PORTS(2),
    .NUM_WRITE_PORTS(1)

) registers (

    .clk(clk),
    .reset(reset),

    .raddr({rs2, rs1}),
    .rdata({rs2_data, rs1_data}),

    .we(wb_enable),
    .waddr(wb_rd),
    .wdata(wb_data)

);

assign operand_a = rs1_data;
assign operand_b = use_imm ? {{21{imm[10]}},imm} : rs2_data; //Aquí se hace el selector del segundo operando.


endmodule