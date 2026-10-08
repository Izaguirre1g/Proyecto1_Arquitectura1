/*
================================================================================
 Módulo: memory

 Descripción:
 ------------------------------------------------------------------------------
 Memoria de datos del procesador VLIW.

 Es una memoria byte-addressable, little-endian, organizada como 16 384
 palabras de 32 bits (64 KB). El byte enable (be) indica qué bytes del dato
 se escriben:

     be = 4'b1111  escribe toda la palabra (32 bits)        — guardap
     be = 4'b0001  escribe el byte LSB (8 bits)             — guardab
     be = 4'b0010  escribe el segundo byte                 — guardab
     be = 4'b0100  escribe el tercer byte                  — guardab
     be = 4'b1000  escribe el byte MSB                     — guardab

 En little-endian el byte menos significativo se guarda en la dirección más
 baja (eff_addr + 0). El be se construye en la LSU como
     4'b0001 << eff_addr[1:0]

 Lectura: combinacional (mismo ciclo que la dirección). Esto mantiene la misma
 latencia de 1 ciclo entre EX y WB que la ALU, simplificando la integración en
 un pipeline VLIW sin forwarding.

 Tamaño: el parámetro SIZE_WORDS permite reducir el tamaño para testbenches;
 por defecto se mantienen los 16 384 palabras (= 64 KB) del enunciado.

================================================================================
*/

`default_nettype none


module memory #(

    parameter int SIZE_WORDS = 16384     // 64 KB / 4 B = 16384 palabras
) (

    input  logic         clk,
    input  logic         we,            // write enable
    input  logic [3:0]   be,            // byte enables (4 bytes por palabra)
    input  logic [31:0]  addr,          // dirección byte-addressable
    input  logic [31:0]  wdata,         // dato a escribir

    output logic [31:0]  rdata          // dato leído (combinacional)
);


logic [31:0] mem [0:SIZE_WORDS-1];

logic [$clog2(SIZE_WORDS)-1:0] word_addr;

// Inicialización explícita (compatible con Icarus 12)
generate
    genvar gi;
    for (gi = 0; gi < SIZE_WORDS; gi = gi + 1) begin : g_mem_init
        initial mem[gi] = 32'b0;
    end
endgenerate


// Selección de palabra: divide la dirección byte-addressable por 4
assign word_addr = addr[$clog2(SIZE_WORDS)+1:2];


// ------------------------------------------------------------------
// Escritura síncrona (flanco positivo). Sólo se modifican los bytes cuyo
// be está activo.
// ------------------------------------------------------------------
always @(posedge clk) begin

    if (we) begin

        if (be[0]) mem[word_addr][ 7: 0] <= wdata[ 7: 0];
        if (be[1]) mem[word_addr][15: 8] <= wdata[15: 8];
        if (be[2]) mem[word_addr][23:16] <= wdata[23:16];
        if (be[3]) mem[word_addr][31:24] <= wdata[31:24];
    end
end


// ------------------------------------------------------------------
// Lectura combinacional (little-endian).
// ------------------------------------------------------------------
assign rdata = mem[word_addr];


endmodule