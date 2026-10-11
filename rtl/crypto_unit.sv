/*
================================================================================
 Módulo: crypto_unit

 Descripción:
 ------------------------------------------------------------------------------
 Unidad criptográfica Feistel4 (slot 3 del bundle). Contiene la bóveda de
 llaves (key_vault) y el registro de estado ESTADO, y ejecuta en EX las 6
 instrucciones cripto del ISA:

     fsl     (L, R) -> (R, L ⊕ F(R, K))       ronda de cifrado
     fsli    (L, R) -> (R ⊕ F(L, K), L)       ronda de descifrado (inversa)
     ell     bóveda[LK][off] = rs1, bóveda[LK][off + 1] = rs2
     vcr     AUTH = (M[dir_cand] == contraseña de la bóveda)
     camcon  contraseña = ROL(contraseña, imm) y M[dir] = ROL(M[dir], imm)
     setpwd  contraseña = rs, INIT = 0

 donde K = bóveda[LK][RK] y F es la función de ronda del enunciado:

     F(x, K) = (ROL(x, 5) + K) ⊕ ROL(x, 13)      (suma módulo 2^32)

 Cifrar un bloque son 4 fsl con RK = 0, 1, 2, 3; descifrarlo, 4 fsli con
 RK = 3, 2, 1, 0. Así se reproduce exactamente feistel4_encrypt y
 feistel4_decrypt de la implementación de referencia.

 ESTADO (32 bits, no accesible desde registros ni memoria):
 ------------------------------------------------------------------------------
     ESTADO[0] = AUTH   1 = autenticado. Lo escribe sólo vcr.
     ESTADO[1] = INIT   1 = provisionamiento: habilita setpwd. Se limpia con
                        el primer setpwd válido.
     ESTADO[31:2] = 0

     Reset: AUTH = 0, INIT = 1, y la bóveda se borra.

 Control de acceso (ISA, "Restricción de uso por instrucción"):
 ------------------------------------------------------------------------------
     fsl, fsli, ell, camcon   requieren AUTH = 1
     setpwd                   requiere INIT = 1
     vcr                      siempre permitida (es la vía de autenticación)

     Si no se cumple, priv_fault = 1 en EX y la instrucción no tiene ningún
     efecto: no escribe registros, ni la bóveda, ni la memoria, ni ESTADO.
     top usa priv_fault para anular el bundle completo y saltar al
     manejador de excepciones.

 Conexión con el pipeline:
 ------------------------------------------------------------------------------
     - Todas las entradas vienen de ID/EX. operand_a/operand_b son las
       lecturas 6 y 7 del banco: (L, R) en fsl/fsli, (rs1, rs2) en ell y
       rs en setpwd.
     - vcr y camcon usan el puerto B de la memoria de datos (lectura
       combinacional en EX, escritura en el flanco), así que pueden ir en el
       mismo bundle que una instrucción de la LSU.
     - El resultado de fsl/fsli se registra aquí, igual que hace la LSU con
       las cargas, para llegar a wb un ciclo después de EX junto con los
       resultados de la ALU. wb escribe L_out en rd y R_out en rd + 1.
     - La bóveda, ESTADO y la memoria se actualizan al final de EX: la
       instrucción cripto del bundle siguiente ya ve el cambio (por ejemplo,
       ell seguida de fsl, o vcr seguida de fsl). Los registros siguen la
       regla general: el par escrito por fsl lo lee el bundle N + 3.

================================================================================
*/

