/*
================================================================================
 Módulo: decoder_crypto

 Descripción:
 ------------------------------------------------------------------------------
 Decoder de instrucciones criptográficas (slot 3 del bundle).

 Recibe la instrucción de 32 bits del slot CRIPTO y genera las señales de
 control para la unidad criptográfica (crypto_unit.sv):

   - Tipo = 7'b0000010 (TYPE_CRYPTO)
   - ID   = 0000 fsl, 0001 fsli, 0010 ell, 0011 vcr, 0100 camcon, 0101 setpwd

 Formatos (ISA_Proyecto.md, "Instrucciones tipo cripto"):

   fsl / fsli   tipo | id | LK [20:19] | RK  [18:17] | rd  [16:12] | r1  [11:7] | RSV
   ell          tipo | id | LK [20:19] | off [18:17] | rs1 [16:12] | rs2 [11:7] | RSV
   vcr          tipo | id | dir_cand [20:5]                         | RSV [4:0]
   camcon       tipo | id | dir      [20:5]                         | imm [4:0]
   setpwd       tipo | id | RSV      [20:5]                         | rs  [4:0]

 Lecturas del banco de registros (puertos 6 y 7 del regfile):

   fsl / fsli   rs_a = r1 (L), rs_b = r1 + 1 (R)
   ell          rs_a = rs1,    rs_b = rs2
   setpwd       rs_a = rs,     rs_b = x0
   vcr, camcon  no leen registros (rs_a = rs_b = x0)

 fsl y fsli escriben el par (rd, rd + 1); el resto no escribe registros. El
 ISA pide que rd y r1 sean pares a partir de x2: lo valida el ensamblador, el
 hardware no lo revisa.

 valid indica que el slot trae una de las 6 instrucciones cripto. Un NOP
 (0x00000000), otro tipo o un ID reservado (0110–1111) dejan valid = 0, y la
 unidad criptográfica no hace nada.

 Validación de privilegios (diagrama de organización: ESTADO -> ID):
     Con el ESTADO actual (auth = ESTADO[0], init = ESTADO[1]) se marca
     priv_fault = 1 si la instrucción no tiene permiso:

         fsl, fsli, ell, camcon   necesitan AUTH = 1
         setpwd                   necesita  INIT = 1
         vcr                      siempre permitida

     priv_fault viaja por ID/EX; en EX la unidad criptográfica no ejecuta la
     instrucción y top toma la excepción. ESTADO se escribe en WB, así que un
     vcr o setpwd del bundle N se ve aquí desde el bundle N + 3.

 Este módulo es combinacional.

================================================================================
*/

`include "isa_defs.sv"


module decoder_crypto(

    input  logic [31:0] instruction,

    // ESTADO actual (desde crypto_unit), para validar privilegios
    input  logic        auth,          // ESTADO[0]
    input  logic        init,          // ESTADO[1]

    // Salidas hacia ID/EX (cripto)
    output logic [3:0]  crypto_op,     // OP_FSL / OP_FSLI / OP_ELL / OP_VCR / OP_CAMCON / OP_SETPWD
    output logic [1:0]  lk,            // índice de llave en la bóveda (0–3)
    output logic [1:0]  rk,            // subllave (fsl/fsli) u offset (ell) dentro de la llave
    output logic [4:0]  rd,            // destino del par (L_out, R_out): rd y rd + 1
    output logic [4:0]  rs_a,          // lectura 6 del banco
    output logic [4:0]  rs_b,          // lectura 7 del banco
    output logic [15:0] addr,          // dirección de memoria (vcr, camcon)
    output logic [4:0]  imm,           // rotación de camcon (0–31)
    output logic        we,            // 1 si la instrucción escribe registros (fsl, fsli)
    output logic        valid,         // 1 si el slot trae una instrucción cripto
    output logic        priv_fault     // 1 si la instrucción no tiene permiso
);

logic [6:0] instr_type;
logic [3:0] id;


always @(*) begin

    // Valores por defecto: el slot está inactivo (NOP)
    crypto_op = 4'b0;
    lk        = 2'b0;
    rk        = 2'b0;
    rd        = 5'b0;
    rs_a      = 5'b0;
    rs_b      = 5'b0;
    addr      = 16'b0;
    imm       = 5'b0;
    we        = 1'b0;
    valid     = 1'b0;

    instr_type = instruction[31:25];
    id         = instruction[24:21];

    if (instr_type == TYPE_CRYPTO) begin

        case (id)

            // -----------------------------------------------------------------
            // Rondas Feistel4: leen el par (r1, r1 + 1) y escriben (rd, rd + 1)
            // -----------------------------------------------------------------
            OP_FSL, OP_FSLI: begin

                crypto_op = id;
                lk        = instruction[20:19];
                rk        = instruction[18:17];
                rd        = instruction[16:12];
                rs_a      = instruction[11:7];
                rs_b      = instruction[11:7] + 5'd1;
                we        = 1'b1;
                valid     = 1'b1;
            end

            // -----------------------------------------------------------------
            // ell: dos palabras de una llave desde rs1 y rs2
            // -----------------------------------------------------------------
            OP_ELL: begin

                crypto_op = id;
                lk        = instruction[20:19];
                rk        = instruction[18:17];      // off
                rs_a      = instruction[16:12];
                rs_b      = instruction[11:7];
                valid     = 1'b1;
            end

            // -----------------------------------------------------------------
            // vcr y camcon: dirección de memoria de 16 bits sin signo
            // -----------------------------------------------------------------
            OP_VCR: begin

                crypto_op = id;
                addr      = instruction[20:5];
                valid     = 1'b1;
            end

            OP_CAMCON: begin

                crypto_op = id;
                addr      = instruction[20:5];
                imm       = instruction[4:0];
                valid     = 1'b1;
            end

            // -----------------------------------------------------------------
            // setpwd: contraseña inicial desde rs
            // -----------------------------------------------------------------
            OP_SETPWD: begin

                crypto_op = id;
                rs_a      = instruction[4:0];
                valid     = 1'b1;
            end

            // IDs reservados (0110–1111): NOP
            default: begin

                valid = 1'b0;
            end
        endcase
    end
end


// ============================================================================
// Validación de privilegios con el ESTADO actual
// ============================================================================

logic needs_auth;

assign needs_auth = (crypto_op == OP_FSL) || (crypto_op == OP_FSLI) ||
                    (crypto_op == OP_ELL) || (crypto_op == OP_CAMCON);

assign priv_fault = valid && ((needs_auth && !auth) || ((crypto_op == OP_SETPWD) && !init));

endmodule
