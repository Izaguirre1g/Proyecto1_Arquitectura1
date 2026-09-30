`timescale 1ns/1ps


module tb_cpu_top;


    logic clk;

    logic reset;



    logic [31:0] debug_result;

    logic [4:0] debug_rd;

    logic debug_write;



    cpu_top DUT (

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

    $dumpfile("cpu_top.vcd");
    $dumpvars(0,tb_cpu_top);


    clk = 0;

    reset = 1;

    $display("RESET ACTIVO");


    #10;


    reset = 0;

    $display("CPU INICIANDO");


    #100;

    $finish;

end


endmodule