`timescale 1ns/1ps


module tb_top;


    logic clk;

    logic reset;



    logic [31:0] debug_result;

    logic [4:0] debug_rd;

    logic debug_write;



    top DUT (

        .clk(clk),

        .reset(reset),

        .debug_result(debug_result),

        .debug_rd(debug_rd),

        .debug_write(debug_write)

    );



    // reloj

    always #5 clk = ~clk;

    always @(posedge clk) begin

        if(debug_write) begin

            $display("==============================");

            $display("WRITE DETECTADO");

            $display("RESULTADO = %d", debug_result);

            $display("RD = x%d", debug_rd);

            $display("==============================");

        end

    end

initial begin

    $dumpfile("top.vcd");
    $dumpvars(0,tb_top);


    clk = 0;

    reset = 1;

    $display("RESET ACTIVO");


    #10;


    reset = 0;

    // El programa de instruction_memory asume x2 = 20 y x3 = 30. El banco de
    // registros ya no trae esos valores fijos en el RTL (el reset lo deja en
    // 0), así que el testbench los carga después del reset.
    DUT.REGFILE.regs[2] = 32'd20;
    DUT.REGFILE.regs[3] = 32'd30;

    $display("CPU INICIANDO");


    #300;

    $finish;

end


endmodule