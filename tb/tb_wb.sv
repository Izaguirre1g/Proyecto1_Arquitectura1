`timescale 1ns/1ps

/*
================================================================================
 Testbench: tb_wb

 Descripción:
 ------------------------------------------------------------------------------
 Verificación autoverificable de la etapa de writeback (wb) y de su conexión
 con el banco de registros (regfile).

 Parte 1 - wb aislado:
   1. Sin escrituras.
   2. Cada unidad sola: ALU, LSU, BRU (enlace de sye) y CRIPTO (par rd, rd+1).
   3. <fu>_we = 0 con destino y dato presentes.
   4. Destino x0 en cada unidad y bordes del par de la cripto (rd = x0 y
      rd = x31).
   5. Bundle completo: las cuatro unidades escriben registros distintos
      (cinco escrituras en el mismo ciclo).
   6. Conflictos de writeback: dos unidades con el mismo destino en el mismo
      ciclo levantan conflict; si una de ellas no escribe o el destino es x0,
      no hay conflicto.
   7. N_RANDOM combinaciones aleatorias (destinos en x0–x7 para forzar
      conflictos) contra un modelo de referencia.

 Parte 2 - wb + regfile:
   Secuencia de bundles que escribe por los 5 puertos, un conflicto (gana el
   puerto de índice mayor), una escritura a x0 y una escritura deshabilitada.
   Al final se verifica el contenido del banco por sus puertos de lectura.

 Plusargs: +seed=N, +verbose.

================================================================================
*/

module tb_wb;

`include "tb_utils.svh"


localparam int N_RANDOM = 2000;

integer seed;


logic clk;
logic reset;


// Entradas de wb

logic        alu_we;
logic [4:0]  alu_rd;
logic [31:0] alu_data;

logic        lsu_we;
logic [4:0]  lsu_rd;
logic [31:0] lsu_data;

logic        bru_we;
logic [4:0]  bru_rd;
logic [31:0] bru_data;

logic        crypto_we;
logic [4:0]  crypto_rd;
logic [31:0] crypto_data_l;
logic [31:0] crypto_data_r;


// Salidas de wb hacia el banco

logic [4:0]       we;
logic [4:0][4:0]  waddr;
logic [4:0][31:0] wdata;
logic             conflict;


wb DUT (

    .alu_we(alu_we),
    .alu_rd(alu_rd),
    .alu_data(alu_data),

    .lsu_we(lsu_we),
    .lsu_rd(lsu_rd),
    .lsu_data(lsu_data),

    .bru_we(bru_we),
    .bru_rd(bru_rd),
    .bru_data(bru_data),

    .crypto_we(crypto_we),
    .crypto_rd(crypto_rd),
    .crypto_data_l(crypto_data_l),
    .crypto_data_r(crypto_data_r),

    .we(we),
    .waddr(waddr),
    .wdata(wdata),

    .conflict(conflict)
);


// Banco de registros alimentado por wb

logic [7:0][4:0]  raddr;
logic [7:0][31:0] rdata;

regfile RF (

    .clk(clk),
    .reset(reset),
    .raddr(raddr),
    .rdata(rdata),
    .we(we),
    .waddr(waddr),
    .wdata(wdata)
);


always #5 clk = ~clk;


task automatic clear_inputs();

    alu_we = 1'b0;    alu_rd = 5'd0;    alu_data = 32'd0;
    lsu_we = 1'b0;    lsu_rd = 5'd0;    lsu_data = 32'd0;
    bru_we = 1'b0;    bru_rd = 5'd0;    bru_data = 32'd0;
    crypto_we = 1'b0; crypto_rd = 5'd0; crypto_data_l = 32'd0; crypto_data_r = 32'd0;
endtask


// Verifica un puerto habilitado
task automatic check_port(input string name, input int p, input logic [4:0] addr, input logic [31:0] data);

    check($sformatf("%s: waddr[%0d]", name, p), waddr[p], addr);
    check($sformatf("%s: wdata[%0d]", name, p), wdata[p], data);
endtask


// Verifica los habilitadores y el indicador de conflicto
task automatic check_we(input string name, input logic [4:0] exp_we, input logic exp_conflict);

    #1;

    check({name, ": we"}, we, exp_we);
    check({name, ": conflict"}, conflict, exp_conflict);
endtask


