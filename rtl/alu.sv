/*
================================================================================
 Módulo: alu

 Descripción:
 ------------------------------------------------------------------------------
 Unidad Aritmético Lógica del procesador.

 Recibe una operación decodificada y dos operandos de 32 bits. Ejecuta la
 operación correspondiente y entrega el resultado.

 La ALU no interpreta instrucciones ni conoce el formato del ISA. Solamente
 utiliza el código interno generado por el decoder.

 Operaciones soportadas:
 ------------------------------------------------------------------------------
 - Suma
 - Resta
 - Corrimiento lógico izquierdo
 - Corrimiento lógico derecho
 - Corrimiento aritmético derecho
 - XOR
 - AND
 - OR
 - Menor que
 - Mayor que

 Este módulo es completamente combinacional.

================================================================================
*/

`include "isa_defs.sv"


module alu(

    input logic [3:0] alu_op,

    input logic [31:0] operand_a,
    input logic [31:0] operand_b,

    output logic [31:0] result

);


always @(*) begin


    case(alu_op)


        ALU_ADD:
            result = operand_a + operand_b;


        ALU_SUB:
            result = operand_a - operand_b;


        ALU_SLL:
            result = operand_a << operand_b;


        ALU_SRL:
            result = operand_a >> operand_b;


        ALU_SRA:
            result = $signed(operand_a) >>> operand_b;


        ALU_XOR:
            result = operand_a ^ operand_b;


        ALU_AND:
            result = operand_a & operand_b;


        ALU_OR:
            result = operand_a | operand_b;


        ALU_LT:
            result = ($signed(operand_a) < $signed(operand_b)) ? 32'd1 : 32'd0;


        ALU_GT:
            result = ($signed(operand_a) > $signed(operand_b)) ? 32'd1 : 32'd0;


        default:
            result = 32'b0;


    endcase


end


endmodule