`timescale 1ns/1ps


module tb_wb;


    logic [31:0] result_in;

    logic [4:0] rd_in;

    logic valid_in;


    logic [31:0] write_data;

    logic [4:0] rd_out;

    logic reg_write;

    wb DUT (

        .result_in(result_in),

        .rd_in(rd_in),

        .valid_in(valid_in),


        .write_data(write_data),

        .rd_out(rd_out),

        .reg_write(reg_write)

    );


    initial begin


        $dumpfile("wb.vcd");
        $dumpvars(0,tb_wb);

        // =====================================
        // Caso 1: Escritura válida
        // =====================================

        result_in = 32'd50;

        rd_in = 5'd5;

        valid_in = 1'b1;


        #10;


        $display("========= WB VALIDO =========");

        $display("WRITE DATA = %d", write_data);

        $display("RD = %d", rd_out);

        $display("REG WRITE = %b", reg_write);

        // =====================================
        // Caso 2: Instrucción inválida
        // =====================================

        result_in = 32'd100;

        rd_in = 5'd8;

        valid_in = 1'b0;


        #10;


        $display("========= WB INVALIDO =========");

        $display("WRITE DATA = %d", write_data);

        $display("RD = %d", rd_out);

        $display("REG WRITE = %b", reg_write);

        $finish;
    end
endmodule