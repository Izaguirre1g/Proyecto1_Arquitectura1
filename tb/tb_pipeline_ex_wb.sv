`timescale 1ns/1ps

/*
================================================================================
 Testbench: tb_pipeline_ex_wb

 Descripción:
 ------------------------------------------------------------------------------
 Verifica el registro de segmentación EX/WB del slot ALU
 (rtl/pipeline_ex_wb.sv).

 Casos:
   1. Reset: resultado, destino y valid en 0.
   2. Captura en el flanco (caso original: 50 hacia x5).
   3. Burbuja: valid_in = 0 llega como valid_out = 0 (caso original).
   4. 300 ciclos aleatorios contra un modelo.

================================================================================
*/

module tb_pipeline_ex_wb;

`include "tb_utils.svh"


logic        clk;
logic        reset;
logic [31:0] result_in;
logic [4:0]  rd_in;
logic        valid_in;
logic [31:0] result_out;
logic [4:0]  rd_out;
logic        valid_out;


pipeline_ex_wb DUT (
    .clk(clk),
    .reset(reset),
    .result_in(result_in),
    .rd_in(rd_in),
    .valid_in(valid_in),
    .result_out(result_out),
    .rd_out(rd_out),
    .valid_out(valid_out)
);


always #5 clk = ~clk;


task automatic expect_out(input string name, input logic [31:0] e_res, input logic [4:0] e_rd,
                          input logic e_valid);

    check({name, ": resultado"}, result_out, e_res);
    check({name, ": rd"},        rd_out, e_rd);
    check({name, ": valid"},     valid_out, e_valid);
endtask


integer seed;


initial begin

    $dumpfile("tb_pipeline_ex_wb.vcd");
    $dumpvars(0, tb_pipeline_ex_wb);

    if (!$value$plusargs("seed=%d", seed))
        seed = 32'hCE4301;

    clk       = 0;
    reset     = 1;
    result_in = 0;
    rd_in     = 0;
    valid_in  = 0;


    tb_section("1. Reset");

    @(negedge clk);
    expect_out("reset", 32'd0, 5'd0, 1'b0);


    tb_section("2. Captura");

    reset     = 0;
    result_in = 32'd50;
    rd_in     = 5'd5;
    valid_in  = 1;
    @(negedge clk);
    expect_out("50 hacia x5", 32'd50, 5'd5, 1'b1);


    tb_section("3. Burbuja");

    result_in = 32'd100;
    rd_in     = 5'd8;
    valid_in  = 0;
    @(negedge clk);
    expect_out("valid_in = 0", 32'd100, 5'd8, 1'b0);


    tb_section("4. 300 ciclos aleatorios");

    repeat (300) begin

        logic [31:0] r;
        logic [4:0]  d;
        logic        v;

        r = $random(seed);
        d = $random(seed);
        v = $random(seed);

        result_in = r;
        rd_in     = d;
        valid_in  = v;
        @(negedge clk);
        expect_out("aleatorio", r, d, v);
    end

    reset = 1;
    @(negedge clk);
    expect_out("reset al final", 32'd0, 5'd0, 1'b0);


    tb_finish("tb_pipeline_ex_wb");
end

endmodule
