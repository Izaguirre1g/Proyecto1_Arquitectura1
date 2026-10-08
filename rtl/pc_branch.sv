/*
================================================================================
 Módulo: pc_branch

 Descripción:
 ------------------------------------------------------------------------------
 Wrapper sobre el Program Counter básico (rtl/pc.sv) que añade soporte para
 los saltos del BRU.

 Comportamiento en cada flanco positivo del reloj:

     reset         pc_out <= 0
     branch_flush  pc_out <= target_pc        (destino del salto)
     default       pc_out <= pc_out + 16      (siguiente bundle)

 El incremento por bundle (16 bytes) coincide con el pc.sv original: cada
 bundle del ISA mide exactamente 128 bits = 16 bytes.

 Las señales branch_flush y target_pc provienen del módulo BRU
 (rtl/bru.sv). El control del pipeline (rtl/cpu_top.sv) las conecta a este
 contador. Cuando branch_flush = 1, el control debe además invalidar los
 dos bundles que están en IF e ID (penalización de 2 ciclos).

================================================================================
*/

`default_nettype none


module pc_branch(

    input  logic         clk,
    input  logic         reset,

    input  logic         branch_flush,
    input  logic [31:0]  target_pc,

    output logic [31:0]  pc_out
);


always @(posedge clk) begin

    if (reset)
        pc_out <= 32'b0;
    else if (branch_flush)
        pc_out <= target_pc;
    else
        pc_out <= pc_out + 32'd16;
end


endmodule