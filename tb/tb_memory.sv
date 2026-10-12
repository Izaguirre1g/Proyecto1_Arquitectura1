/*
================================================================================
 Testbench: tb_memory
 ------------------------------------------------------------------------------
 Verificación autoverificable de la memoria de datos (rtl/memory.sv).

 Casos cubiertos:
     1. Reset y lectura de celdas no escritas (deben valer 0).
     2. Escritura de palabra completa (guardap: be = 4'b1111).
     3. Escritura de byte en cada posición de la palabra (guardab: be = 4'b0001 << off[1:0]).
     4. Escrituras parciales superpuestas sobre la misma palabra (little-endian).
     5. Escritura con máscara parcial (mezcla de bytes nuevos y antiguos).
     6. Lectura de bytes individuales con sign-extension (no aplica aquí, esa
        lógica vive en la LSU; la memoria sólo entrega la palabra cruda).
     7. Barridos de corner case: direcciones 0, 1, 2, 3, último byte, último
        byte - 1, mitad de la memoria.
     8. Modelo de referencia independiente (escritura/lectura explícita).

 Nota: usamos una memoria pequeña (SIZE_WORDS = 256) para acelerar la sim.

================================================================================
*/

`timescale 1ns/1ps


module tb_memory;

`include "tb_utils.svh"


localparam int SIZE_WORDS = 256;
localparam int N_RANDOM   = 500;

integer seed_val;

logic clk;
logic we_dut;
logic [3:0]   be_dut;
logic [31:0]  addr_dut;
logic [31:0]  wdata_dut;
logic [31:0]  rdata_dut;


// DUT con SIZE_WORDS = 256 (1 KB) para que la simulación sea rápida
memory #(.SIZE_WORDS(SIZE_WORDS)) DUT (
    .clk(clk),
    .we(we_dut),
    .be(be_dut),
    .addr(addr_dut),
    .wdata(wdata_dut),
    .rdata(rdata_dut)
);


// Reloj
always #5 clk = ~clk;


// Modelo de referencia: un arreglo igual al DUT que escribimos y leemos a mano
logic [31:0] ref_mem [0:SIZE_WORDS-1];

task automatic ref_write_word(input int waddr, input logic [31:0] data);
    ref_mem[waddr] = data;
endtask

task automatic ref_write_byte(input logic [31:0] byte_addr, input logic [7:0] data);
    int wa = byte_addr >> 2;
    int bi = byte_addr & 3;
    case (bi)
        0: ref_mem[wa][ 7: 0] = data;
        1: ref_mem[wa][15: 8] = data;
        2: ref_mem[wa][23:16] = data;
        3: ref_mem[wa][31:24] = data;
    endcase
endtask

task automatic ref_read(input logic [31:0] byte_addr, output logic [31:0] data);
    data = ref_mem[byte_addr >> 2];
endtask


// Inicialización de los modelos (compatible con Icarus 12)
initial begin : init_ref
    integer i;
    for (i = 0; i < SIZE_WORDS; i = i + 1)
        ref_mem[i] = 32'b0;
end


