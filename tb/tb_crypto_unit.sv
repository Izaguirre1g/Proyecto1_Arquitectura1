`timescale 1ns/1ps

/*
================================================================================
 Testbench: tb_crypto_unit

 Descripción:
 ------------------------------------------------------------------------------
 Verifica la unidad criptográfica (rtl/crypto_unit.sv, con su key_vault)
 conectada al puerto B de la memoria de datos (rtl/memory.sv). Las entradas se
 manejan como las entrega el registro ID/EX.

 La validación de privilegios se hace en ID (decoder_crypto, con su propio
 testbench) y llega a la unidad como fault_in. Aquí la modela id_fault() con
 el ESTADO actual de la unidad. ESTADO se escribe en WB, así que cada
 instrucción se presenta en EX y el testbench espera también el flanco de WB
 antes de la siguiente.

 Casos:
   1.  Reset: AUTH = 0, INIT = 1.
   2.  Sin autenticación, fsl, fsli, ell y camcon generan excepción y no
       tienen efecto; vcr no genera excepción.
   3.  setpwd con INIT = 1; un segundo setpwd genera excepción.
   4.  vcr con contraseña incorrecta (AUTH = 0) y correcta (AUTH = 1).
   5.  Carga de las 4 llaves con ell.
   6.  Vector conocido: "HOLA2026" con la llave del ejemplo da
       03D44466 D685AFAF (vector calculado con la implementación de
       referencia del enunciado), ronda por ronda; 4 fsli lo devuelven al
       original.
   7.  Cifrado y descifrado completos con cada una de las 4 llaves.
   8.  500 rondas aleatorias de fsl y fsli contra el modelo de referencia, y
       fsli(fsl(x)) = x.
   9.  wb_rd lleva el registro destino de la instrucción.
   10. camcon rota la contraseña de la bóveda y la palabra M[dir].
   11. Una instrucción con excepción no modifica llaves, memoria ni ESTADO.
   12. valid_in = 0 no hace nada, ni siquiera genera excepción.
   14. ESTADO se escribe en WB: después del flanco de EX de vcr todavía no
       cambió, y después del flanco de WB sí.
   13. Reset en medio de la ejecución: ESTADO vuelve a AUTH = 0, INIT = 1 y la
       bóveda queda en cero.

 Plusargs: +seed=N cambia la semilla de los vectores aleatorios.

================================================================================
*/

`include "isa_defs.sv"


module tb_crypto_unit;

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

// Una ronda de descifrado (fsli): (L, R) -> (R ^ F(L, k), L)
function automatic logic [63:0] ref_round_dec(input logic [31:0] l, input logic [31:0] r,
                                              input logic [31:0] k);

    return {r ^ ref_f(l, k), l};
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


logic        clk;
logic        reset;

logic        valid_in;
logic        fault_in;
logic [3:0]  crypto_op;
logic [1:0]  lk;
logic [1:0]  rk;
logic [4:0]  rd;
logic [31:0] operand_a;
logic [31:0] operand_b;
logic [15:0] addr;
logic [4:0]  imm;

logic        mem_we;
logic [31:0] mem_addr;
logic [31:0] mem_wdata;
logic [31:0] mem_rdata;

logic        wb_we;
logic [4:0]  wb_rd;
logic [31:0] wb_data_l;
logic [31:0] wb_data_r;

logic        priv_fault;
logic [31:0] estado;


crypto_unit DUT (
    .clk(clk),
    .reset(reset),
    .valid_in(valid_in),
    .fault_in(fault_in),
    .crypto_op(crypto_op),
    .lk(lk),
    .rk(rk),
    .rd(rd),
    .operand_a(operand_a),
    .operand_b(operand_b),
    .addr(addr),
    .imm(imm),
    .mem_we(mem_we),
    .mem_addr(mem_addr),
    .mem_wdata(mem_wdata),
    .mem_rdata(mem_rdata),
    .wb_we(wb_we),
    .wb_rd(wb_rd),
    .wb_data_l(wb_data_l),
    .wb_data_r(wb_data_r),
    .priv_fault(priv_fault),
    .estado(estado)
);

