/*
================================================================================
 Módulo: ex_stage

 Descripción:
 ------------------------------------------------------------------------------
 Etapa Execute (EX) del pipeline.

 Esta etapa recibe la información almacenada en el registro ID/EX y ejecuta la
 operación correspondiente utilizando la ALU.

 Funciones:
 ------------------------------------------------------------------------------
 - Recibir operación de la ALU.
 - Entregar operandos a la ALU.
 - Ejecutar operación.
 - Propagar el registro destino hacia Write Back.

 Este módulo no almacena información, únicamente conecta y ejecuta la lógica
 combinacional de la etapa EX.

================================================================================
*/
module ex_stage(

    input logic [3:0] alu_op,

    input logic [31:0] operand_a,
    input logic [31:0] operand_b,

    input logic [4:0] rd,

    input logic valid_in,


    output logic [31:0] result,

    output logic [4:0] rd_out,

    output logic valid_out

);
    // ALU

    alu alu_unit (

        .alu_op(alu_op),

        .operand_a(operand_a),

        .operand_b(operand_b),

        .result(result)

    );

    // Propagación hacia WB

    always @(*) begin

        rd_out = rd;

        valid_out = valid_in;

    end
endmodule