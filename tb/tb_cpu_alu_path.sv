`timescale 1ns/1ps


module tb_cpu_alu_path;


    logic clk;


    // Señales WB hacia Register File

    wire [4:0] wb_rd;
    wire [31:0] wb_data;
    wire wb_enable;



    // Instrucción

    logic [31:0] instruction;



    // Salidas ID

    logic [3:0] alu_op;

    logic [31:0] operand_a;
    logic [31:0] operand_b;

    logic [4:0] rd;

    logic [10:0] imm;

    logic use_imm;



    // Resultado EX

    logic [31:0] result;



    // ===================================
    // ID
    // ===================================

    id_stage ID (

        .clk(clk),

        .reset(1'b0),

        .instruction(instruction),


        .wb_rd(wb_rd),

        .wb_data(wb_data),

        .wb_enable(wb_enable),


        .alu_op(alu_op),

        .operand_a(operand_a),

        .operand_b(operand_b),

        .rd(rd),

        .imm(imm),

        .use_imm(use_imm)

    );



    // ===================================
    // EX
    // ===================================

    ex_stage EX (

        .alu_op(alu_op),

        .operand_a(operand_a),

        .operand_b(operand_b),

        .rd(rd),

        .valid_in(1'b1),


        .result(result),

        .rd_out(),

        .valid_out()

    );



    // ===================================
    // WB
    // ===================================

    wb WB (

        .result_in(result),

        .rd_in(rd),

        .valid_in(1'b1),


        .write_data(wb_data),

        .rd_out(wb_rd),

        .reg_write(wb_enable)

    );



    always #5 clk = ~clk;



    initial begin


        $dumpfile("cpu_alu_path.vcd");
        $dumpvars(0,tb_cpu_alu_path);



        clk = 0;


        // =====================================
        // Ejecutar:
        //
        // suma x5,x2,x3
        //
        // x2 = 20
        // x3 = 30
        //
        // Resultado esperado:
        // x5 = 50
        // =====================================


        instruction = {

            7'b1101010,   // TYPE_REG

            4'b1000,      // SUMA

            5'd5,         // rd

            5'd2,         // rs1

            5'd3,         // rs2

            6'b0

        };


        #10;



        $display("==============================");

        $display("Resultado ALU = %d", result);

        $display("Destino = x%d", wb_rd);

        $display("Escritura = %b", wb_enable);

        $display("==============================");



        $finish;


    end


endmodule