/*
================================================================================
 Testbench: tb_lsu
 ------------------------------------------------------------------------------
 Verificación autoverificable de la Unidad de Carga/Almacenamiento (rtl/lsu.sv).

 Casos cubiertos:
     1. Decodificación de operaciones (4 instrucciones).
     2. Store de palabra completa: mem_we, mem_be = 1111, mem_addr, mem_wdata.
     3. Store de byte: mem_be = 0001 << eff_addr[1:0].
     4. Load de palabra: wb_we, wb_rd, wb_data después de 1 ciclo.
     5. Load de byte con sign extension: el byte se extiende con signo en
        wb_data según eff_addr[1:0].
     6. Byte enables para cada offset (off = 0,1,2,3).
     7. Loads con signo: byte 0xFF debe dar 0xFFFFFFFF, 0x80 -> 0xFFFFFF80.
     8. Slot inactivo (valid_in=0): mem_we=0, wb_we=0.

================================================================================
*/

`timescale 1ns/1ps


module tb_lsu;

`include "tb_utils.svh"


// ============================================================================
// DUTs (LSU + memoria pequeña)
// ============================================================================

localparam int SIZE_WORDS = 64;

logic         clk;
logic         reset;

logic         valid_in;
logic [3:0]   lsu_op;
logic [4:0]   rd;
logic [10:0]  imm;
logic [31:0]  rf1_data;
logic [31:0]  rf2_data;

logic         mem_we;
logic [3:0]   mem_be;
logic [31:0]  mem_addr;
logic [31:0]  mem_wdata;
logic [31:0]  mem_rdata;

logic         wb_we;
logic [4:0]   wb_rd;
logic [31:0]  wb_data;


lsu DUT (
    .clk(clk),
    .reset(reset),
    .valid_in(valid_in),
    .lsu_op(lsu_op),
    .rd(rd),
    .imm(imm),
    .rf1_data(rf1_data),
    .rf2_data(rf2_data),
    .mem_we(mem_we),
    .mem_be(mem_be),
    .mem_addr(mem_addr),
    .mem_wdata(mem_wdata),
    .mem_rdata(mem_rdata),
    .wb_we(wb_we),
    .wb_rd(wb_rd),
    .wb_data(wb_data)
);


memory #(.SIZE_WORDS(SIZE_WORDS)) MEM (
    .clk(clk),
    .we(mem_we),
    .be(mem_be),
    .addr(mem_addr),
    .wdata(mem_wdata),
    .rdata(mem_rdata)
);


always #5 clk = ~clk;


// ============================================================================
// Helpers
// ============================================================================

task automatic reset_dut();
    @(negedge clk);
    reset = 1;
    @(posedge clk);
    @(posedge clk);
    @(negedge clk);
    reset = 0;
endtask


// ============================================================================
// Estímulo principal
// ============================================================================

