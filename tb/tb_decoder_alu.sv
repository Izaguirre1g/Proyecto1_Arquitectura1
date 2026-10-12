`timescale 1ns/1ps

/*
================================================================================
 Testbench: tb_decoder_alu

 Descripción:
 ------------------------------------------------------------------------------
 Verifica el decoder del slot ALU (rtl/decoder_alu.sv).

 Casos:
   1. Las 10 instrucciones tipo registro: código interno de la ALU y campos
      rg [20:16], rf1 [15:11], rf2 [10:6]; use_imm = 0.
   2. Las 8 instrucciones tipo inmediato: código interno y campos
      rf1 [20:16], rg [15:11], inm [10:0]; use_imm = 1.
   3. Campos en sus extremos: registros x31 e inmediatos 0x7FF y 0x400.
   4. Otros tipos (LSU, BRU, CRIPTO, NOP y 0xFFFFFFFF): rd = x0 y
      use_imm = 0, así que el slot no escribe ningún registro.

================================================================================
*/

`include "isa_defs.sv"


module tb_decoder_alu;

`include "tb_utils.svh"


logic [31:0] instruction;
logic [3:0]  alu_op;
logic [4:0]  rd;
logic [4:0]  rs1;
logic [4:0]  rs2;
logic [10:0] imm;
logic        use_imm;


decoder_alu DUT (
    .instruction(instruction),
    .alu_op(alu_op),
    .rd(rd),
    .rs1(rs1),
    .rs2(rs2),
    .imm(imm),
    .use_imm(use_imm)
);


// Instrucciones del ISA: ID y código interno esperado
function automatic logic [3:0] reg_id(input int i);

    case (i)
        0: return OP_SUM;    1: return OP_RESTA;  2: return OP_CADER;  3: return OP_CIZQ;
        4: return OP_AND;    5: return OP_OR;     6: return OP_XOR;    7: return OP_CDER;
        8: return OP_MRQ;    default: return OP_MYQ;
    endcase
endfunction

function automatic logic [3:0] reg_alu(input int i);

    case (i)
        0: return ALU_ADD;   1: return ALU_SUB;   2: return ALU_SRA;   3: return ALU_SLL;
        4: return ALU_AND;   5: return ALU_OR;    6: return ALU_XOR;   7: return ALU_SRL;
        8: return ALU_LT;    default: return ALU_GT;
    endcase
endfunction

function automatic logic [3:0] imm_id(input int i);

    case (i)
        0: return OP_SUMI;   1: return OP_RESTAI; 2: return OP_CIZQI;  3: return OP_CDERI;
        4: return OP_CADERI; 5: return OP_XORI;   6: return OP_ANDI;   default: return OP_ORI;
    endcase
endfunction

function automatic logic [3:0] imm_alu(input int i);

    case (i)
        0: return ALU_ADD;   1: return ALU_SUB;   2: return ALU_SLL;   3: return ALU_SRL;
        4: return ALU_SRA;   5: return ALU_XOR;   6: return ALU_AND;   default: return ALU_OR;
    endcase
endfunction


task automatic expect_dec(input string name, input logic [31:0] instr,
                          input logic [3:0] e_op, input logic [4:0] e_rd, input logic [4:0] e_rs1,
                          input logic [4:0] e_rs2, input logic [10:0] e_imm, input logic e_use_imm);

    instruction = instr;
    #1;
    check({name, ": alu_op"},  alu_op, e_op);
    check({name, ": rd"},      rd, e_rd);
    check({name, ": rs1"},     rs1, e_rs1);
    check({name, ": rs2"},     rs2, e_rs2);
    check({name, ": imm"},     imm, e_imm);
    check({name, ": use_imm"}, use_imm, e_use_imm);
endtask


initial begin

    $dumpfile("tb_decoder_alu.vcd");
    $dumpvars(0, tb_decoder_alu);


    tb_section("1. Tipo registro");

    // Caso original: suma x5, x2, x3
    expect_dec("suma x5,x2,x3", {TYPE_REG, OP_SUM, 5'd5, 5'd2, 5'd3, 6'b0},
               ALU_ADD, 5'd5, 5'd2, 5'd3, 11'd0, 1'b0);

    for (int i = 0; i < 10; i++)
        expect_dec($sformatf("registro ID %b", reg_id(i)),
                   {TYPE_REG, reg_id(i), 5'd7, 5'd8, 5'd9, 6'b0},
                   reg_alu(i), 5'd7, 5'd8, 5'd9, 11'd0, 1'b0);


    tb_section("2. Tipo inmediato");

    // Caso original: sumai x5, x2, 10 (rf1 = x2, rg = x5)
    expect_dec("sumai x5,x2,10", {TYPE_IMM, OP_SUMI, 5'd2, 5'd5, 11'd10},
               ALU_ADD, 5'd5, 5'd2, 5'd0, 11'd10, 1'b1);

    for (int i = 0; i < 8; i++)
        expect_dec($sformatf("inmediato ID %b", imm_id(i)),
                   {TYPE_IMM, imm_id(i), 5'd12, 5'd13, 11'h155},
                   imm_alu(i), 5'd13, 5'd12, 5'd0, 11'h155, 1'b1);


    tb_section("3. Campos en sus extremos");

    expect_dec("suma x31,x31,x31", {TYPE_REG, OP_SUM, 5'd31, 5'd31, 5'd31, 6'b0},
               ALU_ADD, 5'd31, 5'd31, 5'd31, 11'd0, 1'b0);
    expect_dec("sumai con inm = 1023", {TYPE_IMM, OP_SUMI, 5'd31, 5'd31, 11'h3FF},
               ALU_ADD, 5'd31, 5'd31, 5'd0, 11'h3FF, 1'b1);
    expect_dec("sumai con inm = -1024", {TYPE_IMM, OP_SUMI, 5'd1, 5'd2, 11'h400},
               ALU_ADD, 5'd2, 5'd1, 5'd0, 11'h400, 1'b1);


    tb_section("4. Otros tipos: el slot no escribe");

    expect_dec("NOP",                32'h0000_0000, ALU_ADD, 5'd0, 5'd0, 5'd0, 11'd0, 1'b0);
    expect_dec("0xFFFFFFFF",         32'hFFFF_FFFF, ALU_ADD, 5'd0, 5'd0, 5'd0, 11'd0, 1'b0);
    expect_dec("guardap (LSU)",      {TYPE_LSU, OP_GUARDAP, 5'd1, 5'd2, 11'd4},
               ALU_ADD, 5'd0, 5'd0, 5'd0, 11'd0, 1'b0);
    expect_dec("igualsi (BRU)",      {TYPE_BRU_COND, OP_IGUALSI, 5'd1, 5'd2, 11'd16},
               ALU_ADD, 5'd0, 5'd0, 5'd0, 11'd0, 1'b0);
    expect_dec("sye (BRU)",          {TYPE_BRU_JUMP, OP_SYE, 5'd1, 16'd16},
               ALU_ADD, 5'd0, 5'd0, 5'd0, 11'd0, 1'b0);
    expect_dec("fsl (CRIPTO)",       {TYPE_CRYPTO, OP_FSL, 2'd0, 2'd0, 5'd4, 5'd4, 7'b0},
               ALU_ADD, 5'd0, 5'd0, 5'd0, 11'd0, 1'b0);


    tb_finish("tb_decoder_alu");
end

endmodule
