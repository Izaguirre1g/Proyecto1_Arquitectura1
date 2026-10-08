/*
================================================================================
 Módulo: pipeline_id_ex

 Descripción:
 ------------------------------------------------------------------------------
 Registro de pipeline entre Instruction Decode (ID) y Execute (EX).

 Almacena las señales decodificadas de los 4 slots del bundle:

   Slot 0 - ALU: alu_op, alu_rd, alu_operand_a, alu_operand_b, alu_imm,
                  alu_use_imm
   Slot 1 - LSU: lsu_op, lsu_rd, lsu_imm, lsu_we
   Slot 2 - BRU: bru_op, bru_rd, bru_br_imm, bru_jmp_imm, bru_is_branch,
                  bru_is_jump, bru_we
   Slot 3 - CRIPTO: (gestionado por Dylan, no propagado en este módulo)

Esto se justifica porque cada slot tiene su propio decoder en ID y necesita su
propio conjunto de señales en EX. Mantenerlas separadas evita confusión y
permite que el resto del pipeline (cpu_top, wb, etc.) vea cada unidad de
forma independiente.

Funcionamiento en el flanco positivo:
   reset       → todos los registros a 0 (burbuja)
   !reset      → captura las señales de entrada y las propaga a EX

================================================================================
*/

`default_nettype none


module pipeline_id_ex(

    input  logic         clk,
    input  logic         reset,


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
    input  logic [3:0]   lsu_op,
    input  logic [4:0]   lsu_rd,
    input  logic [10:0]  lsu_imm,
    input  logic         lsu_we,

    output logic [3:0]   lsu_op_out,
    output logic [4:0]   lsu_rd_out,
    output logic [10:0]  lsu_imm_out,
    output logic         lsu_we_out,


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

    output logic [3:0]   bru_op_out,
    output logic [4:0]   bru_rd_out,
    output logic [10:0]  bru_br_imm_out,
    output logic [15:0]  bru_jmp_imm_out,
    output logic         bru_is_branch_out,
    output logic         bru_is_jump_out,
    output logic         bru_we_out,


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

    if (reset) begin

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
        lsu_op_out  <= 4'b0;
        lsu_rd_out  <= 5'b0;
        lsu_imm_out <= 11'b0;
        lsu_we_out  <= 1'b0;

        // BRU
        bru_op_out         <= 4'b0;
        bru_rd_out         <= 5'b0;
        bru_br_imm_out     <= 11'b0;
        bru_jmp_imm_out    <= 16'b0;
        bru_is_branch_out  <= 1'b0;
        bru_is_jump_out    <= 1'b0;
        bru_we_out         <= 1'b0;

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
        lsu_op_out  <= lsu_op;
        lsu_rd_out  <= lsu_rd;
        lsu_imm_out <= lsu_imm;
        lsu_we_out  <= lsu_we;

        // BRU
        bru_op_out         <= bru_op;
        bru_rd_out         <= bru_rd;
        bru_br_imm_out     <= bru_br_imm;
        bru_jmp_imm_out    <= bru_jmp_imm;
        bru_is_branch_out  <= bru_is_branch;
        bru_is_jump_out    <= bru_is_jump;
        bru_we_out         <= bru_we;

        valid_out <= valid_in;
        pc_out    <= pc_in;
    end
end


endmodule