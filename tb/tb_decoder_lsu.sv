/*
================================================================================
 Testbench: tb_decoder_lsu
 ------------------------------------------------------------------------------
 Verificación autoverificable del decoder de instrucciones LSU
 (rtl/decoder_lsu.sv).

 Casos cubiertos:
     1. guardap   → lsu_op=OP_GUARDAP, we=0
     2. guardab   → lsu_op=OP_GUARDAB, we=0
     3. cargai    → lsu_op=OP_CARGAI, we=1, rd=instr[15:11]
     4. cargabai  → lsu_op=OP_CARGABAI, we=1, rd=instr[15:11]
     5. Verificar que rs1, rs2 e imm se extraen correctamente.
     6. Slot inactivo (tipo != TYPE_LSU): todas las salidas en 0, we=0.
     7. Tipo LSU con ID desconocido (4'b0010) → no produce resultados.
     8. Verificación de los 16 IDs posibles para TYPE_LSU.

================================================================================
*/

`timescale 1ns/1ps


module tb_decoder_lsu;

`include "tb_utils.svh"


// ============================================================================
// DUT
// ============================================================================

logic [31:0] instruction;

logic [3:0]  lsu_op;
logic [4:0]  rd;
logic [4:0]  rs1;
logic [4:0]  rs2;
logic [10:0] imm;
logic        we;
logic        valid;


decoder_lsu DUT (
    .instruction(instruction),
    .lsu_op(lsu_op),
    .rd(rd),
    .rs1(rs1),
    .rs2(rs2),
    .imm(imm),
    .we(we),
    .valid(valid)
);


// Codificación manual de las 4 instrucciones LSU
function automatic logic [31:0] encode_lsu(
    input logic [3:0] op_id,
    input logic [4:0] _rs1,
    input logic [4:0] _rs2,
    input logic [10:0] _imm
);
    return {
        TYPE_LSU,
        op_id,
        _rs1,
        _rs2,
        _imm
    };
endfunction


initial begin

    $dumpfile("tb_decoder_lsu.vcd");
    $dumpvars(0, tb_decoder_lsu);


    // =====================================================================
    // 1. guardap
    // =====================================================================
    tb_section("1. guardap");

    instruction = encode_lsu(OP_GUARDAP, 5'd3, 5'd8, 11'sd16);
    #1;
    check("guardap: lsu_op", lsu_op, OP_GUARDAP);
    check("guardap: rs1", rs1, 5'd3);
    check("guardap: rs2", rs2, 5'd8);
    check("guardap: imm", imm, 11'sd16);
    check_true("guardap: we = 0 (store)", we === 1'b0);
    check("guardap: valid = 1", valid, 1'b1);


    // =====================================================================
    // 2. guardab
    // =====================================================================
    tb_section("2. guardab");

    instruction = encode_lsu(OP_GUARDAB, 5'd5, 5'd7, 11'd0);
    #1;
    check("guardab: lsu_op", lsu_op, OP_GUARDAB);
    check("guardab: rs1", rs1, 5'd5);
    check("guardab: rs2", rs2, 5'd7);
    check_true("guardab: we = 0", we === 1'b0);
    check("guardab: valid = 1", valid, 1'b1);


    // =====================================================================
    // 3. cargai
    // =====================================================================
    tb_section("3. cargai");

    instruction = encode_lsu(OP_CARGAI, 5'd3, 5'd10, 11'sd32);
    #1;
    check("cargai: lsu_op", lsu_op, OP_CARGAI);
    check("cargai: rs1 (base)", rs1, 5'd3);
    check("cargai: rd (dest)", rd, 5'd10);
    check("cargai: imm", imm, 11'sd32);
    check_true("cargai: we = 1 (load)", we === 1'b1);
    check("cargai: valid = 1", valid, 1'b1);


    // =====================================================================
    // 4. cargabai
    // =====================================================================
    tb_section("4. cargabai");

    instruction = encode_lsu(OP_CARGABAI, 5'd3, 5'd15, 11'sd4);
    #1;
    check("cargabai: lsu_op", lsu_op, OP_CARGABAI);
    check("cargabai: rs1 (base)", rs1, 5'd3);
    check("cargabai: rd (dest)", rd, 5'd15);
    check_true("cargabai: we = 1", we === 1'b1);
    check("cargabai: valid = 1", valid, 1'b1);


    // =====================================================================
    // 5. Tipo que no es LSU → todo en 0
    // =====================================================================
    tb_section("5. Slot inactivo (tipo != TYPE_LSU)");

    instruction = {
        TYPE_REG,         // otro tipo
        OP_SUM,
        5'd5, 5'd2, 5'd3,
        6'b0
    };
    #1;
    check("slot inactivo: lsu_op = 0", lsu_op, 4'b0);
    check("slot inactivo: rd = 0", rd, 5'b0);
    check("slot inactivo: we = 0", we, 1'b0);
    check("slot inactivo: valid = 0", valid, 1'b0);

    // NOP = 0x00000000 deja lsu_op = 0, que es el código de guardap:
    // sólo valid los distingue.
    instruction = 32'h0000_0000;
    #1;
    check("NOP: lsu_op = 0", lsu_op, 4'b0);
    check("NOP: valid = 0 (no es un guardap)", valid, 1'b0);


    // =====================================================================
    // 6. ID desconocido en TYPE_LSU → no produce resultado
    // =====================================================================
    tb_section("6. ID desconocido en TYPE_LSU");

    instruction = encode_lsu(4'b0010, 5'd1, 5'd2, 11'd0);  // ID no usado
    #1;
    check("ID desconocido: we = 0", we, 1'b0);
    check("ID desconocido: valid = 0", valid, 1'b0);


    // =====================================================================
    // 7. Barrido de los 16 IDs
    // =====================================================================
    tb_section("7. Barrido de los 16 IDs en TYPE_LSU");

    for (int i = 0; i < 16; i++) begin

        logic exp_we;
        logic exp_valid;
        exp_we    = (i == OP_CARGAI || i == OP_CARGABAI) ? 1'b1 : 1'b0;
        exp_valid = (i == OP_GUARDAP || i == OP_GUARDAB ||
                     i == OP_CARGAI  || i == OP_CARGABAI) ? 1'b1 : 1'b0;

        instruction = encode_lsu(i[3:0], 5'd0, 5'd0, 11'd0);
        #1;
        check($sformatf("ID=%0b: we", i[3:0]), we, exp_we);
        check($sformatf("ID=%0b: valid", i[3:0]), valid, exp_valid);
    end


    tb_finish("tb_decoder_lsu");
end

endmodule