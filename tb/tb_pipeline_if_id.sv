`timescale 1ns/1ps


module tb_pipeline_if_id;


    //Señales del DUT

    logic clk;
    logic reset;

    logic [127:0] bundle_in;
    logic [31:0] pc_in;
    logic valid_in;


    logic [127:0] bundle_out;
    logic [31:0] pc_out;
    logic valid_out;



    // Instancia del módulo bajo prueba

    pipeline_if_id DUT (

        .clk(clk),
        .reset(reset),

        .bundle_in(bundle_in),
        .pc_in(pc_in),
        .valid_in(valid_in),

        .bundle_out(bundle_out),
        .pc_out(pc_out),
        .valid_out(valid_out)

    );



    // Generador de reloj

    always #5 clk = ~clk;



    initial begin


        // Archivo para GTKWave

        $dumpfile("pipeline_if_id.vcd");
        $dumpvars(0, tb_pipeline_if_id);



        // Valores iniciales

        clk = 0;

        reset = 1;

        bundle_in = 128'b0;
        pc_in = 32'b0;
        valid_in = 0;

        // Espera un ciclo con reset

        #10;


        // Libera reset
        reset = 0;

        // Envia primer bundle
        pc_in = 32'h00001000;

        bundle_in = 128'h11112222333344445555666677778888;

        valid_in = 1;

        #10;

        $display(
            "Tiempo=%0t PC_IN=%h PC_OUT=%h VALID_OUT=%b",
            $time,
            pc_in,
            pc_out,
            valid_out
        );

        // Envia segundo bundle

        pc_in = 32'h00002000;

        bundle_in = 128'hAAAABBBBCCCCDDDDEEEEFFFF00001111;


        #10;

        $display(
            "Tiempo=%0t PC_IN=%h PC_OUT=%h VALID_OUT=%b",
            $time,
            pc_in,
            pc_out,
            valid_out
        );

        $finish;

    end

endmodule