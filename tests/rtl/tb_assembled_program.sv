`timescale 1ns/1ps

// Adaptador de simulación para el ensamblador. Se carga la memoria existente
// por jerarquía, como tb_regfile_pipeline, sin modificar cpu_top ni el RTL.
module tb_assembled_program;
    logic clk = 0;
    logic reset = 1;
    wire [31:0] debug_result;
    wire [4:0] debug_rd;
    wire debug_write;
    string mem_path, dump_path, wave_path, data_dump_path;
    integer bundles, dump_fd, cycles, data_fd;

    cpu_top DUT (
        .clk(clk), .reset(reset),
        .debug_result(debug_result), .debug_rd(debug_rd),
        .debug_write(debug_write)
    );

    always #5 clk = ~clk;

    always @(posedge clk) begin
        if (!reset && DUT.wb_conflict !== 1'b0)
            $fatal(1, "[FAIL] conflicto o estado indeterminado de writeback");
    end

    initial begin
        if (!$value$plusargs("MEM=%s", mem_path) ||
            !$value$plusargs("REGDUMP=%s", dump_path) ||
            !$value$plusargs("BUNDLES=%d", bundles))
            $fatal(1, "[FAIL] faltan +MEM, +REGDUMP o +BUNDLES");
        if (!$value$plusargs("MEMDUMP=%s", data_dump_path) ||
            !$value$plusargs("CYCLES=%d", cycles))
            $fatal(1, "[FAIL] faltan MEMDUMP o CYCLES");
        // La memoria tiene 32 entradas. Se reservan 4 ciclos para completar
        // FETCH -> IF/ID -> ID/EX -> EX/WB -> REGFILE antes de salir de ella.
        if (bundles < 1 || bundles > 28)
            $fatal(1, "[FAIL] esta prueba admite 1..28 bundles de programa");
        if ($value$plusargs("VCD=%s", wave_path)) begin
            $dumpfile(wave_path);
            $dumpvars(0, tb_assembled_program);
        end

        // instruction_memory ejecuta su initial en t=0; cargar después.
        #1;
        for (int i = 0; i < 32; i++) DUT.IMEM.memory[i] = 128'b0;
        $readmemh(mem_path, DUT.IMEM.memory, 0, bundles - 1);
        for (int i = 0; i < bundles; i++)
            if ((^DUT.IMEM.memory[i]) === 1'bx)
                $fatal(1, "[FAIL] bundle %0d incompleto o desconocido", i);

        repeat (2) @(negedge clk);
        reset = 0;
        // El último bundle completa su escritura cuatro flancos después
        // de ser capturado por FETCH. Se observa el banco después del NBA.
        repeat (cycles) @(posedge clk);
        #1;
        dump_fd = $fopen(dump_path, "w");
        if (!dump_fd) $fatal(1, "[FAIL] no se puede escribir el dump de registros");
        for (int r = 0; r < 32; r++) begin
            if ((^DUT.REGFILE.regs[r]) === 1'bx)
                $fatal(1, "[FAIL] x%0d contiene X/Z", r);
            $fdisplay(dump_fd, "x%0d %08x", r, DUT.REGFILE.regs[r]);
        end
        $fclose(dump_fd);
        data_fd = $fopen(data_dump_path, "w");
        if (!data_fd) $fatal(1, "[FAIL] no se puede escribir el dump de memoria");
        for (int m = 0; m < 16384; m++) $fdisplay(data_fd, "%08x", DUT.DMEM.mem[m]);
        $fclose(data_fd);
        if (DUT.REGFILE.regs[0] !== 32'b0)
            $fatal(1, "[FAIL] x0 dejó de ser cero");
        $display("[OK] programa ejecutado: %0d bundles; 32 registros definidos", bundles);
        $finish;
    end

    initial begin
        #1000100;
        $fatal(1, "[FAIL] tiempo máximo excedido");
    end
endmodule
