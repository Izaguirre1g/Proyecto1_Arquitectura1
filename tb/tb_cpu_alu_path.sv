`timescale 1ns/1ps


module tb_cpu_alu_path;


    logic clk;


    // Señales WB hacia Register File

    wire [4:0] wb_rd;
    wire [31:0] wb_data;
    wire wb_enable;



    // Instrucción

    logic [31:0] instruction;



    // Salidas ID

    logic [3:0] alu_op;

    logic [31:0] operand_a;
    logic [31:0] operand_b;

    logic [4:0] rd;

    logic [10:0] imm;

    logic use_imm;



    // Resultado EX

    logic [31:0] result;



    // ===================================
    // ID
    // ===================================

    logic [4:0] rs1;
    logic [4:0] rs2;
    logic [31:0] rs1_data;
    logic [31:0] rs2_data;

    // El banco de registros vive en cpu_top; aquí se instancia aparte con 2
    // lecturas y 1 escritura (sólo el slot ALU).
    regfile #(

        .NUM_READ_PORTS(2),
        .NUM_WRITE_PORTS(1)

    ) REGFILE (

        .clk(clk),
        .reset(1'b0),

        .raddr({rs2, rs1}),
        .rdata({rs2_data, rs1_data}),

        .we(wb_enable),
        .waddr(wb_rd),
        .wdata(wb_data)

    );

    id_stage ID (

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



    // ===================================
    // EX
    // ===================================

    ex_stage EX (

        .alu_op(alu_op),

        .operand_a(operand_a),

        .operand_b(operand_b),

        .rd(rd),

        .valid_in(1'b1),


        .result(result),

        .rd_out(),

        .valid_out()

    );



    // ===================================
    // WB
    // ===================================

    wire [4:0] wb_we;
    wire [4:0][4:0] wb_waddr;
    wire [4:0][31:0] wb_wdata;

    wb WB (

        .alu_we(1'b1),

        .alu_rd(rd),

        .alu_data(result),

        .lsu_we(1'b0),
        .lsu_rd(5'd0),
        .lsu_data(32'd0),

        .bru_we(1'b0),
        .bru_rd(5'd0),
        .bru_data(32'd0),

        .crypto_we(1'b0),
        .crypto_rd(5'd0),
        .crypto_data_l(32'd0),
        .crypto_data_r(32'd0),

        .we(wb_we),

        .waddr(wb_waddr),

        .wdata(wb_wdata),

        .conflict()

    );

    // El banco de este testbench tiene un solo puerto de escritura: el de la ALU
    assign wb_enable = wb_we[0];
    assign wb_rd = wb_waddr[0];
    assign wb_data = wb_wdata[0];



    always #5 clk = ~clk;



    initial begin


        $dumpfile("cpu_alu_path.vcd");
        $dumpvars(0,tb_cpu_alu_path);



        clk = 0;

        // x2 y x3 ya no vienen fijos en el RTL del banco de registros
        REGFILE.regs[2] = 32'd20;
        REGFILE.regs[3] = 32'd30;


        // =====================================
        // Ejecutar:
        //
        // suma x5,x2,x3
        //
        // x2 = 20
        // x3 = 30
        //
        // Resultado esperado:
        // x5 = 50
        // =====================================


        instruction = {

            7'b1101010,   // TYPE_REG

            4'b1000,      // SUMA

            5'd5,         // rd

            5'd2,         // rs1

            5'd3,         // rs2

            6'b0

        };


        #10;



        $display("==============================");

        $display("Resultado ALU = %d", result);

        $display("Destino = x%d", wb_rd);

        $display("Escritura = %b", wb_enable);

        $display("==============================");



        $finish;


    end


endmodule