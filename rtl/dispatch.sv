/*
Este módulo es parte de la etapa Instruction Decode
Este recibe un bundle de instrucciones de 128 bits que vienen del registro de segmentación IF/ID y además
divide el bundle en 4 instrucciones de 32 bits cada una que corresponden a los 4 slots de la arquitectura VLIW.
La arquitectura utiliza 4 slots fijos, por lo que cada posición del bundle corresponde a un slot específico:

        Slot 0 -> ALU
        Slot 1 -> LSU
        Slot 2 -> BRU
        Slot 3 -> CRYPTO

Dispatch no ejecuta instrucciones o modifica datos, solamente separa el bundle y entrega cada instrucción al decoder
Lo que hace:
 - Recibe el bundle completo desde IF/ID.
 - Divide el bundle en cuatro instrucciones independientes.
 - Propaga la señal de validez hacia las siguientes etapas.
*/
`include "isa_defs.sv"

module dispatch(

    input logic [BUNDLE_W-1:0] bundle_in,
    input logic valid_in,

    output logic [SLOT_W-1:0] slot0_instr,
    output logic [SLOT_W-1:0] slot1_instr,
    output logic [SLOT_W-1:0] slot2_instr,
    output logic [SLOT_W-1:0] slot3_instr,

    output logic valid_out

);

//No es un reloj ni un registro
//Es lógica combinacional, este bloque se ejecuta siempre que cualquier señal interna cambie, y no depende de un reloj
always @(*) begin

    // El slot k ocupa los bits [SLOT_W*k + SLOT_W-1 : SLOT_W*k] del bundle
    slot0_instr = bundle_in[0*SLOT_W +: SLOT_W];      // [31:0]
    slot1_instr = bundle_in[1*SLOT_W +: SLOT_W];      // [63:32]
    slot2_instr = bundle_in[2*SLOT_W +: SLOT_W];      // [95:64]
    slot3_instr = bundle_in[3*SLOT_W +: SLOT_W];      // [127:96]


    valid_out = valid_in;

end


endmodule