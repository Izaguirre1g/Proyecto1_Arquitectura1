`timescale 1ns/1ps

/*
================================================================================
 Testbench: tb_decoder_crypto

 Descripción:
 ------------------------------------------------------------------------------
 Verifica el decoder del slot CRIPTO (rtl/decoder_crypto.sv).

 Casos:
   1. Las 6 instrucciones cripto con codificaciones generadas por el
      ensamblador del grupo (tools/assembler.py), para comprobar que
      ensamblador y hardware leen los campos igual.
   2. Lecturas del banco: (r1, r1 + 1) en fsl/fsli, incluido r1 = x30;
      (rs1, rs2) en ell; rs en setpwd; ninguna en vcr y camcon.
   3. we sólo en fsl y fsli.
   4. Campos en sus extremos: dirección 0xFFFF, rotación 31, LK = RK = 3.
   5. Slot inactivo: NOP, otros tipos de instrucción e IDs reservados
      (0110–1111) dejan valid = 0 y todas las salidas en 0.
   6. Validación de privilegios en ID con el ESTADO actual: las 6
      instrucciones con las 4 combinaciones de AUTH e INIT. fsl, fsli, ell y
      camcon necesitan AUTH = 1, setpwd necesita INIT = 1 y vcr siempre pasa.
      Un slot inactivo nunca marca excepción.

================================================================================
*/

`include "isa_defs.sv"


module tb_decoder_crypto;

