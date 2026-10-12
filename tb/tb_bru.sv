/*
================================================================================
 Testbench: tb_bru
 ------------------------------------------------------------------------------
 Verificación autoverificable de la Unidad de Control de Flujo (rtl/bru.sv).

 Casos cubiertos:
     Parte 1 - branches condicionales:
         1. igualsi: iguales (taken) / diferentes (not taken)
         2. igualno: diferentes (taken) / iguales (not taken)
         3. menora (signed): rf1 < rf2 (taken), rf1 > rf2 (not taken),
                              rf1 = -1 < rf2 = 0 (taken)
         4. mayoroigual (signed): rf1 >= rf2 (taken / not taken),
                                   rf1 = -1 >= rf2 = -2 (taken)

     Parte 2 - jumps (sye y syer):
         5. sye con offset positivo: siempre genera branch_flush (combinacional,
            en el mismo ciclo); link_we_d se retrasa 1 ciclo, link_rd_d =
            link_rd_in y link_value_d = PC + 16 (el bundle siguiente)
         6. sye con offset negativo
         7. syer: target = (rf1 + offset) con los 4 bits bajos en 0, no depende
            del PC ni de jmp_imm; offset positivo, negativo y destino
            desalineado; link_value_d = PC + 16

     Parte 3 - casos negativos:
         8. Slot BRU inactivo (is_branch=0, is_jump=0):
            branch_flush=0, target_pc = PC + 16 (default)

================================================================================
*/

`timescale 1ns/1ps


module tb_bru;

`include "tb_utils.svh"


// ============================================================================
// DUT
// ============================================================================

logic         clk;
logic         reset;

logic [31:0]  rf1_data;
logic [31:0]  rf2_data;
logic [31:0]  pc_current;
logic [3:0]   bru_op;
logic        is_branch;
logic        is_jump;
logic [10:0] br_imm;
logic [15:0] jmp_imm;
logic [4:0]  link_rd_in;

logic        dut_branch_flush;
logic [31:0] dut_target_pc;
logic        dut_link_we_d;
logic [4:0]  dut_link_rd_d;
logic [31:0] dut_link_value_d;


bru DUT (
    .clk(clk),
    .reset(reset),
    .rf1_data(rf1_data),
    .rf2_data(rf2_data),
    .pc_current(pc_current),
    .bru_op(bru_op),
    .is_branch(is_branch),
    .is_jump(is_jump),
    .br_imm(br_imm),
    .jmp_imm(jmp_imm),
    .link_rd_in(link_rd_in),
    .branch_flush(dut_branch_flush),
    .target_pc(dut_target_pc),
    .link_we_d(dut_link_we_d),
    .link_rd_d(dut_link_rd_d),
    .link_value_d(dut_link_value_d)
);


always #5 clk = ~clk;


// ============================================================================
// Helper: avanza un ciclo de reloj para observar los registros link_*
// ============================================================================

task automatic tick();
    @(posedge clk);
    #1;
endtask

task automatic reset_dut();
    @(negedge clk);
    reset = 1;
    tick; tick;
    @(negedge clk);
    reset = 0;
endtask


// ============================================================================
// Estímulo principal
// ============================================================================

