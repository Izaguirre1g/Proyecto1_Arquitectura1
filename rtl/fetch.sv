//Módulo Fetch
/*
Recibe el PC actual
Consulta a la memoria de instrucciones
Obtiene el bundle de VLIW de 128 bits
Entrega el bundle junto con el PC a la siguiente etapa

Cuando flush_in = 1 (el BRU detectó un branch en un ciclo anterior), el
siguiente flanco descarta el bundle que iba a capturarse y se inserta una
burbuja (NOP equivalente, valid_out = 0). Esto implementa la penalización
de 2 ciclos del salto: el bundle que ya está capturado se descarta y se
espera a que el PC se actualice a target_pc para volver a fetchear.
*/
module fetch(
	input logic clk,
	input logic reset,
	input logic [31:0] pc,
	input logic [127:0] instruction_bundle,
	input logic flush_in,

	output logic [31:0] pc_out,
	output logic [127:0] bundle_out,
	output logic         valid_out //Para manejar los reset, ciclos vacíos, NOPs, saltos posibles


);
//Cuando llega un flanco de reloj positivo del reloj se actualizan esos registros, se utiliza lógica secuencial:
//Ejecuta este bloque solo cuando ocurre un flanco de subida del reloj y es lógica secuencial
always @(posedge clk) begin
		if (reset) begin
			pc_out <= 32'b0;
			bundle_out <= 128'b0; //Esto es así porque en el ISA se definió NOP=0x00000000
					//Entonces cada slot es un NOP
			valid_out <= 1'b0;
		end else if (flush_in) begin
			pc_out <= 32'b0;
			bundle_out <= 128'b0;
			valid_out <= 1'b0;
		end else begin
			pc_out <= pc;
			bundle_out <= instruction_bundle;
			valid_out <= 1'b1;
		end
end

endmodule