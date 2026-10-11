/*
================================================================================
 Módulo: bru

 Descripción:
 ------------------------------------------------------------------------------
 Unidad de control de flujo (slot 2 del bundle).

 Instrucciones:
     Branches condicionales (TYPE_BRU_COND, is_branch = 1):
         OP_IGUALSI       if (rf1 == rf2)        PC += off (signed 11 bits)
         OP_IGUALNO       if (rf1 != rf2)        PC += off
         OP_MENORA        if (rf1 <  rf2) (s)    PC += off
         OP_MAYOROIGUAL   if (rf1 >= rf2) (s)    PC += off

     Jump (TYPE_BRU_JUMP, is_jump = 1):
         OP_SYE           rg = PC + 4; PC = PC + off (signed 16 bits)

 Sólo `sye` escribe en el regfile (rg = PC + 4 como dirección de retorno).
 Los branches condicionales sólo afectan al PC.

 Estrategia de saltos (modelo del proyecto, ver docs/simulation.md):
 ------------------------------------------------------------------------------
 El pipeline es IF/ID/EX/WB, sin forwarding ni scoreboarding. Cuando un
 branch condicional se toma o se ejecuta un `sye`, el control del pipeline
 (rtl/top.sv) debe:

     1. Invalidar los dos bundles que están en IF e ID (2 ciclos de penalización)
     2. Cargar el PC con la dirección calculada por este módulo (target_pc)
     3. Si es `sye`, registrar el link (PC + 4) para escribirlo en WB

 Salidas:
     branch_flush   1 si el branch se tomó o si es un jump (top lo usa
                    para hacer flush de IF e ID y cargar el PC con target_pc)
     target_pc      dirección destino del salto (PC + offset firmado)
     link_we_d      1 si hay que escribir el link en el siguiente ciclo (sye)
     link_rd_d      registro destino del link
     link_value_d   valor del link (= PC + 4)

 Las señales link_* están registradas un ciclo para coincidir con la latencia
 de EX→WB de la ALU y del load de la LSU.

================================================================================
*/

`include "isa_defs.sv"


module bru(

    // Clock y reset
    input  logic         clk,
    input  logic         reset,

    // Datos leídos del banco de registros (1 ciclo después de ID)
    input  logic [31:0] rf1_data,
    input  logic [31:0] rf2_data,

    // Contexto del bundle
    input  logic [31:0] pc_current,    // PC al inicio del bundle actual

    // Decodificación del slot BRU
    input  logic [3:0]  bru_op,        // ID operación
    input  logic        is_branch,     // 1 si tipo == TYPE_BRU_COND
    input  logic        is_jump,       // 1 si tipo == TYPE_BRU_JUMP

    // Offsets (signed)
    input  logic [10:0] br_imm,        // 11 bits signed (branch condicional)
    input  logic [15:0] jmp_imm,       // 16 bits signed (sye)

    // Destino del link (sye)
    input  logic [4:0]  link_rd_in,

    // Salidas hacia el control del pipeline (combinacionales)
    output logic        branch_flush,   // 1 si hay que invalidar IF/ID y saltar
    output logic [31:0] target_pc,     // destino del salto

    // Salidas hacia rtl/wb.sv (registradas 1 ciclo para coincidir con ALU)
    output logic        link_we_d,
    output logic [4:0]  link_rd_d,
    output logic [31:0] link_value_d
);


// ============================================================================
// Extensión de signo de los offsets
// ============================================================================

logic [31:0] br_off_sext;
logic [31:0] jmp_off_sext;

assign br_off_sext  = {{21{br_imm[10]}},  br_imm};
assign jmp_off_sext = {{16{jmp_imm[15]}}, jmp_imm};


// ============================================================================
// Comparación y decisión
// ============================================================================

logic        branch_taken;
logic [31:0] pc_branch_target;
logic        flush_now;

always @(*) begin

    branch_taken     = 1'b0;
    pc_branch_target = pc_current + 32'd16;   // default: siguiente bundle
    flush_now        = 1'b0;

    if (is_branch) begin

        case (bru_op)

            OP_IGUALSI:     branch_taken = (rf1_data == rf2_data);
            OP_IGUALNO:     branch_taken = (rf1_data != rf2_data);
            OP_MENORA:      branch_taken = ($signed(rf1_data) <  $signed(rf2_data));
            OP_MAYOROIGUAL: branch_taken = ($signed(rf1_data) >= $signed(rf2_data));

            default:        branch_taken = 1'b0;
        endcase

        if (branch_taken)
            pc_branch_target = pc_current + br_off_sext;

        flush_now = branch_taken;
    end
    else if (is_jump) begin

        pc_branch_target = pc_current + jmp_off_sext;
        flush_now        = 1'b1;     // sye siempre flushea
    end
end


// ============================================================================
// Salidas combinacionales del BRU
// ============================================================================

assign branch_flush = flush_now;
assign target_pc    = pc_branch_target;


// ============================================================================
// Link value: rg = PC + 4 (literal del ISA_Proyecto.md).
// Registrado un ciclo para llegar a WB en el momento correcto.
// ============================================================================

logic        link_we_next;
logic [4:0]  link_rd_next;
logic [31:0] link_value_next;

assign link_we_next   = is_jump;
assign link_rd_next   = link_rd_in;
assign link_value_next = pc_current + 32'd4;

always @(posedge clk) begin

    if (reset) begin

        link_we_d    <= 1'b0;
        link_rd_d    <= 5'd0;
        link_value_d <= 32'd0;
    end
    else begin

        link_we_d    <= link_we_next;
        link_rd_d    <= link_rd_next;
        link_value_d <= link_value_next;
    end
end


// ============================================================================
// Sanity checks (sólo en simulación)
// ============================================================================

`ifndef SYNTHESIS
always @(*) begin

    if (is_branch && is_jump) begin

        $display("[BRU] ERROR: is_branch e is_jump activos a la vez (opcode=%b)", bru_op);
    end
end
`endif

endmodule