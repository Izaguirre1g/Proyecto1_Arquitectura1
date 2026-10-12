/*
Este módulo pertenece a la etapa Instruction Decode (ID).

Recibe la instrucción correspondiente al slot ALU del procesador VLIW y genera
las señales de control necesarias para la ejecución en la unidad ALU.

El decoder interpreta:
    - Tipo de instrucción [31:25]
    - ID de operación [24:21]
    - Registros fuente/destino
    - Valor inmediato

Las instrucciones soportadas corresponden a operaciones ALU de tipo registro
y tipo inmediato.
Este módulo es combinacional, por lo que no posee reloj ni almacenamiento.
*/

`include "rtl/isa_defs.sv"


module decoder_alu(

    input logic [31:0] instruction,

    output logic [3:0] alu_op,

    output logic [4:0] rd,
    output logic [4:0] rs1,
    output logic [4:0] rs2,

    output logic [10:0] imm,

    output logic use_imm

);

logic [6:0] instr_type;
logic [3:0] id;


always @(*) begin


    // Valores por defecto

    alu_op = ALU_ADD;

    rd  = 5'b0;
    rs1 = 5'b0;
    rs2 = 5'b0;

    imm = 11'b0;

    use_imm = 1'b0;

    // Extracción de campos

    instr_type = instruction[31:25];
    id   = instruction[24:21];

    case(instr_type)
        // ==========================================
        // Instrucciones tipo registro
        // ==========================================

        TYPE_REG: begin

            rd  = instruction[20:16];
            rs1 = instruction[15:11];
            rs2 = instruction[10:6];
            case(id)

                OP_SUM:
                    alu_op = ALU_ADD;


                OP_RESTA:
                    alu_op = ALU_SUB;


                OP_CIZQ:
                    alu_op = ALU_SLL;


                OP_CDER:
                    alu_op = ALU_SRL;


                OP_CADER:
                    alu_op = ALU_SRA;


                OP_XOR:
                    alu_op = ALU_XOR;


                OP_AND:
                    alu_op = ALU_AND;


                OP_OR:
                    alu_op = ALU_OR;

                OP_MRQ:
                    alu_op = ALU_LT;

                OP_MYQ:
                     alu_op = ALU_GT;
                     
                default:
                    alu_op = ALU_ADD;

            endcase

        end

        // ==========================================
        // Instrucciones tipo inmediato
        // ==========================================

        TYPE_IMM: begin

            rs1 = instruction[20:16];
            rd  = instruction[15:11];

            imm = instruction[10:0];

            use_imm = 1'b1;


            case(id)

                OP_SUMI:
                    alu_op = ALU_ADD;


                OP_RESTAI:
                    alu_op = ALU_SUB;


                OP_CIZQI:
                    alu_op = ALU_SLL;


                OP_CDERI:
                    alu_op = ALU_SRL;


                OP_CADERI:
                    alu_op = ALU_SRA;


                OP_XORI:
                    alu_op = ALU_XOR;


                OP_ANDI:
                    alu_op = ALU_AND;


                OP_ORI:
                    alu_op = ALU_OR;


                default:
                    alu_op = ALU_ADD;

            endcase
        end
        default: begin
            alu_op = ALU_ADD;
        end
    endcase
end
endmodule