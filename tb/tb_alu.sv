`timescale 1ns/1ps

/*
================================================================================
 Testbench: tb_alu

 Descripción:
 ------------------------------------------------------------------------------
 Verificación autoverificable de la ALU (slot 0).

 Parte 1 - Unidad ALU aislada:
   - Casos dirigidos por operación, con los ejemplos del ISA y casos de borde:
     acarreo y desborde con signo, desplazamientos de 0, 31 y >= 32
     posiciones, relleno del corrimiento aritmético, comparaciones con signo
     en los extremos (INT_MIN, INT_MAX, -1) y códigos de operación no
     definidos.
   - Barrido de todas las combinaciones de un conjunto de valores especiales
     por cada operación.
   - N_RANDOM vectores aleatorios por operación.
   Los resultados se comparan contra ref_alu, un modelo escrito de forma
   independiente al RTL (los desplazamientos se calculan con multiplicación y
   división, la resta con complemento a dos y las comparaciones invirtiendo el
   bit de signo). Los casos dirigidos también verifican el modelo.

 Parte 2 - Instrucciones ALU del ISA a través de la etapa ID:
   Cada una de las 18 instrucciones ALU del ISA (10 tipo registro y 8 tipo
   inmediato), además de los pseudo mov y not, se codifica con los valores
   binarios de ISA_Proyecto.md y pasa por id_stage (decoder_alu y extensión de signo
   del inmediato) con el banco de registros conectado aparte, y luego por la ALU. Se
   verifican el código de operación, el registro destino, el uso de inmediato
   y el resultado.

 Plusargs: +seed=N cambia la semilla de los vectores aleatorios, +verbose.

================================================================================
*/

`include "isa_defs.sv"


module tb_alu;

