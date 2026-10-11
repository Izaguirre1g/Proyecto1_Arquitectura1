`timescale 1ns/1ps

// Fixture para r = (a + b) - 1, emitido por test_generacion --ejemplo.
// Inicializar gp/datos aquí no sustituye el arranque del compilador completo.
`include "isa_defs.sv"

module tb_ce1108_program;
    logic clk = 0, reset = 1;
    string mem_path;
    integer bundles;
    top DUT (.clk(clk), .reset(reset), .debug_result(), .debug_rd(), .debug_write());
    always #5 clk = ~clk;

    initial begin
        if (!$value$plusargs("MEM=%s", mem_path) || !$value$plusargs("BUNDLES=%d", bundles))
            $fatal(1, "[FAIL] faltan MEM y BUNDLES");
        if (bundles < 1 || bundles > IMEM_BUNDLES - 4) $fatal(1, "[FAIL] capacidad de IMEM");
        #1;
        for (int i = 0; i < IMEM_BUNDLES; i++) DUT.IMEM.memory[i] = 0;
        $readmemh(mem_path, DUT.IMEM.memory, 0, bundles - 1);
        for (int i = 0; i < bundles; i++)
            if ((^DUT.IMEM.memory[i]) === 1'bx) $fatal(1, "[FAIL] bundle desconocido");
        repeat (2) @(negedge clk);
        DUT.REGFILE.regs[3] = 32'h4000;
        DUT.DMEM.mem[4096] = 8;
        DUT.DMEM.mem[4097] = 3;
        DUT.DMEM.mem[4098] = 32'hdeadbeef;
        reset = 0;
        repeat (bundles + 4) @(posedge clk);
        #1;
        if (DUT.DMEM.mem[4098] !== 32'd10)
            $fatal(1, "[FAIL] CE1108: r=%08x; esperado=0000000a", DUT.DMEM.mem[4098]);
        if (DUT.DMEM.mem[4096] !== 8 || DUT.DMEM.mem[4097] !== 3)
            $fatal(1, "[FAIL] se modificaron a/b");
        $display("[PASS] expresión CE1108: (8 + 3) - 1 = 10");
        $finish;
    end
    initial begin
        #100000;
        $fatal(1, "[FAIL] tiempo máximo excedido");
    end
endmodule
