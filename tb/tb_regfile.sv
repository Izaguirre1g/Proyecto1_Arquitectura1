`timescale 1ns/1ps

/*
================================================================================
 Testbench: tb_regfile

 Descripción:
 ------------------------------------------------------------------------------
 Verificación autoverificable del banco de registros (regfile) en su
 configuración completa del VLIW: 32 registros, 8 puertos de lectura y 5 de
 escritura.

 Casos:
   1. Reset: los 32 registros se leen como 0 por los 8 puertos.
   2. Escritura y lectura de x1–x31 por los 5 puertos de escritura, leyendo
      cada registro por los 8 puertos de lectura.
   3. x0: las escrituras se descartan desde cualquier puerto.
   4. we = 0: con dirección y dato presentes, no se escribe nada.
   5. Sin bypass: en el ciclo de la escritura se lee el valor anterior; el
      valor nuevo se ve después del flanco.
   6. Cinco escrituras simultáneas a registros distintos.
   7. Ocho lecturas simultáneas, incluyendo x0 y el mismo registro por varios
      puertos.
   8. Conflictos de escritura: gana el puerto de índice mayor.
   9. Reset en medio de la ejecución.
  10. N_RANDOM ciclos aleatorios comparados contra un modelo de referencia.
  11. Configuración de 2 lecturas y 1 escritura (la que usa hoy id_stage).

 El estímulo cambia en el flanco negativo y el banco escribe en el positivo.

 Plusargs: +seed=N, +verbose.

================================================================================
*/

module tb_regfile;

`include "tb_utils.svh"


localparam int NR = 8;
localparam int NW = 5;
localparam int N_RANDOM = 2000;

integer seed;


logic clk;
logic reset;

logic [NR-1:0][4:0]  raddr;
logic [NR-1:0][31:0] rdata;

logic [NW-1:0]       we;
logic [NW-1:0][4:0]  waddr;
logic [NW-1:0][31:0] wdata;


regfile DUT (

    .clk(clk),
    .reset(reset),
    .raddr(raddr),
    .rdata(rdata),
    .we(we),
    .waddr(waddr),
    .wdata(wdata)
);


// Instancia con la configuración de id_stage (2 lecturas, 1 escritura)

logic [1:0][4:0]  s_raddr;
logic [1:0][31:0] s_rdata;
logic             s_we;
logic [4:0]       s_waddr;
logic [31:0]      s_wdata;

regfile #(

    .NUM_READ_PORTS(2),
    .NUM_WRITE_PORTS(1)

) DUT_SMALL (

    .clk(clk),
    .reset(reset),
    .raddr(s_raddr),
    .rdata(s_rdata),
    .we(s_we),
    .waddr(s_waddr),
    .wdata(s_wdata)
);


always #5 clk = ~clk;


// Modelo de referencia del contenido del banco

logic [31:0] model [32];