initial begin

    $dumpfile("tb_lsu.vcd");
    $dumpvars(0, tb_lsu);

    clk      = 0;
    reset    = 1;
    valid_in = 1'b0;
    lsu_op   = 4'b0;
    rd       = 5'd0;
    imm      = 11'd0;
    rf1_data = 32'd0;
    rf2_data = 32'd0;

    reset_dut();


    // =====================================================================
    // 1. Slot inactivo (NOP)
    // =====================================================================
    tb_section("1. Slot inactivo");

    valid_in = 1'b0;
    rf1_data = 32'h0000_1000;
    rf2_data = 32'h1234_5678;
    #1;
    check_true("NOP -> mem_we = 0", mem_we === 1'b0);
    check_true("NOP -> wb_we = 0",  wb_we === 1'b0);


    // =====================================================================
    // 2. guardap: store de palabra completa
    // =====================================================================
    tb_section("2. guardap (palabra completa)");

    valid_in = 1'b1;
    lsu_op   = OP_GUARDAP;
    rf1_data = 32'h0000_0010;
    rf2_data = 32'hCAFE_BABE;
    imm      = 11'd0;
    #1;
    check_true("guardap: mem_we=1", mem_we === 1'b1);
    check      ("guardap: mem_be = 1111", mem_be, 4'b1111);
    check      ("guardap: mem_addr", mem_addr, 32'h0000_0010);
    check      ("guardap: mem_wdata", mem_wdata, 32'hCAFE_BABE);
    check_true("guardap: wb_we = 0", wb_we === 1'b0);

    @(posedge clk);  // escribe
    @(negedge clk);

    // Leer la misma dirección
    rf1_data = 32'h0000_0010;
    lsu_op   = OP_CARGAI;
    valid_in = 1'b1;
    @(posedge clk);  // captura rd para load
    @(negedge clk);
    #1;
    check_true("cargai: wb_we=1", wb_we === 1'b1);
    check      ("cargai: dato leído", wb_data, 32'hCAFE_BABE);


    // =====================================================================
    // 3. guardab: store de byte en cada posición
    // =====================================================================
    tb_section("3. guardab en cada posición");

    // Escribir palabra 0x11223344 primero (byte 2 = 0x22)
    @(negedge clk);
    valid_in = 1'b1;
    lsu_op   = OP_GUARDAP;
    rf1_data = 32'h0000_0020;
    rf2_data = 32'h1122_3344;
    imm      = 11'd0;
    @(posedge clk);
    @(negedge clk);

    // Sobrescribir byte 1 con 0xAA
    lsu_op   = OP_GUARDAB;
    rf1_data = 32'h0000_0021;     // addr+1
    rf2_data = 32'h0000_00AA;     // wdata = 0xAA (sólo importa byte)
    imm      = 11'd0;
    #1;
    check_true("guardab byte 1: mem_we=1", mem_we === 1'b1);
    check      ("guardab byte 1: mem_be = 0010", mem_be, 4'b0010);
    @(posedge clk);
    @(negedge clk);

    // Leer toda la palabra
    lsu_op   = OP_CARGAI;
    rf1_data = 32'h0000_0020;
    imm      = 11'd0;
    @(posedge clk);
    @(negedge clk);
    #1;
    check("guardap + guardab byte 1 = 0x1122_AA44", wb_data, 32'h1122_AA44);


    // =====================================================================
    // 4. be para cada offset
    // =====================================================================
    tb_section("4. mem_be según eff_addr[1:0]");

    valid_in = 1'b1;
    lsu_op   = OP_GUARDAB;

    rf1_data = 32'h0000_0000; #1;
    check("be addr[1:0]=00", mem_be, 4'b0001);

    rf1_data = 32'h0000_0001; #1;
    check("be addr[1:0]=01", mem_be, 4'b0010);

    rf1_data = 32'h0000_0002; #1;
    check("be addr[1:0]=10", mem_be, 4'b0100);

    rf1_data = 32'h0000_0003; #1;
    check("be addr[1:0]=11", mem_be, 4'b1000);


    // =====================================================================
    // 5. Byte load con sign extension
    // =====================================================================
    tb_section("5. cargabai con sign extension");

    // Escribir palabra 0x123456FF
    @(negedge clk);
    lsu_op   = OP_GUARDAP;
    rf1_data = 32'h0000_0030;
    rf2_data = 32'h1234_56FF;
    imm      = 11'd0;
    @(posedge clk);
    @(negedge clk);

    // Cargar byte en +0 = 0xFF -> 0xFFFFFFFF
    lsu_op   = OP_CARGABAI;
    rf1_data = 32'h0000_0030;
    imm      = 11'd0;
    @(posedge clk);
    @(negedge clk);
    #1;
    check("byte 0xFF extendido con signo", wb_data, 32'hFFFF_FFFF);

    // Cargar byte en +1 = 0x56 -> 0x00000056 (positivo)
    lsu_op   = OP_CARGABAI;
    rf1_data = 32'h0000_0031;
    imm      = 11'd0;
    @(posedge clk);
    @(negedge clk);
    #1;
    check("byte 0x56 positivo", wb_data, 32'h0000_0056);

    // Cargar byte en +3 = 0x12 -> 0x00000012
    lsu_op   = OP_CARGABAI;
    rf1_data = 32'h0000_0033;
    imm      = 11'd0;
    @(posedge clk);
    @(negedge clk);
    #1;
    check("byte 0x12 positivo", wb_data, 32'h0000_0012);


    // =====================================================================
    // 6. Offset immediate extendido con signo
    // =====================================================================
    tb_section("6. eff_addr = rf1 + sign_ext(imm)");

    @(negedge clk);
    valid_in = 1'b1;
    lsu_op   = OP_CARGAI;
    rf1_data = 32'h0000_0100;
    imm      = 11'sd8;        // +8 bytes (ef = +1 palabra)
    @(posedge clk);
    @(negedge clk);
    #1;
    check_true("wb_we", wb_we === 1'b1);

    // eff_addr = 0x100 + 8 = 0x108
    @(negedge clk);
    lsu_op   = OP_CARGAI;
    rf1_data = 32'h0000_0100;
    imm      = 11'sd8;
    #1;
    check("eff_addr = rf1 + 8", mem_addr, 32'h0000_0108);

    // imm negativo
    lsu_op   = OP_CARGAI;
    rf1_data = 32'h0000_0108;
    imm      = -11'sd8;
    #1;
    check("eff_addr = rf1 - 8 (signed imm)", mem_addr, 32'h0000_0100);


    valid_in = 1'b0;
    tb_finish("tb_lsu");
end

endmodule