/*
================================================================================
 Módulo: wb

 Descripción:
 ------------------------------------------------------------------------------
 Etapa Write Back (WB) del pipeline.

 Esta etapa recibe el resultado generado durante la ejecución y prepara la
 escritura del dato en el banco de registros.

 Funciones:
 ------------------------------------------------------------------------------
 - Propagar el registro destino.
 - Entregar el resultado calculado.
 - Generar la señal de escritura del Register File.

 Este módulo no modifica datos, únicamente controla el retorno del resultado
 hacia la etapa ID.

================================================================================
*/
module wb(
    input logic [31:0] result_in,

    input logic [4:0] rd_in,

    input logic valid_in,


    output logic [31:0] write_data,

    output logic [4:0] rd_out,

    output logic reg_write

);

always @(*) begin


    write_data = result_in;

    rd_out = rd_in;


    if(valid_in)

        reg_write = 1'b1;

    else

        reg_write = 1'b0;

end
endmodule