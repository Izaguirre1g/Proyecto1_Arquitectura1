`timescale 1ns/1ps

/*
================================================================================
 Testbench: tb_pipeline_if_id

 Descripción:
 ------------------------------------------------------------------------------
 Verifica el registro de segmentación IF/ID (rtl/pipeline_if_id.sv).

 Casos:
   1. Reset: bundle, PC y valid en 0.
   2. Captura en el flanco positivo y mantiene el valor hasta el siguiente
      (casos originales: PC 0x1000 y 0x2000).
   3. flush_in: el flanco siguiente deja una burbuja (bundle NOP, valid 0).
   4. reset tiene prioridad sobre la captura.
   5. 300 ciclos aleatorios contra un modelo.

================================================================================
*/

`include "isa_defs.sv"


module tb_pipeline_if_id;

`include "tb_utils.svh"


logic                clk;
logic                reset;
logic [BUNDLE_W-1:0] bundle_in;
logic [31:0]         pc_in;
logic                valid_in;
logic                flush_in;
logic [BUNDLE_W-1:0] bundle_out;
logic [31:0]         pc_out;
logic                valid_out;


pipeline_if_id DUT (
    .clk(clk),
    .reset(reset),
    .bundle_in(bundle_in),
    .pc_in(pc_in),
    .valid_in(valid_in),
    .flush_in(flush_in),
    .bundle_out(bundle_out),
    .pc_out(pc_out),
    .valid_out(valid_out)
);


always #5 clk = ~clk;


task automatic expect_out(input string name, input logic [BUNDLE_W-1:0] e_bundle,
                          input logic [31:0] e_pc, input logic e_valid);

    check_true({name, ": bundle"}, bundle_out === e_bundle);
    check({name, ": pc"},    pc_out, e_pc);
    check({name, ": valid"}, valid_out, e_valid);
endtask


integer seed;


initial begin

    $dumpfile("tb_pipeline_if_id.vcd");
    $dumpvars(0, tb_pipeline_if_id);

    if (!$value$plusargs("seed=%d", seed))
        seed = 32'hCE4301;

    clk       = 0;
    reset     = 1;
    bundle_in = '0;
    pc_in     = 32'b0;
    valid_in  = 0;
    flush_in  = 0;


    tb_section("1. Reset");

    @(negedge clk);
    expect_out("reset", '0, 32'b0, 1'b0);


    tb_section("2. Captura en el flanco");

    reset     = 0;
    pc_in     = 32'h0000_1000;
    bundle_in = 128'h1111_2222_3333_4444_5555_6666_7777_8888;
    valid_in  = 1;
    #1;
    expect_out("antes del flanco: sigue el valor anterior", '0, 32'b0, 1'b0);
    @(negedge clk);
    expect_out("PC 0x1000", 128'h1111_2222_3333_4444_5555_6666_7777_8888, 32'h1000, 1'b1);

    pc_in     = 32'h0000_2000;
    bundle_in = 128'hAAAA_BBBB_CCCC_DDDD_EEEE_FFFF_0000_1111;
    @(negedge clk);
    expect_out("PC 0x2000", 128'hAAAA_BBBB_CCCC_DDDD_EEEE_FFFF_0000_1111, 32'h2000, 1'b1);


    tb_section("3. flush_in");

    pc_in    = 32'h0000_3000;
    flush_in = 1;
    @(negedge clk);
    expect_out("flush: burbuja", '0, 32'b0, 1'b0);
    flush_in = 0;
    @(negedge clk);
    expect_out("después del flush captura de nuevo", 128'hAAAA_BBBB_CCCC_DDDD_EEEE_FFFF_0000_1111,
               32'h3000, 1'b1);


    tb_section("4. reset tiene prioridad");

    reset = 1;
    @(negedge clk);
    expect_out("reset con valid_in = 1", '0, 32'b0, 1'b0);
    reset = 0;


    tb_section("5. 300 ciclos aleatorios");

    repeat (300) begin

        logic [BUNDLE_W-1:0] b;
        logic [31:0]         p;
        logic                v, f;

        b = {$random(seed), $random(seed), $random(seed), $random(seed)};
        p = $random(seed);
        v = $random(seed);
        f = ($random(seed) % 4) == 0;

        bundle_in = b;
        pc_in     = p;
        valid_in  = v;
        flush_in  = f;
        @(negedge clk);
        if (f)
            expect_out("aleatorio con flush", '0, 32'b0, 1'b0);
        else
            expect_out("aleatorio", b, p, v);
    end


    tb_finish("tb_pipeline_if_id");
end

endmodule
