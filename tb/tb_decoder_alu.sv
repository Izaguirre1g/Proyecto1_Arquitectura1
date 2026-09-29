`timescale 1ns/1ps


module tb_decoder_alu;


    logic [31:0] instruction;


    logic [3:0] alu_op;

    logic [4:0] rd;
    logic [4:0] rs1;
    logic [4:0] rs2;

    logic [10:0] imm;

    logic use_imm;



    decoder_alu DUT (

        .instruction(instruction),

        .alu_op(alu_op),

        .rd(rd),
        .rs1(rs1),
        .rs2(rs2),

        .imm(imm),

        .use_imm(use_imm)

    );



    initial begin


        $dumpfile("decoder_alu.vcd");
        $dumpvars(0, tb_decoder_alu);



        // =====================================================
        // Caso 1: suma x5,x2,x3
        // =====================================================


        instruction = {
            7'b1101010, // TYPE_REG
            4'b1000,    // OP_SUM
            5'd5,        // rd
            5'd2,        // rs1
            5'd3,        // rs2
            6'b0
        };


        #10;


        $display("========= SUMA =========");

        $display("ALU_OP=%d", alu_op);
        $display("RD=%d", rd);
        $display("RS1=%d", rs1);
        $display("RS2=%d", rs2);
        $display("IMM=%d", imm);
        $display("USE_IMM=%b", use_imm);



        // =====================================================
        // Caso 2: sumai x5,x2,10
        // =====================================================


        instruction = {
            7'b1000000, // TYPE_IMM
            4'b0000,    // OP_SUMI
            5'd2,        // rs1
            5'd5,        // rd
            11'd10
        };


        #10;


        $display("========= SUMAI =========");

        $display("ALU_OP=%d", alu_op);
        $display("RD=%d", rd);
        $display("RS1=%d", rs1);
        $display("IMM=%d", imm);
        $display("USE_IMM=%b", use_imm);



        // =====================================================
        // Caso 3: inválido
        // =====================================================


        instruction = 32'hFFFFFFFF;


        #10;


        $display("========= INVALID =========");

        $display("ALU_OP=%d", alu_op);
        $display("USE_IMM=%b", use_imm);



        $finish;


    end


endmodule