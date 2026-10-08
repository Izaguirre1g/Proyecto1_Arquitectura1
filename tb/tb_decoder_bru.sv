/*
================================================================================
 Testbench: tb_decoder_bru
 ------------------------------------------------------------------------------
 Verificación autoverificable del decoder de instrucciones BRU
 (rtl/decoder_bru.sv).

 Casos cubiertos:
     1. igualsi      → is_branch=1, bru_op=OP_IGUALSI, we=0
     2. igualno      → is_branch=1, we=0
     3. menora       → is_branch=1, we=0
     4. mayoroigual  → is_branch=1, we=0
     5. sye          → is_jump=1, we=1, jmp_imm de 16 bits
     6. Verificar extracción de rs1, rs2, br_imm en branches condicionales.
     7. Verificar extracción de rd, jmp_imm en sye.
     8. Tipo que no es BRU → todo en 0.
     9. Barrido de IDs para TYPE_BRU_COND.

================================================================================
*/

`timescale 1ns/1ps


module tb_decoder_bru;

`include "tb_utils.svh"


// ============================================================================
// DUT
// ============================================================================

logic [31:0] instruction;

logic [3:0]  bru_op;
logic [4:0]  rd;
logic [4:0]  rs1;
logic [4:0]  rs2;
logic [10:0] br_imm;
logic [15:0] jmp_imm;
logic        is_branch;
logic        is_jump;
logic        we;


decoder_bru DUT (
    .instruction(instruction),
    .bru_op(bru_op),
    .rd(rd),
    .rs1(rs1),
    .rs2(rs2),
    .br_imm(br_imm),
    .jmp_imm(jmp_imm),
    .is_branch(is_branch),
    .is_jump(is_jump),
    .we(we)
);


// Helper: codifica branch condicional
function automatic logic [31:0] encode_cond(
    input logic [3:0] op_id,
    input logic [4:0] _rs1,
    input logic [4:0] _rs2,
    input logic [10:0] _imm
);
    return {
        TYPE_BRU_COND,
        op_id,
        _rs1,
        _rs2,
        _imm
    };
endfunction


// Helper: codifica sye
function automatic logic [31:0] encode_sye(
    input logic [4:0] rg,
    input logic [15:0] offset
);
    return {
        TYPE_BRU_JUMP,
        OP_SYE,
        rg,
        offset
    };
endfunction


initial begin

    $dumpfile("tb_decoder_bru.vcd");
    $dumpvars(0, tb_decoder_bru);


    // =====================================================================
    // 1. igualsi
    // =====================================================================
    tb_section("1. igualsi");

    instruction = encode_cond(OP_IGUALSI, 5'd3, 5'd4, 11'sd16);
    #1;
    check("igualsi: bru_op", bru_op, OP_IGUALSI);
    check("igualsi: rs1", rs1, 5'd3);
    check("igualsi: rs2", rs2, 5'd4);
    check("igualsi: br_imm", br_imm, 11'sd16);
    check_true("igualsi: is_branch", is_branch === 1'b1);
    check_true("igualsi: !is_jump",   is_jump   === 1'b0);
    check_true("igualsi: we = 0",     we        === 1'b0);


    // =====================================================================
    // 2. igualno
    // =====================================================================
    tb_section("2. igualno");

    instruction = encode_cond(OP_IGUALNO, 5'd5, 5'd6, 11'sd32);
    #1;
    check("igualno: bru_op", bru_op, OP_IGUALNO);
    check("igualno: br_imm", br_imm, 11'sd32);


    // =====================================================================
    // 3. menora
    // =====================================================================
    tb_section("3. menora");

    instruction = encode_cond(OP_MENORA, 5'd7, 5'd8, -11'sd4);
    #1;
    check("menora: bru_op", bru_op, OP_MENORA);
    check("menora: br_imm (negativo, 11 bits)", br_imm, 11'h7FC);


    // =====================================================================
    // 4. mayoroigual
    // =====================================================================
    tb_section("4. mayoroigual");

    instruction = encode_cond(OP_MAYOROIGUAL, 5'd9, 5'd10, 11'sd5);
    #1;
    check("mayoroigual: bru_op", bru_op, OP_MAYOROIGUAL);


    // =====================================================================
    // 5. sye
    // =====================================================================
    tb_section("5. sye");

    instruction = encode_sye(5'd1, 16'sd256);
    #1;
    check("sye: bru_op", bru_op, OP_SYE);
    check("sye: rd", rd, 5'd1);
    check("sye: jmp_imm", jmp_imm, 16'sd256);
    check_true("sye: is_jump", is_jump === 1'b1);
    check_true("sye: !is_branch", is_branch === 1'b0);
    check_true("sye: we = 1", we === 1'b1);


    // =====================================================================
    // 6. sye con offset negativo
    // =====================================================================
    tb_section("6. sye offset negativo");

    instruction = encode_sye(5'd2, 16'hFC00);  // -1024 en 16 bits
    #1;
    check("sye-: rd", rd, 5'd2);
    check("sye-: jmp_imm (16 bits)", jmp_imm, 16'hFC00);


    // =====================================================================
    // 7. Tipo que no es BRU
    // =====================================================================
    tb_section("7. Tipo que no es BRU");

    instruction = {
        TYPE_REG,
        OP_SUM,
        5'd5, 5'd2, 5'd3,
        11'b0
    };
    #1;
    check_true("no BRU: is_branch = 0", is_branch === 1'b0);
    check_true("no BRU: is_jump = 0",   is_jump === 1'b0);
    check_true("no BRU: we = 0",        we === 1'b0);


    // =====================================================================
    // 8. Barrido IDs TYPE_BRU_COND
    // =====================================================================
    tb_section("8. Barrido de los 16 IDs en TYPE_BRU_COND");

    for (int i = 0; i < 16; i++) begin

        instruction = encode_cond(i[3:0], 5'd0, 5'd0, 11'd0);
        #1;
        check_true($sformatf("ID=%0b: is_branch", i[3:0]), is_branch === 1'b1);
        check      ($sformatf("ID=%0b: bru_op", i[3:0]), bru_op, i[3:0]);
    end


    tb_finish("tb_decoder_bru");
end

endmodule