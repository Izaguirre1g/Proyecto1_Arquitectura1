`timescale 1ns/1ps


module tb_ex_stage;


    logic [3:0] alu_op;

    logic [31:0] operand_a;
    logic [31:0] operand_b;

    logic [4:0] rd;

    logic valid_in;


    logic [31:0] result;

    logic [4:0] rd_out;

    logic valid_out;



    ex_stage DUT (

        .alu_op(alu_op),

        .operand_a(operand_a),
        .operand_b(operand_b),

        .rd(rd),

        .valid_in(valid_in),


        .result(result),

        .rd_out(rd_out),

        .valid_out(valid_out)

    );



    initial begin


        $dumpfile("ex_stage.vcd");
        $dumpvars(0,tb_ex_stage);



        // ==========================================
        // Caso 1: suma
        // x5 = x2 + x3
        // ==========================================

        alu_op = ALU_ADD;

        operand_a = 20;

        operand_b = 30;

        rd = 5;

        valid_in = 1;


        #10;


        $display("========= SUMA =========");

        $display("RESULTADO = %d", result);

        $display("RD = %d", rd_out);

        $display("VALID = %b", valid_out);



        // ==========================================
        // Caso 2: resta
        // ==========================================

        alu_op = ALU_SUB;

        operand_a = 50;

        operand_b = 15;

        rd = 6;


        #10;


        $display("========= RESTA =========");

        $display("RESULTADO = %d", result);

        $display("RD = %d", rd_out);



        // ==========================================
        // Caso 3: inmediato
        // sumai x7,x2,10
        // ==========================================

        alu_op = ALU_ADD;

        operand_a = 20;

        operand_b = 10;

        rd = 7;


        #10;


        $display("========= SUMAI =========");

        $display("RESULTADO = %d", result);

        $display("RD = %d", rd_out);



        $finish;


    end


endmodule