`include "tb_utils.svh"


localparam int N_RANDOM = 1000;

integer seed;


// =====================================
// Parte 1: ALU aislada
// =====================================

logic [3:0] alu_op;

logic [31:0] operand_a;
logic [31:0] operand_b;

logic [31:0] result;


alu DUT (

    .alu_op(alu_op),
    .operand_a(operand_a),
    .operand_b(operand_b),
    .result(result)
);


// =====================================
// Parte 2: ID + ALU
// =====================================

logic clk;
logic reset;

logic [31:0] instruction;

logic [4:0] wb_rd;
logic [31:0] wb_data;
logic wb_enable;

logic [3:0] id_alu_op;
logic [31:0] id_operand_a;
logic [31:0] id_operand_b;
logic [4:0] id_rd;
logic [10:0] id_imm;
logic id_use_imm;

logic [31:0] id_result;


logic [4:0] id_rs1;
logic [4:0] id_rs2;
logic [31:0] id_rs1_data;
logic [31:0] id_rs2_data;

// El banco de registros vive en cpu_top; aquí se instancia aparte con 2
// lecturas y 1 escritura (sólo el slot ALU).
regfile #(

    .NUM_READ_PORTS(2),
    .NUM_WRITE_PORTS(1)

) RF (

    .clk(clk),
    .reset(reset),
    .raddr({id_rs2, id_rs1}),
    .rdata({id_rs2_data, id_rs1_data}),
    .we(wb_enable),
    .waddr(wb_rd),
    .wdata(wb_data)
);


id_stage ID (

    .instruction(instruction),
    .rs1(id_rs1),
    .rs2(id_rs2),
    .rs1_data(id_rs1_data),
    .rs2_data(id_rs2_data),
    .alu_op(id_alu_op),
    .operand_a(id_operand_a),
    .operand_b(id_operand_b),
    .rd(id_rd),
    .imm(id_imm),
    .use_imm(id_use_imm)
);


alu ALU_ID (

    .alu_op(id_alu_op),
    .operand_a(id_operand_a),
    .operand_b(id_operand_b),
    .result(id_result)
);


always #5 clk = ~clk;


// =====================================
// Modelo de referencia
// =====================================

function automatic logic [31:0] ref_alu(input logic [3:0] op, input logic [31:0] a, input logic [31:0] b);

    logic [31:0] pow2;
    logic [63:0] prod;

    pow2 = 32'd1 << b[4:0];
    prod = {32'd0, a} * {32'd0, pow2};

    case(op)

        ALU_ADD: ref_alu = a + b;
        ALU_SUB: ref_alu = a + ~b + 32'd1;
        ALU_SLL: ref_alu = prod[31:0];
        ALU_SRL: ref_alu = a / pow2;
        ALU_SRA: ref_alu = a[31] ? ~((~a) / pow2) : a / pow2;
        ALU_XOR: ref_alu = (a | b) & ~(a & b);
        ALU_AND: ref_alu = ~(~a | ~b);
        ALU_OR:  ref_alu = ~(~a & ~b);
        ALU_LT:  ref_alu = ((a ^ 32'h8000_0000) < (b ^ 32'h8000_0000)) ? 32'd1 : 32'd0;
        ALU_GT:  ref_alu = ((b ^ 32'h8000_0000) < (a ^ 32'h8000_0000)) ? 32'd1 : 32'd0;
        default: ref_alu = 32'd0;
    endcase
endfunction


// =====================================
// Tareas de la parte 1
// =====================================

// Caso dirigido: verifica la ALU y el modelo contra el valor esperado
task automatic alu_case(input string name, input logic [3:0] op, input logic [31:0] a,
                        input logic [31:0] b, input logic [31:0] exp);

    alu_op = op;
    operand_a = a;
    operand_b = b;

    #1;

    check(name, result, exp);
    check({name, " (modelo)"}, ref_alu(op, a, b), exp);
endtask


// Caso contra el modelo
task automatic alu_vs_model(input logic [3:0] op, input logic [31:0] a, input logic [31:0] b);

    alu_op = op;
    operand_a = a;
    operand_b = b;

    #1;

    check($sformatf("op=%0d a=0x%08h b=0x%08h", op, a, b), result, ref_alu(op, a, b));
endtask


// =====================================
// Tareas de la parte 2
// =====================================

function automatic logic [31:0] enc_reg(input logic [3:0] id, input logic [4:0] rg,
                                        input logic [4:0] rf1, input logic [4:0] rf2);

    return {7'b1101010, id, rg, rf1, rf2, 6'b0};
endfunction


function automatic logic [31:0] enc_imm(input logic [3:0] id, input logic [4:0] rf1,
                                        input logic [4:0] rg, input logic [10:0] imm);

    return {7'b1000000, id, rf1, rg, imm};
endfunction


// Escribe un registro por el puerto de escritura del banco
task automatic write_reg(input logic [4:0] r, input logic [31:0] v);

    @(negedge clk);

    wb_enable = 1'b1;
    wb_rd = r;
    wb_data = v;

    @(negedge clk);

    wb_enable = 1'b0;
endtask


// Carga x6 (rf1) y x7 (rf2), presenta la instrucción y verifica la salida
task automatic isa_case(input string name, input logic [31:0] instr,
                        input logic [31:0] v_rf1, input logic [31:0] v_rf2,
                        input logic [3:0] exp_op, input logic exp_use_imm,
                        input logic [31:0] exp_result);

    write_reg(5'd6, v_rf1);
    write_reg(5'd7, v_rf2);

    instruction = instr;

    #1;

    check({name, ": alu_op"}, id_alu_op, exp_op);
    check({name, ": rd"}, id_rd, 5'd5);
    check({name, ": use_imm"}, id_use_imm, exp_use_imm);
    check({name, ": resultado"}, id_result, exp_result);
endtask


// Valores especiales para el barrido exhaustivo
localparam int N_SPECIAL = 13;

function automatic logic [31:0] special(input int i);

    case(i)

        0:  special = 32'h0000_0000;
        1:  special = 32'h0000_0001;
        2:  special = 32'h0000_0002;
        3:  special = 32'h0000_001F;
        4:  special = 32'h0000_0020;
        5:  special = 32'h7FFF_FFFF;
        6:  special = 32'h8000_0000;
        7:  special = 32'h8000_0001;
        8:  special = 32'hFFFF_FFFF;
        9:  special = 32'hFFFF_FFFE;
        10: special = 32'hAAAA_AAAA;
        11: special = 32'h5555_5555;
        default: special = 32'h1234_5678;
    endcase
endfunction


initial begin

    $dumpfile("tb_alu.vcd");
    $dumpvars(0, tb_alu);

    if(!$value$plusargs("seed=%d", seed))
        seed = 32'hCE4301;

    $display("tb_alu: semilla de vectores aleatorios = %0d", seed);

    clk = 0;
    reset = 1;
    instruction = 32'b0;
    wb_rd = 5'd0;
    wb_data = 32'd0;
    wb_enable = 1'b0;


    // =================================================
    // Parte 1: casos dirigidos
    // =================================================

    tb_section("Suma");

    alu_case("suma 10 + 5",                       ALU_ADD, 32'd10,        32'd5,        32'd15);
    alu_case("suma 0xFFFFFFFF + 1 (acarreo)",     ALU_ADD, 32'hFFFF_FFFF, 32'd1,        32'h0000_0000);
    alu_case("suma 0x7FFFFFFF + 1 (desborde)",    ALU_ADD, 32'h7FFF_FFFF, 32'd1,        32'h8000_0000);
    alu_case("suma -3 + -4",                      ALU_ADD, -32'sd3,       -32'sd4,      -32'sd7);

    tb_section("Resta");

    alu_case("resta 10 - 3",                      ALU_SUB, 32'd10,        32'd3,        32'd7);
    alu_case("resta 5 - 10",                      ALU_SUB, 32'd5,         32'd10,       -32'sd5);
    alu_case("resta 0 - 1",                       ALU_SUB, 32'd0,         32'd1,        32'hFFFF_FFFF);
    alu_case("resta 0x80000000 - 1 (desborde)",   ALU_SUB, 32'h8000_0000, 32'd1,        32'h7FFF_FFFF);
    alu_case("resta x - x",                       ALU_SUB, 32'h1234_5678, 32'h1234_5678, 32'd0);

    tb_section("AND / OR / XOR");

    alu_case("and 1010 & 1100 (ejemplo ISA)",     ALU_AND, 32'b1010,      32'b1100,      32'b1000);
    alu_case("or 1010 | 1100 (ejemplo ISA)",      ALU_OR,  32'b1010,      32'b1100,      32'b1110);
    alu_case("xor 1010 ^ 1100 (ejemplo ISA)",     ALU_XOR, 32'b1010,      32'b1100,      32'b0110);
    alu_case("and 0xAAAAAAAA & 0xCCCCCCCC",       ALU_AND, 32'hAAAA_AAAA, 32'hCCCC_CCCC, 32'h8888_8888);
    alu_case("or 0xAAAAAAAA | 0xCCCCCCCC",        ALU_OR,  32'hAAAA_AAAA, 32'hCCCC_CCCC, 32'hEEEE_EEEE);
    alu_case("xor 0xAAAAAAAA ^ 0xCCCCCCCC",       ALU_XOR, 32'hAAAA_AAAA, 32'hCCCC_CCCC, 32'h6666_6666);
    alu_case("xor con -1 (not)",                  ALU_XOR, 32'h0F0F_1234, 32'hFFFF_FFFF, 32'hF0F0_EDCB);
    alu_case("and con 0",                         ALU_AND, 32'hDEAD_BEEF, 32'd0,         32'd0);
    alu_case("or con -1",                         ALU_OR,  32'h1234_5678, 32'hFFFF_FFFF, 32'hFFFF_FFFF);

    tb_section("Corrimiento lógico izquierdo (cizq / cizqi)");

    alu_case("cizq 5 << 2 (ejemplo ISA)",         ALU_SLL, 32'd5,         32'd2,         32'd20);
    alu_case("cizq 1 << 31",                      ALU_SLL, 32'd1,         32'd31,        32'h8000_0000);
    alu_case("cizq x << 0",                       ALU_SLL, 32'hDEAD_BEEF, 32'd0,         32'hDEAD_BEEF);
    alu_case("cizq pierde los bits que salen",    ALU_SLL, 32'hF000_000F, 32'd4,         32'h0000_00F0);
    alu_case("cizq b = 32 usa b[4:0] = 0",        ALU_SLL, 32'h0000_00FF, 32'd32,        32'h0000_00FF);
    alu_case("cizq b = 33 usa b[4:0] = 1",        ALU_SLL, 32'd1,         32'd33,        32'd2);
    alu_case("cizq b = -1 usa b[4:0] = 31",       ALU_SLL, 32'd1,         32'hFFFF_FFFF, 32'h8000_0000);

    tb_section("Corrimiento lógico derecho (cder / cderi)");

    alu_case("cder 20 >> 2 (ejemplo ISA)",        ALU_SRL, 32'd20,        32'd2,         32'd5);
    alu_case("cder rellena con ceros",            ALU_SRL, 32'h8000_0000, 32'd31,        32'd1);
    alu_case("cder 0xF0000000 >> 4",              ALU_SRL, 32'hF000_0000, 32'd4,         32'h0F00_0000);
    alu_case("cder x >> 0",                       ALU_SRL, 32'hDEAD_BEEF, 32'd0,         32'hDEAD_BEEF);
    alu_case("cder b = 36 usa b[4:0] = 4",        ALU_SRL, 32'hF000_0000, 32'd36,        32'h0F00_0000);

    tb_section("Corrimiento aritmético derecho (cader / caderi)");

    alu_case("cader -8 >>> 2 (ejemplo ISA)",      ALU_SRA, -32'sd8,       32'd2,         -32'sd2);
    alu_case("cader 0xFFFFFFF0 >>> 2 (ej. ISA)",  ALU_SRA, 32'hFFFF_FFF0, 32'd2,         32'hFFFF_FFFC);
    alu_case("cader 0x80000000 >>> 31",           ALU_SRA, 32'h8000_0000, 32'd31,        32'hFFFF_FFFF);
    alu_case("cader positivo rellena con ceros",  ALU_SRA, 32'h7000_0000, 32'd4,         32'h0700_0000);
    alu_case("cader -1 >>> 31",                   ALU_SRA, 32'hFFFF_FFFF, 32'd31,        32'hFFFF_FFFF);
    alu_case("cader -5 >>> 1 (hacia -infinito)",  ALU_SRA, -32'sd5,       32'd1,         -32'sd3);
    alu_case("cader x >>> 0",                     ALU_SRA, 32'h8765_4321, 32'd0,         32'h8765_4321);

    tb_section("Comparación menor que con signo (mrq)");

    alu_case("mrq 5 < 10",                        ALU_LT,  32'd5,         32'd10,        32'd1);
    alu_case("mrq 10 < 5",                        ALU_LT,  32'd10,        32'd5,         32'd0);
    alu_case("mrq 7 < 7",                         ALU_LT,  32'd7,         32'd7,         32'd0);
    alu_case("mrq -1 < 0",                        ALU_LT,  -32'sd1,       32'd0,         32'd1);
    alu_case("mrq -1 < 1 (con signo)",            ALU_LT,  -32'sd1,       32'd1,         32'd1);
    alu_case("mrq INT_MIN < INT_MAX",             ALU_LT,  32'h8000_0000, 32'h7FFF_FFFF, 32'd1);
    alu_case("mrq INT_MAX < INT_MIN",             ALU_LT,  32'h7FFF_FFFF, 32'h8000_0000, 32'd0);
    alu_case("mrq -8 < -3",                       ALU_LT,  -32'sd8,       -32'sd3,       32'd1);

    tb_section("Comparación mayor que con signo (myq)");

    alu_case("myq 10 > 5",                        ALU_GT,  32'd10,        32'd5,         32'd1);
    alu_case("myq 5 > 10",                        ALU_GT,  32'd5,         32'd10,        32'd0);
    alu_case("myq 7 > 7",                         ALU_GT,  32'd7,         32'd7,         32'd0);
    alu_case("myq 0 > -1 (con signo)",            ALU_GT,  32'd0,         -32'sd1,       32'd1);
    alu_case("myq INT_MAX > INT_MIN",             ALU_GT,  32'h7FFF_FFFF, 32'h8000_0000, 32'd1);
    alu_case("myq INT_MIN > INT_MAX",             ALU_GT,  32'h8000_0000, 32'h7FFF_FFFF, 32'd0);
    alu_case("myq -3 > -8",                       ALU_GT,  -32'sd3,       -32'sd8,       32'd1);

    tb_section("Códigos de operación no definidos");

    for(int op = 10; op < 16; op++)
        alu_case($sformatf("alu_op = %0d produce 0", op), op[3:0], 32'hFFFF_FFFF, 32'hFFFF_FFFF, 32'd0);


    // =================================================
    // Parte 1: barrido de valores especiales y aleatorios
    // =================================================

    tb_section($sformatf("Barrido de valores especiales (%0d x %0d por operación)", N_SPECIAL, N_SPECIAL));

    for(int op = 0; op < 10; op++)
        for(int i = 0; i < N_SPECIAL; i++)
            for(int j = 0; j < N_SPECIAL; j++)
                alu_vs_model(op[3:0], special(i), special(j));

    tb_section($sformatf("Vectores aleatorios (%0d por operación)", N_RANDOM));

    for(int op = 0; op < 10; op++)
        repeat(N_RANDOM)
            alu_vs_model(op[3:0], $random(seed), $random(seed));


    // =================================================
    // Parte 2: instrucciones del ISA a través de ID
    // =================================================

    @(negedge clk);
    @(negedge clk);

    reset = 0;

    tb_section("Instrucciones tipo registro (rg = x5, rf1 = x6, rf2 = x7)");

    isa_case("suma",          enc_reg(4'b1000, 5'd5, 5'd6, 5'd7), 32'd10,     32'd5,      ALU_ADD, 1'b0, 32'd15);
    isa_case("resta",         enc_reg(4'b1001, 5'd5, 5'd6, 5'd7), 32'd10,     32'd3,      ALU_SUB, 1'b0, 32'd7);
    isa_case("cizq",          enc_reg(4'b1011, 5'd5, 5'd6, 5'd7), 32'd5,      32'd2,      ALU_SLL, 1'b0, 32'd20);
    isa_case("cder",          enc_reg(4'b1111, 5'd5, 5'd6, 5'd7), 32'd20,     32'd2,      ALU_SRL, 1'b0, 32'd5);
    isa_case("cader",         enc_reg(4'b1010, 5'd5, 5'd6, 5'd7), -32'sd8,    32'd2,      ALU_SRA, 1'b0, -32'sd2);
    isa_case("xor",           enc_reg(4'b1110, 5'd5, 5'd6, 5'd7), 32'b1010,   32'b1100,   ALU_XOR, 1'b0, 32'b0110);
    isa_case("and",           enc_reg(4'b1100, 5'd5, 5'd6, 5'd7), 32'b1010,   32'b1100,   ALU_AND, 1'b0, 32'b1000);
    isa_case("or",            enc_reg(4'b1101, 5'd5, 5'd6, 5'd7), 32'b1010,   32'b1100,   ALU_OR,  1'b0, 32'b1110);
    isa_case("mrq 5 < 10",    enc_reg(4'b0101, 5'd5, 5'd6, 5'd7), 32'd5,      32'd10,     ALU_LT,  1'b0, 32'd1);
    isa_case("mrq -1 < 1",    enc_reg(4'b0101, 5'd5, 5'd6, 5'd7), -32'sd1,    32'd1,      ALU_LT,  1'b0, 32'd1);
    isa_case("myq 10 > 5",    enc_reg(4'b0110, 5'd5, 5'd6, 5'd7), 32'd10,     32'd5,      ALU_GT,  1'b0, 32'd1);
    isa_case("myq -1 > 1",    enc_reg(4'b0110, 5'd5, 5'd6, 5'd7), -32'sd1,    32'd1,      ALU_GT,  1'b0, 32'd0);

    tb_section("Instrucciones tipo inmediato (rf1 = x6, rg = x5)");

    // En estos casos x7 se carga con 0xBAD0BAD0 para detectar si se usara rf2
    isa_case("sumai 10 + 5",           enc_imm(4'b0000, 5'd6, 5'd5, 11'd5),     32'd10,        32'hBAD0_BAD0, ALU_ADD, 1'b1, 32'd15);
    isa_case("sumai 10 + (-1)",        enc_imm(4'b0000, 5'd6, 5'd5, 11'h7FF),   32'd10,        32'hBAD0_BAD0, ALU_ADD, 1'b1, 32'd9);
    isa_case("sumai 10 + 1023 (máx.)", enc_imm(4'b0000, 5'd6, 5'd5, 11'h3FF),   32'd10,        32'hBAD0_BAD0, ALU_ADD, 1'b1, 32'd1033);
    isa_case("restai 10 - 3",          enc_imm(4'b0001, 5'd6, 5'd5, 11'd3),     32'd10,        32'hBAD0_BAD0, ALU_SUB, 1'b1, 32'd7);
    isa_case("restai 10 - (-1024)",    enc_imm(4'b0001, 5'd6, 5'd5, 11'h400),   32'd10,        32'hBAD0_BAD0, ALU_SUB, 1'b1, 32'd1034);
    isa_case("cizqi 5 << 2",           enc_imm(4'b0010, 5'd6, 5'd5, 11'd2),     32'd5,         32'hBAD0_BAD0, ALU_SLL, 1'b1, 32'd20);
    isa_case("cderi 20 >> 2",          enc_imm(4'b0011, 5'd6, 5'd5, 11'd2),     32'd20,        32'hBAD0_BAD0, ALU_SRL, 1'b1, 32'd5);
    isa_case("caderi -16 >>> 2",       enc_imm(4'b0100, 5'd6, 5'd5, 11'd2),     32'hFFFF_FFF0, 32'hBAD0_BAD0, ALU_SRA, 1'b1, 32'hFFFF_FFFC);
    isa_case("xori 1010 ^ 1100",       enc_imm(4'b0101, 5'd6, 5'd5, 11'b1100),  32'b1010,      32'hBAD0_BAD0, ALU_XOR, 1'b1, 32'b0110);
    isa_case("andi 1010 & 1100",       enc_imm(4'b0110, 5'd6, 5'd5, 11'b1100),  32'b1010,      32'hBAD0_BAD0, ALU_AND, 1'b1, 32'b1000);
    isa_case("andi con inm. negativo", enc_imm(4'b0110, 5'd6, 5'd5, 11'h400),   32'h1234_5678, 32'hBAD0_BAD0, ALU_AND, 1'b1, 32'h1234_5400);
    isa_case("ori 1010 | 1100",        enc_imm(4'b0111, 5'd6, 5'd5, 11'b1100),  32'b1010,      32'hBAD0_BAD0, ALU_OR,  1'b1, 32'b1110);

    tb_section("Pseudoinstrucciones y casos con x0");

    isa_case("not x5, x6 (xori -1)",   enc_imm(4'b0101, 5'd6, 5'd5, 11'h7FF),   32'h0F0F_1234, 32'hBAD0_BAD0, ALU_XOR, 1'b1, 32'hF0F0_EDCB);
    isa_case("mov x5, x6 (suma x0)",   enc_reg(4'b1000, 5'd5, 5'd6, 5'd0),      32'hCAFE_BABE, 32'd123,       ALU_ADD, 1'b0, 32'hCAFE_BABE);
    isa_case("suma x5, x0, x7",        enc_reg(4'b1000, 5'd5, 5'd0, 5'd7),      32'd99,        32'd42,        ALU_ADD, 1'b0, 32'd42);

    // NOP: rd = x0, así que la instrucción no tiene efecto arquitectónico
    instruction = 32'h0000_0000;

    #1;

    check("nop: rd", id_rd, 5'd0);
    check("nop: use_imm", id_use_imm, 1'b0);


    tb_finish("tb_alu");
end

endmodule
