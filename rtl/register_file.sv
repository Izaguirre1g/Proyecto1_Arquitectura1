/*
================================================================================
 Módulo: register_file

 Descripción:
 ------------------------------------------------------------------------------
 Banco de registros del procesador.

 Contiene 32 registros de propósito general de 32 bits definidos por el ISA.

 La lectura de registros pertenece a la etapa Instruction Decode (ID), mientras
 que la escritura se realiza en el flanco positivo del reloj mediante la etapa
 Write Back (WB).

 Características:
 ------------------------------------------------------------------------------
 - 32 registros de 32 bits.
 - x0 siempre contiene el valor 0.
 - Dos puertos de lectura.
 - Un puerto de escritura.

 Funcionamiento:
 ------------------------------------------------------------------------------
 Lectura:
    Los registros indicados por rs1_addr y rs2_addr entregan sus valores
    correspondientes.

 Escritura:
    Si reg_write está activo y el registro destino no es x0, se almacena el dato
    recibido en rd_addr.

================================================================================
*/

module register_file(

    input logic clk,

    // Lectura

    input logic [4:0] rs1_addr,
    input logic [4:0] rs2_addr,

    output logic [31:0] rs1_data,
    output logic [31:0] rs2_data,


    // Escritura

    input logic [4:0] rd_addr,
    input logic [31:0] write_data,

    input logic reg_write

);

logic [31:0] registers [0:31];
integer i;

initial begin
    registers[2] = 32'd20;
    registers[3] = 32'd30;
end

// Escritura de registros

always @(posedge clk) begin

    if(reg_write && rd_addr != 5'd0) begin

        registers[rd_addr] <= write_data;
    end
end

// Lectura combinacional

always @(*) begin

    if(rs1_addr == 5'd0)
        rs1_data = 32'b0;
    else
        rs1_data = registers[rs1_addr];



    if(rs2_addr == 5'd0)
        rs2_data = 32'b0;
    else
        rs2_data = registers[rs2_addr];

end
endmodule