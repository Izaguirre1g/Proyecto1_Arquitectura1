/*
================================================================================
 Módulo: pc

 Descripción:
 ------------------------------------------------------------------------------
 Registro del Program Counter.

 Almacena la dirección de la instrucción actual.

 En cada flanco positivo:
    - Si reset está activo, PC vuelve a cero.
    - Si no, incrementa al siguiente bundle.

 En este procesador VLIW cada instrucción corresponde a un bundle de 128 bits.

================================================================================
*/
module program_counter(

    input logic clk,

    input logic reset,


    output logic [31:0] pc_out

);



always @(posedge clk) begin


    if(reset)

        pc_out <= 32'b0;


    else

        pc_out <= pc_out + 32'd16;


end


endmodule