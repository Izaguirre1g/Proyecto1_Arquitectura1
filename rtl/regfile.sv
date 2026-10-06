/*
================================================================================
 Módulo: regfile

 Descripción:
 ------------------------------------------------------------------------------
 Banco de registros de propósito general del procesador VLIW.

 Contiene los 32 registros de 32 bits definidos por el ISA (x0–x31). Es un
 banco multipuerto porque los cuatro slots de un bundle leen sus operandos en
 el mismo ciclo (etapa ID) y varias unidades pueden escribir su resultado en
 el mismo ciclo (etapa WB).

 Características:
 ------------------------------------------------------------------------------
 - NUM_REGS registros de XLEN bits (32 × 32 por defecto).
 - x0 siempre se lee como 0 y las escrituras hacia x0 se descartan.
 - NUM_READ_PORTS puertos de lectura combinacional.
 - NUM_WRITE_PORTS puertos de escritura en el flanco positivo del reloj.
 - Reset síncrono: todos los registros vuelven a 0.

 Configuración por defecto (bundle completo, 8 lecturas / 5 escrituras):
 ------------------------------------------------------------------------------
   Lectura    0, 1   slot 0  ALU     rf1, rf2
              2, 3   slot 1  LSU     rf1 (base), rf2 (dato de guardap/guardab)
              4, 5   slot 2  BRU     rf1, rf2 (comparaciones de control)
              6, 7   slot 3  CRIPTO  par fuente (r1, r1+1) o (rs1, rs2) de ell

   Escritura  0      slot 0  ALU     rg
              1      slot 1  LSU     rg de cargai / cargabai
              2      slot 2  BRU     rg de sye (dirección de retorno)
              3      slot 3  CRIPTO  rd   (L_out de fsl / fsli)
              4      slot 3  CRIPTO  rd+1 (R_out de fsl / fsli)

 El orden de los puertos de escritura coincide con las salidas del módulo wb.
 Un módulo puede instanciar menos puertos mediante los parámetros
 NUM_READ_PORTS y NUM_WRITE_PORTS. cpu_top lo instancia con la configuración
 completa.

 Temporización y dependencias de datos:
 ------------------------------------------------------------------------------
 La lectura es combinacional y la escritura ocurre en el flanco positivo, al
 final del ciclo de WB. El banco NO tiene bypass interno (write-first): una
 lectura en el mismo ciclo de la escritura entrega el valor anterior. Esto es
 intencional, porque el enunciado prohíbe el forwarding automático entre
 bundles.

 Con el pipeline IF/ID/EX/WB, el valor que escribe el bundle N lo puede leer
 en ID el bundle N+3 o uno posterior. Los bundles N+1 y N+2 todavía leen el
 valor anterior. El ensamblador o compilador debe respetar esa distancia
 insertando bundles independientes o NOP.

 Conflictos de escritura:
 ------------------------------------------------------------------------------
 Si dos puertos habilitados escriben el mismo registro en el mismo ciclo, gana
 el puerto de índice mayor (CRIPTO > BRU > LSU > ALU). Ese caso es un error de
 calendarización: wb lo señala con su salida conflict, pero el banco se
 comporta igual en todos los casos para que la simulación sea determinista.

================================================================================
*/

module regfile #(

    parameter int NUM_REGS        = 32,
    parameter int XLEN            = 32,
    parameter int NUM_READ_PORTS  = 8,
    parameter int NUM_WRITE_PORTS = 5,
    parameter int ADDR_W          = $clog2(NUM_REGS)

)(

    input logic clk,
    input logic reset,


    // Lectura

    input  logic [NUM_READ_PORTS-1:0][ADDR_W-1:0] raddr,
    output logic [NUM_READ_PORTS-1:0][XLEN-1:0]   rdata,


    // Escritura

    input logic [NUM_WRITE_PORTS-1:0]             we,
    input logic [NUM_WRITE_PORTS-1:0][ADDR_W-1:0] waddr,
    input logic [NUM_WRITE_PORTS-1:0][XLEN-1:0]   wdata

);

logic [XLEN-1:0] regs [NUM_REGS];


// Escritura de registros
//
// Los puertos se recorren en orden ascendente: si dos puertos escriben el
// mismo registro, la última asignación no bloqueante (puerto de índice mayor)
// es la que queda.

always @(posedge clk) begin

    if(reset) begin

        for(int r = 0; r < NUM_REGS; r++)
            regs[r] <= '0;
    end
    else begin

        for(int p = 0; p < NUM_WRITE_PORTS; p++)
            if(we[p] && waddr[p] != '0)
                regs[waddr[p]] <= wdata[p];
    end
end


// Lectura combinacional

genvar i;

generate
    for(i = 0; i < NUM_READ_PORTS; i++) begin : g_read

        assign rdata[i] = (raddr[i] == '0) ? '0 : regs[raddr[i]];
    end
endgenerate

endmodule
