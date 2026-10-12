//Módulo Fetch
/*
Recibe el PC actual
Consulta a la memoria de instrucciones
Obtiene el bundle de VLIW de BUNDLE_W bits (128)
Entrega el bundle junto con el PC a la siguiente etapa

Es combinacional: el único registro entre IF e ID es pipeline_if_id. Si este
módulo también registrara el bundle, se agregaría un ciclo vacío entre IF e ID
(5 etapas en lugar de IF / ID / EX / WB) y quedarían 3 bundles detrás de un
salto tomado en lugar de los 2 que define el ISA.

El descarte de bundles al tomar un salto lo hacen pipeline_if_id y
pipeline_id_ex, y el PC lo actualiza pc_branch.
*/
`include "isa_defs.sv"

module fetch(
	input logic reset,
	input logic [31:0] pc,
	input logic [BUNDLE_W-1:0] instruction_bundle,

	output logic [31:0] pc_out,
	output logic [BUNDLE_W-1:0] bundle_out,
	output logic         valid_out //Para manejar los reset, ciclos vacíos, NOPs, saltos posibles
);

assign pc_out     = pc;
assign bundle_out = instruction_bundle;
assign valid_out  = !reset;

endmodule
