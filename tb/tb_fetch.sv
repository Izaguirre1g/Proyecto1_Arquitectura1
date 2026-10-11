`timescale 1ns/1ps

/*
================================================================================
 Testbench: tb_fetch

 Descripción:
 ------------------------------------------------------------------------------
 Verifica el módulo fetch (rtl/fetch.sv). Es combinacional: entrega el PC y el
 bundle leído de la memoria de instrucciones sin registrarlos (el registro
 entre IF e ID es pipeline_if_id).

 Casos:
   1. Durante el reset: valid_out = 0.
   2. PC y bundle pasan en el mismo instante, sin esperar un flanco (casos
      originales: PC 0x1000 y 0x2000).
   3. 200 valores aleatorios de PC y bundle.

================================================================================
*/

`include "isa_defs.sv"


module tb_fetch;

`include "tb_utils.svh"


logic                reset;
logic [31:0]         pc;
logic [BUNDLE_W-1:0] instruction_bundle;
logic [31:0]         pc_out;
logic [BUNDLE_W-1:0] bundle_out;
logic                valid_out;


fetch DUT (
    .reset(reset),
    .pc(pc),
    .instruction_bundle(instruction_bundle),
    .pc_out(pc_out),
    .bundle_out(bundle_out),
    .valid_out(valid_out)
);


// Compara PC, bundle y valid con lo esperado
task automatic expect_out(input string name, input logic exp_valid);

    #1;
    check({name, ": pc_out"}, pc_out, pc);
    check_true({name, ": bundle_out"}, bundle_out === instruction_bundle);
    check({name, ": valid_out"}, valid_out, exp_valid);
endtask


integer seed;


initial begin

    $dumpfile("tb_fetch.vcd");
    $dumpvars(0, tb_fetch);

    if (!$value$plusargs("seed=%d", seed))
        seed = 32'hCE4301;


    tb_section("1. Reset");

    reset              = 1;
    pc                 = 32'h0000_0000;
    instruction_bundle = '0;
    expect_out("reset", 1'b0);


    tb_section("2. PC y bundle pasan sin esperar un flanco");

    reset              = 0;
    pc                 = 32'h0000_1000;
    instruction_bundle = 128'h1234_5678_9ABC_DEF0_0123_4567_89AB_CDEF;
    expect_out("PC 0x1000", 1'b1);

    pc                 = 32'h0000_2000;
    instruction_bundle = 128'hFEDC_BA98_7654_3210_FEDC_BA98_7654_3210;
    expect_out("PC 0x2000", 1'b1);


    tb_section("3. 200 valores aleatorios");

    repeat (200) begin

        pc                 = $random(seed);
        instruction_bundle = {$random(seed), $random(seed), $random(seed), $random(seed)};
        expect_out("aleatorio", 1'b1);
    end


    tb_finish("tb_fetch");
end

endmodule
