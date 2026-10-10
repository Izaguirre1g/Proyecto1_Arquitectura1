//Módulo Fetch
/*
Recibe el PC actual
Consulta a la memoria de instrucciones
Obtiene el bundle de VLIW de 128 bits
Entrega el bundle junto con el PC a la siguiente etapa

Es combinacional: el único registro entre IF e ID es pipeline_if_id. Antes
este módulo también registraba el bundle, lo que agregaba un ciclo vacío
entre IF e ID (5 etapas en lugar de IF / ID / EX / WB) y dejaba 3 bundles
detrás de un salto tomado en lugar de los 2 que define el ISA.

clk y flush_in se conservan para no cambiar la interfaz, pero no se usan: el
descarte de bundles al tomar un salto lo hacen pipeline_if_id y
pipeline_id_ex, y el PC lo actualiza pc_branch.
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

assign pc_out     = pc;
assign bundle_out = instruction_bundle;
assign valid_out  = !reset;

endmodule
