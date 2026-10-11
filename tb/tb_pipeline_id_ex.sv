`timescale 1ns/1ps

/*
================================================================================
 Testbench: tb_pipeline_id_ex

 Descripción:
 ------------------------------------------------------------------------------
 Verifica el registro de segmentación ID/EX (rtl/pipeline_id_ex.sv) con todos
 los campos de los 4 slots, el PC y valid.

 Casos:
   1. Reset: todas las salidas en 0.
   2. Captura en el flanco y mantiene el valor hasta el siguiente (caso
      original: suma de 20 y 30 hacia x5, y sumai con inmediato 20).
   3. flush (salto tomado o excepción en EX): el flanco siguiente deja una
      burbuja con todas las salidas en 0.
   4. reset tiene prioridad sobre la captura.
   5. 300 ciclos aleatorios: cada campo llega intacto a su salida, o en 0 si
      hubo flush.

================================================================================
*/

module tb_pipeline_id_ex;

`include "tb_utils.svh"


logic clk;
logic reset;
logic flush;

// Entradas (ID) y salidas (EX) de cada campo
logic [3:0] alu_op, alu_op_out;
logic [4:0] alu_rd, alu_rd_out;
logic [31:0] alu_operand_a, alu_operand_a_out;
logic [31:0] alu_operand_b, alu_operand_b_out;
logic [10:0] alu_imm, alu_imm_out;
logic       alu_use_imm, alu_use_imm_out;
logic       lsu_valid, lsu_valid_out;
logic [3:0] lsu_op, lsu_op_out;
logic [4:0] lsu_rd, lsu_rd_out;
logic [10:0] lsu_imm, lsu_imm_out;
logic [31:0] lsu_operand_a, lsu_operand_a_out;
logic [31:0] lsu_operand_b, lsu_operand_b_out;
logic [3:0] bru_op, bru_op_out;
logic [4:0] bru_rd, bru_rd_out;
logic [10:0] bru_br_imm, bru_br_imm_out;
logic [15:0] bru_jmp_imm, bru_jmp_imm_out;
logic       bru_is_branch, bru_is_branch_out;
logic       bru_is_jump, bru_is_jump_out;
logic [31:0] bru_operand_a, bru_operand_a_out;
logic [31:0] bru_operand_b, bru_operand_b_out;
logic       crypto_valid, crypto_valid_out;
logic       crypto_fault, crypto_fault_out;
logic [3:0] crypto_op, crypto_op_out;
logic [1:0] crypto_lk, crypto_lk_out;
logic [1:0] crypto_rk, crypto_rk_out;
logic [4:0] crypto_rd, crypto_rd_out;
logic [15:0] crypto_addr, crypto_addr_out;
logic [4:0] crypto_imm, crypto_imm_out;
logic [31:0] crypto_operand_a, crypto_operand_a_out;
logic [31:0] crypto_operand_b, crypto_operand_b_out;
logic [31:0] pc_in, pc_out;
logic       valid_in, valid_out;


