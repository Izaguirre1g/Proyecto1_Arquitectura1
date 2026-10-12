`timescale 1ns/1ps

/*
================================================================================
 Testbench: tb_dispatch

 Descripción:
 ------------------------------------------------------------------------------
 Verifica el módulo dispatch (rtl/dispatch.sv), que separa el bundle en sus 4
 slots fijos:

     slot 0 = bits [31:0]   ALU        slot 2 = bits [95:64]   BRU
     slot 1 = bits [63:32]  LSU        slot 3 = bits [127:96]  CRIPTO

 Casos:
   1. Bundles con un patrón distinto por slot (casos originales).
   2. valid_out sigue a valid_in.
   3. 500 bundles aleatorios.

================================================================================
*/

`include "isa_defs.sv"


module tb_dispatch;

`include "tb_utils.svh"


logic [BUNDLE_W-1:0] bundle_in;
logic                valid_in;
logic [SLOT_W-1:0]   slot0_instr;
logic [SLOT_W-1:0]   slot1_instr;
logic [SLOT_W-1:0]   slot2_instr;
logic [SLOT_W-1:0]   slot3_instr;
logic                valid_out;


dispatch DUT (
    .bundle_in(bundle_in),
    .valid_in(valid_in),
    .slot0_instr(slot0_instr),
    .slot1_instr(slot1_instr),
    .slot2_instr(slot2_instr),
    .slot3_instr(slot3_instr),
    .valid_out(valid_out)
);


// Arma el bundle con los 4 slots y verifica cada salida
task automatic expect_slots(input string name, input logic [31:0] s3, input logic [31:0] s2,
                            input logic [31:0] s1, input logic [31:0] s0);

    bundle_in = {s3, s2, s1, s0};
    #1;
    check({name, ": slot 0 (ALU)"},    slot0_instr, s0);
    check({name, ": slot 1 (LSU)"},    slot1_instr, s1);
    check({name, ": slot 2 (BRU)"},    slot2_instr, s2);
    check({name, ": slot 3 (CRIPTO)"}, slot3_instr, s3);
endtask


integer seed;


initial begin

    $dumpfile("tb_dispatch.vcd");
    $dumpvars(0, tb_dispatch);

    if (!$value$plusargs("seed=%d", seed))
        seed = 32'hCE4301;


    tb_section("1. Un patrón por slot");

    valid_in = 1'b1;
    expect_slots("caso 1", 32'hCCCC_CCCC, 32'hBBBB_BBBB, 32'hAAAA_AAAA, 32'h1111_1111);
    expect_slots("caso 2", 32'h1234_5678, 32'h8765_4321, 32'hFEDC_BA98, 32'hABCD_EF01);
    expect_slots("bundle NOP", 32'h0, 32'h0, 32'h0, 32'h0);


    tb_section("2. valid_out");

    check("valid_in = 1", valid_out, 1'b1);
    valid_in = 1'b0;
    #1;
    check("valid_in = 0", valid_out, 1'b0);


    tb_section("3. 500 bundles aleatorios");

    valid_in = 1'b1;
    repeat (500)
        expect_slots("aleatorio", $random(seed), $random(seed), $random(seed), $random(seed));


    tb_finish("tb_dispatch");
end

endmodule
