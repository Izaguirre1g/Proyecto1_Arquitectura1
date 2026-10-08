/*
================================================================================
 Módulo: cpu_top

 Descripción:
 ------------------------------------------------------------------------------
 Módulo superior del procesador VLIW.

 Pipeline IF / ID / EX / WB (4 etapas, 3 registros de segmentación):
     FETCH  →  IF/ID  →  ID (dispatch + decode)  →  ID/EX  →  EX
                                                                  ↓
                                                                  EX/WB
                                                                  ↓
                                                                  WB → banco de registros

 Slots del bundle (fijos):
     slot 0 = ALU       (suma, resta, AND, OR, XOR, shifts, comparaciones,
                          instrucciones tipo registro y tipo inmediato)
     slot 1 = LSU       (guardap, guardab, cargai, cargabai)
     slot 2 = BRU       (igualsi, igualno, menora, mayoroigual, sye)
     slot 3 = CRIPTO    (fsl, fsli, ell, vcr, camcon, setpwd — Dylan)

 Banco de registros (rtl/regfile.sv): 8 lecturas (2 por slot) y 5 escrituras.
 Memoria de datos (rtl/memory.sv): 64 KB byte-addressable little-endian,
                                  conectada directamente a la LSU.

 Saltos:
     El BRU produce branch_flush + target_pc. Esas señales se conectan a:
         - fetch.flush_in            (descarta el bundle que se va a fetchear)
         - pipeline_if_id.flush_in   (descarta el bundle en IF/ID)
         - pc_branch.branch_flush    (carga el PC con target_pc)
     Penalización: 2 ciclos (los dos bundles detrás del salto se descartan).
     Sin forwarding ni scoreboarding entre bundles (regla del proyecto).

================================================================================
*/

