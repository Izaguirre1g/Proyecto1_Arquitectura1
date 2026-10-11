/*
================================================================================
 Archivo: isa_defs.sv

 Descripción:
 ------------------------------------------------------------------------------
 Definiciones constantes del ISA del procesador VLIW.

 Contiene:
 - Tipos de instrucción.
 - Identificadores de operación.
 - Códigos internos usados por la ALU.

 Este archivo será incluido por los módulos de decodificación para evitar
 valores numéricos repetidos.
================================================================================
*/
`ifndef ISA_DEFS_SV
`define ISA_DEFS_SV
// ============================================================================
// Tipos de instrucción [31:25]
// ============================================================================

localparam logic [6:0] TYPE_STORE     = 7'b1001001;   // LSU (load/store)
localparam logic [6:0] TYPE_IMM       = 7'b1000000;
localparam logic [6:0] TYPE_BRU_JUMP  = 7'b1001011;   // sye (jump-and-link)
localparam logic [6:0] TYPE_BRU_COND  = 7'b1000001;   // igualsi, igualno, menora, mayoroigual
localparam logic [6:0] TYPE_REG       = 7'b1101010;
localparam logic [6:0] TYPE_CRYPTO    = 7'b0000010;
localparam logic [6:0] TYPE_NOP       = 7'b0000000;   // NOP por slot

// Alias usado por decoder_lsu
localparam logic [6:0] TYPE_LSU = TYPE_STORE;


// ============================================================================
// Operaciones tipo REGISTRO
// ID [24:21]
// ============================================================================

localparam logic [3:0] OP_SUM  = 4'b1000;
localparam logic [3:0] OP_RESTA = 4'b1001;
localparam logic [3:0] OP_CADER = 4'b1010;
localparam logic [3:0] OP_CIZQ  = 4'b1011;
localparam logic [3:0] OP_AND   = 4'b1100;
localparam logic [3:0] OP_OR    = 4'b1101;
localparam logic [3:0] OP_XOR   = 4'b1110;
localparam logic [3:0] OP_CDER  = 4'b1111;

localparam logic [3:0] OP_MRQ   = 4'b0101;
localparam logic [3:0] OP_MYQ   = 4'b0110;


// ============================================================================
// Operaciones tipo INMEDIATO
// ============================================================================

localparam logic [3:0] OP_SUMI   = 4'b0000;
localparam logic [3:0] OP_RESTAI = 4'b0001;
localparam logic [3:0] OP_CIZQI  = 4'b0010;
localparam logic [3:0] OP_CDERI  = 4'b0011;
localparam logic [3:0] OP_CADERI = 4'b0100;
localparam logic [3:0] OP_XORI   = 4'b0101;
localparam logic [3:0] OP_ANDI   = 4'b0110;
localparam logic [3:0] OP_ORI    = 4'b0111;


// ============================================================================
// Operaciones tipo LSU (load / store)
// ID [24:21]
// ============================================================================

localparam logic [3:0] OP_GUARDAP  = 4'b0000;   // M[rf1+off] = rf2       (palabra 32 bits)
localparam logic [3:0] OP_GUARDAB  = 4'b0001;   // M[rf1+off] = rf2[7:0]  (byte)
localparam logic [3:0] OP_CARGAI  = 4'b1000;   // rg = M[rf1+off]        (palabra 32 bits)
localparam logic [3:0] OP_CARGABAI= 4'b1001;   // rg = M[rf1+off] (byte, sign-extend)


// ============================================================================
// Operaciones tipo BRU condicional (tipo 7'b1000001)
// ID [24:21]
// ============================================================================

localparam logic [3:0] OP_IGUALSI    = 4'b0001;  // if (rf1 == rf2) PC += off
localparam logic [3:0] OP_IGUALNO    = 4'b0010;  // if (rf1 != rf2) PC += off
localparam logic [3:0] OP_MENORA     = 4'b0100;  // if (rf1 <  rf2) PC += off   (signed)
localparam logic [3:0] OP_MAYOROIGUAL= 4'b1000;  // if (rf1 >= rf2) PC += off   (signed)


// ============================================================================
// Operaciones tipo BRU jump (sye, tipo 7'b1001011)
// ID [24:21]
// ============================================================================

localparam logic [3:0] OP_SYE = 4'b0000;        // rg = PC + 4; PC = PC + offset


// ============================================================================
// Operaciones tipo CRIPTO (tipo 7'b0000010)
// ID [24:21]
// ============================================================================

localparam logic [3:0] OP_FSL    = 4'b0000;     // (L, R) = ronda Feistel4 directa
localparam logic [3:0] OP_FSLI   = 4'b0001;     // (L, R) = ronda Feistel4 inversa
localparam logic [3:0] OP_ELL    = 4'b0010;     // bóveda[LK][off..off+1] = (rs1, rs2)
localparam logic [3:0] OP_VCR    = 4'b0011;     // AUTH = (M[dir_cand] == contraseña)
localparam logic [3:0] OP_CAMCON = 4'b0100;     // contraseña y M[dir] rotan imm bits
localparam logic [3:0] OP_SETPWD = 4'b0101;     // contraseña = rs (sólo con INIT = 1)


// ============================================================================
// Operaciones internas de ALU
// (estas son nuestras señales hacia la unidad ALU)
// ============================================================================

localparam logic [3:0] ALU_ADD  = 4'd0;
localparam logic [3:0] ALU_SUB  = 4'd1;
localparam logic [3:0] ALU_SLL  = 4'd2;
localparam logic [3:0] ALU_SRL  = 4'd3;
localparam logic [3:0] ALU_SRA  = 4'd4;
localparam logic [3:0] ALU_XOR  = 4'd5;
localparam logic [3:0] ALU_AND  = 4'd6;
localparam logic [3:0] ALU_OR   = 4'd7;
localparam logic [3:0] ALU_LT   = 4'd8;
localparam logic [3:0] ALU_GT   = 4'd9;

`endif