`timescale 1ns/1ps


module tb_register_file;

    logic clk;
    // Lectura
    logic [4:0] rs1_addr;
    logic [4:0] rs2_addr;

    logic [31:0] rs1_data;
    logic [31:0] rs2_data;

    // Escritura
    logic [4:0] rd_addr;

    logic [31:0] write_data;

    logic reg_write;

    // Instancia del DUT

    register_file DUT (

        .clk(clk),

        .rs1_addr(rs1_addr),
        .rs2_addr(rs2_addr),

        .rs1_data(rs1_data),
        .rs2_data(rs2_data),

        .rd_addr(rd_addr),
        .write_data(write_data),

        .reg_write(reg_write)

    );

    // Reloj

    always #5 clk = ~clk;

    initial begin
        $dumpfile("register_file.vcd");
        $dumpvars(0,tb_register_file);
        clk = 0;
        // Valores iniciales

        rs1_addr = 0;
        rs2_addr = 0;

        rd_addr = 0;

        write_data = 0;

        reg_write = 0;

        #10;

        // ==================================================
        // Caso 1:
        // Leer x0
        // ==================================================

        rs1_addr = 0;

        #10;


        $display("========= LECTURA X0 =========");

        $display("x0 = %d", rs1_data);

        // ==================================================
        // Caso 2:
        // Escribir x5 = 123
        // ==================================================

        rd_addr = 5;

        write_data = 123;

        reg_write = 1;

        #10;

        reg_write = 0;

        // Leer x5

        rs1_addr = 5;

        #10;

        $display("========= ESCRITURA X5 =========");

        $display("x5 = %d", rs1_data);

        // ==================================================
        // Caso 3:
        // Escribir x0
        // ==================================================

        rd_addr = 0;

        write_data = 999;

        reg_write = 1;

        #10;

        reg_write = 0;

        rs1_addr = 0;

        #10;

        $display("========= PROTECCION X0 =========");

        $display("x0 = %d", rs1_data);

        // ==================================================
        // Caso 4:
        // Dos lecturas simultaneas
        // ==================================================

        rs1_addr = 5;

        rs2_addr = 0;


        #10;

        $display("========= DOS LECTURAS =========");

        $display("RS1 = %d", rs1_data);

        $display("RS2 = %d", rs2_data);

        $finish;

    end
endmodule