// Aplica al modelo las escrituras presentes en los puertos, con la misma
// prioridad del banco (el puerto de índice mayor se aplica de último)
task automatic model_write();

    for(int p = 0; p < NW; p++)
        if(we[p] && waddr[p] != 5'd0)
            model[waddr[p]] = wdata[p];
endtask


task automatic idle_ports();

    we = '0;
    waddr = '0;
    wdata = '0;
endtask


// Ejecuta un ciclo de escritura con los puertos ya configurados
task automatic do_cycle();

    @(posedge clk);

    model_write();

    @(negedge clk);

    idle_ports();
endtask


task automatic do_reset();

    @(negedge clk);

    reset = 1'b1;
    idle_ports();

    @(negedge clk);

    reset = 1'b0;

    for(int r = 0; r < 32; r++)
        model[r] = 32'd0;
endtask


// Lee un registro por un puerto y lo compara con el valor esperado
task automatic read_check(input string name, input int port, input logic [4:0] addr, input logic [31:0] exp);

    raddr[port] = addr;

    #1;

    check($sformatf("%s: puerto %0d lee x%0d", name, port, addr), rdata[port], exp);
endtask


// Lee los 32 registros por todos los puertos y los compara con el modelo
task automatic check_all(input string name);

    for(int r = 0; r < 32; r++)
        for(int p = 0; p < NR; p++)
            read_check(name, p, r[4:0], model[r]);
endtask


// Valor de prueba distinto para cada registro
function automatic logic [31:0] pattern(input int r);

    return {8'hA0 + r[7:0], 8'h5C, r[7:0], ~r[7:0]};
endfunction


initial begin

    $dumpfile("tb_regfile.vcd");
    $dumpvars(0, tb_regfile);

    if(!$value$plusargs("seed=%d", seed))
        seed = 32'hCE4301;

    $display("tb_regfile: semilla de vectores aleatorios = %0d", seed);

    clk = 0;
    reset = 0;
    raddr = '0;
    idle_ports();

    s_raddr = '0;
    s_we = 1'b0;
    s_waddr = 5'd0;
    s_wdata = 32'd0;


    // =================================================
    // 1. Reset
    // =================================================

    tb_section("1. Reset");

    do_reset();

    check_all("reset");


    // =================================================
    // 2. Escritura y lectura de x1-x31
    // =================================================

    tb_section("2. Escritura de x1-x31 por los 5 puertos y lectura por los 8");

    for(int r = 1; r < 32; r++) begin

        @(negedge clk);

        we[r % NW] = 1'b1;
        waddr[r % NW] = r[4:0];
        wdata[r % NW] = pattern(r);

        do_cycle();
    end

    check_all("escritura");


    // =================================================
    // 3. x0
    // =================================================

    tb_section("3. Escrituras a x0 desde todos los puertos");

    @(negedge clk);

    for(int p = 0; p < NW; p++) begin

        we[p] = 1'b1;
        waddr[p] = 5'd0;
        wdata[p] = 32'hFFFF_FFFF;
    end

    do_cycle();

    for(int p = 0; p < NR; p++)
        read_check("x0", p, 5'd0, 32'd0);

    check_all("x0 no altera otros registros");


    // =================================================
    // 4. we = 0
    // =================================================

    tb_section("4. Puertos con we = 0");

    @(negedge clk);

    for(int p = 0; p < NW; p++) begin

        we[p] = 1'b0;
        waddr[p] = p[4:0] + 5'd1;
        wdata[p] = 32'hDEAD_0000 + p;
    end

    do_cycle();

    check_all("we = 0");


    // =================================================
    // 5. Sin bypass: lectura en el mismo ciclo de la escritura
    // =================================================

    tb_section("5. Lectura en el mismo ciclo de la escritura (sin bypass)");

    @(negedge clk);

    we[0] = 1'b1;
    waddr[0] = 5'd9;
    wdata[0] = 32'h1234_ABCD;

    read_check("antes del flanco", 0, 5'd9, model[9]);

    do_cycle();

    read_check("después del flanco", 0, 5'd9, 32'h1234_ABCD);


    // =================================================
    // 6. Cinco escrituras simultáneas
    // =================================================

    tb_section("6. Cinco escrituras simultáneas a registros distintos");

    @(negedge clk);

    for(int p = 0; p < NW; p++) begin

        we[p] = 1'b1;
        waddr[p] = 5'd10 + p[4:0];
        wdata[p] = 32'hC0DE_0000 + p;
    end

    do_cycle();

    for(int p = 0; p < NW; p++)
        read_check("escritura simultánea", 0, 5'd10 + p[4:0], 32'hC0DE_0000 + p);


    // =================================================
    // 7. Ocho lecturas simultáneas
    // =================================================

    tb_section("7. Ocho lecturas simultáneas");

    @(negedge clk);

    raddr[0] = 5'd10;
    raddr[1] = 5'd11;
    raddr[2] = 5'd12;
    raddr[3] = 5'd13;
    raddr[4] = 5'd14;
    raddr[5] = 5'd0;
    raddr[6] = 5'd10;
    raddr[7] = 5'd31;

    #1;

    for(int p = 0; p < NR; p++)
        check($sformatf("lectura simultánea: puerto %0d lee x%0d", p, raddr[p]), rdata[p], model[raddr[p]]);


    // =================================================
    // 8. Conflictos de escritura
    // =================================================

    tb_section("8. Conflictos: gana el puerto de índice mayor");

    // Puertos 0 (ALU) y 1 (LSU) sobre x15
    @(negedge clk);

    we[0] = 1'b1; waddr[0] = 5'd15; wdata[0] = 32'hAAAA_0000;
    we[1] = 1'b1; waddr[1] = 5'd15; wdata[1] = 32'hAAAA_0001;

    do_cycle();

    read_check("ALU vs LSU", 0, 5'd15, 32'hAAAA_0001);

    // Puertos 0, 2 y 4 sobre x16
    @(negedge clk);

    we[0] = 1'b1; waddr[0] = 5'd16; wdata[0] = 32'hBBBB_0000;
    we[2] = 1'b1; waddr[2] = 5'd16; wdata[2] = 32'hBBBB_0002;
    we[4] = 1'b1; waddr[4] = 5'd16; wdata[4] = 32'hBBBB_0004;

    do_cycle();

    read_check("ALU vs BRU vs CRIPTO R", 0, 5'd16, 32'hBBBB_0004);

    // Los 5 puertos sobre x17
    @(negedge clk);

    for(int p = 0; p < NW; p++) begin

        we[p] = 1'b1;
        waddr[p] = 5'd17;
        wdata[p] = 32'hCCCC_0000 + p;
    end

    do_cycle();

    read_check("5 puertos", 0, 5'd17, 32'hCCCC_0004);

    // Conflicto en un registro y escritura normal en otro, en el mismo ciclo
    @(negedge clk);

    we[1] = 1'b1; waddr[1] = 5'd18; wdata[1] = 32'hDDDD_0001;
    we[3] = 1'b1; waddr[3] = 5'd18; wdata[3] = 32'hDDDD_0003;
    we[2] = 1'b1; waddr[2] = 5'd19; wdata[2] = 32'hDDDD_0002;

    do_cycle();

    read_check("LSU vs CRIPTO L", 0, 5'd18, 32'hDDDD_0003);
    read_check("escritura sin conflicto en el mismo ciclo", 1, 5'd19, 32'hDDDD_0002);

    check_all("después de los conflictos");


    // =================================================
    // 9. Reset en medio de la ejecución
    // =================================================

    tb_section("9. Reset en medio de la ejecución");

    do_reset();

    check_all("segundo reset");


    // =================================================
    // 10. Ciclos aleatorios contra el modelo
    // =================================================

    tb_section($sformatf("10. %0d ciclos aleatorios", N_RANDOM));

    repeat(N_RANDOM) begin

        @(negedge clk);

        for(int p = 0; p < NW; p++) begin

            we[p] = $random(seed);
            waddr[p] = $random(seed);
            wdata[p] = $random(seed);
        end

        for(int p = 0; p < NR; p++)
            raddr[p] = $random(seed);

        #1;

        // Antes del flanco se leen los valores anteriores
        for(int p = 0; p < NR; p++)
            check($sformatf("aleatorio: puerto %0d lee x%0d", p, raddr[p]), rdata[p], model[raddr[p]]);

        do_cycle();
    end

    check_all("final aleatorio");


    // =================================================
    // 11. Configuración 2R / 1W
    // =================================================

    tb_section("11. Configuración de 2 lecturas y 1 escritura");

    @(negedge clk);

    s_we = 1'b1;
    s_waddr = 5'd21;
    s_wdata = 32'h0BAD_F00D;

    @(negedge clk);

    s_we = 1'b1;
    s_waddr = 5'd0;
    s_wdata = 32'hFFFF_FFFF;

    @(negedge clk);

    s_we = 1'b0;
    s_raddr[0] = 5'd21;
    s_raddr[1] = 5'd0;

    #1;

    check("2R/1W: lee x21", s_rdata[0], 32'h0BAD_F00D);
    check("2R/1W: x0 sigue en 0", s_rdata[1], 32'd0);


    tb_finish("tb_regfile");
end

endmodule
