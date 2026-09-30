/*
================================================================================
 Módulo: instruction_memory

 Descripción:
 ------------------------------------------------------------------------------
 Memoria de instrucciones del procesador.

 Recibe el PC y entrega el bundle VLIW correspondiente.

 Cada posición almacena un bundle de 128 bits.

================================================================================
*/


module instruction_memory(

    input logic [31:0] address,

    output logic [127:0] instruction_bundle

);



logic [127:0] memory [0:31];



initial begin
    integer i;
    memory[0] = {

        7'b1101010,   // TYPE REG

        4'b1000,      // SUMA

        5'd5,         // rd

        5'd2,         // rs1

        5'd3,         // rs2

        6'b0

    };

    
    for(i=1;i<32;i=i+1)
        memory[i] = 128'b0;
end



always @(*) begin


    instruction_bundle = memory[address >> 4];


end



endmodule