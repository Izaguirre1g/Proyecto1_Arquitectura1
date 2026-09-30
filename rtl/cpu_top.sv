/*
================================================================================
 Módulo: cpu_top

 Descripción:
 ------------------------------------------------------------------------------
 Módulo superior del procesador.

 Integra las etapas principales del pipeline:

 FETCH
 IF/ID
 ID
 ID/EX
 EX
 EX/WB
 WB

 Esta primera versión implementa únicamente el camino ALU.

================================================================================
*/


module cpu_top(

    input logic clk,

    input logic reset,


    output logic [31:0] debug_result,

    output logic [4:0] debug_rd,

    output logic debug_write

    
);

logic [31:0] pc;
logic [127:0] instruction_bundle;

instruction_memory IMEM(

    .address(pc),

    .instruction_bundle(instruction_bundle)

);

program_counter PC_REG(

    .clk(clk),

    .reset(reset),

    .pc_out(pc)

);

// =====================================
// FETCH
// =====================================

logic [31:0] fetch_pc;

logic [127:0] fetch_bundle;

logic fetch_valid;



fetch FETCH (

    .clk(clk),

    .reset(reset),

    .pc(pc),

    .instruction_bundle(instruction_bundle),

    .pc_out(fetch_pc),

    .bundle_out(fetch_bundle),

    .valid_out(fetch_valid)

);



// =====================================
// IF / ID
// =====================================


logic [31:0] id_pc;

logic [127:0] id_bundle;

logic id_valid;



pipeline_if_id IF_ID (

    .clk(clk),

    .reset(reset),

    .pc_in(fetch_pc),

    .bundle_in(fetch_bundle),

    .valid_in(fetch_valid),


    .pc_out(id_pc),

    .bundle_out(id_bundle),

    .valid_out(id_valid)

);



// =====================================
// Por ahora usamos slot 0
// =====================================


logic [31:0] instruction;



assign instruction = id_bundle[31:0];



// =====================================
// ID
// =====================================


logic [3:0] alu_op;

logic [31:0] operand_a;

logic [31:0] operand_b;

logic [4:0] rd;

logic [10:0] imm;

logic use_imm;



logic [4:0] wb_rd;

logic [31:0] wb_data;

logic wb_enable;



id_stage ID (

    .clk(clk),

    .reset(reset),

    .instruction(instruction),


    .wb_rd(wb_rd),

    .wb_data(wb_data),

    .wb_enable(wb_enable),


    .alu_op(alu_op),

    .operand_a(operand_a),

    .operand_b(operand_b),

    .rd(rd),

    .imm(imm),

    .use_imm(use_imm)

);



// =====================================
// ID / EX
// =====================================


logic [3:0] ex_alu_op;

logic [31:0] ex_operand_a;

logic [31:0] ex_operand_b;

logic [4:0] ex_rd;

logic ex_valid;



pipeline_id_ex ID_EX (

    .clk(clk),

    .reset(reset),

    .alu_op(alu_op),

    .rd(rd),

    .operand_a(operand_a),

    .operand_b(operand_b),

    .imm(imm),

    .use_imm(use_imm),

    .valid_in(id_valid),


    .alu_op_out(ex_alu_op),

    .rd_out(ex_rd),

    .operand_a_out(ex_operand_a),

    .operand_b_out(ex_operand_b),

    .imm_out(),

    .use_imm_out(),

    .valid_out(ex_valid)

);



// =====================================
// EX
// =====================================


logic [31:0] alu_result;



ex_stage EX (

    .alu_op(ex_alu_op),

    .operand_a(ex_operand_a),

    .operand_b(ex_operand_b),

    .rd(ex_rd),

    .valid_in(ex_valid),

    .result(alu_result)

);



// =====================================
// EX / WB
// =====================================


logic [31:0] wb_result;

logic [4:0] wb_rd_pipe;

logic wb_valid;



pipeline_ex_wb EX_WB (

    .clk(clk),

    .reset(reset),

    .result_in(alu_result),

    .rd_in(ex_rd),

    .valid_in(ex_valid),

    .result_out(wb_result),

    .rd_out(wb_rd_pipe),

    .valid_out(wb_valid)

);



// =====================================
// WB
// =====================================


wb WB (

    .result_in(wb_result),

    .rd_in(wb_rd_pipe),

    .valid_in(wb_valid),

    .write_data(wb_data),

    .rd_out(wb_rd),

    .reg_write(wb_enable)


);
    assign debug_result = wb_data;

    assign debug_rd = wb_rd;

    assign debug_write = wb_enable;


endmodule