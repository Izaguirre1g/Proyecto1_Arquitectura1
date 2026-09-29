`timescale 1ns/1ps


module tb_alu;


    logic [3:0] alu_op;

    logic [31:0] operand_a;
    logic [31:0] operand_b;

    logic [31:0] result;



    // Instancia ALU

    alu DUT (

        .alu_op(alu_op),

        .operand_a(operand_a),
        .operand_b(operand_b),

        .result(result)

    );



    initial begin


        $dumpfile("alu.vcd");
        $dumpvars(0,tb_alu);



        // =====================================================
        // SUMA
        // =====================================================

        alu_op = ALU_ADD;

        operand_a = 10;
        operand_b = 5;

        #10;


        $display("========= SUMA =========");

        $display("Resultado = %d", result);



        // =====================================================
        // RESTA
        // =====================================================

        alu_op = ALU_SUB;

        operand_a = 10;
        operand_b = 5;

        #10;


        $display("========= RESTA =========");

        $display("Resultado = %d", result);



        // =====================================================
        // AND
        // =====================================================

        alu_op = ALU_AND;

        operand_a = 8'b10101010;

        operand_b = 8'b11001100;

        #10;


        $display("========= AND =========");

        $display("Resultado = %b", result);



        // =====================================================
        // OR
        // =====================================================

        alu_op = ALU_OR;

        operand_a = 8'b10101010;

        operand_b = 8'b11001100;

        #10;


        $display("========= OR =========");

        $display("Resultado = %b", result);



        // =====================================================
        // XOR
        // =====================================================

        alu_op = ALU_XOR;

        operand_a = 8'b10101010;

        operand_b = 8'b11001100;

        #10;


        $display("========= XOR =========");

        $display("Resultado = %b", result);



        // =====================================================
        // SHIFT IZQUIERDA
        // =====================================================

        alu_op = ALU_SLL;

        operand_a = 5;

        operand_b = 2;

        #10;


        $display("========= SLL =========");

        $display("Resultado = %d", result);



        // =====================================================
        // SHIFT DERECHO LOGICO
        // =====================================================

        alu_op = ALU_SRL;

        operand_a = 20;

        operand_b = 2;

        #10;


        $display("========= SRL =========");

        $display("Resultado = %d", result);



        // =====================================================
        // MENOR QUE
        // =====================================================

        alu_op = ALU_LT;

        operand_a = 5;

        operand_b = 10;

        #10;


        $display("========= LT =========");

        $display("Resultado = %d", result);



        // =====================================================
        // MAYOR QUE
        // =====================================================

        alu_op = ALU_GT;

        operand_a = 10;

        operand_b = 5;

        #10;


        $display("========= GT =========");

        $display("Resultado = %d", result);



        $finish;


    end


endmodule