initial begin

    $dumpfile("tb_wb.vcd");
    $dumpvars(0, tb_wb);

    if(!$value$plusargs("seed=%d", seed))
        seed = 32'hCE4301;

    $display("tb_wb: semilla de vectores aleatorios = %0d", seed);

    clk = 0;
    reset = 1;
    raddr = '0;
    clear_inputs();


    // =================================================
    // Parte 1: wb aislado
    // =================================================

    tb_section("1. Sin escrituras");

    check_we("ninguna unidad escribe", 5'b00000, 1'b0);


    tb_section("2. Cada unidad sola");

    clear_inputs();
    alu_we = 1'b1; alu_rd = 5'd5; alu_data = 32'h0000_0032;
    check_we("ALU x5", 5'b00001, 1'b0);
    check_port("ALU x5", 0, 5'd5, 32'h0000_0032);

    clear_inputs();
    lsu_we = 1'b1; lsu_rd = 5'd8; lsu_data = 32'hCAFE_0008;
    check_we("LSU x8 (cargai)", 5'b00010, 1'b0);
    check_port("LSU x8 (cargai)", 1, 5'd8, 32'hCAFE_0008);

    clear_inputs();
    bru_we = 1'b1; bru_rd = 5'd1; bru_data = 32'h0000_0104;
    check_we("BRU x1 (enlace de sye)", 5'b00100, 1'b0);
    check_port("BRU x1 (enlace de sye)", 2, 5'd1, 32'h0000_0104);

    clear_inputs();
    crypto_we = 1'b1; crypto_rd = 5'd6; crypto_data_l = 32'h1111_1111; crypto_data_r = 32'h2222_2222;
    check_we("CRIPTO par x6, x7", 5'b11000, 1'b0);
    check_port("CRIPTO L -> x6", 3, 5'd6, 32'h1111_1111);
    check_port("CRIPTO R -> x7", 4, 5'd7, 32'h2222_2222);


    tb_section("3. Unidades con we = 0");

    clear_inputs();
    alu_rd = 5'd5;    alu_data = 32'hFFFF_FFFF;
    lsu_rd = 5'd6;    lsu_data = 32'hFFFF_FFFF;
    bru_rd = 5'd7;    bru_data = 32'hFFFF_FFFF;
    crypto_rd = 5'd8; crypto_data_l = 32'hFFFF_FFFF; crypto_data_r = 32'hFFFF_FFFF;
    check_we("todas con we = 0", 5'b00000, 1'b0);


    tb_section("4. Destino x0 y bordes del par de la cripto");

    clear_inputs();
    alu_we = 1'b1; lsu_we = 1'b1; bru_we = 1'b1;
    check_we("ALU, LSU y BRU hacia x0", 5'b00000, 1'b0);

    clear_inputs();
    crypto_we = 1'b1; crypto_rd = 5'd0;
    check_we("CRIPTO rd = x0: sólo se escribe R en x1", 5'b10000, 1'b0);
    check_port("CRIPTO rd = x0: R -> x1", 4, 5'd1, 32'd0);

    clear_inputs();
    crypto_we = 1'b1; crypto_rd = 5'd31;
    check_we("CRIPTO rd = x31: R iría a x0 y se descarta", 5'b01000, 1'b0);
    check_port("CRIPTO rd = x31: L -> x31", 3, 5'd31, 32'd0);


    tb_section("5. Bundle completo sin conflictos");

    clear_inputs();
    alu_we = 1'b1;    alu_rd = 5'd5;     alu_data = 32'hA000_0005;
    lsu_we = 1'b1;    lsu_rd = 5'd8;     lsu_data = 32'hB000_0008;
    bru_we = 1'b1;    bru_rd = 5'd1;     bru_data = 32'hC000_0001;
    crypto_we = 1'b1; crypto_rd = 5'd10; crypto_data_l = 32'hD000_000A; crypto_data_r = 32'hD000_000B;
    check_we("4 unidades, 5 escrituras", 5'b11111, 1'b0);
    check_port("bundle completo ALU", 0, 5'd5, 32'hA000_0005);
    check_port("bundle completo LSU", 1, 5'd8, 32'hB000_0008);
    check_port("bundle completo BRU", 2, 5'd1, 32'hC000_0001);
    check_port("bundle completo CRIPTO L", 3, 5'd10, 32'hD000_000A);
    check_port("bundle completo CRIPTO R", 4, 5'd11, 32'hD000_000B);


    tb_section("6. Conflictos de writeback");

    clear_inputs();
    alu_we = 1'b1; alu_rd = 5'd5;
    lsu_we = 1'b1; lsu_rd = 5'd5;
    check_we("ALU y LSU sobre x5", 5'b00011, 1'b1);

    clear_inputs();
    alu_we = 1'b1; alu_rd = 5'd1;
    bru_we = 1'b1; bru_rd = 5'd1;
    check_we("ALU y BRU sobre x1", 5'b00101, 1'b1);

    clear_inputs();
    alu_we = 1'b1;    alu_rd = 5'd7;
    crypto_we = 1'b1; crypto_rd = 5'd6;
    check_we("ALU sobre x7 y CRIPTO R sobre x7", 5'b11001, 1'b1);

    clear_inputs();
    lsu_we = 1'b1;    lsu_rd = 5'd6;
    crypto_we = 1'b1; crypto_rd = 5'd6;
    check_we("LSU sobre x6 y CRIPTO L sobre x6", 5'b11010, 1'b1);

    clear_inputs();
    alu_we = 1'b1; alu_rd = 5'd5;
    lsu_we = 1'b0; lsu_rd = 5'd5;
    check_we("mismo destino pero LSU no escribe", 5'b00001, 1'b0);

    clear_inputs();
    alu_we = 1'b1; alu_rd = 5'd0;
    lsu_we = 1'b1; lsu_rd = 5'd0;
    check_we("ALU y LSU sobre x0 (se descartan)", 5'b00000, 1'b0);


    tb_section($sformatf("7. %0d combinaciones aleatorias", N_RANDOM));

    repeat(N_RANDOM) begin

        logic [4:0] exp_we;
        logic [4:0][4:0] exp_addr;
        logic exp_conflict;

        alu_we = $random(seed);    alu_rd = $random(seed) & 7;    alu_data = $random(seed);
        lsu_we = $random(seed);    lsu_rd = $random(seed) & 7;    lsu_data = $random(seed);
        bru_we = $random(seed);    bru_rd = $random(seed) & 7;    bru_data = $random(seed);
        crypto_we = $random(seed); crypto_rd = $random(seed) & 7;
        crypto_data_l = $random(seed);
        crypto_data_r = $random(seed);

        exp_addr[0] = alu_rd;
        exp_addr[1] = lsu_rd;
        exp_addr[2] = bru_rd;
        exp_addr[3] = crypto_rd;
        exp_addr[4] = crypto_rd + 5'd1;

        exp_we[0] = alu_we & (alu_rd != 0);
        exp_we[1] = lsu_we & (lsu_rd != 0);
        exp_we[2] = bru_we & (bru_rd != 0);
        exp_we[3] = crypto_we & (exp_addr[3] != 0);
        exp_we[4] = crypto_we & (exp_addr[4] != 0);

        exp_conflict = 1'b0;

        for(int i = 0; i < 5; i++)
            for(int j = 0; j < i; j++)
                if(exp_we[i] && exp_we[j] && exp_addr[i] == exp_addr[j])
                    exp_conflict = 1'b1;

        check_we("aleatorio", exp_we, exp_conflict);

        for(int p = 0; p < 5; p++)
            if(exp_we[p])
                check($sformatf("aleatorio: waddr[%0d]", p), waddr[p], exp_addr[p]);

        check("aleatorio: wdata[0]", wdata[0], alu_data);
        check("aleatorio: wdata[1]", wdata[1], lsu_data);
        check("aleatorio: wdata[2]", wdata[2], bru_data);
        check("aleatorio: wdata[3]", wdata[3], crypto_data_l);
        check("aleatorio: wdata[4]", wdata[4], crypto_data_r);
    end


    // =================================================
    // Parte 2: wb + regfile
    // =================================================

    tb_section("8. wb conectado al banco de registros");

    clear_inputs();

    @(negedge clk);
    @(negedge clk);

    reset = 0;

    // Bundle A: las cuatro unidades escriben
    alu_we = 1'b1;    alu_rd = 5'd5;    alu_data = 32'h0000_0011;
    lsu_we = 1'b1;    lsu_rd = 5'd8;    lsu_data = 32'h0000_0022;
    bru_we = 1'b1;    bru_rd = 5'd1;    bru_data = 32'h0000_0033;
    crypto_we = 1'b1; crypto_rd = 5'd10; crypto_data_l = 32'h0000_0044; crypto_data_r = 32'h0000_0055;

    @(negedge clk);

    // Bundle B: conflicto en x5 entre ALU y CRIPTO R (par x4, x5)
    clear_inputs();
    alu_we = 1'b1;    alu_rd = 5'd5;    alu_data = 32'h0000_00AA;
    crypto_we = 1'b1; crypto_rd = 5'd4; crypto_data_l = 32'h0000_00BB; crypto_data_r = 32'h0000_00CC;

    #1;

    check("bundle B: conflict", conflict, 1'b1);

    @(negedge clk);

    // Bundle C: escritura hacia x0
    clear_inputs();
    alu_we = 1'b1; alu_rd = 5'd0; alu_data = 32'hFFFF_FFFF;

    @(negedge clk);

    // Bundle D: destino válido pero sin habilitar
    clear_inputs();
    lsu_rd = 5'd8; lsu_data = 32'hFFFF_FFFF;

    @(negedge clk);

    clear_inputs();

    raddr[0] = 5'd5;
    raddr[1] = 5'd8;
    raddr[2] = 5'd1;
    raddr[3] = 5'd10;
    raddr[4] = 5'd11;
    raddr[5] = 5'd4;
    raddr[6] = 5'd0;
    raddr[7] = 5'd2;

    #1;

    check("banco: x5 (gana CRIPTO R sobre ALU)", rdata[0], 32'h0000_00CC);
    check("banco: x8 (LSU, sin cambio en bundle D)", rdata[1], 32'h0000_0022);
    check("banco: x1 (BRU)", rdata[2], 32'h0000_0033);
    check("banco: x10 (CRIPTO L)", rdata[3], 32'h0000_0044);
    check("banco: x11 (CRIPTO R)", rdata[4], 32'h0000_0055);
    check("banco: x4 (CRIPTO L del bundle B)", rdata[5], 32'h0000_00BB);
    check("banco: x0", rdata[6], 32'd0);
    check("banco: x2 sin escribir", rdata[7], 32'd0);


    tb_finish("tb_wb");
end

endmodule
