`timescale 1ns/1ps

/*
================================================================================
 Testbench: tb_key_vault

 Descripción:
 ------------------------------------------------------------------------------
 Verifica la bóveda de llaves (rtl/key_vault.sv) por sí sola.

 Casos:
   1. Reset: las 16 subllaves en 0 y la contraseña sin definir.
   2. Antes de setpwd no se puede autenticar, ni siquiera con candidata 0.
   3. Carga de las 4 llaves de 128 bits con ell (off = 0 y off = 2) y lectura
      de las 16 subllaves: cada escritura toca sólo sus dos palabras.
   4. key_we = 0 no escribe.
   5. setpwd: pwd_set = 1 y sólo coincide la contraseña exacta.
   6. camcon: la contraseña rota imm bits (0, 1, 7, 31) y deja de coincidir
      la anterior.
   7. off = 1 y off = 3 escriben (off, off + 1) módulo 4 (el ISA sólo usa 0 y
      2; se documenta lo que hace el hardware).
   8. 1000 escrituras y lecturas aleatorias contra un modelo.
   9. Reset en medio de la ejecución: borra llaves y contraseña.

 La bóveda no tiene ningún puerto que entregue la contraseña: la única salida
 relacionada es pwd_match.

================================================================================
*/

module tb_key_vault;

`include "tb_utils.svh"


logic        clk;
logic        reset;

logic [1:0]  rd_key;
logic [1:0]  rd_word;
logic [31:0] subkey;

logic        key_we;
logic [1:0]  wr_key;
logic [1:0]  wr_word;
logic [31:0] wr_data0;
logic [31:0] wr_data1;

logic        pwd_we;
logic [31:0] pwd_wdata;
logic        pwd_rot;
logic [4:0]  pwd_rot_amount;

logic [31:0] pwd_candidate;
logic        pwd_match;
logic        pwd_set;


key_vault DUT (
    .clk(clk),
    .reset(reset),
    .rd_key(rd_key),
    .rd_word(rd_word),
    .subkey(subkey),
    .key_we(key_we),
    .wr_key(wr_key),
    .wr_word(wr_word),
    .wr_data0(wr_data0),
    .wr_data1(wr_data1),
    .pwd_we(pwd_we),
    .pwd_wdata(pwd_wdata),
    .pwd_rot(pwd_rot),
    .pwd_rot_amount(pwd_rot_amount),
    .pwd_candidate(pwd_candidate),
    .pwd_match(pwd_match),
    .pwd_set(pwd_set)
);


always #5 clk = ~clk;


// ============================================================================
// Modelo y utilidades
// ============================================================================

logic [31:0] model [0:3][0:3];

function automatic logic [31:0] rol(input logic [31:0] x, input int r);

    r = r % 32;
    return (r == 0) ? x : ((x << r) | (x >> (32 - r)));
endfunction

