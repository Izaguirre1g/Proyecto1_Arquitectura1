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
`include "isa_defs.sv"

module instruction_memory(

    input logic [31:0] address,

    output logic [127:0] instruction_bundle

);



logic [127:0] memory [0:31];



initial begin

    integer i;


    // =====================================
    // Instrucción 0
    // suma x5,x2,x3
    //
    // x2 = 20
    // x3 = 30
    //
    // Resultado:
    // x5 = 50
    // =====================================

    memory[0] = {

        7'b1101010,   // TYPE_REG

        OP_SUM,      // OP_SUM

        5'd5,         // rd

        5'd2,         // rs1

        5'd3,         // rs2

        6'b0

    };



    // =====================================
    // Instrucción 1
    // NOP
    // =====================================

    memory[1] = 128'b0;



    // =====================================
    // Instrucción 2
    // NOP
    // =====================================

    memory[2] = 128'b0;



    // =====================================
    // Instrucción 3
    // NOP
    // =====================================

    memory[3] = 128'b0;



    // =====================================
    // Instrucción 4
    // resta x6,x5,x2
    //
    // x6 = 50 - 20
    //
    // Resultado esperado:
    // x6 = 30
    // =====================================

    memory[4] = {

        7'b1101010,   // TYPE_REG

        OP_RESTA,      // OP_RESTA

        5'd6,         // rd

        5'd5,         // rs1

        5'd2,         // rs2

        6'b0

    };



    // =====================================
    // Resto de memoria = NOP
    // =====================================

    for(i=5;i<32;i=i+1)

        memory[i] = 128'b0;


end



// Lectura combinacional. Con assign la salida se actualiza también cuando
// cambia el contenido de la memoria (por ejemplo, si un testbench o un loader
// escribe el programa con el PC ya en 0); con always @(address) se quedaba
// con el bundle anterior hasta que cambiara el PC.
assign instruction_bundle = memory[address >> 4];



endmodule