pipeline_id_ex DUT (
    .clk(clk),
    .reset(reset),
    .flush(flush),
    .alu_op(alu_op),
    .alu_op_out(alu_op_out),
    .alu_rd(alu_rd),
    .alu_rd_out(alu_rd_out),
    .alu_operand_a(alu_operand_a),
    .alu_operand_a_out(alu_operand_a_out),
    .alu_operand_b(alu_operand_b),
    .alu_operand_b_out(alu_operand_b_out),
    .alu_imm(alu_imm),
    .alu_imm_out(alu_imm_out),
    .alu_use_imm(alu_use_imm),
    .alu_use_imm_out(alu_use_imm_out),
    .lsu_valid(lsu_valid),
    .lsu_valid_out(lsu_valid_out),
    .lsu_op(lsu_op),
    .lsu_op_out(lsu_op_out),
    .lsu_rd(lsu_rd),
    .lsu_rd_out(lsu_rd_out),
    .lsu_imm(lsu_imm),
    .lsu_imm_out(lsu_imm_out),
    .lsu_operand_a(lsu_operand_a),
    .lsu_operand_a_out(lsu_operand_a_out),
    .lsu_operand_b(lsu_operand_b),
    .lsu_operand_b_out(lsu_operand_b_out),
    .bru_op(bru_op),
    .bru_op_out(bru_op_out),
    .bru_rd(bru_rd),
    .bru_rd_out(bru_rd_out),
    .bru_br_imm(bru_br_imm),
    .bru_br_imm_out(bru_br_imm_out),
    .bru_jmp_imm(bru_jmp_imm),
    .bru_jmp_imm_out(bru_jmp_imm_out),
    .bru_is_branch(bru_is_branch),
    .bru_is_branch_out(bru_is_branch_out),
    .bru_is_jump(bru_is_jump),
    .bru_is_jump_out(bru_is_jump_out),
    .bru_operand_a(bru_operand_a),
    .bru_operand_a_out(bru_operand_a_out),
    .bru_operand_b(bru_operand_b),
    .bru_operand_b_out(bru_operand_b_out),
    .crypto_valid(crypto_valid),
    .crypto_valid_out(crypto_valid_out),
    .crypto_fault(crypto_fault),
    .crypto_fault_out(crypto_fault_out),
    .crypto_op(crypto_op),
    .crypto_op_out(crypto_op_out),
    .crypto_lk(crypto_lk),
    .crypto_lk_out(crypto_lk_out),
    .crypto_rk(crypto_rk),
    .crypto_rk_out(crypto_rk_out),
    .crypto_rd(crypto_rd),
    .crypto_rd_out(crypto_rd_out),
    .crypto_addr(crypto_addr),
    .crypto_addr_out(crypto_addr_out),
    .crypto_imm(crypto_imm),
    .crypto_imm_out(crypto_imm_out),
    .crypto_operand_a(crypto_operand_a),
    .crypto_operand_a_out(crypto_operand_a_out),
    .crypto_operand_b(crypto_operand_b),
    .crypto_operand_b_out(crypto_operand_b_out),
    .pc_in(pc_in),
    .pc_out(pc_out),
    .valid_in(valid_in),
    .valid_out(valid_out)
);


always #5 clk = ~clk;


integer seed;

// Pone un valor aleatorio en cada entrada
task automatic randomize_inputs();

    alu_op                = $random(seed);
    alu_rd                = $random(seed);
    alu_operand_a         = $random(seed);
    alu_operand_b         = $random(seed);
    alu_imm               = $random(seed);
    alu_use_imm           = $random(seed);
    lsu_valid             = $random(seed);
    lsu_op                = $random(seed);
    lsu_rd                = $random(seed);
    lsu_imm               = $random(seed);
    lsu_operand_a         = $random(seed);
    lsu_operand_b         = $random(seed);
    bru_op                = $random(seed);
    bru_rd                = $random(seed);
    bru_br_imm            = $random(seed);
    bru_jmp_imm           = $random(seed);
    bru_is_branch         = $random(seed);
    bru_is_jump           = $random(seed);
    bru_operand_a         = $random(seed);
    bru_operand_b         = $random(seed);
    crypto_valid          = $random(seed);
    crypto_fault          = $random(seed);
    crypto_op             = $random(seed);
    crypto_lk             = $random(seed);
    crypto_rk             = $random(seed);
    crypto_rd             = $random(seed);
    crypto_addr           = $random(seed);
    crypto_imm            = $random(seed);
    crypto_operand_a      = $random(seed);
    crypto_operand_b      = $random(seed);
    pc_in                 = $random(seed);
    valid_in              = $random(seed);
endtask