// Memoria de datos: sólo se usa el puerto B
memory #(.SIZE_WORDS(256)) MEM (
    .clk(clk),
    .we(1'b0),
    .be(4'b0),
    .addr(32'b0),
    .wdata(32'b0),
    .rdata(),
    .we_b(mem_we),
    .addr_b(mem_addr),
    .wdata_b(mem_wdata),
    .rdata_b(mem_rdata)
);


always #5 clk = ~clk;


// ============================================================================
// Utilidades
// ============================================================================

localparam logic [31:0] PWD  = 32'h5EC2_E7A1;     // contraseña de prueba
localparam logic [15:0] A_OK  = 16'h0040;          // M[0x40] = PWD
localparam logic [15:0] A_BAD = 16'h0044;          // M[0x44] = PWD con un bit cambiado

logic [3:0][31:0] keys [0:3];   // copia de lo que se carga en la bóveda
logic             last_fault;   // priv_fault de la última instrucción
integer           seed;

// Salidas hacia wb de la última instrucción (se capturan después de EX)
logic             res_we;
logic [4:0]       res_rd;
logic [31:0]      res_l;
logic [31:0]      res_r;

// Validación de ID (la misma regla que decoder_crypto) con el ESTADO actual
function automatic logic id_fault(input logic [3:0] op);

    logic needs_auth;

    needs_auth = (op == OP_FSL) || (op == OP_FSLI) || (op == OP_ELL) || (op == OP_CAMCON);
    return (needs_auth && !estado[0]) || ((op == OP_SETPWD) && !estado[1]);
endfunction

// Ejecuta una instrucción: la presenta en EX en un flanco negativo, captura
// las salidas hacia wb después del flanco de EX (cuando la bóveda y la memoria
// ya se actualizaron) y vuelve después del flanco de WB, cuando ESTADO ya se
// actualizó.
task automatic issue(input logic [3:0] op, input logic [1:0] k, input logic [1:0] w,
                     input logic [4:0] dst, input logic [31:0] a, input logic [31:0] b,
                     input logic [15:0] dir, input logic [4:0] n);

    @(negedge clk);
    valid_in  = 1'b1;
    crypto_op = op;
    lk        = k;
    rk        = w;
    rd        = dst;
    operand_a = a;
    operand_b = b;
    addr      = dir;
    imm       = n;
    fault_in  = id_fault(op);
    #1;
    last_fault = priv_fault;
    @(negedge clk);                 // flanco de EX
    valid_in  = 1'b0;
    fault_in  = 1'b0;
    res_we    = wb_we;
    res_rd    = wb_rd;
    res_l     = wb_data_l;
    res_r     = wb_data_r;
    @(negedge clk);                 // flanco de WB
endtask

task automatic do_fsl(input logic [1:0] k, input logic [1:0] w,
                      input logic [31:0] l, input logic [31:0] r);

    issue(OP_FSL, k, w, 5'd4, l, r, 16'h0, 5'd0);
endtask

task automatic do_fsli(input logic [1:0] k, input logic [1:0] w,
                       input logic [31:0] l, input logic [31:0] r);

    issue(OP_FSLI, k, w, 5'd4, l, r, 16'h0, 5'd0);
endtask

task automatic do_ell(input logic [1:0] k, input logic [1:0] off,
                      input logic [31:0] w0, input logic [31:0] w1);

    issue(OP_ELL, k, off, 5'd0, w0, w1, 16'h0, 5'd0);
endtask

task automatic do_vcr(input logic [15:0] dir);

    issue(OP_VCR, 2'd0, 2'd0, 5'd0, 32'h0, 32'h0, dir, 5'd0);
endtask

task automatic do_setpwd(input logic [31:0] p);

    issue(OP_SETPWD, 2'd0, 2'd0, 5'd0, p, 32'h0, 16'h0, 5'd0);
endtask

task automatic do_camcon(input logic [15:0] dir, input logic [4:0] n);

    issue(OP_CAMCON, 2'd0, 2'd0, 5'd0, 32'h0, 32'h0, dir, n);
endtask

task automatic load_key(input logic [1:0] k);

    do_ell(k, 2'd0, keys[k][0], keys[k][1]);
    do_ell(k, 2'd2, keys[k][2], keys[k][3]);
endtask

// Cifra / descifra (L, R) con 4 rondas de la llave k y devuelve {L, R}
task automatic encrypt_hw(input logic [1:0] k, input logic [63:0] in, output logic [63:0] out);

    out = in;
    for (int i = 0; i < 4; i++) begin

        do_fsl(k, i[1:0], out[63:32], out[31:0]);
        out = {res_l, res_r};
    end
endtask

task automatic decrypt_hw(input logic [1:0] k, input logic [63:0] in, output logic [63:0] out);

    out = in;
    for (int i = 3; i >= 0; i--) begin

        do_fsli(k, i[1:0], out[63:32], out[31:0]);
        out = {res_l, res_r};
    end
endtask

function automatic logic [31:0] mem_word(input logic [15:0] a);

    return MEM.mem[a >> 2];
endfunction


// ============================================================================
// Estímulo
// ============================================================================

initial begin

    $dumpfile("tb_crypto_unit.vcd");
    $dumpvars(0, tb_crypto_unit);

    if (!$value$plusargs("seed=%d", seed))
        seed = 32'hCE4301;

    clk       = 0;
    reset     = 1;
    valid_in  = 0;
    fault_in  = 0;
    res_we    = 0;
    res_rd    = 0;
    res_l     = 0;
    res_r     = 0;
    crypto_op = 0;
    lk        = 0;
    rk        = 0;
    rd        = 0;
    operand_a = 0;
    operand_b = 0;
    addr      = 0;
    imm       = 0;

    // Llave 0: la del vector conocido. Llaves 1-3 aleatorias.
    keys[0] = {32'hC3D2_E1F0, 32'h8796_A5B4, 32'h4B5A_6978, 32'h0F1E_2D3C};
    for (int k = 1; k < 4; k++)
        for (int w = 0; w < 4; w++)
            keys[k][w] = $random(seed);

    // Esperar la inicialización de la memoria y cargar las contraseñas candidatas
    #1;
    MEM.mem[A_OK  >> 2] = PWD;
    MEM.mem[A_BAD >> 2] = PWD ^ 32'h0000_0100;

    @(negedge clk);
    @(negedge clk);
    reset = 0;


    // ========================================================================
    tb_section("1. Reset");

    check("ESTADO tras reset: INIT = 1, AUTH = 0", estado, 32'b10);
    check("sin resultado hacia wb", res_we, 1'b0);


    // ========================================================================
    tb_section("2. Sin autenticación");

    do_fsl(2'd0, 2'd0, 32'h1, 32'h2);
    check("fsl sin AUTH: excepción", last_fault, 1'b1);
    check("fsl sin AUTH: no escribe registros", res_we, 1'b0);

    do_fsli(2'd0, 2'd0, 32'h1, 32'h2);
    check("fsli sin AUTH: excepción", last_fault, 1'b1);
    check("fsli sin AUTH: no escribe registros", res_we, 1'b0);

    do_ell(2'd0, 2'd0, 32'hBAD0_0000, 32'hBAD0_0001);
    check("ell sin AUTH: excepción", last_fault, 1'b1);

    do_camcon(A_OK, 5'd3);
    check("camcon sin AUTH: excepción", last_fault, 1'b1);
    check("camcon sin AUTH: M[dir] sin cambios", mem_word(A_OK), PWD);

    do_vcr(A_OK);
    check("vcr antes de setpwd: sin excepción", last_fault, 1'b0);
    check("vcr antes de setpwd: AUTH = 0", estado[0], 1'b0);


    // ========================================================================
    tb_section("3. setpwd");

    do_setpwd(PWD);
    check("setpwd con INIT = 1: sin excepción", last_fault, 1'b0);
    check("setpwd: INIT pasa a 0", estado, 32'b00);

    do_setpwd(32'h1234_5678);
    check("segundo setpwd: excepción", last_fault, 1'b1);


    // ========================================================================
    tb_section("4. vcr");

    do_vcr(A_BAD);
    check("vcr incorrecta: sin excepción", last_fault, 1'b0);
    check("vcr incorrecta: AUTH = 0", estado[0], 1'b0);

    do_vcr(A_OK);
    check("vcr correcta (el segundo setpwd no cambió la contraseña): AUTH = 1", estado[0], 1'b1);

    do_vcr(A_BAD);
    check("vcr incorrecta después de autenticar: AUTH = 0", estado[0], 1'b0);

    do_vcr(A_OK);
    check("vcr correcta otra vez: AUTH = 1", estado[0], 1'b1);


    // ========================================================================
    tb_section("5. Carga de las 4 llaves");

    for (int k = 0; k < 4; k++) begin

        load_key(k[1:0]);
        check($sformatf("ell llave %0d: sin excepción", k), last_fault, 1'b0);
    end


    // ========================================================================
    tb_section("6. Vector conocido HOLA2026");

    begin
        logic [63:0] lr, exp;

        lr = {32'h414C_4F48, 32'h3632_3032};     // "HOLA" "2026" en little-endian

        for (int i = 0; i < 4; i++) begin

            exp = ref_round_enc(lr[63:32], lr[31:0], keys[0][i]);
            do_fsl(2'd0, i[1:0], lr[63:32], lr[31:0]);
            check($sformatf("fsl ronda %0d: L", i + 1), res_l, exp[63:32]);
            check($sformatf("fsl ronda %0d: R", i + 1), res_r, exp[31:0]);
            check($sformatf("fsl ronda %0d: res_we", i + 1), res_we, 1'b1);
            lr = {res_l, res_r};
        end

        check("cifrado HOLA2026: L = 03D44466 (vector conocido)", lr[63:32], 32'h03D4_4466);
        check("cifrado HOLA2026: R = D685AFAF (vector conocido)", lr[31:0],  32'hD685_AFAF);

        decrypt_hw(2'd0, lr, lr);
        check("descifrado: L = 414C4F48 (HOLA)", lr[63:32], 32'h414C_4F48);
        check("descifrado: R = 36323032 (2026)", lr[31:0],  32'h3632_3032);
    end


    // ========================================================================
    tb_section("7. Cifrado y descifrado con cada llave");

    for (int k = 0; k < 4; k++) begin

        logic [63:0] p, c, d;

        p = {$random(seed), $random(seed)};
        encrypt_hw(k[1:0], p, c);
        check($sformatf("llave %0d: cifrado = referencia (L)", k), c[63:32],
              ref_encrypt(p[63:32], p[31:0], keys[k]) >> 32);
        check($sformatf("llave %0d: cifrado = referencia (R)", k), c[31:0],
              ref_encrypt(p[63:32], p[31:0], keys[k]));

        decrypt_hw(k[1:0], c, d);
        check($sformatf("llave %0d: descifrado = original (L)", k), d[63:32], p[63:32]);
        check($sformatf("llave %0d: descifrado = original (R)", k), d[31:0], p[31:0]);
    end


    // ========================================================================
    tb_section("8. 500 rondas aleatorias");

    repeat (500) begin

        logic [1:0]  k, w;
        logic [31:0] l, r;
        logic [63:0] e, enc;

        k = $random(seed);
        w = $random(seed);
        l = $random(seed);
        r = $random(seed);

        e = ref_round_enc(l, r, keys[k][w]);
        do_fsl(k, w, l, r);
        check("fsl aleatoria: L", res_l, e[63:32]);
        check("fsl aleatoria: R", res_r, e[31:0]);
        enc = {res_l, res_r};

        e = ref_round_dec(l, r, keys[k][w]);
        do_fsli(k, w, l, r);
        check("fsli aleatoria: L", res_l, e[63:32]);
        check("fsli aleatoria: R", res_r, e[31:0]);

        do_fsli(k, w, enc[63:32], enc[31:0]);
        check("fsli(fsl(x)) = x: L", res_l, l);
        check("fsli(fsl(x)) = x: R", res_r, r);
    end


    // ========================================================================
    tb_section("9. Registro destino");

    issue(OP_FSL, 2'd0, 2'd0, 5'd20, 32'h1, 32'h2, 16'h0, 5'd0);
    check("fsl rd = x20: res_rd = 20", res_rd, 5'd20);
    issue(OP_FSLI, 2'd0, 2'd0, 5'd30, 32'h1, 32'h2, 16'h0, 5'd0);
    check("fsli rd = x30: res_rd = 30", res_rd, 5'd30);
    do_vcr(A_OK);
    check("vcr no escribe registros", res_we, 1'b0);


    // ========================================================================
    tb_section("10. camcon");

    MEM.mem[16'h80 >> 2] = PWD;      // copia de la contraseña que se va a renovar
    MEM.mem[16'h84 >> 2] = PWD;      // copia vieja que no se rota

    do_camcon(16'h80, 5'd7);
    check("camcon: sin excepción", last_fault, 1'b0);
    check("camcon: M[0x80] = ROL(contraseña, 7)", mem_word(16'h80), ref_rol(PWD, 7));

    do_vcr(16'h80);
    check("vcr con la contraseña rotada: AUTH = 1", estado[0], 1'b1);
    do_vcr(16'h84);
    check("vcr con la contraseña vieja: AUTH = 0", estado[0], 1'b0);
    do_vcr(16'h80);

    do_camcon(16'h80, 5'd0);
    check("camcon 0: M[0x80] sin cambios", mem_word(16'h80), ref_rol(PWD, 7));
    do_vcr(16'h80);
    check("camcon 0: la contraseña no cambia", estado[0], 1'b1);


    // ========================================================================
    tb_section("11. Una excepción no tiene efectos");

    begin
        logic [63:0] prev;

        do_fsl(2'd1, 2'd2, 32'hAAAA_5555, 32'h1234_ABCD);
        prev = {res_l, res_r};

        do_vcr(16'h84);                             // AUTH = 0
        do_ell(2'd1, 2'd2, 32'hBAD, 32'hBAD);
        check("ell sin AUTH: excepción", last_fault, 1'b1);
        do_camcon(16'h80, 5'd5);
        check("camcon sin AUTH: excepción", last_fault, 1'b1);
        check("camcon sin AUTH: M[0x80] sin cambios", mem_word(16'h80), ref_rol(PWD, 7));
        check("la excepción no cambia ESTADO", estado, 32'b00);

        do_vcr(16'h80);                             // la contraseña no rotó
        check("la contraseña no rotó con la excepción: AUTH = 1", estado[0], 1'b1);

        do_fsl(2'd1, 2'd2, 32'hAAAA_5555, 32'h1234_ABCD);
        check("ell con excepción no cambió la llave (L)", res_l, prev[63:32]);
        check("ell con excepción no cambió la llave (R)", res_r, prev[31:0]);
    end


    // ========================================================================
    tb_section("12. valid_in = 0");

    @(negedge clk);
    valid_in  = 1'b0;
    crypto_op = OP_ELL;
    lk        = 2'd0;
    rk        = 2'd0;
    operand_a = 32'hFFFF_FFFF;
    operand_b = 32'hFFFF_FFFF;
    @(negedge clk);
    crypto_op = OP_CAMCON;
    addr      = 16'h80;
    imm       = 5'd9;
    #1;
    check("valid_in = 0: no escribe memoria", mem_we, 1'b0);
    @(negedge clk);
    check("valid_in = 0: M[0x80] sin cambios", mem_word(16'h80), ref_rol(PWD, 7));
    check("valid_in = 0: no hay resultado hacia wb", wb_we, 1'b0);

    do_fsl(2'd0, 2'd0, 32'h414C_4F48, 32'h3632_3032);
    check("valid_in = 0: la llave 0 no cambió", res_r, 32'hD22E_3A0C);

    do_vcr(16'h84);                                 // AUTH = 0
    @(negedge clk);
    crypto_op = OP_FSL;
    fault_in  = 1'b1;
    #1;
    check("valid_in = 0 con fault_in = 1: sin excepción", priv_fault, 1'b0);
    fault_in  = 1'b0;


    // ========================================================================
    tb_section("13. Reset en medio de la ejecución");

    @(negedge clk);
    reset = 1;
    @(negedge clk);
    reset = 0;

    check("reset: INIT = 1, AUTH = 0", estado, 32'b10);

    do_vcr(A_OK);
    check("reset: la contraseña anterior ya no autentica", estado[0], 1'b0);

    do_setpwd(PWD);
    do_vcr(A_OK);
    check("nuevo setpwd y vcr: AUTH = 1", estado[0], 1'b1);

    begin
        logic [3:0][31:0] zero_key;
        logic [63:0]      e;

        zero_key = '0;
        e = ref_round_enc(32'h414C_4F48, 32'h3632_3032, zero_key[0]);
        do_fsl(2'd0, 2'd0, 32'h414C_4F48, 32'h3632_3032);
        check("reset: la bóveda quedó en cero (L)", res_l, e[63:32]);
        check("reset: la bóveda quedó en cero (R)", res_r, e[31:0]);
    end


    // ========================================================================
    tb_section("14. ESTADO se escribe en WB");

    MEM.mem[A_BAD >> 2] = 32'hFFFF_FFFF;    // candidata incorrecta

    @(negedge clk);
    valid_in  = 1'b1;
    fault_in  = 1'b0;
    crypto_op = OP_VCR;
    addr      = A_BAD;
    @(negedge clk);                          // flanco de EX
    valid_in  = 1'b0;
    check("vcr incorrecta: después de EX, AUTH sigue en 1", estado[0], 1'b1);
    @(negedge clk);                          // flanco de WB
    check("vcr incorrecta: después de WB, AUTH = 0", estado[0], 1'b0);

    @(negedge clk);
    valid_in  = 1'b1;
    crypto_op = OP_VCR;
    addr      = A_OK;
    @(negedge clk);
    valid_in  = 1'b0;
    check("vcr correcta: después de EX, AUTH sigue en 0", estado[0], 1'b0);
    @(negedge clk);
    check("vcr correcta: después de WB, AUTH = 1", estado[0], 1'b1);


    tb_finish("tb_crypto_unit");
end

endmodule
