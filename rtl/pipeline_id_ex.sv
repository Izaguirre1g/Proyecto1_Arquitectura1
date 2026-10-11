/*
================================================================================
 Módulo: pipeline_id_ex

 Descripción:
 ------------------------------------------------------------------------------
 Registro de pipeline entre Instruction Decode (ID) y Execute (EX).

 Almacena las señales decodificadas de los 4 slots del bundle:

   Slot 0 - ALU: alu_op, alu_rd, alu_operand_a, alu_operand_b, alu_imm,
                  alu_use_imm
   Slot 1 - LSU: lsu_valid, lsu_op, lsu_rd, lsu_imm, lsu_we,
                  lsu_operand_a (base), lsu_operand_b (dato de store)
   Slot 2 - BRU: bru_op, bru_rd, bru_br_imm, bru_jmp_imm, bru_is_branch,
                  bru_is_jump, bru_we, bru_operand_a, bru_operand_b
   Slot 3 - CRIPTO: crypto_valid, crypto_op, crypto_lk, crypto_rk, crypto_rd,
                     crypto_addr, crypto_imm, crypto_operand_a, crypto_operand_b

Esto se justifica porque cada slot tiene su propio decoder en ID y necesita su
propio conjunto de señales en EX. Mantenerlas separadas evita confusión y
permite que el resto del pipeline (top, wb, etc.) vea cada unidad de
forma independiente.

Los operandos leídos del banco de registros en ID también pasan por este
registro: todas las unidades de EX deben usar las salidas *_out, nunca las
lecturas del banco, porque éstas ya corresponden al bundle siguiente.

Funcionamiento en el flanco positivo:
   reset o flush → todos los registros a 0 (burbuja: NOP en los 4 slots)
   en otro caso  → captura las señales de entrada y las propaga a EX

flush lo activa top cuando un salto se toma en EX o cuando la unidad
criptográfica genera una excepción de privilegio: el bundle que está en ID en
ese ciclo se anula (no hay delay slots).

================================================================================
*/

