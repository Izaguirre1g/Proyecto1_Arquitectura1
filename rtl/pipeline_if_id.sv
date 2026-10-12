/*
================================================================================
 Módulo: pipeline_if_id

 Descripción:
 ------------------------------------------------------------------------------
 Registro de pipeline entre Instruction Fetch (IF) e Instruction Decode (ID).
 Almacena el bundle, el PC asociado y la señal de validez durante un ciclo.

 Cuando el BRU produce un salto (branch_flush), los dos bundles que ya
 están en IF/ID deben descartarse para no ejecutar las instrucciones que
 están detrás del salto. Eso se hace con la entrada flush_in:

     flush_in = 1  →  valid_out = 0, bundle_out = 0 (NOP equivalente)

 Esta señal llega una vez que el BRU calculó el branch (ciclo N) y debe
 afectar el bundle que está en IF/ID en el ciclo N+1. La conexión exacta
 (combinacional desde el BRU o registrada) la hace top.sv.

================================================================================
*/

`default_nettype none


`include "isa_defs.sv"

module pipeline_if_id(

    input  logic         clk,
    input  logic         reset,

    input  logic [BUNDLE_W-1:0] bundle_in,
    input  logic [31:0]  pc_in,
    input  logic         valid_in,
    input  logic         flush_in,        // 1 = descartar este bundle (branch en EX)

    output logic [BUNDLE_W-1:0] bundle_out,
    output logic [31:0]  pc_out,
    output logic         valid_out

);


always @(posedge clk) begin

    if (reset) begin

        bundle_out <= '0;
        pc_out     <= 32'b0;
        valid_out  <= 1'b0;
    end
    else begin

        bundle_out <= flush_in ? '0 : bundle_in;
        pc_out     <= flush_in ? 32'b0  : pc_in;
        valid_out  <= flush_in ? 1'b0   : valid_in;
    end
end


endmodule