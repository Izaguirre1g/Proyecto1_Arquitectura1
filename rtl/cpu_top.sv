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
// DISPATCH VLIW
// =====================================


logic [31:0] slot0_instr;

logic [31:0] slot1_instr;

logic [31:0] slot2_instr;

logic [31:0] slot3_instr;

logic dispatch_valid;



dispatch DISPATCH (

    .bundle_in(id_bundle),

    .valid_in(id_valid),


    .slot0_instr(slot0_instr),

    .slot1_instr(slot1_instr),

    .slot2_instr(slot2_instr),

    .slot3_instr(slot3_instr),


    .valid_out(dispatch_valid)

);

logic [31:0] instruction;
assign instruction = slot0_instr;

// =====================================
// ID
// =====================================


logic [3:0] alu_op;

logic [31:0] operand_a;

logic [31:0] operand_b;

logic [4:0] rd;

logic [10:0] imm;

logic use_imm;



logic [4:0] rs1;

logic [4:0] rs2;

logic [31:0] rs1_data;

logic [31:0] rs2_data;



id_stage ID (

    .instruction(instruction),


    .rs1(rs1),

    .rs2(rs2),

    .rs1_data(rs1_data),

    .rs2_data(rs2_data),


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

// Por ahora sólo el slot 0 (ALU) produce resultados. Las entradas de LSU, BRU
// y CRIPTO quedan en 0 hasta que se integren esas unidades.

logic [4:0] wb_we;

logic [4:0][4:0] wb_waddr;

logic [4:0][31:0] wb_wdata;

logic wb_conflict;


wb WB (

    .alu_we(wb_valid),
    .alu_rd(wb_rd_pipe),
    .alu_data(wb_result),

    .lsu_we(1'b0),
    .lsu_rd(5'd0),
    .lsu_data(32'd0),

    .bru_we(1'b0),
    .bru_rd(5'd0),
    .bru_data(32'd0),

    .crypto_we(1'b0),
    .crypto_rd(5'd0),
    .crypto_data_l(32'd0),
    .crypto_data_r(32'd0),

    .we(wb_we),
    .waddr(wb_waddr),
    .wdata(wb_wdata),

    .conflict(wb_conflict)

);

// =====================================
// REGISTER FILE
// =====================================

// Banco compartido por los 4 slots, con su configuración completa:
// 8 lecturas y 5 escrituras (ver regfile.sv).
//
//   Lectura   0, 1  slot 0 ALU     (conectado a ID)
//             2, 3  slot 1 LSU     (pendiente: Alejandro/Dylan)
//             4, 5  slot 2 BRU     (pendiente)
//             6, 7  slot 3 CRIPTO  (pendiente)
//
//   Escritura 0..4  salidas de wb (ALU, LSU, BRU, CRIPTO rd, CRIPTO rd+1)
//
// Las lecturas de las unidades aún no integradas quedan en x0 (siempre 0);
// al conectar cada decoder basta con reemplazar su par de direcciones y
// tomar sus datos de reg_rdata.

logic [7:0][4:0] reg_raddr;

logic [7:0][31:0] reg_rdata;


assign reg_raddr = {

    5'd0, 5'd0,     // slot 3 CRIPTO
    5'd0, 5'd0,     // slot 2 BRU
    5'd0, 5'd0,     // slot 1 LSU
    rs2,  rs1       // slot 0 ALU

};

assign rs1_data = reg_rdata[0];

assign rs2_data = reg_rdata[1];


regfile REGFILE (

    .clk(clk),

    .reset(reset),

    .raddr(reg_raddr),

    .rdata(reg_rdata),

    .we(wb_we),

    .waddr(wb_waddr),

    .wdata(wb_wdata)

);

    assign debug_result = wb_wdata[0];

    assign debug_rd = wb_waddr[0];

    assign debug_write = wb_we[0];


endmodule