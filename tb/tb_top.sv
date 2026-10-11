`timescale 1ns/1ps

/*
================================================================================
 Testbench: tb_top

 Descripción:
 ------------------------------------------------------------------------------
 Prueba del sistema completo (rtl/top.sv) con un programa cargado desde un
 archivo .mem, igual que un programa del ensamblador.

 El testbench escribe el programa en programa_tb_top.mem (una línea de 32
 dígitos hexadecimales por bundle, con el slot CRIPTO en los bits altos y el
 slot ALU en los bajos, el formato de tools/assembler.py) y lo carga en la
 memoria de instrucciones con $readmemh:

     B0   suma  x5, x2, x3       x5 = 20 + 30 = 50
     B1   nop
     B2   nop
     B3   nop
     B4   resta x6, x5, x2       x6 = 50 - 20 = 30
     B5   nop
     B6   nop
     B7   sye   x0, 0            fin: se queda en este bundle

 Casos:
   1. El archivo .mem se carga en el orden de slots correcto.
   2. Las escrituras de la ALU (salidas debug) llegan en orden: x5 = 50 y
      después x6 = 30 (caso original).
   3. Resultado final en el banco de registros.
   4. Pipeline: en un mismo ciclo hay 4 bundles distintos, uno en cada
      etapa IF, ID, EX y WB, con PCs consecutivos.

================================================================================
*/

`include "isa_defs.sv"


module tb_top;

`include "tb_utils.svh"


logic        clk;
logic        reset;
logic [31:0] debug_result;
logic [4:0]  debug_rd;
logic        debug_write;


top DUT (
    .clk(clk),
    .reset(reset),
    .debug_result(debug_result),
    .debug_rd(debug_rd),
    .debug_write(debug_write)
);


always #5 clk = ~clk;


// ============================================================================
// Programa
// ============================================================================

localparam logic [31:0] NOP = 32'h0;

logic [BUNDLE_W-1:0] program_bundles [0:7];

function automatic logic [BUNDLE_W-1:0] bundle(input logic [31:0] alu, input logic [31:0] lsu,
                                               input logic [31:0] bru, input logic [31:0] cripto);

    return {cripto, bru, lsu, alu};
endfunction

task automatic write_program_file(input string path);

    integer fd;

    program_bundles[0] = bundle({TYPE_REG, OP_SUM,   5'd5, 5'd2, 5'd3, 6'b0}, NOP, NOP, NOP);
    program_bundles[1] = '0;
    program_bundles[2] = '0;
    program_bundles[3] = '0;
    program_bundles[4] = bundle({TYPE_REG, OP_RESTA, 5'd6, 5'd5, 5'd2, 6'b0}, NOP, NOP, NOP);
    program_bundles[5] = '0;
    program_bundles[6] = '0;
    program_bundles[7] = bundle(NOP, NOP, {TYPE_BRU_JUMP, OP_SYE, 5'd0, 16'd0}, NOP);

    fd = $fopen(path, "w");
    for (int i = 0; i < 8; i++)
        $fdisplay(fd, "%032h", program_bundles[i]);
    $fclose(fd);
endtask


// ============================================================================
// Monitores
// ============================================================================

// Escrituras de la ALU vistas en las salidas debug
int          n_writes = 0;
logic [4:0]  write_rd   [0:7];
logic [31:0] write_data [0:7];

always @(posedge clk) begin

    if (!reset && debug_write && n_writes < 8) begin

        write_rd[n_writes]   = debug_rd;
        write_data[n_writes] = debug_result;
        n_writes++;
    end
end

// Ciclos con un bundle distinto en cada etapa
int full_cycles = 0;

always @(negedge clk) begin

    if (!reset && DUT.id_valid && DUT.id_ex_valid && DUT.ex_wb_valid &&
        DUT.id_pc == DUT.ex_pc + BUNDLE_BYTES && DUT.pc == DUT.id_pc + BUNDLE_BYTES)
        full_cycles++;
end


// ============================================================================
// Estímulo
// ============================================================================

initial begin

    $dumpfile("tb_top.vcd");
    $dumpvars(0, tb_top);

    clk   = 0;
    reset = 1;

    // Esperar la inicialización de instruction_memory y cargar el programa
    #1;
    write_program_file("programa_tb_top.mem");
    $readmemh("programa_tb_top.mem", DUT.IMEM.memory, 0, 7);


    tb_section("1. Carga del archivo .mem");

    for (int i = 0; i < 8; i++)
        check_true($sformatf("bundle %0d cargado igual", i), DUT.IMEM.memory[i] === program_bundles[i]);
    check("B0: el slot ALU está en los bits bajos", DUT.IMEM.memory[0][31:0], program_bundles[0][31:0]);
    check("B7: el sye está en el slot BRU [95:64]", DUT.IMEM.memory[7][95:64],
          {TYPE_BRU_JUMP, OP_SYE, 5'd0, 16'd0});

    @(negedge clk);
    @(negedge clk);
    reset = 0;
    DUT.REGFILE.regs[2] = 32'd20;
    DUT.REGFILE.regs[3] = 32'd30;

    repeat (20) @(negedge clk);


    tb_section("2. Escrituras de la ALU (salidas debug)");

    check("primera escritura: x5", write_rd[0], 5'd5);
    check("primera escritura: 50", write_data[0], 32'd50);
    check("segunda escritura: x6", write_rd[1], 5'd6);
    check("segunda escritura: 30", write_data[1], 32'd30);


    tb_section("3. Banco de registros");

    check("x5 = x2 + x3 = 50", DUT.REGFILE.regs[5], 32'd50);
    check("x6 = x5 - x2 = 30", DUT.REGFILE.regs[6], 32'd30);
    check("x0 = 0", DUT.REGFILE.regs[0], 32'd0);


    tb_section("4. Bundles simultáneos en IF, ID, EX y WB");

    check_true("al menos un ciclo con 4 bundles distintos en el pipeline", full_cycles > 0);


    tb_finish("tb_top");
end

endmodule
