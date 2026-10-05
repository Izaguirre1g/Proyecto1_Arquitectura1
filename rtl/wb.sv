/*
================================================================================
 Módulo: wb

 Descripción:
 ------------------------------------------------------------------------------
 Etapa Write Back (WB) del pipeline.

 Recibe, desde el registro EX/WB, el resultado de cada unidad funcional del
 bundle y los ordena en los puertos de escritura del banco de registros
 (regfile). Es la única lógica que decide qué se escribe en los registros.

 Productores de resultados por slot (según el ISA):
 ------------------------------------------------------------------------------
   Puerto 0  slot 0  ALU     rg de las instrucciones tipo registro e inmediato
   Puerto 1  slot 1  LSU     rg de cargai / cargabai
   Puerto 2  slot 2  BRU     rg de sye (dirección de retorno)
   Puerto 3  slot 3  CRIPTO  rd   <- L_out de fsl / fsli
   Puerto 4  slot 3  CRIPTO  rd+1 <- R_out de fsl / fsli

 Las cuatro unidades pueden escribir en el mismo ciclo (cinco escrituras como
 máximo, porque la cripto escribe un par de 32 bits).

 Entradas por unidad:
 ------------------------------------------------------------------------------
 - <fu>_we:   la instrucción del slot es válida y escribe un registro. La
              unidad o su decoder lo deben poner en 0 cuando la instrucción no
              produce resultado (guardap, saltos condicionales, ell, vcr...),
              cuando el slot es NOP o cuando el bundle fue anulado.
 - <fu>_rd:   registro destino.
 - <fu>_data: dato a escribir.

 Reglas:
 ------------------------------------------------------------------------------
 - Una escritura hacia x0 no habilita su puerto (x0 es constante 0).
 - conflict = 1 si dos puertos habilitados escriben el mismo registro en el
   mismo ciclo. Es un error de calendarización del software. Si ocurre, el
   banco aplica una prioridad fija (gana el puerto de índice mayor) y este
   indicador permite detectarlo en simulación.

 Este módulo es completamente combinacional.

================================================================================
*/
module wb(

    // Slot 0 - ALU

    input logic        alu_we,
    input logic [4:0]  alu_rd,
    input logic [31:0] alu_data,


    // Slot 1 - LSU

    input logic        lsu_we,
    input logic [4:0]  lsu_rd,
    input logic [31:0] lsu_data,


    // Slot 2 - BRU

    input logic        bru_we,
    input logic [4:0]  bru_rd,
    input logic [31:0] bru_data,


    // Slot 3 - CRIPTO (par de registros rd, rd+1)

    input logic        crypto_we,
    input logic [4:0]  crypto_rd,
    input logic [31:0] crypto_data_l,
    input logic [31:0] crypto_data_r,


    // Hacia los puertos de escritura del banco de registros

    output logic [4:0]       we,
    output logic [4:0][4:0]  waddr,
    output logic [4:0][31:0] wdata,

    output logic conflict

);

// Segundo registro del par de la cripto

logic [4:0] crypto_rd_r;

assign crypto_rd_r = crypto_rd + 5'd1;


// Asignación de puertos

always @(*) begin

    waddr[0] = alu_rd;
    wdata[0] = alu_data;
    we[0]    = alu_we && alu_rd != 5'd0;


    waddr[1] = lsu_rd;
    wdata[1] = lsu_data;
    we[1]    = lsu_we && lsu_rd != 5'd0;


    waddr[2] = bru_rd;
    wdata[2] = bru_data;
    we[2]    = bru_we && bru_rd != 5'd0;


    // La cripto escribe el par (rd, rd+1). El ISA exige rd par, así que rd+1
    // nunca desborda; si rd = x31, rd+1 vale x0 y esa escritura se descarta.

    waddr[3] = crypto_rd;
    wdata[3] = crypto_data_l;
    we[3]    = crypto_we && crypto_rd != 5'd0;

    waddr[4] = crypto_rd_r;
    wdata[4] = crypto_data_r;
    we[4]    = crypto_we && crypto_rd_r != 5'd0;
end


// Detección de conflictos: dos puertos habilitados con el mismo destino

always @(*) begin

    conflict = 1'b0;

    for(int i = 0; i < 5; i++)
        for(int j = i + 1; j < 5; j++)
            if(we[i] && we[j] && waddr[i] == waddr[j])
                conflict = 1'b1;
end

endmodule
