`timescale 1ns/1ps

/*
================================================================================
 Testbench: tb_pipeline_cripto

 Descripción:
 ------------------------------------------------------------------------------
 Ejecuta programas criptográficos sobre el procesador completo (top) y
 compara los resultados con un modelo de referencia de Feistel4 incluido en
 este testbench.
 Cada programa se escribe directo en instruction_memory y se ejecuta desde el
 reset. El reset borra la bóveda, pero no la memoria de datos.

 Datos en memoria:
     0x100  contraseña inicial (la usa setpwd)
     0x104  contraseña candidata (la usa vcr)
     0x110  llave 0: K0, K1, K2, K3
     0x200  archivo de 32 bytes "HOLA2026Procesador VLIW CE4301!!" (4 bloques)

 Casos:
   A. Cifrado del archivo con el programa de docs (setpwd, vcr, 2 ell y un
      bucle de 4 fsl por bloque). El resultado coincide con la referencia y
      el primer bloque es el vector conocido 03D44466 D685AFAF.
   B. Descifrado del archivo cifrado (4 fsli con RK = 3..0): vuelve el texto
      original. Como el reset borró la bóveda, el programa vuelve a
      autenticarse y a cargar la llave.
   C. Bundle mixto: ALU, LSU, BRU y CRIPTO en el mismo bundle, todas con
      efecto; 3 escrituras al banco en el mismo ciclo; vcr justo después de
      setpwd y ell justo después de vcr (la bóveda y ESTADO se actualizan al
      final de EX).
   D. Excepciones de privilegio: fsl sin autenticar, setpwd repetido y ell
      después de un vcr fallido. En los tres casos se anula el bundle completo
      (ALU, LSU, BRU y CRIPTO; un sye no salta ni escribe su enlace), se
      anulan los 2 bundles siguientes, el PC salta
      al manejador en TRAP_VECTOR (0x1F0) y trap_pc guarda el PC culpable.
   E. Aislamiento de la llave: el programa carga la llave en la bóveda y borra
      todas sus copias en registros y memoria; aun así cifra bien, y al final
      ni el banco de registros ni la memoria contienen la llave o la
      contraseña.

================================================================================
*/

`include "isa_defs.sv"


module tb_pipeline_cripto;

