/*
================================================================================
 Módulo: pc_branch

 Descripción:
 ------------------------------------------------------------------------------
 Program Counter del procesador, con soporte para los saltos del BRU y para
 las excepciones de la unidad criptográfica.

 Comportamiento en cada flanco positivo del reloj:

     reset         pc_out <= 0
     branch_flush  pc_out <= target_pc        (destino del salto)
     default       pc_out <= pc_out + BUNDLE_BYTES   (siguiente bundle, 16 bytes)

 Cada bundle del ISA mide exactamente BUNDLE_W = 128 bits = 16 bytes.

 rtl/top.sv conecta branch_flush y target_pc al cambio de flujo: un salto
 tomado del BRU (rtl/bru.sv) o una excepción de privilegio (target_pc =
 TRAP_VECTOR). En ese caso el control además invalida los dos bundles que
 están en IF e ID (penalización de 2 ciclos).

================================================================================
*/

`default_nettype none
`include "isa_defs.sv"


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
        pc_out <= pc_out + BUNDLE_BYTES;
end


endmodule