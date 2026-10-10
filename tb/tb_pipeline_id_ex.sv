`timescale 1ns/1ps


module tb_pipeline_id_ex;


    // ==================================================
    // Entradas
    // ==================================================

    logic clk;
    logic reset;

    logic [3:0] alu_op;

    logic [4:0] rd;

    logic [31:0] operand_a;
    logic [31:0] operand_b;

    logic [10:0] imm;

    logic use_imm;

    logic valid_in;


    // ==================================================
    // Salidas
    // ==================================================

    logic [3:0] alu_op_out;

    logic [4:0] rd_out;

    logic [31:0] operand_a_out;
    logic [31:0] operand_b_out;

    logic [10:0] imm_out;

    logic use_imm_out;

    logic valid_out;


    // ==================================================
    // Instancia del DUT
    // ==================================================

    pipeline_id_ex DUT (

        .clk(clk),

        .reset(reset),

        .flush(1'b0),

        .alu_op(alu_op),

        .rd(rd),

        .operand_a(operand_a),

        .operand_b(operand_b),

        .imm(imm),

        .use_imm(use_imm),

        .valid_in(valid_in),


        .alu_op_out(alu_op_out),

        .rd_out(rd_out),

        .operand_a_out(operand_a_out),

        .operand_b_out(operand_b_out),

        .imm_out(imm_out),

        .use_imm_out(use_imm_out),

        .valid_out(valid_out)

    );


    // ==================================================
    // Reloj
    // ==================================================

    always #5 clk = ~clk;


    // ==================================================
    // Pruebas
    // ==================================================

    initial begin

        $dumpfile("pipeline_id_ex.vcd");

        $dumpvars(0, tb_pipeline_id_ex);


        // ==================================================
        // Valores iniciales
        // ==================================================

        clk = 0;

        reset = 1;

        alu_op = 0;

        rd = 0;

        operand_a = 0;

        operand_b = 0;

        imm = 0;

        use_imm = 0;

        valid_in = 0;


        // ==================================================
        // Reset por un ciclo
        // ==================================================

        #10;

        reset = 0;


        // ==================================================
        // Caso 1: suma x5,x2,x3
        //
        // operand_a = 20
        // operand_b = 30
        // resultado esperado posteriormente = 50
        // ==================================================

        alu_op = 4'd0;

        rd = 5;

        operand_a = 20;

        operand_b = 30;

        imm = 0;

        use_imm = 0;

        valid_in = 1;


        #10;


        $display("========= SUMA =========");

        $display("ALU_OP=%d", alu_op_out);

        $display("RD=%d", rd_out);

        $display("OPERAND_A=%d", operand_a_out);

        $display("OPERAND_B=%d", operand_b_out);

        $display("IMM=%d", imm_out);

        $display("USE_IMM=%b", use_imm_out);

        $display("VALID=%b", valid_out);


        // ==================================================
        // Caso 2: sumai x7,x4,20
        //
        // operand_a = 10
        // immediate = 20
        //
        // La etapa ID/EX solamente transporta las señales.
        // ==================================================

        alu_op = 4'd0;

        rd = 7;

        operand_a = 10;

        operand_b = 20;

        imm = 20;

        use_imm = 1;

        valid_in = 1;


        #10;


        $display("========= SUMAI =========");

        $display("ALU_OP=%d", alu_op_out);

        $display("RD=%d", rd_out);

        $display("OPERAND_A=%d", operand_a_out);

        $display("OPERAND_B=%d", operand_b_out);

        $display("IMM=%d", imm_out);

        $display("USE_IMM=%b", use_imm_out);

        $display("VALID=%b", valid_out);


        $finish;

    end


endmodule