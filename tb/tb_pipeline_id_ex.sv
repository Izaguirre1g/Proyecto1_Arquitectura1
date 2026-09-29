`timescale 1ns/1ps


module tb_pipeline_id_ex;


    // Entradas

    logic clk;
    logic reset;


    logic [3:0] alu_op;

    logic [4:0] rd;
    logic [4:0] rs1;
    logic [4:0] rs2;

    logic [10:0] imm;

    logic use_imm;

    logic valid_in;



    // Salidas

    logic [3:0] alu_op_out;

    logic [4:0] rd_out;
    logic [4:0] rs1_out;
    logic [4:0] rs2_out;

    logic [10:0] imm_out;

    logic use_imm_out;

    logic valid_out;



    // Instancia DUT

    pipeline_id_ex DUT (

        .clk(clk),
        .reset(reset),

        .alu_op(alu_op),

        .rd(rd),
        .rs1(rs1),
        .rs2(rs2),

        .imm(imm),

        .use_imm(use_imm),

        .valid_in(valid_in),


        .alu_op_out(alu_op_out),

        .rd_out(rd_out),
        .rs1_out(rs1_out),
        .rs2_out(rs2_out),

        .imm_out(imm_out),

        .use_imm_out(use_imm_out),

        .valid_out(valid_out)

    );



    // Reloj

    always #5 clk = ~clk;



    initial begin


        $dumpfile("pipeline_id_ex.vcd");
        $dumpvars(0,tb_pipeline_id_ex);



        // Valores iniciales

        clk = 0;

        reset = 1;

        alu_op = 0;

        rd = 0;
        rs1 = 0;
        rs2 = 0;

        imm = 0;

        use_imm = 0;

        valid_in = 0;



        // Reset por un ciclo

        #10;



        reset = 0;



        // ==================================================
        // Caso 1: suma x5,x2,x3
        // ==================================================

        alu_op = 4'd0; // ALU_ADD

        rd = 5;

        rs1 = 2;

        rs2 = 3;

        imm = 0;

        use_imm = 0;

        valid_in = 1;



        #10;


        $display("========= SUMA =========");

        $display("ALU_OP=%d", alu_op_out);
        $display("RD=%d", rd_out);
        $display("RS1=%d", rs1_out);
        $display("RS2=%d", rs2_out);
        $display("IMM=%d", imm_out);
        $display("USE_IMM=%b", use_imm_out);
        $display("VALID=%b", valid_out);



        // ==================================================
        // Caso 2: sumai x7,x4,20
        // ==================================================

        alu_op = 4'd0;

        rd = 7;

        rs1 = 4;

        rs2 = 0;

        imm = 20;

        use_imm = 1;



        #10;



        $display("========= SUMAI =========");

        $display("ALU_OP=%d", alu_op_out);
        $display("RD=%d", rd_out);
        $display("RS1=%d", rs1_out);
        $display("IMM=%d", imm_out);
        $display("USE_IMM=%b", use_imm_out);
        $display("VALID=%b", valid_out);



        $finish;


    end


endmodule