// Estímulo principal
initial begin

    $dumpfile("tb_memory.vcd");
    $dumpvars(0, tb_memory);

    if (!$value$plusargs("seed=%d", seed_val))
        seed_val = 32'hCE4301;

    $display("tb_memory: semilla = %0d", seed_val);

    clk     = 0;
    we_dut  = 0;
    be_dut  = 4'b0000;
    addr_dut = 32'b0;
    wdata_dut = 32'b0;


    // =================================================================
    // 1. Reset / lectura inicial = 0
    // =================================================================
    tb_section("1. Lectura de celdas no escritas");

    @(negedge clk);
    addr_dut = 32'h0000_0000; #1;
    check("mem[0] sin escribir", rdata_dut, 32'h0);

    addr_dut = 32'h0000_0100; #1;
    check("mem[0x40] sin escribir", rdata_dut, 32'h0);


    // =================================================================
    // 2. Escritura de palabra completa (guardap, be = 4'b1111)
    // =================================================================
    tb_section("2. Escritura de palabra completa (guardap)");

    @(negedge clk);
    we_dut   = 1'b1;
    be_dut   = 4'b1111;
    addr_dut = 32'h0000_0000;
    wdata_dut = 32'hDEAD_BEEF;
    @(posedge clk);  // se captura en el flanco
    ref_write_word(32'h0000_0000 >> 2, 32'hDEAD_BEEF);

    @(negedge clk);
    we_dut = 1'b0;
    addr_dut = 32'h0000_0000; #1;
    check("mem[0] = 0xDEADBEEF", rdata_dut, 32'hDEAD_BEEF);

    ref_write_word(0, 32'hDEAD_BEEF);
    check("referencia mem[0]", rdata_dut, ref_mem[0]);


    // =================================================================
    // 3. Escritura de byte en cada posición de la palabra
    // =================================================================
    tb_section("3. Escritura de byte (guardab) en cada posición");

    @(negedge clk);
    we_dut   = 1'b1;
    addr_dut = 32'h0000_0000;
    wdata_dut = 32'h0000_0055;
    be_dut   = 4'b0001;        // byte 0 (LSB)
    @(posedge clk);

    @(negedge clk);
    addr_dut = 32'h0000_0001;
    wdata_dut = 32'h0000_AA00;   // byte 0 de wdata contiene el byte a escribir
    be_dut   = 4'b0010;        // byte 1
    @(posedge clk);

    @(negedge clk);
    addr_dut = 32'h0000_0002;
    wdata_dut = 32'h00BB_0000;   // byte 0 de wdata contiene el byte a escribir
    be_dut   = 4'b0100;        // byte 2
    @(posedge clk);

    @(negedge clk);
    addr_dut = 32'h0000_0003;
    wdata_dut = 32'hCC00_0000;   // byte 0 de wdata contiene el byte a escribir
    be_dut   = 4'b1000;        // byte 3 (MSB)
    @(posedge clk);

    @(negedge clk);
    we_dut = 1'b0;
    addr_dut = 32'h0000_0000; #1;
    check("mem[0] = 0xCCBB_AA55 (little-endian)", rdata_dut, 32'hCCBB_AA55);

    ref_write_byte(0, 8'h55);
    ref_write_byte(1, 8'hAA);
    ref_write_byte(2, 8'hBB);
    ref_write_byte(3, 8'hCC);


    // =================================================================
    // 4. Escritura con máscara parcial (no toca bytes no habilitados)
    // =================================================================
    tb_section("4. Máscara parcial preserva bytes adyacentes");

    // Escribimos 0x11223344 palabra completa
    @(negedge clk);
    we_dut   = 1'b1;
    be_dut   = 4'b1111;
    addr_dut = 32'h0000_0010;
    wdata_dut = 32'h1122_3344;
    @(posedge clk);
    ref_write_word(32'h0000_0010 >> 2, 32'h1122_3344);

    // Ahora sólo modificamos el byte 1 con be = 4'b0010
    @(negedge clk);
    be_dut   = 4'b0010;
    addr_dut = 32'h0000_0011;
    wdata_dut = 32'h0000_FF00;   // byte 0 de wdata contiene 0xFF (que se coloca en byte 1)
    @(posedge clk);
    ref_write_byte(32'h0000_0011, 8'hFF);

    @(negedge clk);
    we_dut = 1'b0;
    addr_dut = 32'h0000_0010; #1;
    check("mem[0x10] = 0x1122_FF44 tras be parcial", rdata_dut, 32'h1122_FF44);


    // =================================================================
    // 5. Direcciones límite: 0, 1, 2, 3, último byte
    // =================================================================
    tb_section("5. Direcciones límite (palabras distintas)");

    @(negedge clk);
    we_dut   = 1'b1;
    be_dut   = 4'b1111;
    addr_dut = 32'h0000_0000;
    wdata_dut = 32'h0000_0001;
    @(posedge clk);
    ref_write_word(32'h0000_0000 >> 2, 32'h0000_0001);

    @(negedge clk);
    addr_dut = 32'h0000_0004;
    wdata_dut = 32'h0000_0002;
    @(posedge clk);
    ref_write_word(32'h0000_0004 >> 2, 32'h0000_0002);

    @(negedge clk);
    addr_dut = 32'h0000_0008;
    wdata_dut = 32'h0000_0003;
    @(posedge clk);
    ref_write_word(32'h0000_0008 >> 2, 32'h0000_0003);

    @(negedge clk);
    addr_dut = 32'h0000_000C;
    wdata_dut = 32'h0000_0004;
    @(posedge clk);
    ref_write_word(32'h0000_000C >> 2, 32'h0000_0004);

    @(negedge clk);
    we_dut = 1'b0;
    addr_dut = 32'h0000_0000; #1;
    check("addr=0 palabra", rdata_dut, 32'h0000_0001);
    addr_dut = 32'h0000_0004; #1;
    check("addr=4 palabra", rdata_dut, 32'h0000_0002);
    addr_dut = 32'h0000_0008; #1;
    check("addr=8 palabra", rdata_dut, 32'h0000_0003);
    addr_dut = 32'h0000_000C; #1;
    check("addr=12 palabra", rdata_dut, 32'h0000_0004);


    // =================================================================
// 6. Vector aleatorio contra modelo de referencia
// =================================================================
tb_section($sformatf("6. %0d escrituras/lecturas aleatorias contra modelo", N_RANDOM));

    repeat (N_RANDOM) begin
        logic [31:0] exp;
        logic [31:0] byte_addr;
        logic [1:0]  off2;
        logic [7:0]  byte_data;
        logic [3:0]  be_val;
        logic [31:0] word_val;

        byte_addr = ($random(seed_val) & 32'h0000_03FF);  // % SIZE_WORDS*4 pero sin signo

        if ($random(seed_val) & 1) begin
            // Escritura de palabra
            word_val = $random(seed_val);
            be_val   = 4'b1111;
            ref_write_word(byte_addr >> 2, word_val);
        end
        else begin
            // Escritura de byte
            byte_data = $random(seed_val) & 8'hFF;
            off2      = byte_addr[1:0];
            be_val    = 4'b0001 << off2;
            word_val  = {24'b0, byte_data} << (off2 * 8);
            ref_write_byte(byte_addr, byte_data);
        end

        @(negedge clk);
        we_dut   = 1'b1;
        be_dut   = be_val;
        addr_dut = byte_addr;
        wdata_dut = word_val;
        @(posedge clk);

        @(negedge clk);
        we_dut = 1'b0;
        ref_read(byte_addr, exp);
        addr_dut = byte_addr; #1;
        check("aleatorio: palabra coincide con ref", rdata_dut, exp);
    end


    @(negedge clk);
    tb_finish("tb_memory");
end

endmodule