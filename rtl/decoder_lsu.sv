/*
================================================================================
 Módulo: decoder_lsu

 Descripción:
 ------------------------------------------------------------------------------
 Decoder de instrucciones LSU (slot 1 del bundle).

 Recibe la instrucción de 32 bits del slot LSU y genera las señales de control
 para la unidad de carga/almacenamiento (lsu.sv):

   - Tipo     = 7'b1001001 (TYPE_LSU / TYPE_STORE)
   - ID       = 0000 guardap, 0001 guardab, 1000 cargai, 1001 cargabai

 Decodifica los índices de registro y el offset de 11 bits (signed) que se usa
 para calcular la dirección efectiva en la etapa EX.

 Este módulo es combinacional.

================================================================================
*/

`include "isa_defs.sv"


module decoder_lsu(

    input  logic [31:0] instruction,

    // Salidas hacia ID/EX (lsu)
    output logic [3:0]  lsu_op,        // OP_GUARDAP / OP_GUARDAB / OP_CARGAI / OP_CARGABAI
    output logic [4:0]  rd,            // registro destino (sólo usado por loads)
    output logic [4:0]  rs1,           // registro base (dirección)
    output logic [4:0]  rs2,           // registro dato (stores) / no usado en loads
    output logic [10:0] imm,           // offset de 11 bits (signed, extiende en EX)
    output logic        we             // 1 si la instrucción escribe en regfile
);

logic [6:0] instr_type;
logic [3:0] id;


always @(*) begin

    // Valores por defecto: el slot está inactivo (NOP)
    lsu_op = 4'b0;
    rd     = 5'b0;
    rs1    = 5'b0;
    rs2    = 5'b0;
    imm    = 11'b0;
    we     = 1'b0;

    instr_type = instruction[31:25];
    id         = instruction[24:21];

    case (instr_type)

        TYPE_LSU: begin

            // Formato: tipo (7) | id (4) | rf1 (5) | rf2 (5) | offset (11)
            //   - guardap / guardab: rf2 = dato a escribir
            //   - cargai / cargabai: rd = destino, rf1 = base, rf2 no se usa
            // (Ver ISA_Proyecto.md, "Instrucciones tipo almacenar".)

            rs1 = instruction[20:16];
            rs2 = instruction[15:11];
            rd  = instruction[15:11];
            imm = instruction[10:0];

            case (id)

                OP_GUARDAP: begin
                    lsu_op = OP_GUARDAP;
                    we     = 1'b0;   // store: no escribe regfile
                end

                OP_GUARDAB: begin
                    lsu_op = OP_GUARDAB;
                    we     = 1'b0;
                end

                OP_CARGAI: begin
                    lsu_op = OP_CARGAI;
                    we     = 1'b1;   // load: sí escribe regfile
                end

                OP_CARGABAI: begin
                    lsu_op = OP_CARGABAI;
                    we     = 1'b1;
                end

                default: begin
                    lsu_op = 4'b0;
                    we     = 1'b0;
                end

            endcase
        end

        // Cualquier otro tipo no corresponde al slot LSU: NOP
        default: begin
            lsu_op = 4'b0;
            rd     = 5'b0;
            rs1    = 5'b0;
            rs2    = 5'b0;
            imm    = 11'b0;
            we     = 1'b0;
        end

    endcase
end

endmodule