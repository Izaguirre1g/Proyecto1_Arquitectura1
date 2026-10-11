`timescale 1ns/1ps

/*
================================================================================
 Testbench: tb_pipeline_integracion

 Descripción:
 ------------------------------------------------------------------------------
 Ejecuta programas cortos sobre el procesador completo (top) y verifica la
 integración de los slots ALU, LSU y BRU dentro del pipeline IF / ID / EX / WB.
 Cada programa se escribe directo en instruction_memory, se ejecuta desde el
 reset y al final se revisan el banco de registros, la memoria de datos y el
 orden y los ciclos en que cada bundle pasó por EX.

 Casos:
   A. Memoria: guardap, guardab, cargai y cargabai seguidos, y ningún bundle
      con NOP en el slot 1 escribe la memoria (NOP = 0x00000000 deja
      lsu_op = 0, que es el código de guardap).
   B. Saltos: un salto no tomado no cuesta ciclos; uno tomado (igualno, sye,
      mayoroigual) anula exactamente los 2 bundles que lo siguen y el destino
      llega a EX 3 ciclos después del salto (penalización de 2 ciclos, sin
      delay slots). sye escribe rg = PC + 4.
   C. Bundle mixto: ALU, LSU y BRU en el mismo bundle, y un bundle cuyo
      writeback escribe 3 registros en el mismo ciclo (ALU, carga y enlace
      de sye).
   D. Bucle hacia atrás (offset negativo) que se repite 3 veces.

 En todos los casos wb no debe reportar conflictos de escritura.

 Los programas respetan la regla de dependencias del banco de registros: un
 valor escrito por el bundle N se lee desde el bundle N+3.

================================================================================
*/

`include "isa_defs.sv"


module tb_pipeline_integracion;

