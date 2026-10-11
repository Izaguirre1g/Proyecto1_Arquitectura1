/*
================================================================================
 Módulo: decoder_bru

 Descripción:
 ------------------------------------------------------------------------------
 Decoder de instrucciones BRU (slot 2 del bundle).

 Tipos soportados:
     - TYPE_BRU_COND = 7'b1000001
         ID 0001 = igualsi       if (rf1 == rf2) PC += off
         ID 0010 = igualno       if (rf1 != rf2) PC += off
         ID 0100 = menora        if (rf1 <  rf2) PC += off   (signed)
         ID 1000 = mayoroigual   if (rf1 >= rf2) PC += off   (signed)
     - TYPE_BRU_JUMP = 7'b1001011
         ID 0000 = sye           rg = PC + 16; PC = PC + offset
         ID 0001 = syer          rg = PC + 16; PC = (rf1 + offset) & ~15
         ID 0010-1111            reservados: se decodifican como NOP

 Las instrucciones de control (condicionales) NO escriben en el regfile.
 sye y syer sí escriben (rg = dirección de retorno).

 syer lee rf1 de [15:11] y usa el offset de 11 bits [10:0] (salida br_imm),
 por eso sale por rs1 hacia el puerto de lectura del BRU.

 Genera las señales de control para la unidad bru.sv.

 Este módulo es combinacional.

================================================================================
*/

`include "isa_defs.sv"


module decoder_bru(

    input  logic [31:0] instruction,

    // Salidas hacia ID/EX (bru)
    output logic [3:0]  bru_op,        // OP_IGUALSI / OP_IGUALNO / OP_MENORA / OP_MAYOROIGUAL / OP_SYE / OP_SYER
    output logic [4:0]  rd,            // registro destino (sólo usado por sye y syer → rg)
    output logic [4:0]  rs1,           // registro fuente 1 (en syer, la dirección base)
    output logic [4:0]  rs2,           // registro fuente 2
    output logic [10:0] br_imm,        // offset de 11 bits (signed) para branch cond y syer
    output logic [15:0] jmp_imm,       // offset de 16 bits (signed) para sye
    output logic        is_branch,     // 1 si es branch condicional
    output logic        is_jump,       // 1 si es sye o syer
    output logic        we             // 1 si la instrucción escribe en regfile (sye y syer)
);

logic [6:0] instr_type;
logic [3:0] id;


always @(*) begin

    // Valores por defecto: el slot está inactivo (NOP)
    bru_op   = 4'b0;
    rd       = 5'b0;
    rs1      = 5'b0;
    rs2      = 5'b0;
    br_imm   = 11'b0;
    jmp_imm  = 16'b0;
    is_branch = 1'b0;
    is_jump   = 1'b0;
    we       = 1'b0;

    instr_type = instruction[31:25];
    id         = instruction[24:21];

    case (instr_type)

        // ---------------------------------------------------------------------
        // Branches condicionales
        // Formato: tipo (7) | id (4) | rf1 (5) | rf2 (5) | offset (11)
        // ---------------------------------------------------------------------
        TYPE_BRU_COND: begin

            rs1     = instruction[20:16];
            rs2     = instruction[15:11];
            br_imm  = instruction[10:0];
            is_branch = 1'b1;
            we      = 1'b0;   // branches condicionales no escriben regfile
            bru_op  = id;

        end

        // ---------------------------------------------------------------------
        // Jumps
        // sye:  tipo (7) | id (4) | rg (5) | offset (16)
        // syer: tipo (7) | id (4) | rg (5) | rf1 (5) | offset (11)
        // Un ID reservado queda en NOP (valores por defecto).
        // ---------------------------------------------------------------------
        TYPE_BRU_JUMP: begin

            if (id == OP_SYE) begin
                rd      = instruction[20:16];
                jmp_imm = instruction[15:0];
                is_jump = 1'b1;
                we      = 1'b1;   // sye sí escribe (rg = PC + 16)
                bru_op  = id;
            end
            else if (id == OP_SYER) begin
                rd      = instruction[20:16];
                rs1     = instruction[15:11];
                br_imm  = instruction[10:0];
                is_jump = 1'b1;
                we      = 1'b1;   // syer sí escribe (rg = PC + 16)
                bru_op  = id;
            end

        end

        // Cualquier otro tipo: NOP
        default: begin
            bru_op   = 4'b0;
            rd       = 5'b0;
            rs1      = 5'b0;
            rs2      = 5'b0;
            br_imm   = 11'b0;
            jmp_imm  = 16'b0;
            is_branch = 1'b0;
            is_jump   = 1'b0;
            we       = 1'b0;
        end

    endcase
end

endmodule