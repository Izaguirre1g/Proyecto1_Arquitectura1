`timescale 1ns/1ps
module tb_id_stage;
    logic clk;
    logic reset;

    logic [31:0] instruction;

    // Señales WB

    logic [4:0] wb_rd;
    logic [31:0] wb_data;
    logic wb_enable;



    // Salidas ID

    logic [3:0] alu_op;

    logic [31:0] operand_a;
    logic [31:0] operand_b;

    logic [4:0] rd;

    logic [10:0] imm;

    logic use_imm;



    // El banco de registros vive en top; aquí se instancia aparte con la
    // configuración de 2 lecturas y 1 escritura (sólo el slot ALU).

    logic [4:0] rs1;
    logic [4:0] rs2;

    logic [31:0] rs1_data;
    logic [31:0] rs2_data;

    regfile #(

        .NUM_READ_PORTS(2),
        .NUM_WRITE_PORTS(1)

    ) registers (

        .clk(clk),
        .reset(reset),

        .raddr({rs2, rs1}),
        .rdata({rs2_data, rs1_data}),

        .we(wb_enable),
        .waddr(wb_rd),
        .wdata(wb_data)

    );

    id_stage DUT (

        .instruction(instruction),

        .rs1(rs1),
        .rs2(rs2),
        .rs1_data(rs1_data),
        .rs2_data(rs2_data),

        .alu_op(alu_op),

        .operand_a(operand_a),
        .operand_b(operand_b),

        .rd(rd),

        .imm(imm),

        .use_imm(use_imm)

    );



    always #5 clk = ~clk;



    initial begin


        $dumpfile("id_stage.vcd");
        $dumpvars(0,tb_id_stage);



        clk = 0;
        reset = 0;


        instruction = 0;


        wb_rd = 0;
        wb_data = 0;
        wb_enable = 0;



        // =================================================
        // Inicializar registros
        //
        // x2 = 20
        // x3 = 30
        //
        // Usamos WB para escribir
        // =================================================


        wb_rd = 5'd2;
        wb_data = 32'd20;
        wb_enable = 1;


        #10;


        wb_rd = 5'd3;
        wb_data = 32'd30;


        #10;


        wb_enable = 0;



        // =================================================
        // suma x5,x2,x3
        // =================================================


        instruction = {

            7'b1101010, // TYPE_REG

            4'b1000,    // OP_SUM

            5'd5,       // rd

            5'd2,       // rs1

            5'd3,       // rs2

            6'b0

        };



        #10;



        $display("========= SUMA =========");


        $display("ALU_OP = %d", alu_op);

        $display("RD = %d", rd);

        $display("OPERAND A = %d", operand_a);

        $display("OPERAND B = %d", operand_b);

        $display("USE IMM = %b", use_imm);



        // =================================================
        // sumai x6,x2,10
        // =================================================


        instruction = {

            7'b1000000, // TYPE_IMM

            4'b0000,    // SUMAI

            5'd2,       // rs1

            5'd6,       // rd

            11'd10

        };


        #10;



        $display("========= SUMAI =========");


        $display("ALU_OP = %d", alu_op);

        $display("RD = %d", rd);

        $display("OPERAND A = %d", operand_a);

        $display("OPERAND B = %d", operand_b);

        $display("USE IMM = %b", use_imm);



        $finish;


    end


endmodule