`include "isa_defs.sv"


module crypto_unit(

    input  logic         clk,
    input  logic         reset,

    // Entradas desde ID/EX
    input  logic         valid_in,      // el slot 3 trae una instrucción cripto válida
    input  logic [3:0]   crypto_op,     // OP_FSL ... OP_SETPWD
    input  logic [1:0]   lk,            // llave
    input  logic [1:0]   rk,            // subllave (fsl/fsli) u offset (ell)
    input  logic [4:0]   rd,            // destino del par (fsl/fsli)
    input  logic [31:0]  operand_a,     // L (fsl/fsli), rs1 (ell), rs (setpwd)
    input  logic [31:0]  operand_b,     // R (fsl/fsli), rs2 (ell)
    input  logic [15:0]  addr,          // dirección de vcr / camcon
    input  logic [4:0]   imm,           // rotación de camcon

    // Puerto B de rtl/memory.sv (vcr / camcon)
    output logic         mem_we,
    output logic [31:0]  mem_addr,
    output logic [31:0]  mem_wdata,
    input  logic [31:0]  mem_rdata,

    // Salidas hacia rtl/wb.sv (registradas, igual que la LSU)
    output logic         wb_we,
    output logic [4:0]   wb_rd,
    output logic [31:0]  wb_data_l,     // -> rd
    output logic [31:0]  wb_data_r,     // -> rd + 1

    // Control de acceso
    output logic         priv_fault,    // instrucción privilegiada sin permiso (combinacional)
    output logic [31:0]  estado         // ESTADO, sólo para observación en simulación
);


// ============================================================================
// Decodificación de la operación
// ============================================================================

logic is_fsl, is_fsli, is_ell, is_vcr, is_camcon, is_setpwd;

assign is_fsl    = (crypto_op == OP_FSL);
assign is_fsli   = (crypto_op == OP_FSLI);
assign is_ell    = (crypto_op == OP_ELL);
assign is_vcr    = (crypto_op == OP_VCR);
assign is_camcon = (crypto_op == OP_CAMCON);
assign is_setpwd = (crypto_op == OP_SETPWD);


// ============================================================================
// ESTADO y control de acceso
// ============================================================================

logic auth;     // ESTADO[0]
logic init;     // ESTADO[1]

assign estado = {30'b0, init, auth};

logic needs_auth;
logic exec;     // la instrucción es válida y tiene permiso: produce efectos

assign needs_auth = is_fsl || is_fsli || is_ell || is_camcon;

assign priv_fault = valid_in && ((needs_auth && !auth) || (is_setpwd && !init));

assign exec = valid_in && !priv_fault;


// ============================================================================
// Bóveda de llaves
// ============================================================================

logic [31:0] subkey;
logic        pwd_match;
logic        pwd_set;

key_vault VAULT (
    .clk(clk),
    .reset(reset),

    .rd_key(lk),
    .rd_word(rk),
    .subkey(subkey),

    .key_we(exec && is_ell),
    .wr_key(lk),
    .wr_word(rk),
    .wr_data0(operand_a),
    .wr_data1(operand_b),

    .pwd_we(exec && is_setpwd),
    .pwd_wdata(operand_a),
    .pwd_rot(exec && is_camcon),
    .pwd_rot_amount(imm),

    .pwd_candidate(mem_rdata),
    .pwd_match(pwd_match),
    .pwd_set(pwd_set)
);


// ============================================================================
// Ronda Feistel4
// ============================================================================

// Rotación circular a la izquierda de 32 bits
function automatic logic [31:0] rol32(input logic [31:0] x, input logic [4:0] r);

    return (x << r) | (x >> (6'd32 - r));
endfunction

// Función de ronda F del enunciado (Fig. 1)
function automatic logic [31:0] feistel_f(input logic [31:0] x, input logic [31:0] k);

    return (rol32(x, 5'd5) + k) ^ rol32(x, 5'd13);
endfunction

logic [31:0] round_l;
logic [31:0] round_r;

always @(*) begin

    if (is_fsli) begin

        // Ronda inversa: deshace una fsl hecha con la misma subllave
        round_l = operand_b ^ feistel_f(operand_a, subkey);
        round_r = operand_a;
    end
    else begin

        // Ronda directa (fsl)
        round_l = operand_b;
        round_r = operand_a ^ feistel_f(operand_b, subkey);
    end
end


// ============================================================================
// Puerto B de la memoria: vcr lee la candidata; camcon rota la palabra en M[dir]
// ============================================================================

assign mem_addr  = {16'b0, addr};
assign mem_we    = exec && is_camcon;
assign mem_wdata = rol32(mem_rdata, imm);


// ============================================================================
// Registros: ESTADO y resultado de la ronda hacia wb
// ============================================================================

logic        result_we_d;
logic [4:0]  result_rd_d;
logic [31:0] result_l_d;
logic [31:0] result_r_d;

always @(posedge clk) begin

    if (reset) begin

        auth        <= 1'b0;
        init        <= 1'b1;
        result_we_d <= 1'b0;
        result_rd_d <= 5'd0;
        result_l_d  <= 32'd0;
        result_r_d  <= 32'd0;
    end
    else begin

        // vcr: AUTH = 1 si la candidata coincide con la contraseña; si no, 0
        if (exec && is_vcr)
            auth <= pwd_match;

        // setpwd cierra el provisionamiento
        if (exec && is_setpwd)
            init <= 1'b0;

        result_we_d <= exec && (is_fsl || is_fsli);
        result_rd_d <= rd;
        result_l_d  <= round_l;
        result_r_d  <= round_r;
    end
end

assign wb_we     = result_we_d;
assign wb_rd     = result_rd_d;
assign wb_data_l = result_l_d;
assign wb_data_r = result_r_d;


// ============================================================================
// Mensajes (sólo en simulación)
// ============================================================================

`ifndef SYNTHESIS
always @(posedge clk) begin

    if (!reset && priv_fault) begin

        $display("[CRIPTO] excepción de privilegio: op=%b AUTH=%b INIT=%b",
                 crypto_op, auth, init);
    end
end
`endif

endmodule
