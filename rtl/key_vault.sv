/*
================================================================================
 Módulo: key_vault

 Descripción:
 ------------------------------------------------------------------------------
 Bóveda de llaves (raíz de confianza) de la unidad criptográfica.

 Almacena:
     - NUM_KEYS llaves de 128 bits, cada una como 4 subllaves de 32 bits
       (una por ronda de Feistel4): keys[llave][subllave].
     - La contraseña maestra de 32 bits, usada por vcr para autenticar.

 La bóveda sólo se instancia dentro de crypto_unit y sólo tiene estos accesos:

     Lectura de subllave   subkey = keys[rd_key][rd_word]. Va únicamente a la
                           función de ronda de crypto_unit (fsl / fsli).
     Escritura de llave    ell: keys[wr_key][wr_word]     = wr_data0
                                keys[wr_key][wr_word + 1] = wr_data1
     Contraseña            setpwd: password = pwd_wdata
                           camcon: password = ROL(password, pwd_rot_amount)
     Comparación           pwd_match = (pwd_candidate == password), para vcr.

 Ni las llaves ni la contraseña tienen un camino hacia el banco de registros o
 hacia la memoria de datos: no existe un puerto que entregue la contraseña, y
 la subllave sólo se usa dentro del cálculo de la ronda.

 Reset:
     El reset borra la bóveda completa (llaves y contraseña) y deja la
     contraseña sin definir (pwd_set = 0). Así, reiniciar el procesador no
     permite recuperar llaves anteriores. Mientras pwd_set = 0, pwd_match es
     0 aunque la candidata sea 0: no se puede autenticar antes de setpwd.

 Temporización:
     Lecturas y comparación combinacionales. Escrituras en el flanco positivo
     (al final de la etapa EX de la instrucción), por lo que una instrucción
     del bundle siguiente ya ve el valor nuevo.

 ell usa wr_word y wr_word + 1 (módulo 4). El ISA sólo permite off = 0 u
 off = 2; esa restricción la valida el ensamblador.

================================================================================
*/

module key_vault #(

    parameter int NUM_KEYS      = 4,     // llaves de 128 bits
    parameter int WORDS_PER_KEY = 4,     // subllaves de 32 bits por llave
    parameter int KEY_W         = $clog2(NUM_KEYS),
    parameter int WORD_W        = $clog2(WORDS_PER_KEY)
) (

    input  logic              clk,
    input  logic              reset,

    // Lectura de subllave (ronda Feistel4)
    input  logic [KEY_W-1:0]  rd_key,
    input  logic [WORD_W-1:0] rd_word,
    output logic [31:0]       subkey,

    // Escritura de dos palabras de una llave (ell)
    input  logic              key_we,
    input  logic [KEY_W-1:0]  wr_key,
    input  logic [WORD_W-1:0] wr_word,
    input  logic [31:0]       wr_data0,          // -> keys[wr_key][wr_word]
    input  logic [31:0]       wr_data1,          // -> keys[wr_key][wr_word + 1]

    // Contraseña maestra
    input  logic              pwd_we,            // setpwd
    input  logic [31:0]       pwd_wdata,
    input  logic              pwd_rot,           // camcon
    input  logic [4:0]        pwd_rot_amount,

    // Comparación para vcr
    input  logic [31:0]       pwd_candidate,
    output logic              pwd_match,
    output logic              pwd_set            // 1 si ya se ejecutó setpwd
);


logic [31:0] keys [0:NUM_KEYS-1][0:WORDS_PER_KEY-1];
logic [31:0] password;

logic [WORD_W-1:0] wr_word_next;

assign wr_word_next = wr_word + 1'b1;


// Rotación circular a la izquierda de 32 bits
function automatic logic [31:0] rol32(input logic [31:0] x, input logic [4:0] r);

    return (x << r) | (x >> (6'd32 - r));
endfunction


// ============================================================================
// Escritura (flanco positivo) y reset síncrono
// ============================================================================

always @(posedge clk) begin

    if (reset) begin

        for (int k = 0; k < NUM_KEYS; k++)
            for (int w = 0; w < WORDS_PER_KEY; w++)
                keys[k][w] <= 32'b0;

        password <= 32'b0;
        pwd_set  <= 1'b0;
    end
    else begin

        if (key_we) begin

            keys[wr_key][wr_word]      <= wr_data0;
            keys[wr_key][wr_word_next] <= wr_data1;
        end

        if (pwd_we) begin

            password <= pwd_wdata;
            pwd_set  <= 1'b1;
        end
        else if (pwd_rot) begin

            password <= rol32(password, pwd_rot_amount);
        end
    end
end


// ============================================================================
// Lecturas (combinacionales)
// ============================================================================

assign subkey    = keys[rd_key][rd_word];
assign pwd_match = pwd_set && (pwd_candidate == password);


endmodule