`include "tb_utils.svh"


logic clk;
logic reset;

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
// Codificación de instrucciones (formatos del ISA)
// ============================================================================

localparam logic [31:0] NOP = 32'h0000_0000;

// sumai rg, rf1, imm
function automatic logic [31:0] sumai(input logic [4:0] rg, input logic [4:0] rf1,
                                      input logic [10:0] imm);

    return {TYPE_IMM, OP_SUMI, rf1, rg, imm};
endfunction

// Tipo almacenar: guardap/guardab base, dato, off · cargai/cargabai rg, base, off
function automatic logic [31:0] lsu(input logic [3:0] id, input logic [4:0] base,
                                    input logic [4:0] reg_dato, input logic [10:0] off);

    return {TYPE_LSU, id, base, reg_dato, off};
endfunction

// Tipo control: igualsi/igualno/menora/mayoroigual rf1, rf2, off (bytes)
function automatic logic [31:0] branch(input logic [3:0] id, input logic [4:0] rf1,
                                       input logic [4:0] rf2, input logic [10:0] off);

    return {TYPE_BRU_COND, id, rf1, rf2, off};
endfunction

// sye rg, off (bytes)
function automatic logic [31:0] sye(input logic [4:0] rg, input logic [15:0] off);

    return {TYPE_BRU_JUMP, OP_SYE, rg, off};
endfunction

// Bundle: slot 0 ALU en los bits bajos, slot 3 CRIPTO en los altos
function automatic logic [127:0] bundle(input logic [31:0] alu, input logic [31:0] mem,
                                        input logic [31:0] bru, input logic [31:0] cripto);

    return {cripto, bru, mem, alu};
endfunction

function automatic logic [127:0] solo_alu(input logic [31:0] alu);

    return bundle(alu, NOP, NOP, NOP);
endfunction


// ============================================================================
// Monitores: qué bundle pasa por EX en cada ciclo y cuántas escrituras hace wb
// ============================================================================

int cycle = 0;

always @(posedge clk)
    cycle <= cycle + 1;

logic [31:0] ex_pc_log  [0:255];
int          ex_cyc_log [0:255];
int          n_ex = 0;
int          conflicts = 0;
int          max_writes = 0;

always @(negedge clk) begin

    if(!reset) begin

        if(DUT.id_ex_valid && n_ex < 256) begin

            ex_pc_log[n_ex]  = DUT.ex_pc;
            ex_cyc_log[n_ex] = cycle;
            n_ex++;
        end

        if(DUT.wb_conflict)
            conflicts++;

        if(DUT.wb_we[0] + DUT.wb_we[1] + DUT.wb_we[2] + DUT.wb_we[3] + DUT.wb_we[4] > max_writes)
            max_writes = DUT.wb_we[0] + DUT.wb_we[1] + DUT.wb_we[2] + DUT.wb_we[3] + DUT.wb_we[4];
    end
end

// Ciclo en que el bundle de dirección pc pasó por EX por primera vez (-1 si nunca)
function automatic int first_ex(input logic [31:0] pc);

    for(int i = 0; i < n_ex; i++)
        if(ex_pc_log[i] == pc)
            return ex_cyc_log[i];

    return -1;
endfunction

function automatic logic [31:0] reg_val(input int r);

    return DUT.REGFILE.regs[r];
endfunction

function automatic logic [31:0] mem_word(input logic [31:0] byte_addr);

    return DUT.DMEM.mem[byte_addr >> 2];
endfunction


// ============================================================================
// Carga y ejecución de programas
// ============================================================================

logic [127:0] prog [0:31];

task automatic clear_prog();

    for(int i = 0; i < 32; i++)
        prog[i] = 128'b0;
endtask

// Carga prog en la memoria de instrucciones, aplica reset y ejecuta.
// El banco de registros se reinicia; la memoria de datos no.
task automatic run_program(input int cycles);

    @(negedge clk);
    reset = 1;

    for(int i = 0; i < 32; i++)
        DUT.IMEM.memory[i] = prog[i];

    repeat(2) @(negedge clk);

    n_ex = 0;
    conflicts = 0;
    max_writes = 0;
    reset = 0;

    repeat(cycles) @(negedge clk);
endtask


// ============================================================================
// Programas
// ============================================================================

initial begin

    $dumpfile("tb_pipeline_integracion.vcd");
    $dumpvars(0, tb_pipeline_integracion);

    clk = 0;
    reset = 1;

    // Esperar a que instruction_memory y memory terminen su inicialización
    #1;


    // ========================================================================
    // A. Memoria
    // ========================================================================
    tb_section("A. Cargas, guardados y NOP en el slot LSU");

    // Valor centinela en la dirección 0: ningún bundle sin LSU debe tocarlo
    DUT.DMEM.mem[0] = 32'hCAFE_BABE;

    clear_prog();
    prog[0]  = solo_alu(sumai(5'd4, 5'd0, 11'd127));                       // x4 = 127
    prog[1]  = solo_alu(sumai(5'd7, 5'd0, -11'sd1));                       // x7 = -1
    prog[2]  = solo_alu(sumai(5'd9, 5'd0, 11'd256));                       // x9 = 0x100
    prog[5]  = bundle(NOP, lsu(OP_GUARDAP,  5'd9, 5'd4,  11'd0), NOP, NOP); // M[0x100] = x4
    prog[6]  = bundle(NOP, lsu(OP_GUARDAB,  5'd9, 5'd7,  11'd5), NOP, NOP); // M[0x105] = 0xFF
    prog[7]  = bundle(NOP, lsu(OP_CARGAI,   5'd9, 5'd5,  11'd0), NOP, NOP); // x5 = M[0x100]
    prog[8]  = bundle(NOP, lsu(OP_CARGABAI, 5'd9, 5'd6,  11'd5), NOP, NOP); // x6 = sext(M[0x105])
    prog[9]  = bundle(NOP, lsu(OP_CARGAI,   5'd0, 5'd8,  11'd0), NOP, NOP); // x8 = M[0]
    prog[10] = bundle(NOP, lsu(OP_CARGAI,   5'd9, 5'd10, 11'd4), NOP, NOP); // x10 = M[0x104]
    prog[13] = bundle(NOP, NOP, sye(5'd0, 16'd0), NOP);                    // fin: bucle

    run_program(30);

    check("guardap: M[0x100] = 127",                    mem_word(32'h100), 32'd127);
    check("guardab: M[0x104] = 0x0000FF00",             mem_word(32'h104), 32'h0000_FF00);
    check("cargai: x5 = 127",                           reg_val(5), 32'd127);
    check("cargabai: x6 = sext(0xFF) = -1",             reg_val(6), 32'hFFFF_FFFF);
    check("cargai de M[0]: x8 = 0xCAFEBABE",            reg_val(8), 32'hCAFE_BABE);
    check("cargai: x10 = 0x0000FF00",                   reg_val(10), 32'h0000_FF00);
    check("NOP en el slot LSU no escribe M[0]",         mem_word(32'h0), 32'hCAFE_BABE);
    check("sin conflictos de writeback",                conflicts, 0);


    // ========================================================================
    // B. Saltos
    // ========================================================================
    tb_section("B. Saltos tomados y no tomados");

    clear_prog();
    prog[0]  = solo_alu(sumai(5'd4, 5'd0, 11'd1));                                  // x4 = 1
    prog[1]  = solo_alu(sumai(5'd5, 5'd0, 11'd2));                                  // x5 = 2
    prog[4]  = bundle(sumai(5'd11, 5'd0, 11'd11), NOP,
                      branch(OP_IGUALSI, 5'd4, 5'd5, 11'd32), NOP);                 // no se toma
    prog[5]  = solo_alu(sumai(5'd12, 5'd0, 11'd12));
    prog[6]  = bundle(sumai(5'd13, 5'd0, 11'd13), NOP,
                      branch(OP_IGUALNO, 5'd4, 5'd5, 11'd64), NOP);                 // -> B10
    prog[7]  = solo_alu(sumai(5'd20, 5'd0, 11'd1));                                 // anulado
    prog[8]  = solo_alu(sumai(5'd21, 5'd0, 11'd1));                                 // anulado
    prog[9]  = solo_alu(sumai(5'd22, 5'd0, 11'd1));                                 // saltado
    prog[10] = bundle(sumai(5'd14, 5'd0, 11'd14), NOP, sye(5'd1, 16'd48), NOP);     // -> B13
    prog[11] = solo_alu(sumai(5'd23, 5'd0, 11'd1));                                 // anulado
    prog[12] = solo_alu(sumai(5'd24, 5'd0, 11'd1));                                 // anulado
    prog[13] = bundle(sumai(5'd15, 5'd0, 11'd15), NOP,
                      branch(OP_MENORA, 5'd5, 5'd4, 11'd32), NOP);                  // no se toma
    prog[14] = bundle(NOP, NOP, branch(OP_MAYOROIGUAL, 5'd5, 5'd4, 11'd48), NOP);   // -> B17
    prog[15] = solo_alu(sumai(5'd25, 5'd0, 11'd1));                                 // anulado
    prog[16] = solo_alu(sumai(5'd26, 5'd0, 11'd1));                                 // anulado
    prog[17] = bundle(NOP, NOP, sye(5'd0, 16'd0), NOP);                             // fin: bucle

    run_program(45);

    check("igualsi no tomado: B5 entra a EX 1 ciclo después de B4",
          first_ex(32'h50) - first_ex(32'h40), 32'd1);
    check("igualno tomado: B10 entra a EX 3 ciclos después de B6",
          first_ex(32'hA0) - first_ex(32'h60), 32'd3);
    check("sye: B13 entra a EX 3 ciclos después de B10",
          first_ex(32'hD0) - first_ex(32'hA0), 32'd3);
    check("menora no tomado: B14 entra a EX 1 ciclo después de B13",
          first_ex(32'hE0) - first_ex(32'hD0), 32'd1);
    check("mayoroigual tomado: B17 entra a EX 3 ciclos después de B14",
          first_ex(32'h110) - first_ex(32'hE0), 32'd3);

    check_true("los bundles detrás de un salto tomado no llegan a EX",
               first_ex(32'h70) == -1 && first_ex(32'h80) == -1 && first_ex(32'h90) == -1 &&
               first_ex(32'hB0) == -1 && first_ex(32'hC0) == -1 &&
               first_ex(32'hF0) == -1 && first_ex(32'h100) == -1);

    check("ALU en el bundle de igualsi: x11 = 11",   reg_val(11), 32'd11);
    check("bundle tras salto no tomado: x12 = 12",   reg_val(12), 32'd12);
    check("ALU en el bundle de igualno: x13 = 13",   reg_val(13), 32'd13);
    check("ALU en el bundle de sye: x14 = 14",       reg_val(14), 32'd14);
    check("ALU en el bundle de menora: x15 = 15",    reg_val(15), 32'd15);
    check("sye x1: x1 = PC + 4 = 0xA4",              reg_val(1), 32'hA4);

    for(int r = 20; r <= 26; r++)
        check($sformatf("bundle anulado o saltado: x%0d = 0", r), reg_val(r), 32'd0);

    check("sin conflictos de writeback", conflicts, 0);


    // ========================================================================
    // C. Bundle mixto
    // ========================================================================
    tb_section("C. ALU, LSU y BRU en el mismo bundle");

    DUT.DMEM.mem[32'h200 >> 2] = 32'h1234_5678;

    clear_prog();
    prog[0]  = solo_alu(sumai(5'd4, 5'd0, 11'd9));                                  // x4 = 9
    prog[1]  = solo_alu(sumai(5'd5, 5'd0, 11'd64));                                 // x5 = 0x40
    prog[2]  = solo_alu(sumai(5'd9, 5'd0, 11'd512));                                // x9 = 0x200
    prog[5]  = bundle(sumai(5'd6, 5'd4, 11'd1),                                     // x6 = x4 + 1
                      lsu(OP_GUARDAP, 5'd5, 5'd4, 11'd0),                           // M[0x40] = x4
                      branch(OP_IGUALNO, 5'd4, 5'd0, 11'd48), NOP);                 // -> B8
    prog[6]  = solo_alu(sumai(5'd7, 5'd0, 11'd1));                                  // anulado
    prog[7]  = solo_alu(sumai(5'd7, 5'd0, 11'd2));                                  // anulado
    prog[8]  = bundle(sumai(5'd10, 5'd0, 11'd5),                                    // x10 = 5
                      lsu(OP_CARGAI, 5'd9, 5'd11, 11'd0),                           // x11 = M[0x200]
                      sye(5'd12, 16'd48), NOP);                                     // x12 = PC+4, -> B11
    prog[9]  = solo_alu(sumai(5'd7, 5'd0, 11'd3));                                  // anulado
    prog[10] = solo_alu(sumai(5'd7, 5'd0, 11'd4));                                  // anulado
    prog[11] = bundle(NOP, lsu(OP_CARGAI, 5'd5, 5'd8, 11'd0), NOP, NOP);            // x8 = M[0x40]
    prog[14] = bundle(NOP, NOP, sye(5'd0, 16'd0), NOP);                             // fin: bucle

    run_program(40);

    check("ALU del bundle mixto: x6 = 10",                 reg_val(6), 32'd10);
    check("LSU del bundle mixto: M[0x40] = 9",             mem_word(32'h40), 32'd9);
    check("bundles anulados: x7 = 0",                      reg_val(7), 32'd0);
    check("cargai después del salto: x8 = 9",              reg_val(8), 32'd9);
    check("ALU junto a cargai y sye: x10 = 5",             reg_val(10), 32'd5);
    check("cargai junto a ALU y sye: x11 = 0x12345678",    reg_val(11), 32'h1234_5678);
    check("sye junto a ALU y cargai: x12 = 0x84",          reg_val(12), 32'h84);
    check("wb escribió 3 registros en el mismo ciclo",     max_writes, 3);
    check("sin conflictos de writeback",                   conflicts, 0);


    // ========================================================================
    // D. Bucle hacia atrás
    // ========================================================================
    tb_section("D. Bucle con salto hacia atrás");

    clear_prog();
    prog[0] = solo_alu(sumai(5'd4, 5'd0, 11'd3));                                   // x4 = 3
    prog[3] = solo_alu(sumai(5'd4, 5'd4, -11'sd1));                                 // bucle: x4--
    prog[6] = bundle(sumai(5'd5, 5'd5, 11'd1), NOP,                                 // x5++
                     branch(OP_IGUALNO, 5'd4, 5'd0, -11'sd48), NOP);                // -> B3 si x4 != 0
    prog[7] = bundle(NOP, NOP, sye(5'd0, 16'd0), NOP);                              // fin: bucle

    run_program(60);

    check("contador: x4 = 0",                      reg_val(4), 32'd0);
    check("el cuerpo se ejecutó 3 veces: x5 = 3",  reg_val(5), 32'd3);
    check("sin conflictos de writeback",           conflicts, 0);


    tb_finish("tb_pipeline_integracion");
end

endmodule
