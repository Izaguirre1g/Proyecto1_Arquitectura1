/*
Descripción:
 ------------------------------------------------------------------------------
 Registro de segmentación entre las etapas Instruction Decode (ID) y Execute
 (EX).

 Su función es almacenar las señales generadas por los decodificadores antes de
 ser utilizadas por las unidades funcionales de ejecución.

 Este registro permite que la etapa ID y la etapa EX trabajen simultáneamente
 sobre instrucciones diferentes.

 Información almacenada:
 ------------------------------------------------------------------------------
 - Operación de la ALU.
 - Registro destino.
 - Registros fuente.
 - Valor inmediato.
 - Señal indicando uso de inmediato.
 - Señal de validez.

 Funcionamiento:
 ------------------------------------------------------------------------------
 En cada flanco positivo del reloj:
    - Si reset está activo, se limpian los valores generando una burbuja.
    - Si reset está inactivo, se almacenan las señales provenientes de ID.

 Este módulo no realiza cálculos, únicamente sincroniza información entre
 etapas del pipeline.

================================================================================
*/
module pipeline_id_ex(
    input logic clk,
    input logic reset,

    input logic [3:0] alu_op,

    input logic [4:0] rd,
    input logic [4:0] rs1,
    input logic [4:0] rs2,

    input logic [10:0] imm,

    input logic use_imm,

    input logic valid_in,

    output logic [3:0] alu_op_out,

    output logic [4:0] rd_out,
    output logic [4:0] rs1_out,
    output logic [4:0] rs2_out,

    output logic [10:0] imm_out,

    output logic use_imm_out,

    output logic valid_out

);

always @(posedge clk) begin

    if(reset) begin

        alu_op_out <= 4'b0;

        rd_out <= 5'b0;
        rs1_out <= 5'b0;
        rs2_out <= 5'b0;

        imm_out <= 11'b0;

        use_imm_out <= 1'b0;

        valid_out <= 1'b0;

    end
    else begin

        alu_op_out <= alu_op;

        rd_out <= rd;
        rs1_out <= rs1;
        rs2_out <= rs2;

        imm_out <= imm;

        use_imm_out <= use_imm;

        valid_out <= valid_in;

    end
end
endmodule