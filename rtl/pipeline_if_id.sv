`timescale 1ns/1ps
/*
Este módulo representa el registro de pipeline entre las etapas de Instruction Fetch (IF) y Instruction Decode (ID). 
Su función principal es almacenar temporalmente los datos que se transfieren de la etapa de IF a la etapa de ID en el siguiente ciclo de reloj.
Entradas:   
- clk: Señal de reloj que sincroniza la operación del registro.
- reset: Señal de reinicio que inicializa el registro a un estado conocido.
- bundle_in: Datos de entrada del registro.
- pc_in: Dirección de memoria del programa de entrada.
- valid_in: Señal de validación de los datos de entrada.

Salidas:
- bundle_out: Datos de salida del registro.
- pc_out: Dirección de memoria del programa de salida.
- valid_out: Señal de validación de los datos de salida.

*/
module pipeline_if_id(
    input logic clk,
    input logic reset,

    input logic [127:0] bundle_in,
    input logic [31:0] pc_in,
    input logic valid_in,

    output logic [127:0] bundle_out,
    output logic [31:0] pc_out,
    output logic valid_out
);

always @(posedge clk) begin
    if (reset) begin
        bundle_out <= 128'b0;
        pc_out <= 32'b0;
        valid_out <= 1'b0;
    end else begin
        bundle_out <= bundle_in;
        pc_out <= pc_in;
        valid_out <= valid_in;
    end
end
endmodule