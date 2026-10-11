`timescale 1ns/1ps

/*
================================================================================
 Testbench: tb_regfile_pipeline

 Descripción:
 ------------------------------------------------------------------------------
 Verifica, sobre el pipeline completo (top), la regla de dependencias de
 datos que impone el banco de registros sin bypass:

     El valor que escribe el bundle N lo lee correctamente el bundle N+3 o
     uno posterior. Los bundles N+1 y N+2 todavía leen el valor anterior.

 Esta regla es la que el ensamblador y el compilador de CE1108 deben respetar
 insertando bundles independientes o NOP entre productor y consumidor.

 El testbench reemplaza el programa de instruction_memory por uno propio
 (sólo el slot 0, el resto de slots en NOP), lo ejecuta y revisa el contenido
 final del banco de registros:

   B0   sumai x2, x0, 7      x2 = 7
   B1   suma  x5, x2, x0     distancia 1 -> lee x2 viejo -> x5 = 0
   B2   suma  x6, x2, x0     distancia 2 -> lee x2 viejo -> x6 = 0
   B3   suma  x7, x2, x0     distancia 3 -> lee x2 nuevo -> x7 = 7
   B4   sumai x8, x0, -5     x8 = -5
   B5   nop
   B6   nop
   B7   suma  x9, x8, x7     distancias 3 y 4 -> x9 = -5 + 7 = 2
   B8   sumai x0, x0, 99     escritura a x0, se descarta
   B9   sumai x2, x2, 1      x2 = 8
   B10  suma  x10, x2, x0    distancia 1 -> x10 = 7 (valor anterior de x2)
   B11  nop
   B12  nop
   B13  suma  x11, x2, x0    distancia 4 -> x11 = 8

 Además verifica que wb nunca reporte un conflicto de escritura.

================================================================================
*/

module tb_regfile_pipeline;

`include "tb_utils.svh"


logic clk;
logic reset;

logic [31:0] debug_result;
logic [4:0] debug_rd;
logic debug_write;


top DUT (

    .clk(clk),
    .reset(reset),
    .debug_result(debug_result),
    .debug_rd(debug_rd),
    .debug_write(debug_write)
);


always #5 clk = ~clk;


function automatic logic [31:0] enc_reg(input logic [3:0] id, input logic [4:0] rg,
                                        input logic [4:0] rf1, input logic [4:0] rf2);

    return {7'b1101010, id, rg, rf1, rf2, 6'b0};
endfunction


function automatic logic [31:0] enc_imm(input logic [3:0] id, input logic [4:0] rf1,
                                        input logic [4:0] rg, input logic [10:0] imm);

    return {7'b1000000, id, rf1, rg, imm};
endfunction


// Bundle con la instrucción en el slot 0 (ALU) y NOP en los demás slots
function automatic logic [127:0] alu_bundle(input logic [31:0] slot0);

    return {96'b0, slot0};
endfunction


localparam logic [3:0] SUMA  = 4'b1000;
localparam logic [3:0] SUMAI = 4'b0000;


// Ningún bundle del programa debe producir un conflicto de escritura
int conflicts = 0;

always @(posedge clk)
    if(!reset && DUT.wb_conflict)
        conflicts++;


initial begin

    $dumpfile("tb_regfile_pipeline.vcd");
    $dumpvars(0, tb_regfile_pipeline);

    clk = 0;
    reset = 1;

    // Esperar a que instruction_memory cargue su programa para reemplazarlo
    #1;

    for(int i = 0; i < 32; i++)
        DUT.IMEM.memory[i] = 128'b0;

    DUT.IMEM.memory[0]  = alu_bundle(enc_imm(SUMAI, 5'd0, 5'd2, 11'd7));
    DUT.IMEM.memory[1]  = alu_bundle(enc_reg(SUMA,  5'd5, 5'd2, 5'd0));
    DUT.IMEM.memory[2]  = alu_bundle(enc_reg(SUMA,  5'd6, 5'd2, 5'd0));
    DUT.IMEM.memory[3]  = alu_bundle(enc_reg(SUMA,  5'd7, 5'd2, 5'd0));
    DUT.IMEM.memory[4]  = alu_bundle(enc_imm(SUMAI, 5'd0, 5'd8, -11'sd5));
    DUT.IMEM.memory[7]  = alu_bundle(enc_reg(SUMA,  5'd9, 5'd8, 5'd7));
    DUT.IMEM.memory[8]  = alu_bundle(enc_imm(SUMAI, 5'd0, 5'd0, 11'd99));
    DUT.IMEM.memory[9]  = alu_bundle(enc_imm(SUMAI, 5'd2, 5'd2, 11'd1));
    DUT.IMEM.memory[10] = alu_bundle(enc_reg(SUMA,  5'd10, 5'd2, 5'd0));
    DUT.IMEM.memory[13] = alu_bundle(enc_reg(SUMA,  5'd11, 5'd2, 5'd0));

    @(negedge clk);
    @(negedge clk);

    reset = 0;

    // 14 bundles + 4 etapas, con margen
    repeat(25) @(negedge clk);


    tb_section("Distancia entre productor y consumidor (x2 = 7 en B0)");

    check("distancia 1: x5 lee el valor anterior", DUT.REGFILE.regs[5], 32'd0);
    check("distancia 2: x6 lee el valor anterior", DUT.REGFILE.regs[6], 32'd0);
    check("distancia 3: x7 lee el valor nuevo",    DUT.REGFILE.regs[7], 32'd7);

    tb_section("Resto del programa");

    check("x8 = -5 (inmediato negativo)",         DUT.REGFILE.regs[8], -32'sd5);
    check("x9 = x8 + x7 a distancias 3 y 4",      DUT.REGFILE.regs[9], 32'd2);
    check("x0 sigue en 0",                        DUT.REGFILE.regs[0], 32'd0);
    check("x2 = 8",                               DUT.REGFILE.regs[2], 32'd8);
    check("x10: distancia 1 lee x2 anterior (7)", DUT.REGFILE.regs[10], 32'd7);
    check("x11: distancia 4 lee x2 nuevo (8)",    DUT.REGFILE.regs[11], 32'd8);
    check("sin conflictos de writeback",          conflicts, 0);


    tb_finish("tb_regfile_pipeline");
end

endmodule
