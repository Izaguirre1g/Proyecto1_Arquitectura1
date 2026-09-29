`timescale 1ns/1ps


module tb_dispatch;

    // Entradas
    logic [127:0] bundle_in;
    logic valid_in;
    // Salidas
    logic [31:0] slot0_instr;
    logic [31:0] slot1_instr;
    logic [31:0] slot2_instr;
    logic [31:0] slot3_instr;

    logic valid_out;

    // Instancia del DUT

    dispatch DUT (
        .bundle_in(bundle_in),
        .valid_in(valid_in),

        .slot0_instr(slot0_instr),
        .slot1_instr(slot1_instr),
        .slot2_instr(slot2_instr),
        .slot3_instr(slot3_instr),

        .valid_out(valid_out)
    );

    initial begin
        // GTKWave
        $dumpfile("dispatch.vcd");
        $dumpvars(0, tb_dispatch);
        // Caso 1:
        // Bundle con valores conocidos

        valid_in = 1'b1;


        bundle_in = {
            32'hCCCCCCCC,   // Slot 3 CRYPTO
            32'hBBBBBBBB,   // Slot 2 BRU
            32'hAAAAAAAA,   // Slot 1 LSU
            32'h11111111    // Slot 0 ALU
        };


        #10;


        $display("========= Caso 1 =========");

        $display("Slot0 = %h", slot0_instr);
        $display("Slot1 = %h", slot1_instr);
        $display("Slot2 = %h", slot2_instr);
        $display("Slot3 = %h", slot3_instr);
        $display("Valid = %b", valid_out);



        // Caso 2:
        // Bundle diferente

        bundle_in = {
            32'h12345678,
            32'h87654321,
            32'hFEDCBA98,
            32'hABCDEF01
        };


        #10;

        $display("========= Caso 2 =========");

        $display("Slot0 = %h", slot0_instr);
        $display("Slot1 = %h", slot1_instr);
        $display("Slot2 = %h", slot2_instr);
        $display("Slot3 = %h", slot3_instr);
        $display("Valid = %b", valid_out);

        // Caso 3:
        // Bundle inválido

        valid_in = 1'b0;


        #10;

        $display("========= Caso 3 =========");
        $display("Valid = %b", valid_out);
        $finish;

    end

endmodule