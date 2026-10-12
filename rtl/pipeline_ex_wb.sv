/*
================================================================================
 Módulo: pipeline_ex_wb

 Descripción:
 ------------------------------------------------------------------------------
 Registro de segmentación entre las etapas Execute (EX) y Write Back (WB).

 Su función es almacenar el resultado generado por las unidades funcionales de
 ejecución antes de ser utilizado por la etapa de escritura de registros.

 Información almacenada:
 ------------------------------------------------------------------------------
 - Resultado de la ALU.
 - Registro destino.
 - Señal de validez.

 Funcionamiento:
 ------------------------------------------------------------------------------
 En cada flanco positivo del reloj:

    - Si reset está activo, se limpian los valores generando una burbuja.
    - Si reset está inactivo, se almacenan las señales provenientes de EX.

 Este módulo no realiza cálculos, únicamente sincroniza información entre
 etapas del pipeline.

================================================================================
*/

module pipeline_ex_wb(

    input logic clk,
    input logic reset,


    // Señales provenientes de EX

    input logic [31:0] result_in,

    input logic [4:0] rd_in,

    input logic valid_in,


    // Señales hacia WB

    output logic [31:0] result_out,

    output logic [4:0] rd_out,

    output logic valid_out

);



always @(posedge clk) begin


    if(reset) begin

        result_out <= 32'b0;
        rd_out <= 5'b0;
        valid_out <= 1'b0;


    end
    else begin

        result_out <= result_in;
        rd_out <= rd_in;
        valid_out <= valid_in;

    end
end
endmodule