// Compara cada salida con su entrada (bubble = 1: con 0)
task automatic check_capture(input string name, input logic bubble);

    check({name, ": alu_op"}, alu_op_out, bubble ? 4'd0 : alu_op);
    check({name, ": alu_rd"}, alu_rd_out, bubble ? 5'd0 : alu_rd);
    check({name, ": alu_operand_a"}, alu_operand_a_out, bubble ? 32'd0 : alu_operand_a);
    check({name, ": alu_operand_b"}, alu_operand_b_out, bubble ? 32'd0 : alu_operand_b);
    check({name, ": alu_imm"}, alu_imm_out, bubble ? 11'd0 : alu_imm);
    check({name, ": alu_use_imm"}, alu_use_imm_out, bubble ? 1'd0 : alu_use_imm);
    check({name, ": lsu_valid"}, lsu_valid_out, bubble ? 1'd0 : lsu_valid);
    check({name, ": lsu_op"}, lsu_op_out, bubble ? 4'd0 : lsu_op);
    check({name, ": lsu_rd"}, lsu_rd_out, bubble ? 5'd0 : lsu_rd);
    check({name, ": lsu_imm"}, lsu_imm_out, bubble ? 11'd0 : lsu_imm);
    check({name, ": lsu_operand_a"}, lsu_operand_a_out, bubble ? 32'd0 : lsu_operand_a);
    check({name, ": lsu_operand_b"}, lsu_operand_b_out, bubble ? 32'd0 : lsu_operand_b);
    check({name, ": bru_op"}, bru_op_out, bubble ? 4'd0 : bru_op);
    check({name, ": bru_rd"}, bru_rd_out, bubble ? 5'd0 : bru_rd);
    check({name, ": bru_br_imm"}, bru_br_imm_out, bubble ? 11'd0 : bru_br_imm);
    check({name, ": bru_jmp_imm"}, bru_jmp_imm_out, bubble ? 16'd0 : bru_jmp_imm);
    check({name, ": bru_is_branch"}, bru_is_branch_out, bubble ? 1'd0 : bru_is_branch);
    check({name, ": bru_is_jump"}, bru_is_jump_out, bubble ? 1'd0 : bru_is_jump);
    check({name, ": bru_operand_a"}, bru_operand_a_out, bubble ? 32'd0 : bru_operand_a);
    check({name, ": bru_operand_b"}, bru_operand_b_out, bubble ? 32'd0 : bru_operand_b);
    check({name, ": crypto_valid"}, crypto_valid_out, bubble ? 1'd0 : crypto_valid);
    check({name, ": crypto_fault"}, crypto_fault_out, bubble ? 1'd0 : crypto_fault);
    check({name, ": crypto_op"}, crypto_op_out, bubble ? 4'd0 : crypto_op);
    check({name, ": crypto_lk"}, crypto_lk_out, bubble ? 2'd0 : crypto_lk);
    check({name, ": crypto_rk"}, crypto_rk_out, bubble ? 2'd0 : crypto_rk);
    check({name, ": crypto_rd"}, crypto_rd_out, bubble ? 5'd0 : crypto_rd);
    check({name, ": crypto_addr"}, crypto_addr_out, bubble ? 16'd0 : crypto_addr);
    check({name, ": crypto_imm"}, crypto_imm_out, bubble ? 5'd0 : crypto_imm);
    check({name, ": crypto_operand_a"}, crypto_operand_a_out, bubble ? 32'd0 : crypto_operand_a);
    check({name, ": crypto_operand_b"}, crypto_operand_b_out, bubble ? 32'd0 : crypto_operand_b);
    check({name, ": pc"}, pc_out, bubble ? 32'd0 : pc_in);
    check({name, ": valid"}, valid_out, bubble ? 1'd0 : valid_in);
endtask


initial begin

    $dumpfile("tb_pipeline_id_ex.vcd");
    $dumpvars(0, tb_pipeline_id_ex);

    if (!$value$plusargs("seed=%d", seed))
        seed = 32'hCE4301;

    clk   = 0;
    reset = 1;
    flush = 0;
    randomize_inputs();


    tb_section("1. Reset");

    @(negedge clk);
    check_capture("reset", 1'b1);


    tb_section("2. Captura en el flanco");

    reset = 0;
    randomize_inputs();

    // Caso original: suma 20 + 30 hacia x5
    alu_op        = 4'd0;
    alu_rd        = 5'd5;
    alu_operand_a = 32'd20;
    alu_operand_b = 32'd30;
    alu_imm       = 11'd0;
    alu_use_imm   = 1'b0;
    valid_in      = 1'b1;
    #1;
    check("antes del flanco: alu_rd sigue en 0", alu_rd_out, 5'd0);
    @(negedge clk);
    check_capture("suma", 1'b0);

    // Caso original: sumai con inmediato 20 hacia x7
    alu_rd      = 5'd7;
    alu_imm     = 11'd20;
    alu_use_imm = 1'b1;
    @(negedge clk);
    check_capture("sumai", 1'b0);


    tb_section("3. flush");

    randomize_inputs();
    flush = 1;
    @(negedge clk);
    check_capture("flush", 1'b1);
    flush = 0;
    @(negedge clk);
    check_capture("después del flush captura de nuevo", 1'b0);


    tb_section("4. reset tiene prioridad");

    randomize_inputs();
    reset = 1;
    @(negedge clk);
    check_capture("reset", 1'b1);
    reset = 0;


    tb_section("5. 300 ciclos aleatorios");

    repeat (300) begin

        logic f;

        randomize_inputs();
        f     = ($random(seed) % 4) == 0;
        flush = f;
        @(negedge clk);
        check_capture(f ? "aleatorio con flush" : "aleatorio", f);
    end


    tb_finish("tb_pipeline_id_ex");
end

endmodule