`default_nettype none


module pipeline_id_ex(

    input  logic         clk,
    input  logic         reset,
    input  logic         flush,               // salto tomado en EX: anula el bundle de ID


    // -------------------------------------------------------------------------
    // Slot 0 - ALU
    // -------------------------------------------------------------------------
    input  logic [3:0]   alu_op,
    input  logic [4:0]   alu_rd,
    input  logic [31:0]  alu_operand_a,
    input  logic [31:0]  alu_operand_b,
    input  logic [10:0]  alu_imm,
    input  logic         alu_use_imm,

    output logic [3:0]   alu_op_out,
    output logic [4:0]   alu_rd_out,
    output logic [31:0]  alu_operand_a_out,
    output logic [31:0]  alu_operand_b_out,
    output logic [10:0]  alu_imm_out,
    output logic         alu_use_imm_out,


    // -------------------------------------------------------------------------
    // Slot 0 - ALU (API vieja: alias para compatibilidad con tb_pipeline_id_ex)
    // -------------------------------------------------------------------------
    input  logic [4:0]   rd,                  // alias de alu_rd
    input  logic [31:0]  operand_a,           // alias de alu_operand_a
    input  logic [31:0]  operand_b,           // alias de alu_operand_b
    input  logic [10:0]  imm,                 // alias de alu_imm
    input  logic         use_imm,             // alias de alu_use_imm

    output logic [4:0]   rd_out,              // alias de alu_rd_out
    output logic [31:0]  operand_a_out,       // alias de alu_operand_a_out
    output logic [31:0]  operand_b_out,       // alias de alu_operand_b_out
    output logic [10:0]  imm_out,             // alias de alu_imm_out
    output logic         use_imm_out,          // alias de alu_use_imm_out


    // -------------------------------------------------------------------------
    // Slot 1 - LSU
    // -------------------------------------------------------------------------
    input  logic         lsu_valid,           // el slot 1 trae una instrucción LSU
    input  logic [3:0]   lsu_op,
    input  logic [4:0]   lsu_rd,
    input  logic [10:0]  lsu_imm,
    input  logic         lsu_we,
    input  logic [31:0]  lsu_operand_a,       // base (rf1)
    input  logic [31:0]  lsu_operand_b,       // dato de guardap / guardab (rf2)

    output logic         lsu_valid_out,
    output logic [3:0]   lsu_op_out,
    output logic [4:0]   lsu_rd_out,
    output logic [10:0]  lsu_imm_out,
    output logic         lsu_we_out,
    output logic [31:0]  lsu_operand_a_out,
    output logic [31:0]  lsu_operand_b_out,


    // -------------------------------------------------------------------------
    // Slot 2 - BRU
    // -------------------------------------------------------------------------
    input  logic [3:0]   bru_op,
    input  logic [4:0]   bru_rd,
    input  logic [10:0]  bru_br_imm,
    input  logic [15:0]  bru_jmp_imm,
    input  logic         bru_is_branch,
    input  logic         bru_is_jump,
    input  logic         bru_we,
    input  logic [31:0]  bru_operand_a,       // rf1 de la comparación
    input  logic [31:0]  bru_operand_b,       // rf2 de la comparación

    output logic [3:0]   bru_op_out,
    output logic [4:0]   bru_rd_out,
    output logic [10:0]  bru_br_imm_out,
    output logic [15:0]  bru_jmp_imm_out,
    output logic         bru_is_branch_out,
    output logic         bru_is_jump_out,
    output logic         bru_we_out,
    output logic [31:0]  bru_operand_a_out,
    output logic [31:0]  bru_operand_b_out,


    // -------------------------------------------------------------------------
    // Slot 3 - CRIPTO
    // -------------------------------------------------------------------------
    input  logic         crypto_valid,        // el slot 3 trae una instrucción cripto
    input  logic [3:0]   crypto_op,
    input  logic [1:0]   crypto_lk,
    input  logic [1:0]   crypto_rk,           // subllave (fsl/fsli) u offset (ell)
    input  logic [4:0]   crypto_rd,
    input  logic [15:0]  crypto_addr,         // vcr / camcon
    input  logic [4:0]   crypto_imm,          // camcon
    input  logic [31:0]  crypto_operand_a,    // L, rs1 o rs
    input  logic [31:0]  crypto_operand_b,    // R o rs2

    output logic         crypto_valid_out,
    output logic [3:0]   crypto_op_out,
    output logic [1:0]   crypto_lk_out,
    output logic [1:0]   crypto_rk_out,
    output logic [4:0]   crypto_rd_out,
    output logic [15:0]  crypto_addr_out,
    output logic [4:0]   crypto_imm_out,
    output logic [31:0]  crypto_operand_a_out,
    output logic [31:0]  crypto_operand_b_out,


    // -------------------------------------------------------------------------
    // PC (para calcular saltos en EX y para debug)
    // -------------------------------------------------------------------------
    input  logic [31:0]  pc_in,
    output logic [31:0]  pc_out,


    // -------------------------------------------------------------------------
    // Validez
    // -------------------------------------------------------------------------
    input  logic         valid_in,
    output logic         valid_out

);


always @(posedge clk) begin

    if (reset || flush) begin

        // ALU
        alu_op_out        <= 4'b0;
        alu_rd_out        <= 5'b0;
        alu_operand_a_out <= 32'b0;
        alu_operand_b_out <= 32'b0;
        alu_imm_out       <= 11'b0;
        alu_use_imm_out   <= 1'b0;

        // ALU (API vieja: alias)
        rd_out        <= 5'b0;
        operand_a_out <= 32'b0;
        operand_b_out <= 32'b0;
        imm_out       <= 11'b0;
        use_imm_out   <= 1'b0;

        // LSU
        lsu_valid_out     <= 1'b0;
        lsu_op_out        <= 4'b0;
        lsu_rd_out        <= 5'b0;
        lsu_imm_out       <= 11'b0;
        lsu_we_out        <= 1'b0;
        lsu_operand_a_out <= 32'b0;
        lsu_operand_b_out <= 32'b0;

        // BRU
        bru_op_out         <= 4'b0;
        bru_rd_out         <= 5'b0;
        bru_br_imm_out     <= 11'b0;
        bru_jmp_imm_out    <= 16'b0;
        bru_is_branch_out  <= 1'b0;
        bru_is_jump_out    <= 1'b0;
        bru_we_out         <= 1'b0;
        bru_operand_a_out  <= 32'b0;
        bru_operand_b_out  <= 32'b0;

        // CRIPTO
        crypto_valid_out     <= 1'b0;
        crypto_op_out        <= 4'b0;
        crypto_lk_out        <= 2'b0;
        crypto_rk_out        <= 2'b0;
        crypto_rd_out        <= 5'b0;
        crypto_addr_out      <= 16'b0;
        crypto_imm_out       <= 5'b0;
        crypto_operand_a_out <= 32'b0;
        crypto_operand_b_out <= 32'b0;

        valid_out <= 1'b0;
        pc_out    <= 32'b0;
    end
    else begin

        // ALU
        alu_op_out        <= alu_op;
        alu_rd_out        <= alu_rd;
        alu_operand_a_out <= alu_operand_a;
        alu_operand_b_out <= alu_operand_b;
        alu_imm_out       <= alu_imm;
        alu_use_imm_out   <= alu_use_imm;

        // ALU (API vieja: alias)
        rd_out        <= rd;
        operand_a_out <= operand_a;
        operand_b_out <= operand_b;
        imm_out       <= imm;
        use_imm_out   <= use_imm;

        // LSU
        lsu_valid_out     <= lsu_valid;
        lsu_op_out        <= lsu_op;
        lsu_rd_out        <= lsu_rd;
        lsu_imm_out       <= lsu_imm;
        lsu_we_out        <= lsu_we;
        lsu_operand_a_out <= lsu_operand_a;
        lsu_operand_b_out <= lsu_operand_b;

        // BRU
        bru_op_out         <= bru_op;
        bru_rd_out         <= bru_rd;
        bru_br_imm_out     <= bru_br_imm;
        bru_jmp_imm_out    <= bru_jmp_imm;
        bru_is_branch_out  <= bru_is_branch;
        bru_is_jump_out    <= bru_is_jump;
        bru_we_out         <= bru_we;
        bru_operand_a_out  <= bru_operand_a;
        bru_operand_b_out  <= bru_operand_b;

        // CRIPTO
        crypto_valid_out     <= crypto_valid;
        crypto_op_out        <= crypto_op;
        crypto_lk_out        <= crypto_lk;
        crypto_rk_out        <= crypto_rk;
        crypto_rd_out        <= crypto_rd;
        crypto_addr_out      <= crypto_addr;
        crypto_imm_out       <= crypto_imm;
        crypto_operand_a_out <= crypto_operand_a;
        crypto_operand_b_out <= crypto_operand_b;

        valid_out <= valid_in;
        pc_out    <= pc_in;
    end
end


endmodule