`include "isa_defs.sv"


module cpu_top(

    input  logic         clk,
    input  logic         reset,

    output logic [31:0]  debug_result,
    output logic [4:0]   debug_rd,
    output logic         debug_write

);


// =============================================================================
// Wires globales
// =============================================================================

// PC e instruction memory
logic [31:0]  pc;
logic [127:0] instruction_bundle;

// FETCH → IF/ID
logic [31:0]  fetch_pc;
logic [127:0] fetch_bundle;
logic         fetch_valid;
logic         branch_flush;     // del BRU, sirve para fetch, IF/ID y pc_branch

// IF/ID → ID (dispatch)
logic [31:0]  id_pc;
logic [127:0] id_bundle;
logic         id_valid;

// ID (dispatch) → 4 slots
logic [31:0]  slot0_instr, slot1_instr, slot2_instr, slot3_instr;
logic         dispatch_valid;

// Banco de registros (compartido entre los 4 slots)
logic [7:0][4:0]  reg_raddr;
logic [7:0][31:0] reg_rdata;

// Decoders slot 0 (ALU)
logic [3:0]  alu_op;
logic [4:0]  alu_rd;
logic [10:0] alu_imm;
logic        alu_use_imm;
logic [4:0]  alu_rs1, alu_rs2;
logic [31:0] alu_rs1_data, alu_rs2_data;

// Decoders slot 1 (LSU)
logic [3:0]  lsu_op;
logic [4:0]  lsu_rd;
logic [10:0] lsu_imm;
logic        lsu_we;
logic [4:0]  lsu_rs1, lsu_rs2;
logic [31:0] lsu_rs1_data, lsu_rs2_data;

// Decoders slot 2 (BRU)
logic [3:0]  bru_op;
logic [4:0]  bru_rd;
logic [10:0] bru_br_imm;
logic [15:0] bru_jmp_imm;
logic        bru_is_branch;
logic        bru_is_jump;
logic        bru_we;
logic [4:0]  bru_rs1, bru_rs2;
logic [31:0] bru_rs1_data, bru_rs2_data;

// ID/EX
logic        id_ex_valid;
logic [3:0]  ex_alu_op;
logic [4:0]  ex_alu_rd;
logic [10:0] ex_alu_imm;
logic        ex_alu_use_imm;
logic [3:0]  ex_lsu_op;
logic [4:0]  ex_lsu_rd;
logic [10:0] ex_lsu_imm;
logic        ex_lsu_we;
logic [3:0]  ex_bru_op;
logic [4:0]  ex_bru_rd;
logic [10:0] ex_bru_br_imm;
logic [15:0] ex_bru_jmp_imm;
logic        ex_bru_is_branch;
logic        ex_bru_is_jump;
logic        ex_bru_we;

// EX - ALU
logic [31:0] ex_operand_a;
logic [31:0] ex_operand_b;
logic [31:0] alu_result;

// EX - LSU
logic        mem_we;
logic [3:0]  mem_be;
logic [31:0] mem_addr;
logic [31:0] mem_wdata;
logic [31:0] mem_rdata;
logic        lsu_we_d;
logic [4:0]  lsu_rd_d;
logic [31:0] lsu_data_d;

// EX - BRU
logic [31:0] ex_pc_from_id_ex;
logic [31:0] ex_pc;
logic        bru_branch_flush;
logic [31:0] bru_target_pc;
logic        bru_link_we_d;
logic [4:0]  bru_link_rd_d;
logic [31:0] bru_link_value_d;

// EX/WB → WB
logic [4:0]       wb_we;
logic [4:0][4:0]  wb_waddr;
logic [4:0][31:0] wb_wdata;
logic             wb_conflict;


// =============================================================================
// PC + Memoria de instrucciones
// =============================================================================

instruction_memory IMEM(
    .address(pc),
    .instruction_bundle(instruction_bundle)
);

pc_branch PC_BRANCH (
    .clk(clk),
    .reset(reset),
    .branch_flush(branch_flush),
    .target_pc(bru_target_pc),
    .pc_out(pc)
);


// =============================================================================
// FETCH
// =============================================================================

fetch FETCH (
    .clk(clk),
    .reset(reset),
    .pc(pc),
    .instruction_bundle(instruction_bundle),
    .flush_in(branch_flush),
    .pc_out(fetch_pc),
    .bundle_out(fetch_bundle),
    .valid_out(fetch_valid)
);


// =============================================================================
// IF / ID
// =============================================================================

pipeline_if_id IF_ID (
    .clk(clk),
    .reset(reset),
    .pc_in(fetch_pc),
    .bundle_in(fetch_bundle),
    .valid_in(fetch_valid),
    .flush_in(branch_flush),
    .pc_out(id_pc),
    .bundle_out(id_bundle),
    .valid_out(id_valid)
);


// =============================================================================
// DISPATCH VLIW (4 slots fijos)
// =============================================================================

dispatch DISPATCH (
    .bundle_in(id_bundle),
    .valid_in(id_valid),
    .slot0_instr(slot0_instr),
    .slot1_instr(slot1_instr),
    .slot2_instr(slot2_instr),
    .slot3_instr(slot3_instr),
    .valid_out(dispatch_valid)
);


// =============================================================================
// ID: decoder_alu (slot 0)
// =============================================================================

decoder_alu DECODER_ALU (
    .instruction(slot0_instr),
    .alu_op(alu_op),
    .rd(alu_rd),
    .rs1(alu_rs1),
    .rs2(alu_rs2),
    .imm(alu_imm),
    .use_imm(alu_use_imm)
);

assign ex_operand_a = alu_rs1_data;
assign ex_operand_b = alu_use_imm ? {{21{alu_imm[10]}}, alu_imm} : alu_rs2_data;


// =============================================================================
// ID: decoder_lsu (slot 1)
// =============================================================================

decoder_lsu DECODER_LSU (
    .instruction(slot1_instr),
    .lsu_op(lsu_op),
    .rd(lsu_rd),
    .rs1(lsu_rs1),
    .rs2(lsu_rs2),
    .imm(lsu_imm),
    .we(lsu_we)
);


// =============================================================================
// ID: decoder_bru (slot 2)
// =============================================================================

decoder_bru DECODER_BRU (
    .instruction(slot2_instr),
    .bru_op(bru_op),
    .rd(bru_rd),
    .rs1(bru_rs1),
    .rs2(bru_rs2),
    .br_imm(bru_br_imm),
    .jmp_imm(bru_jmp_imm),
    .is_branch(bru_is_branch),
    .is_jump(bru_is_jump),
    .we(bru_we)
);


// =============================================================================
// Banco de registros (8 lecturas × 5 escrituras, compartido entre slots)
//
//   Lectura   0, 1   slot 0 ALU     rf1, rf2
//             2, 3   slot 1 LSU     rf1 (base), rf2 (dato de store)
//             4, 5   slot 2 BRU     rf1, rf2 de las comparaciones
//             6, 7   slot 3 CRIPTO  (Dylan)
//
//   Escritura 0..4  slot 0..4 lógica     (ver wb.sv)
// =============================================================================

assign reg_raddr = {
    5'd0, 5'd0,            // slot 3 CRIPTO (pendiente Dylan)
    bru_rs2, bru_rs1,      // slot 2 BRU
    lsu_rs2, lsu_rs1,      // slot 1 LSU
    alu_rs2, alu_rs1       // slot 0 ALU
};

assign alu_rs1_data = reg_rdata[0];
assign alu_rs2_data = reg_rdata[1];
assign lsu_rs1_data = reg_rdata[2];
assign lsu_rs2_data = reg_rdata[3];
assign bru_rs1_data = reg_rdata[4];
assign bru_rs2_data = reg_rdata[5];

regfile REGFILE (
    .clk(clk),
    .reset(reset),
    .raddr(reg_raddr),
    .rdata(reg_rdata),
    .we(wb_we),
    .waddr(wb_waddr),
    .wdata(wb_wdata)
);


// =============================================================================
// ID / EX (registros de segmentación)
// =============================================================================

pipeline_id_ex ID_EX (
    .clk(clk),
    .reset(reset),

    // ALU
    .alu_op(alu_op),
    .alu_rd(alu_rd),
    .alu_operand_a(alu_rs1_data),
    .alu_operand_b(alu_rs2_data),
    .alu_imm(alu_imm),
    .alu_use_imm(alu_use_imm),

    // LSU
    .lsu_op(lsu_op),
    .lsu_rd(lsu_rd),
    .lsu_imm(lsu_imm),
    .lsu_we(lsu_we),

    // BRU
    .bru_op(bru_op),
    .bru_rd(bru_rd),
    .bru_br_imm(bru_br_imm),
    .bru_jmp_imm(bru_jmp_imm),
    .bru_is_branch(bru_is_branch),
    .bru_is_jump(bru_is_jump),
    .bru_we(bru_we),

    .pc_in(id_pc),

    .valid_in(dispatch_valid),

    // Salidas
    .alu_op_out(ex_alu_op),
    .alu_rd_out(ex_alu_rd),
    .alu_operand_a_out(),          // sin uso (la ALU ya tiene operand_a/b directos)
    .alu_operand_b_out(),
    .alu_imm_out(ex_alu_imm),
    .alu_use_imm_out(ex_alu_use_imm),

    .lsu_op_out(ex_lsu_op),
    .lsu_rd_out(ex_lsu_rd),
    .lsu_imm_out(ex_lsu_imm),
    .lsu_we_out(ex_lsu_we),

    .bru_op_out(ex_bru_op),
    .bru_rd_out(ex_bru_rd),
    .bru_br_imm_out(ex_bru_br_imm),
    .bru_jmp_imm_out(ex_bru_jmp_imm),
    .bru_is_branch_out(ex_bru_is_branch),
    .bru_is_jump_out(ex_bru_is_jump),
    .bru_we_out(ex_bru_we),

    .pc_out(ex_pc_from_id_ex),

    // API vieja (alias): conectados a 0 para silenciar warnings
    .rd(5'd0),
    .operand_a(32'd0),
    .operand_b(32'd0),
    .imm(11'd0),
    .use_imm(1'b0),
    .rd_out(),
    .operand_a_out(),
    .operand_b_out(),
    .imm_out(),
    .use_imm_out(),

    .valid_out(id_ex_valid)
);


// =============================================================================
// EX - ALU (slot 0)
// =============================================================================

alu ALU (
    .alu_op(ex_alu_op),
    .operand_a(ex_operand_a),
    .operand_b(ex_operand_b),
    .result(alu_result)
);


// =============================================================================
// EX - LSU (slot 1) + memoria
// =============================================================================

lsu LSU (
    .clk(clk),
    .reset(reset),
    .valid_in(id_ex_valid),
    .lsu_op(ex_lsu_op),
    .rd(ex_lsu_rd),
    .imm(ex_lsu_imm),
    .rf1_data(lsu_rs1_data),    // base address
    .rf2_data(lsu_rs2_data),    // dato store
    .mem_we(mem_we),
    .mem_be(mem_be),
    .mem_addr(mem_addr),
    .mem_wdata(mem_wdata),
    .mem_rdata(mem_rdata),
    .wb_we(lsu_we_d),
    .wb_rd(lsu_rd_d),
    .wb_data(lsu_data_d)
);

memory #(.SIZE_WORDS(16384)) DMEM (
    .clk(clk),
    .we(mem_we),
    .be(mem_be),
    .addr(mem_addr),
    .wdata(mem_wdata),
    .rdata(mem_rdata)
);


// =============================================================================
// EX - BRU (slot 2)
// =============================================================================

// El PC del bundle en EX lo entrega pipeline_id_ex (lo captura del id_pc
// en ID y lo expone como ex_pc). El bru lo usa como base para calcular el
// target de los saltos condicionales y de sye.
assign ex_pc = ex_pc_from_id_ex;

bru BRU (
    .clk(clk),
    .reset(reset),
    .rf1_data(bru_rs1_data),
    .rf2_data(bru_rs2_data),
    .pc_current(ex_pc),
    .bru_op(ex_bru_op),
    .is_branch(ex_bru_is_branch),
    .is_jump(ex_bru_is_jump),
    .br_imm(ex_bru_br_imm),
    .jmp_imm(ex_bru_jmp_imm),
    .link_rd_in(ex_bru_rd),
    .branch_flush(bru_branch_flush),
    .target_pc(bru_target_pc),
    .link_we_d(bru_link_we_d),
    .link_rd_d(bru_link_rd_d),
    .link_value_d(bru_link_value_d)
);

// Branch flush al fetch, IF/ID y PC
assign branch_flush = bru_branch_flush;


// =============================================================================
// EX / WB (solo ALU por ahora; LSU y BRU escriben directo desde sus
// registros internos para igualar la latencia).
// =============================================================================

// ALU pasa por pipeline_ex_wb (igual que en el código del equipo)
logic        ex_wb_valid;
logic [4:0]  ex_wb_rd;
logic [31:0] ex_wb_alu_result;

pipeline_ex_wb EX_WB (
    .clk(clk),
    .reset(reset),
    .result_in(alu_result),
    .rd_in(ex_alu_rd),
    .valid_in(id_ex_valid),
    .result_out(ex_wb_alu_result),
    .rd_out(ex_wb_rd),
    .valid_out(ex_wb_valid)
);


// =============================================================================
// WB: ordena los 5 puertos de escritura y maneja conflictos
// =============================================================================

wb WB (
    .alu_we(ex_wb_valid),
    .alu_rd(ex_wb_rd),
    .alu_data(ex_wb_alu_result),

    .lsu_we(lsu_we_d),
    .lsu_rd(lsu_rd_d),
    .lsu_data(lsu_data_d),

    .bru_we(bru_link_we_d),
    .bru_rd(bru_link_rd_d),
    .bru_data(bru_link_value_d),

    .crypto_we(1'b0),
    .crypto_rd(5'd0),
    .crypto_data_l(32'd0),
    .crypto_data_r(32'd0),

    .we(wb_we),
    .waddr(wb_waddr),
    .wdata(wb_wdata),
    .conflict(wb_conflict)
);


// =============================================================================
// Debug
// =============================================================================

assign debug_result = wb_wdata[0];
assign debug_rd     = wb_waddr[0];
assign debug_write  = wb_we[0];


endmodule