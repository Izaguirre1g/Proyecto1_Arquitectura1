`timescale 1ns/1ps


module tb_pipeline_ex_wb;


    logic clk;
    logic reset;


    // Entradas desde EX

    logic [31:0] result_in;

    logic [4:0] rd_in;

    logic valid_in;



    // Salidas hacia WB

    logic [31:0] result_out;

    logic [4:0] rd_out;

    logic valid_out;



    // DUT

    pipeline_ex_wb DUT (

        .clk(clk),

        .reset(reset),


        .result_in(result_in),

        .rd_in(rd_in),

        .valid_in(valid_in),


        .result_out(result_out),

        .rd_out(rd_out),

        .valid_out(valid_out)

    );



    // Reloj

    always #5 clk = ~clk;



    initial begin


        $dumpfile("pipeline_ex_wb.vcd");
        $dumpvars(0,tb_pipeline_ex_wb);



        clk = 0;

        reset = 1;


        result_in = 0;

        rd_in = 0;

        valid_in = 0;



        // ==================================
        // Reset
        // ==================================

        #10;


        reset = 0;



        // ==================================
        // Caso 1:
        // Resultado ALU válido
        //
        // x5 = 50
        // ==================================


        result_in = 32'd50;

        rd_in = 5;

        valid_in = 1;



        #10;



        $display("========= EX/WB =========");


        $display("RESULTADO = %d", result_out);

        $display("RD = %d", rd_out);

        $display("VALID = %b", valid_out);



        // ==================================
        // Caso 2:
        // Burbuja
        // ==================================


        result_in = 32'd100;

        rd_in = 8;

        valid_in = 0;



        #10;



        $display("========= BURBUJA =========");
        $display("RESULTADO = %d", result_out);
        $display("RD = %d", rd_out);
        $display("VALID = %b", valid_out);
        $finish;
    end
endmodule