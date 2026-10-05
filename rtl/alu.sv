/*
================================================================================
 Módulo: alu

 Descripción:
 ------------------------------------------------------------------------------
 Unidad Aritmético Lógica del procesador (slot 0 del bundle).

 Recibe una operación decodificada y dos operandos de 32 bits. Ejecuta la
 operación correspondiente y entrega el resultado.

 La ALU no interpreta instrucciones ni conoce el formato del ISA. Solamente
 utiliza el código interno (ALU_*) generado por decoder_alu. Cuando la
 instrucción es de tipo inmediato, operand_b ya llega con el inmediato de 11
 bits extendido con signo desde la etapa ID.

 Operaciones soportadas e instrucciones del ISA que las usan:
 ------------------------------------------------------------------------------
   ALU_ADD  suma, sumai          a + b (módulo 2^32)
   ALU_SUB  resta, restai        a - b (módulo 2^32)
   ALU_SLL  cizq, cizqi          a << b[4:0]
   ALU_SRL  cder, cderi          a >> b[4:0]   (rellena con ceros)
   ALU_SRA  cader, caderi        a >>> b[4:0]  (replica el bit de signo)
   ALU_XOR  xor, xori            a ^ b
   ALU_AND  and, andi            a & b
   ALU_OR   or, ori              a | b
   ALU_LT   mrq                  1 si a < b con signo, 0 si no
   ALU_GT   myq                  1 si a > b con signo, 0 si no

 Convenciones (ISA, "Convención de comparaciones y de signo"):
 ------------------------------------------------------------------------------
 - Las comparaciones interpretan los operandos en complemento a dos.
 - La cantidad de desplazamiento es una magnitud sin signo: se toman sólo los
   5 bits bajos de operand_b (0–31), igual que en RISC-V o MIPS. Un
   desplazamiento de 32 o más posiciones se reduce módulo 32. Esto también
   evita que un inmediato negativo extendido con signo produzca un
   desplazamiento fuera de rango.
 - Un código de operación no definido produce 0.

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

// Cantidad de desplazamiento: 5 bits sin signo
logic [4:0] shamt;

assign shamt = operand_b[4:0];


always @(*) begin


    case(alu_op)


        ALU_ADD:
            result = operand_a + operand_b;


        ALU_SUB:
            result = operand_a - operand_b;


        ALU_SLL:
            result = operand_a << shamt;


        ALU_SRL:
            result = operand_a >> shamt;


        ALU_SRA:
            result = $signed(operand_a) >>> shamt;


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
