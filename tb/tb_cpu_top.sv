`timescale 1ns/1ps


module tb_cpu_top;


    logic clk;

    logic reset;


    // Memoria de instrucciones simulada

    logic [127:0] instruction_bundle;



    // DUT

    cpu_top DUT (

        .clk(clk),

        .reset(reset),

        .instruction_bundle(instruction_bundle)

    );



    // Reloj

    always #5 clk = ~clk;



    initial begin


        $dumpfile("cpu_top.vcd");

        $dumpvars(0,tb_cpu_top);



        clk = 0;

        reset = 1;


        instruction_bundle = 128'b0;



        // =====================================
        // Reset inicial
        // =====================================

        #10;


        reset = 0;



        // =====================================
        // Instrucción:
        //
        // suma x5,x2,x3
        //
        // slot 0
        //
        // =====================================


        instruction_bundle[31:0] = {

            7'b1101010,   // TYPE REG

            4'b1000,      // SUMA

            5'd5,         // rd

            5'd2,         // rs1

            5'd3,         // rs2

            6'b0

        };



        // Los demás slots quedan como NOP

        instruction_bundle[63:32]   = 32'b0;

        instruction_bundle[95:64]   = 32'b0;

        instruction_bundle[127:96]  = 32'b0;



        // Esperar varios ciclos del pipeline

        #50;



        $display("==============================");

        $display("Fin prueba CPU TOP");

        $display("==============================");



        $finish;


    end


endmodule