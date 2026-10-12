/*
================================================================================
 Módulo: lsu

 Descripción:
 ------------------------------------------------------------------------------
 Unidad de carga / almacenamiento (slot 1 del bundle).

 Instrucciones soportadas (decodificadas en bobbin_lsu):
     OP_GUARDAP    M[rf1+off]   = rf2[31:0]    palabra 32 bits
     OP_GUARDAB    M[rf1+off]   = rf2[7:0]     1 byte
     OP_CARGAI     rg           = M[rf1+off]   palabra 32 bits
     OP_CARGABAI   rg           = M[rf1+off]   1 byte con extensión de signo

 Conexión con el pipeline:
     - La dirección efectiva (rf1 + sign_ext(off)) se calcula en EX y se
       presenta a la memoria de forma combinacional.
     - La memoria tiene lectura combinacional (rtl/memory.sv), por lo que el
       dato leído de una instrucción load está disponible en el mismo ciclo
       en que se presenta la dirección.
     - Para igualar la latencia de 1 ciclo de EX→WB con la ALU (que pasa por
       pipeline_ex_wb), esta LSU captura internamente el load (we, rd y el
       dato leído) en un registro que se actualiza en el flanco positivo, de
       modo que la escritura en wb ocurre exactamente un ciclo después de la
       dirección, igual que la ALU.
     - valid_in debe ser 1 sólo si el slot trae una instrucción LSU
       (decoder_lsu.valid): lsu_op = 0 es también el código de guardap.
     - Los stores no escriben en el regfile: la señal wb_we permanece en 0.

 Salidas hacia la memoria (rtl/memory.sv):
     mem_we   escritura habilitada durante el ciclo de EX del store
     mem_be   byte enables según tamaño (palabra = 4'b1111, byte = 1 << off[1:0])
     mem_addr dirección efectiva byte-addressable
     mem_wdata dato a escribir (rf2_data)

 Salidas hacia el writeback (rtl/wb.sv):
     wb_we    1 si hay un load pendiente de escribir su resultado
     wb_rd    registro destino del load
     wb_data  dato leído de la memoria (con sign-extension si es byte)

================================================================================
*/

`include "isa_defs.sv"


module lsu(

    input  logic         clk,
    input  logic         reset,

    // Entradas desde ID/EX (1 ciclo después de ID)
    input  logic         valid_in,    // la instrucción del slot LSU es válida
    input  logic [3:0]   lsu_op,      // OP_GUARDAP / OP_GUARDAB / OP_CARGAI / OP_CARGABAI
    input  logic [4:0]   rd,          // registro destino (loads)
    input  logic [10:0]  imm,         // offset de 11 bits
    input  logic [31:0]  rf1_data,    // base address
    input  logic [31:0]  rf2_data,    // dato a almacenar (stores)

    // Salidas hacia rtl/memory.sv
    output logic         mem_we,
    output logic [3:0]   mem_be,
    output logic [31:0]  mem_addr,
    output logic [31:0]  mem_wdata,

    // Entrada desde rtl/memory.sv (lectura combinacional)
    input  logic [31:0]  mem_rdata,

    // Salidas hacia rtl/wb.sv
    output logic         wb_we,
    output logic [4:0]   wb_rd,
    output logic [31:0]  wb_data
);


// ============================================================================
// Decodificación de la operación
// ============================================================================

logic is_word_load;
logic is_byte_load;
logic is_word_store;
logic is_byte_store;

assign is_word_load  = (lsu_op == OP_CARGAI);
assign is_byte_load  = (lsu_op == OP_CARGABAI);
assign is_word_store = (lsu_op == OP_GUARDAP);
assign is_byte_store = (lsu_op == OP_GUARDAB);

logic is_load;
logic is_byte;

assign is_load = is_word_load || is_byte_load;
assign is_byte = is_byte_load || is_byte_store;


// ============================================================================
// Dirección efectiva: rf1 + sign_ext(imm de 11 bits)
// ============================================================================

logic [31:0] eff_addr;

assign eff_addr = rf1_data + {{21{imm[10]}}, imm};


// ============================================================================
// Salidas hacia rtl/memory.sv
// ============================================================================

assign mem_we    = valid_in && (is_word_store || is_byte_store);
assign mem_be    = is_byte ? (4'b0001 << eff_addr[1:0]) : 4'b1111;
assign mem_addr  = eff_addr;

// Colocar el byte de rf2_data en la posición correcta según eff_addr[1:0].
// Para guardap (palabra completa) se usa el dato entero. Para guardab, sólo
// el byte en la posición del byte enable.
assign mem_wdata = is_byte ? (rf2_data << (eff_addr[1:0] * 8)) : rf2_data;


// ============================================================================
// Pipeline interno: el load se retrasa 1 ciclo para igualar la latencia de
// la ALU, que pasa por pipeline_ex_wb. Así el dato escrito en wb está
// disponible un ciclo después del ciclo en que la dirección se presentó.
// ============================================================================

// Sign-extension del byte leído según eff_addr[1:0]
logic [31:0] rdata_byte_sext;

always @(*) begin

    case (eff_addr[1:0])

        2'd0: rdata_byte_sext = {{24{mem_rdata[ 7]}}, mem_rdata[ 7: 0]};
        2'd1: rdata_byte_sext = {{24{mem_rdata[15]}}, mem_rdata[15: 8]};
        2'd2: rdata_byte_sext = {{24{mem_rdata[23]}}, mem_rdata[23:16]};
        2'd3: rdata_byte_sext = {{24{mem_rdata[31]}}, mem_rdata[31:24]};

        default: rdata_byte_sext = mem_rdata;
    endcase
end


// El dato se registra junto con wb_we y wb_rd: en el ciclo siguiente la
// dirección de la memoria ya es la del bundle que sigue en EX, así que el
// dato leído tiene que quedar guardado aquí.
logic        load_pending_d;   // hay un load en vuelo que escribirá en el próximo ciclo
logic [4:0]  load_rd_d;        // rd del load en vuelo
logic [31:0] load_data_d;      // dato leído por el load en vuelo

always @(posedge clk) begin

    if (reset) begin

        load_pending_d <= 1'b0;
        load_rd_d      <= 5'd0;
        load_data_d    <= 32'd0;
    end
    else begin

        load_pending_d <= valid_in && is_load;
        load_rd_d      <= rd;
        load_data_d    <= is_byte_load ? rdata_byte_sext : mem_rdata;
    end
end


// ============================================================================
// Salidas hacia rtl/wb.sv (desde el registro interno)
// ============================================================================

assign wb_we   = load_pending_d;
assign wb_rd   = load_rd_d;
assign wb_data = load_data_d;


// ============================================================================
// Sanity checks (sólo en simulación)
// ============================================================================

// Se revisa en el flanco, con las señales ya estables. Con always @(*) el
// mensaje salía también por valores transitorios dentro de un mismo instante.
`ifndef SYNTHESIS
always @(posedge clk) begin

    if (!reset && valid_in && !is_load && !is_word_store && !is_byte_store) begin

        $display("[LSU] WARNING: lsu_op=%b no es una operación LSU válida", lsu_op);
    end
end
`endif

endmodule