`include "tb_utils.svh"


logic [31:0] instruction;

logic [3:0]  crypto_op;
logic [1:0]  lk;
logic [1:0]  rk;
logic [4:0]  rd;
logic [4:0]  rs_a;
logic [4:0]  rs_b;
logic [15:0] addr;
logic [4:0]  imm;
logic        we;
logic        valid;
logic        auth;
logic        init;
logic        priv_fault;


decoder_crypto DUT (
    .instruction(instruction),
    .crypto_op(crypto_op),
    .lk(lk),
    .rk(rk),
    .rd(rd),
    .rs_a(rs_a),
    .rs_b(rs_b),
    .addr(addr),
    .imm(imm),
    .we(we),
    .valid(valid),
    .auth(auth),
    .init(init),
    .priv_fault(priv_fault)
);


// Verifica todas las salidas del decoder para una instrucción
task automatic expect_dec(input string name, input logic [31:0] instr,
                          input logic [3:0] e_op, input logic [1:0] e_lk, input logic [1:0] e_rk,
                          input logic [4:0] e_rd, input logic [4:0] e_rs_a, input logic [4:0] e_rs_b,
                          input logic [15:0] e_addr, input logic [4:0] e_imm,
                          input logic e_we, input logic e_valid);

    instruction = instr;
    #1;
    check({name, ": valid"}, valid, e_valid);
    check({name, ": op"},    crypto_op, e_op);
    check({name, ": LK"},    lk, e_lk);
    check({name, ": RK/off"}, rk, e_rk);
    check({name, ": rd"},    rd, e_rd);
    check({name, ": rs_a"},  rs_a, e_rs_a);
    check({name, ": rs_b"},  rs_b, e_rs_b);
    check({name, ": dir"},   addr, e_addr);
    check({name, ": imm"},   imm, e_imm);
    check({name, ": we"},    we, e_we);
    check({name, ": sin excepción con AUTH = INIT = 1 (salvo setpwd)"}, priv_fault, 1'b0);
endtask

task automatic expect_nop(input string name, input logic [31:0] instr);

    expect_dec(name, instr, 4'b0, 2'b0, 2'b0, 5'b0, 5'b0, 5'b0, 16'b0, 5'b0, 1'b0, 1'b0);
endtask


initial begin

    $dumpfile("tb_decoder_crypto.vcd");
    $dumpvars(0, tb_decoder_crypto);

    // Secciones 1-5: con permiso para todo (setpwd sólo se revisa en la 6)
    auth = 1'b1;
    init = 1'b1;


    // ========================================================================
    tb_section("1-3. Codificaciones del ensamblador");

    //          nombre                       instrucción   op          LK RK rd  rs_a rs_b dir      imm we valid
    expect_dec("fsl x4,x4,0,0",              32'h04004200, OP_FSL,     0, 0, 4,  4,   5,   16'h0,   0, 1, 1);
    expect_dec("fsl x6,x2,1,3",              32'h040E6100, OP_FSL,     1, 3, 6,  2,   3,   16'h0,   0, 1, 1);
    expect_dec("fsli x30,x28,3,2",           32'h043DEE00, OP_FSLI,    3, 2, 30, 28,  29,  16'h0,   0, 1, 1);
    expect_dec("ell 0,0,x8,x10",             32'h04408500, OP_ELL,     0, 0, 0,  8,   10,  16'h0,   0, 0, 1);
    expect_dec("ell 3,2,x20,x2",             32'h045D4100, OP_ELL,     3, 2, 0,  20,  2,   16'h0,   0, 0, 1);
    expect_dec("vcr 0x104",                  32'h04602080, OP_VCR,     0, 0, 0,  0,   0,   16'h104, 0, 0, 1);
    expect_dec("vcr 65535",                  32'h047FFFE0, OP_VCR,     0, 0, 0,  0,   0,   16'hFFFF,0, 0, 1);
    expect_dec("camcon 0x2000,7",            32'h04840007, OP_CAMCON,  0, 0, 0,  0,   0,   16'h2000,7, 0, 1);
    expect_dec("camcon 65535,31",            32'h049FFFFF, OP_CAMCON,  0, 0, 0,  0,   0,   16'hFFFF,31,0, 1);
    expect_dec("setpwd x6",                  32'h04A00006, OP_SETPWD,  0, 0, 0,  6,   0,   16'h0,   0, 0, 1);
    expect_dec("setpwd x31",                 32'h04A0001F, OP_SETPWD,  0, 0, 0,  31,  0,   16'h0,   0, 0, 1);


    // ========================================================================
    tb_section("4. Campos armados a mano");

    // fsl rd=x16, r1=x30, LK=3, RK=3: R se lee de x31
    expect_dec("fsl x16,x30,3,3", {TYPE_CRYPTO, OP_FSL, 2'd3, 2'd3, 5'd16, 5'd30, 7'b0},
               OP_FSL, 3, 3, 16, 30, 31, 16'h0, 0, 1, 1);

    // Los bits reservados no cambian la decodificación
    expect_dec("fsli con RSV = 1111111", {TYPE_CRYPTO, OP_FSLI, 2'd1, 2'd0, 5'd8, 5'd2, 7'h7F},
               OP_FSLI, 1, 0, 8, 2, 3, 16'h0, 0, 1, 1);


    // ========================================================================
    tb_section("5. Slot inactivo");

    expect_nop("NOP 0x00000000", 32'h0000_0000);
    expect_nop("tipo registro (suma)", {TYPE_REG, OP_SUM, 5'd5, 5'd2, 5'd3, 6'b0});
    expect_nop("tipo inmediato (sumai)", {TYPE_IMM, OP_SUMI, 5'd0, 5'd4, 11'd7});
    expect_nop("tipo almacenar (guardap)", {TYPE_LSU, OP_GUARDAP, 5'd0, 5'd4, 11'd0});
    expect_nop("tipo control (igualsi)", {TYPE_BRU_COND, OP_IGUALSI, 5'd1, 5'd2, 11'd16});
    expect_nop("tipo salto (sye)", {TYPE_BRU_JUMP, OP_SYE, 5'd1, 16'd16});

    for (int id = 6; id < 16; id++)
        expect_nop($sformatf("ID reservado %b", id[3:0]),
                   {TYPE_CRYPTO, id[3:0], 2'd3, 2'd3, 5'd31, 5'd31, 7'h7F});


    // ========================================================================
    tb_section("6. Validación de privilegios");

    begin
        logic [31:0] instr [0:5];
        string       name  [0:5];
        logic        need_auth, need_init, e_fault;

        instr[0] = 32'h04004200;  name[0] = "fsl";
        instr[1] = 32'h043DEE00;  name[1] = "fsli";
        instr[2] = 32'h04408500;  name[2] = "ell";
        instr[3] = 32'h04602080;  name[3] = "vcr";
        instr[4] = 32'h04840007;  name[4] = "camcon";
        instr[5] = 32'h04A00006;  name[5] = "setpwd";

        for (int i = 0; i < 6; i++) begin

            need_auth = (i == 0 || i == 1 || i == 2 || i == 4);
            need_init = (i == 5);

            for (int st = 0; st < 4; st++) begin

                auth = st[0];
                init = st[1];
                instruction = instr[i];
                e_fault = (need_auth && !auth) || (need_init && !init);
                #1;
                check($sformatf("%s con AUTH=%0d INIT=%0d", name[i], auth, init), priv_fault, e_fault);
            end
        end

        auth = 1'b0;
        init = 1'b0;
        instruction = 32'h0000_0000;
        #1;
        check("NOP con AUTH = INIT = 0: sin excepción", priv_fault, 1'b0);
        instruction = {TYPE_CRYPTO, 4'b0110, 21'b0};
        #1;
        check("ID reservado con AUTH = INIT = 0: sin excepción", priv_fault, 1'b0);
    end


    tb_finish("tb_decoder_crypto");
end

endmodule