// Escribe dos palabras como lo hace ell y actualiza el modelo
task automatic write_pair(input logic [1:0] k, input logic [1:0] w,
                          input logic [31:0] d0, input logic [31:0] d1);

    @(negedge clk);
    key_we   = 1'b1;
    wr_key   = k;
    wr_word  = w;
    wr_data0 = d0;
    wr_data1 = d1;
    @(negedge clk);
    key_we   = 1'b0;

    model[k][w]        = d0;
    model[k][w + 2'd1] = d1;
endtask

// Compara las 16 subllaves con el modelo
task automatic check_all(input string tag);

    for (int k = 0; k < 4; k++) begin

        for (int w = 0; w < 4; w++) begin

            rd_key  = k;
            rd_word = w;
            #1;
            check($sformatf("%s: llave %0d subllave %0d", tag, k, w), subkey, model[k][w]);
        end
    end
endtask

task automatic set_password(input logic [31:0] p);

    @(negedge clk);
    pwd_we    = 1'b1;
    pwd_wdata = p;
    @(negedge clk);
    pwd_we    = 1'b0;
endtask

task automatic rotate_password(input logic [4:0] n);

    @(negedge clk);
    pwd_rot        = 1'b1;
    pwd_rot_amount = n;
    @(negedge clk);
    pwd_rot        = 1'b0;
endtask

integer seed;


initial begin

    $dumpfile("tb_key_vault.vcd");
    $dumpvars(0, tb_key_vault);

    if (!$value$plusargs("seed=%d", seed))
        seed = 32'hCE4301;

    clk            = 0;
    reset          = 1;
    rd_key         = 0;
    rd_word        = 0;
    key_we         = 0;
    wr_key         = 0;
    wr_word        = 0;
    wr_data0       = 0;
    wr_data1       = 0;
    pwd_we         = 0;
    pwd_wdata      = 0;
    pwd_rot        = 0;
    pwd_rot_amount = 0;
    pwd_candidate  = 0;

    for (int k = 0; k < 4; k++)
        for (int w = 0; w < 4; w++)
            model[k][w] = 32'b0;

    @(negedge clk);
    @(negedge clk);
    reset = 0;


    // ========================================================================
    tb_section("1. Reset");

    check_all("reset");
    check("reset: pwd_set = 0", pwd_set, 1'b0);


    // ========================================================================
    tb_section("2. Sin contraseña no hay autenticación");

    pwd_candidate = 32'h0; #1;
    check("candidata 0 sin setpwd: pwd_match = 0", pwd_match, 1'b0);
    pwd_candidate = 32'hDEAD_BEEF; #1;
    check("candidata cualquiera sin setpwd: pwd_match = 0", pwd_match, 1'b0);


    // ========================================================================
    tb_section("3. Carga de las 4 llaves con ell");

    for (int k = 0; k < 4; k++) begin

        write_pair(k, 2'd0, 32'h1000_0000 * (k + 1) + 32'h0, 32'h1000_0000 * (k + 1) + 32'h1);
        write_pair(k, 2'd2, 32'h1000_0000 * (k + 1) + 32'h2, 32'h1000_0000 * (k + 1) + 32'h3);
    end

    check_all("4 llaves");


    // ========================================================================
    tb_section("4. key_we = 0 no escribe");

    @(negedge clk);
    wr_key   = 2'd1;
    wr_word  = 2'd0;
    wr_data0 = 32'hFFFF_FFFF;
    wr_data1 = 32'hFFFF_FFFF;
    @(negedge clk);
    check_all("key_we = 0");


    // ========================================================================
    tb_section("5. setpwd");

    set_password(32'hC0FF_EE42);

    check("setpwd: pwd_set = 1", pwd_set, 1'b1);
    pwd_candidate = 32'hC0FF_EE42; #1;
    check("contraseña correcta: pwd_match = 1", pwd_match, 1'b1);
    pwd_candidate = 32'hC0FF_EE43; #1;
    check("contraseña con 1 bit distinto: pwd_match = 0", pwd_match, 1'b0);
    pwd_candidate = 32'h0; #1;
    check("candidata 0: pwd_match = 0", pwd_match, 1'b0);
    check_all("setpwd no toca las llaves");


    // ========================================================================
    tb_section("6. camcon: rotación de la contraseña");

    begin
        logic [31:0] p;
        int          n;

        p = 32'hC0FF_EE42;

        for (int i = 0; i < 4; i++) begin

            n = (i == 0) ? 0 : (i == 1) ? 1 : (i == 2) ? 7 : 31;

            rotate_password(n[4:0]);
            p = rol(p, n);

            pwd_candidate = p; #1;
            check($sformatf("rotación %0d: coincide la contraseña rotada", n), pwd_match, 1'b1);

            if (n != 0) begin

                pwd_candidate = rol(p, 32 - n); #1;
                check($sformatf("rotación %0d: la anterior ya no coincide", n), pwd_match, 1'b0);
            end
        end
    end


    // ========================================================================
    tb_section("7. off = 1 y off = 3");

    write_pair(2'd2, 2'd1, 32'hAAAA_0001, 32'hAAAA_0002);   // palabras 1 y 2
    write_pair(2'd3, 2'd3, 32'hBBBB_0003, 32'hBBBB_0000);   // palabras 3 y 0
    check_all("off impar");


    // ========================================================================
    tb_section("8. 1000 escrituras y lecturas aleatorias");

    repeat (1000) begin

        logic [1:0]  k, w;
        logic [31:0] d0, d1;

        k  = $random(seed);
        w  = $random(seed);
        d0 = $random(seed);
        d1 = $random(seed);

        write_pair(k, w, d0, d1);

        rd_key  = $random(seed);
        rd_word = $random(seed);
        #1;
        check("aleatorio: subllave", subkey, model[rd_key][rd_word]);
    end

    check_all("después de las aleatorias");


    // ========================================================================
    tb_section("9. Reset en medio de la ejecución");

    @(negedge clk);
    reset = 1;
    @(negedge clk);
    reset = 0;

    for (int k = 0; k < 4; k++)
        for (int w = 0; w < 4; w++)
            model[k][w] = 32'b0;

    check_all("después del reset");
    check("reset: pwd_set = 0", pwd_set, 1'b0);
    pwd_candidate = 32'h0; #1;
    check("reset: la contraseña anterior no autentica", pwd_match, 1'b0);


    tb_finish("tb_key_vault");
end

endmodule