initial begin

    $dumpfile("tb_bru.vcd");
    $dumpvars(0, tb_bru);

    clk       = 0;
    reset     = 1;
    rf1_data  = 32'd0;
    rf2_data  = 32'd0;
    pc_current = 32'd0;
    bru_op    = 4'd0;
    is_branch = 1'b0;
    is_jump   = 1'b0;
    br_imm    = 11'd0;
    jmp_imm   = 16'd0;
    link_rd_in = 5'd0;

    reset_dut();


    // =====================================================================
    // Parte 1: branches condicionales
    // =====================================================================

    tb_section("1. igualsi (OP_IGUALSI)");

    pc_current = 32'h0000_1000;
    br_imm    = 11'sd256;     // +256 bytes
    is_branch = 1'b1;
    bru_op    = OP_IGUALSI;

    rf1_data = 32'h0000_0055;
    rf2_data = 32'h0000_0055;
    #1;
    check_true("igualsi iguales -> flush", dut_branch_flush === 1'b1);
    check      ("igualsi iguales -> target", dut_target_pc, pc_current + 32'sd256);

    rf2_data = 32'h0000_00AA;
    #1;
    check_true("igualsi diferentes -> no flush", dut_branch_flush === 1'b0);
    check      ("igualsi diferentes -> target default", dut_target_pc, pc_current + 32'd16);


    tb_section("2. igualno (OP_IGUALNO)");

    pc_current = 32'h0000_2000;
    br_imm    = -11'sd8;      // -8 bytes (signed)
    bru_op    = OP_IGUALNO;

    rf1_data = 32'h0000_0055;
    rf2_data = 32'h0000_00AA;
    #1;
    check_true("igualno diferentes -> flush", dut_branch_flush === 1'b1);
    check      ("igualno diferentes -> target", dut_target_pc, pc_current - 32'd8);

    rf2_data = 32'h0000_0055;
    #1;
    check_true("igualno iguales -> no flush", dut_branch_flush === 1'b0);


    tb_section("3. menora (signed)");

    pc_current = 32'h0000_3000;
    br_imm    = 11'sd32;
    bru_op    = OP_MENORA;

    rf1_data = 32'sd5;
    rf2_data = 32'sd10;
    #1;
    check_true("menora 5 < 10 -> flush", dut_branch_flush === 1'b1);

    rf1_data = 32'sd10;
    rf2_data = 32'sd5;
    #1;
    check_true("menora 10 > 5 -> no flush", dut_branch_flush === 1'b0);

    rf1_data = 32'hFFFF_FFFF;   // -1
    rf2_data = 32'h0000_0000;   // 0
    #1;
    check_true("menora -1 < 0 (signed) -> flush", dut_branch_flush === 1'b1);

    rf1_data = 32'h0000_0000;
    rf2_data = 32'hFFFF_FFFF;   // -1
    #1;
    check_true("menora 0 < -1 (signed) -> NO flush", dut_branch_flush === 1'b0);


    tb_section("4. mayoroigual (signed)");

    pc_current = 32'h0000_4000;
    br_imm    = 11'sd64;
    bru_op    = OP_MAYOROIGUAL;

    rf1_data = 32'sd10;
    rf2_data = 32'sd5;
    #1;
    check_true("mayoroigual 10 >= 5 -> flush", dut_branch_flush === 1'b1);

    rf1_data = 32'sd5;
    rf2_data = 32'sd10;
    #1;
    check_true("mayoroigual 5 >= 10 -> no flush", dut_branch_flush === 1'b0);

    rf1_data = 32'hFFFF_FFFF;   // -1
    rf2_data = 32'hFFFF_FFFE;   // -2
    #1;
    check_true("mayoroigual -1 >= -2 (signed) -> flush", dut_branch_flush === 1'b1);


    // =====================================================================
    // Parte 2: jumps (sye y syer)
    // =====================================================================

    tb_section("5. sye: offset positivo");

    pc_current  = 32'h0000_5000;
    jmp_imm     = 16'sd256;
    link_rd_in  = 5'd1;       // x1 (ra)
    is_branch   = 1'b0;
    is_jump     = 1'b1;
    bru_op      = OP_SYE;
    #1;

    check_true("sye genera flush", dut_branch_flush === 1'b1);
    check      ("sye target = PC + 256", dut_target_pc, pc_current + 32'sd256);
    check_true("link no escrito aún (mismo ciclo)", dut_link_we_d === 1'b0);

    tick;
    check_true("tras tick: link_we_d", dut_link_we_d === 1'b1);
    check      ("tras tick: link_rd_d", dut_link_rd_d, 5'd1);
    check      ("tras tick: link_value_d = PC + 16", dut_link_value_d, pc_current + 32'd16);


    tb_section("6. sye: offset negativo");

    pc_current = 32'h0000_6000;
    jmp_imm    = -16'sd256;
    #1;
    check      ("sye target = PC - 256", dut_target_pc, pc_current - 32'sd256);


    tb_section("7. syer: salto a la dirección de un registro");

    pc_current = 32'h0000_8000;
    rf1_data   = 32'h0000_1230;
    br_imm     = 11'sd0;
    jmp_imm    = 16'sd512;    // syer no usa jmp_imm
    link_rd_in = 5'd5;
    bru_op     = OP_SYER;
    #1;
    check_true("syer genera flush", dut_branch_flush === 1'b1);
    check      ("syer x0, rf1, 0: target = rf1", dut_target_pc, 32'h0000_1230);

    tick;
    check_true("syer tras tick: link_we_d", dut_link_we_d === 1'b1);
    check      ("syer tras tick: link_rd_d", dut_link_rd_d, 5'd5);
    check      ("syer tras tick: link_value_d = PC + 16", dut_link_value_d, 32'h0000_8010);

    br_imm = 11'sd32;
    #1;
    check      ("syer offset +32: target = rf1 + 32", dut_target_pc, 32'h0000_1250);

    br_imm = -11'sd16;
    #1;
    check      ("syer offset -16: target = rf1 - 16", dut_target_pc, 32'h0000_1220);

    pc_current = 32'h0000_9000;
    #1;
    check      ("syer: el target no depende del PC", dut_target_pc, 32'h0000_1220);

    rf1_data = 32'h0000_1237;
    br_imm   = 11'sd5;
    #1;
    check      ("syer desalineado: 0x1237 + 5 -> 0x1230", dut_target_pc, 32'h0000_1230);

    rf1_data = 32'h0000_123F;
    br_imm   = 11'sd1;
    #1;
    check      ("syer desalineado: 0x123F + 1 -> 0x1240", dut_target_pc, 32'h0000_1240);


    // =====================================================================
    // Parte 3: casos negativos / NOP
    // =====================================================================

    tb_section("8. Slot inactivo (NOP)");

    // Resetear el DUT para limpiar el link_we_d que quedó en 1 desde el syer
    reset_dut();

    pc_current = 32'h0000_7000;
    is_branch  = 1'b0;
    is_jump    = 1'b0;
    #1;
    check_true("NOP -> no flush", dut_branch_flush === 1'b0);
    check      ("NOP -> target default = PC + 16", dut_target_pc, pc_current + 32'd16);
    check_true("NOP -> link no escrito", dut_link_we_d === 1'b0);


    tb_finish("tb_bru");
end

endmodule