`include "tb_utils.svh"


// ============================================================================
// Modelo de referencia de Feistel4 (Fig. 1 del enunciado)
//
// Es independiente del RTL: no usa crypto_unit ni key_vault. Los pares
// (L, R) se devuelven como {L, R} en 64 bits y la llave como logic
// [3:0][31:0], con key[i] = Ki.
// ============================================================================

function automatic logic [31:0] ref_rol(input logic [31:0] x, input int r);

    r = r % 32;
    return (r == 0) ? x : ((x << r) | (x >> (32 - r)));
endfunction

// F(x, k) = (ROL(x, 5) + k) ^ ROL(x, 13)
function automatic logic [31:0] ref_f(input logic [31:0] x, input logic [31:0] k);

    return (ref_rol(x, 5) + k) ^ ref_rol(x, 13);
endfunction

// Una ronda de cifrado (fsl): (L, R) -> (R, L ^ F(R, k))
function automatic logic [63:0] ref_round_enc(input logic [31:0] l, input logic [31:0] r,
                                              input logic [31:0] k);

    return {r, l ^ ref_f(r, k)};
endfunction

// Cifrado completo: 4 rondas con key[0], key[1], key[2], key[3]
function automatic logic [63:0] ref_encrypt(input logic [31:0] l, input logic [31:0] r,
                                            input logic [3:0][31:0] key);

    logic [63:0] lr;

    lr = {l, r};
    for (int i = 0; i < 4; i++)
        lr = ref_round_enc(lr[63:32], lr[31:0], key[i]);

    return lr;
endfunction


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

function automatic logic [31:0] sumai(input logic [4:0] rg, input logic [4:0] rf1,
                                      input logic [10:0] imm);

    return {TYPE_IMM, OP_SUMI, rf1, rg, imm};
endfunction

function automatic logic [31:0] lsu(input logic [3:0] id, input logic [4:0] base,
                                    input logic [4:0] reg_dato, input logic [10:0] off);

    return {TYPE_LSU, id, base, reg_dato, off};
endfunction

function automatic logic [31:0] branch(input logic [3:0] id, input logic [4:0] rf1,
                                       input logic [4:0] rf2, input logic [10:0] off);

    return {TYPE_BRU_COND, id, rf1, rf2, off};
endfunction

function automatic logic [31:0] sye(input logic [4:0] rg, input logic [15:0] off);

    return {TYPE_BRU_JUMP, OP_SYE, rg, off};
endfunction

// Cripto
function automatic logic [31:0] fsl(input logic [4:0] rd, input logic [4:0] r1,
                                    input logic [1:0] lk, input logic [1:0] rk);

    return {TYPE_CRYPTO, OP_FSL, lk, rk, rd, r1, 7'b0};
endfunction

function automatic logic [31:0] fsli(input logic [4:0] rd, input logic [4:0] r1,
                                     input logic [1:0] lk, input logic [1:0] rk);

    return {TYPE_CRYPTO, OP_FSLI, lk, rk, rd, r1, 7'b0};
endfunction

function automatic logic [31:0] ell(input logic [1:0] lk, input logic [1:0] off,
                                    input logic [4:0] rs1, input logic [4:0] rs2);

    return {TYPE_CRYPTO, OP_ELL, lk, off, rs1, rs2, 7'b0};
endfunction

function automatic logic [31:0] vcr(input logic [15:0] dir);

    return {TYPE_CRYPTO, OP_VCR, dir, 5'b0};
endfunction

function automatic logic [31:0] setpwd(input logic [4:0] rs);

    return {TYPE_CRYPTO, OP_SETPWD, 16'b0, rs};
endfunction

// Bundle: slot 0 ALU en los bits bajos, slot 3 CRIPTO en los altos
function automatic logic [127:0] bundle(input logic [31:0] alu, input logic [31:0] mem,
                                        input logic [31:0] bru, input logic [31:0] cripto);

    return {cripto, bru, mem, alu};
endfunction

function automatic logic [127:0] solo_alu(input logic [31:0] i);

    return bundle(i, NOP, NOP, NOP);
endfunction

function automatic logic [127:0] solo_lsu(input logic [31:0] i);

    return bundle(NOP, i, NOP, NOP);
endfunction

function automatic logic [127:0] solo_cri(input logic [31:0] i);

    return bundle(NOP, NOP, NOP, i);
endfunction


// ============================================================================
// Datos de prueba
// ============================================================================

localparam logic [31:0] PWD = 32'h5EC2_E7A1;

logic [3:0][31:0] key;          // K0..K3 (la del ejemplo de docs)
logic [31:0]      plain  [0:7]; // "HOLA2026Procesador VLIW CE4301!!" en palabras little-endian
logic [31:0]      cipher [0:7]; // cifrado de referencia

// Memoria de datos en el estado inicial de los casos A, B, C y E
task automatic preload_data();

    DUT.DMEM.mem[32'h100 >> 2] = PWD;
    DUT.DMEM.mem[32'h104 >> 2] = PWD;
    for (int i = 0; i < 4; i++)
        DUT.DMEM.mem[(32'h110 >> 2) + i] = key[i];
endtask


// ============================================================================
// Monitores: qué bundle pasa por EX en cada ciclo y cuántas escrituras hace wb
// ============================================================================

int cycle = 0;

always @(posedge clk)
    cycle <= cycle + 1;

logic [31:0] ex_pc_log  [0:511];
int          ex_cyc_log [0:511];
int          n_ex = 0;
int          conflicts = 0;
int          max_writes = 0;

always @(negedge clk) begin

    if (!reset) begin

        if (DUT.id_ex_valid && n_ex < 512) begin

            ex_pc_log[n_ex]  = DUT.ex_pc;
            ex_cyc_log[n_ex] = cycle;
            n_ex++;
        end

        if (DUT.wb_conflict)
            conflicts++;

        if (DUT.wb_we[0] + DUT.wb_we[1] + DUT.wb_we[2] + DUT.wb_we[3] + DUT.wb_we[4] > max_writes)
            max_writes = DUT.wb_we[0] + DUT.wb_we[1] + DUT.wb_we[2] + DUT.wb_we[3] + DUT.wb_we[4];
    end
end

// Ciclo en que el bundle de dirección pc pasó por EX por primera vez (-1 si nunca)
function automatic int first_ex(input logic [31:0] pc);

    for (int i = 0; i < n_ex; i++)
        if (ex_pc_log[i] == pc)
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

// Manejador de excepciones en TRAP_VECTOR (0x1F0, bundle 31): x30 = 99 y se
// queda en un bucle
task automatic clear_prog();

    for (int i = 0; i < 32; i++)
        prog[i] = 128'b0;

    prog[31] = bundle(sumai(5'd30, 5'd0, 11'd99), NOP, sye(5'd0, 16'd0), NOP);
endtask

// Carga prog en la memoria de instrucciones, aplica reset y ejecuta.
// El reset borra el banco de registros y la bóveda; la memoria de datos no.
task automatic run_program(input int cycles);

    @(negedge clk);
    reset = 1;

    for (int i = 0; i < 32; i++)
        DUT.IMEM.memory[i] = prog[i];

    repeat (2) @(negedge clk);

    n_ex       = 0;
    conflicts  = 0;
    max_writes = 0;
    reset      = 0;

    repeat (cycles) @(negedge clk);
endtask

// Programa de docs: cifra (o descifra) el archivo de 4 bloques en 0x200
task automatic build_file_program(input logic decrypt);

    clear_prog();
    prog[0]  = bundle(sumai(5'd16, 5'd0, 11'd512), lsu(OP_CARGAI, 5'd0, 5'd6,  11'd256), NOP, NOP);
    prog[1]  = bundle(sumai(5'd17, 5'd0, 11'd544), lsu(OP_CARGAI, 5'd0, 5'd8,  11'd272), NOP, NOP);
    prog[2]  = solo_lsu(lsu(OP_CARGAI, 5'd0, 5'd10, 11'd276));
    prog[3]  = bundle(NOP, lsu(OP_CARGAI, 5'd0, 5'd12, 11'd280), NOP, setpwd(5'd6));
    prog[4]  = solo_lsu(lsu(OP_CARGAI, 5'd0, 5'd14, 11'd284));
    prog[6]  = solo_cri(vcr(16'h104));
    prog[9]  = solo_cri(ell(2'd0, 2'd0, 5'd8, 5'd10));
    prog[10] = solo_cri(ell(2'd0, 2'd2, 5'd12, 5'd14));
    // bloque:
    prog[11] = solo_lsu(lsu(OP_CARGAI, 5'd16, 5'd4, 11'd0));             // L = M[p]
    prog[12] = solo_lsu(lsu(OP_CARGAI, 5'd16, 5'd5, 11'd4));             // R = M[p+4]
    prog[13] = solo_alu(sumai(5'd16, 5'd16, 11'd8));                     // p = p + 8
    for (int i = 0; i < 4; i++)
        prog[15 + 3 * i] = solo_cri(decrypt ? fsli(5'd4, 5'd4, 2'd0, 2'(3 - i))
                                            : fsl (5'd4, 5'd4, 2'd0, 2'(i)));
    prog[27] = solo_lsu(lsu(OP_GUARDAP, 5'd16, 5'd4, -11'sd8));          // M[p-8] = L
    prog[28] = bundle(NOP, lsu(OP_GUARDAP, 5'd16, 5'd5, -11'sd4),        // M[p-4] = R
                      branch(OP_IGUALNO, 5'd16, 5'd17, -11'sd272), NOP); // -> bloque
    prog[29] = bundle(NOP, NOP, sye(5'd0, 16'd0), NOP);                  // fin
endtask


// ============================================================================
// Programas
// ============================================================================

initial begin

    $dumpfile("tb_pipeline_cripto.vcd");
    $dumpvars(0, tb_pipeline_cripto);

    clk   = 0;
    reset = 1;

    key = {32'hC3D2_E1F0, 32'h8796_A5B4, 32'h4B5A_6978, 32'h0F1E_2D3C};

    plain[0] = 32'h414C_4F48;  plain[1] = 32'h3632_3032;     // "HOLA" "2026"
    plain[2] = 32'h636F_7250;  plain[3] = 32'h6461_7365;     // "Proc" "esad"
    plain[4] = 32'h5620_726F;  plain[5] = 32'h2057_494C;     // "or V" "LIW "
    plain[6] = 32'h3334_4543;  plain[7] = 32'h2121_3130;     // "CE43" "01!!"

    for (int b = 0; b < 4; b++) begin

        logic [63:0] c;
        c = ref_encrypt(plain[2 * b], plain[2 * b + 1], key);
        cipher[2 * b]     = c[63:32];
        cipher[2 * b + 1] = c[31:0];
    end

    // Esperar a que instruction_memory y memory terminen su inicialización
    #1;

    preload_data();
    for (int i = 0; i < 8; i++)
        DUT.DMEM.mem[(32'h200 >> 2) + i] = plain[i];


    // ========================================================================
    // A. Cifrado del archivo
    // ========================================================================
    tb_section("A. Cifrado de un archivo de 4 bloques");

    build_file_program(1'b0);
    run_program(130);

    check("vector conocido: bloque 0 L = 03D44466", mem_word(32'h200), 32'h03D4_4466);
    check("vector conocido: bloque 0 R = D685AFAF", mem_word(32'h204), 32'hD685_AFAF);

    for (int i = 0; i < 8; i++)
        check($sformatf("cifrado: M[0x%0h] = referencia", 32'h200 + 4 * i),
              mem_word(32'h200 + 4 * i), cipher[i]);

    check("el bucle recorrió el archivo: p = 0x220", reg_val(16), 32'h220);
    check("ESTADO: AUTH = 1, INIT = 0", DUT.crypto_estado, 32'b01);
    check("sin excepciones", DUT.trap_count, 32'd0);
    check("sin conflictos de writeback", conflicts, 0);


    // ========================================================================
    // B. Descifrado del archivo
    // ========================================================================
    tb_section("B. Descifrado del archivo cifrado");

    build_file_program(1'b1);
    run_program(130);

    for (int i = 0; i < 8; i++)
        check($sformatf("descifrado: M[0x%0h] = texto original", 32'h200 + 4 * i),
              mem_word(32'h200 + 4 * i), plain[i]);

    check("sin excepciones", DUT.trap_count, 32'd0);
    check("sin conflictos de writeback", conflicts, 0);


    // ========================================================================
    // C. Bundle mixto
    // ========================================================================
    tb_section("C. ALU, LSU, BRU y CRIPTO en el mismo bundle");

    clear_prog();
    prog[0]  = bundle(sumai(5'd4, 5'd0, 11'd100), lsu(OP_CARGAI, 5'd0, 5'd6,  11'd256), NOP, NOP);
    prog[1]  = bundle(sumai(5'd5, 5'd0, 11'd200), lsu(OP_CARGAI, 5'd0, 5'd8,  11'd272), NOP, NOP);
    prog[2]  = solo_lsu(lsu(OP_CARGAI, 5'd0, 5'd10, 11'd276));
    prog[3]  = bundle(NOP, lsu(OP_CARGAI, 5'd0, 5'd12, 11'd280), NOP, setpwd(5'd6));
    prog[4]  = bundle(NOP, lsu(OP_CARGAI, 5'd0, 5'd14, 11'd284), NOP, vcr(16'h104));   // justo después de setpwd
    prog[5]  = solo_cri(ell(2'd0, 2'd0, 5'd8, 5'd10));                                 // justo después de vcr
    prog[7]  = solo_cri(ell(2'd0, 2'd2, 5'd12, 5'd14));
    prog[8]  = bundle(sumai(5'd20, 5'd0, 11'd7),                                        // x20 = 7
                      lsu(OP_GUARDAP, 5'd0, 5'd5, 11'd768),                             // M[0x300] = x5
                      branch(OP_IGUALNO, 5'd4, 5'd5, 11'd48),                           // -> B11
                      fsl(5'd16, 5'd4, 2'd0, 2'd0));                                    // (x16, x17)
    prog[9]  = solo_alu(sumai(5'd21, 5'd0, 11'd1));                                     // anulado
    prog[10] = solo_alu(sumai(5'd22, 5'd0, 11'd1));                                     // anulado
    prog[11] = solo_cri(fsl(5'd18, 5'd16, 2'd0, 2'd1));                                 // (x18, x19)
    prog[14] = bundle(NOP, NOP, sye(5'd0, 16'd0), NOP);                                 // fin

    DUT.DMEM.mem[32'h300 >> 2] = 32'h0;

    run_program(40);

    begin
        logic [63:0] r1, r2;

        r1 = ref_round_enc(32'd100, 32'd200, key[0]);
        r2 = ref_round_enc(r1[63:32], r1[31:0], key[1]);

        check("ALU del bundle mixto: x20 = 7",            reg_val(20), 32'd7);
        check("LSU del bundle mixto: M[0x300] = 200",     mem_word(32'h300), 32'd200);
        check("BRU del bundle mixto saltó: x21 = 0",      reg_val(21), 32'd0);
        check("BRU del bundle mixto saltó: x22 = 0",      reg_val(22), 32'd0);
        check("CRIPTO del bundle mixto: x16 = L",         reg_val(16), r1[63:32]);
        check("CRIPTO del bundle mixto: x17 = R",         reg_val(17), r1[31:0]);
        check("fsl sobre el resultado anterior: x18",     reg_val(18), r2[63:32]);
        check("fsl sobre el resultado anterior: x19",     reg_val(19), r2[31:0]);
        check("wb escribió 3 registros en el mismo ciclo (ALU + par cripto)", max_writes, 3);
        check("sin excepciones", DUT.trap_count, 32'd0);
        check("sin conflictos de writeback", conflicts, 0);
    end


    // ========================================================================
    // D. Excepciones de privilegio
    // ========================================================================
    tb_section("D1. fsl sin autenticación");

    clear_prog();
    prog[0] = solo_alu(sumai(5'd4, 5'd0, 11'd5));
    prog[3] = bundle(sumai(5'd20, 5'd0, 11'd7),                     // anulado por la excepción
                     lsu(OP_GUARDAP, 5'd0, 5'd4, 11'd768),          // anulado
                     sye(5'd24, 16'd48),                            // no salta ni escribe x24
                     fsl(5'd16, 5'd4, 2'd0, 2'd0));                 // sin AUTH
    prog[4] = solo_alu(sumai(5'd21, 5'd0, 11'd1));                  // anulado
    prog[5] = solo_alu(sumai(5'd22, 5'd0, 11'd1));                  // anulado
    prog[6] = solo_alu(sumai(5'd23, 5'd0, 11'd1));                  // destino del salto
    prog[7] = bundle(NOP, NOP, sye(5'd0, 16'd0), NOP);

    DUT.DMEM.mem[32'h300 >> 2] = 32'hCAFE_BABE;

    run_program(30);

    check("una excepción",                              DUT.trap_count, 32'd1);
    check("trap_pc = 0x30 (bundle del fsl)",            DUT.trap_pc, 32'h30);
    check("se ejecutó el manejador: x30 = 99",          reg_val(30), 32'd99);
    check("el manejador entra a EX 3 ciclos después",   first_ex(32'h1F0) - first_ex(32'h30), 32'd3);
    check_true("los bundles 4, 5 y 6 no llegan a EX",
               first_ex(32'h40) == -1 && first_ex(32'h50) == -1 && first_ex(32'h60) == -1);
    check("ALU del bundle anulada: x20 = 0",            reg_val(20), 32'd0);
    check("LSU del bundle anulada: M[0x300] sin cambio", mem_word(32'h300), 32'hCAFE_BABE);
    check("fsl sin efecto: x16 = 0",                    reg_val(16), 32'd0);
    check("fsl sin efecto: x17 = 0",                    reg_val(17), 32'd0);
    check("x21 = 0", reg_val(21), 32'd0);
    check("x22 = 0", reg_val(22), 32'd0);
    check("x23 = 0", reg_val(23), 32'd0);
    check("sye del bundle anulado: x24 = 0 (sin enlace)", reg_val(24), 32'd0);
    check("lo anterior a la excepción sí se ejecutó: x4 = 5", reg_val(4), 32'd5);


    tb_section("D2. setpwd repetido");

    clear_prog();
    prog[0] = solo_alu(sumai(5'd6, 5'd0, 11'd85));
    prog[3] = solo_cri(setpwd(5'd6));                               // INIT = 1: válido
    prog[4] = bundle(sumai(5'd20, 5'd0, 11'd1), NOP, NOP, setpwd(5'd6));   // INIT = 0: excepción
    prog[5] = bundle(NOP, NOP, sye(5'd0, 16'd0), NOP);

    run_program(30);

    check("una excepción",                       DUT.trap_count, 32'd1);
    check("trap_pc = 0x40 (segundo setpwd)",     DUT.trap_pc, 32'h40);
    check("se ejecutó el manejador: x30 = 99",   reg_val(30), 32'd99);
    check("ALU del bundle anulada: x20 = 0",     reg_val(20), 32'd0);
    check("ESTADO: INIT = 0, AUTH = 0",          DUT.crypto_estado, 32'b00);


    tb_section("D3. ell después de un vcr fallido");

    DUT.DMEM.mem[32'h108 >> 2] = 32'd85;        // contraseña correcta
    DUT.DMEM.mem[32'h10C >> 2] = 32'd84;        // incorrecta

    clear_prog();
    prog[0] = solo_alu(sumai(5'd6, 5'd0, 11'd85));
    prog[3] = solo_cri(setpwd(5'd6));
    prog[4] = solo_cri(vcr(16'h108));                               // AUTH = 1
    prog[5] = solo_cri(ell(2'd0, 2'd0, 5'd6, 5'd6));                // válido
    prog[6] = solo_cri(vcr(16'h10C));                               // AUTH = 0
    prog[7] = solo_cri(ell(2'd0, 2'd2, 5'd6, 5'd6));                // excepción
    prog[8] = bundle(NOP, NOP, sye(5'd0, 16'd0), NOP);

    run_program(30);

    check("una excepción",                          DUT.trap_count, 32'd1);
    check("trap_pc = 0x70 (ell sin AUTH)",          DUT.trap_pc, 32'h70);
    check("se ejecutó el manejador: x30 = 99",      reg_val(30), 32'd99);
    check("ESTADO: AUTH = 0 tras el vcr fallido",   DUT.crypto_estado, 32'b00);
    check("el ell válido escribió la palabra 0",    DUT.CRYPTO.VAULT.keys[0][0], 32'd85);
    check("el ell válido escribió la palabra 1",    DUT.CRYPTO.VAULT.keys[0][1], 32'd85);
    check("el ell con excepción no escribió la palabra 2", DUT.CRYPTO.VAULT.keys[0][2], 32'd0);
    check("el ell con excepción no escribió la palabra 3", DUT.CRYPTO.VAULT.keys[0][3], 32'd0);


    // ========================================================================
    // E. Aislamiento de la llave
    // ========================================================================
    tb_section("E. La llave sólo queda en la bóveda");

    preload_data();
    for (int i = 0; i < 2; i++)
        DUT.DMEM.mem[(32'h200 >> 2) + i] = plain[i];

    clear_prog();
    prog[0]  = solo_lsu(lsu(OP_CARGAI, 5'd0, 5'd6,  11'd256));
    prog[1]  = solo_lsu(lsu(OP_CARGAI, 5'd0, 5'd8,  11'd272));
    prog[2]  = solo_lsu(lsu(OP_CARGAI, 5'd0, 5'd10, 11'd276));
    prog[3]  = bundle(NOP, lsu(OP_CARGAI, 5'd0, 5'd12, 11'd280), NOP, setpwd(5'd6));
    prog[4]  = bundle(NOP, lsu(OP_CARGAI, 5'd0, 5'd14, 11'd284), NOP, vcr(16'h104));
    // Carga de la llave y borrado de todas sus copias
    prog[5]  = bundle(sumai(5'd6, 5'd0, 11'd0),  lsu(OP_GUARDAP, 5'd0, 5'd0, 11'd256), NOP,
                      ell(2'd0, 2'd0, 5'd8, 5'd10));
    prog[6]  = solo_lsu(lsu(OP_GUARDAP, 5'd0, 5'd0, 11'd272));
    prog[7]  = bundle(sumai(5'd8, 5'd0, 11'd0),  lsu(OP_GUARDAP, 5'd0, 5'd0, 11'd276), NOP,
                      ell(2'd0, 2'd2, 5'd12, 5'd14));
    prog[8]  = bundle(sumai(5'd10, 5'd0, 11'd0), lsu(OP_GUARDAP, 5'd0, 5'd0, 11'd280), NOP, NOP);
    prog[9]  = bundle(sumai(5'd12, 5'd0, 11'd0), lsu(OP_GUARDAP, 5'd0, 5'd0, 11'd284), NOP, NOP);
    prog[10] = bundle(sumai(5'd14, 5'd0, 11'd0), lsu(OP_CARGAI, 5'd0, 5'd4, 11'd512), NOP, NOP);
    prog[11] = solo_lsu(lsu(OP_CARGAI, 5'd0, 5'd5, 11'd516));
    prog[12] = solo_lsu(lsu(OP_GUARDAP, 5'd0, 5'd0, 11'd260));     // borra la candidata
    // Cifrado de un bloque
    for (int i = 0; i < 4; i++)
        prog[14 + 3 * i] = solo_cri(fsl(5'd4, 5'd4, 2'd0, 2'(i)));
    prog[26] = solo_lsu(lsu(OP_GUARDAP, 5'd0, 5'd4, 11'd512));
    prog[27] = solo_lsu(lsu(OP_GUARDAP, 5'd0, 5'd5, 11'd516));
    prog[28] = bundle(NOP, NOP, sye(5'd0, 16'd0), NOP);

    run_program(50);

    check("cifra bien sólo con la bóveda: L = 03D44466", mem_word(32'h200), 32'h03D4_4466);
    check("cifra bien sólo con la bóveda: R = D685AFAF", mem_word(32'h204), 32'hD685_AFAF);
    check("sin excepciones", DUT.trap_count, 32'd0);

    begin
        int in_regs, in_mem;

        in_regs = 0;
        in_mem  = 0;

        for (int r = 0; r < 32; r++)
            for (int k = 0; k < 4; k++)
                if (reg_val(r) == key[k] || reg_val(r) == PWD)
                    in_regs++;

        for (int a = 0; a < 16384; a++)
            for (int k = 0; k < 4; k++)
                if (DUT.DMEM.mem[a] == key[k] || DUT.DMEM.mem[a] == PWD)
                    in_mem++;

        check("ningún registro contiene la llave ni la contraseña", in_regs, 0);
        check("ninguna palabra de la memoria contiene la llave ni la contraseña", in_mem, 0);
    end


    tb_finish("tb_pipeline_cripto");
end

endmodule
