`timescale 1ns/1ps

// Adaptador de simulación para el ensamblador. Se carga la memoria existente
// por jerarquía, como tb_regfile_pipeline, sin modificar top ni el RTL.
`include "isa_defs.sv"

module tb_assembled_program;
    logic clk = 0;
    logic reset = 1;
    wire [31:0] debug_result;
    wire [4:0] debug_rd;
    wire debug_write;
    string mem_path, dump_path, wave_path, data_dump_path;
    integer bundles, dump_fd, cycles, data_fd;

    top DUT (
        .clk(clk), .reset(reset),
        .debug_result(debug_result), .debug_rd(debug_rd),
        .debug_write(debug_write)
    );

    always #5 clk = ~clk;

    always @(posedge clk) begin
        if (!reset && DUT.wb_conflict !== 1'b0)
            $fatal(1, "[FAIL] conflicto o estado indeterminado de writeback");
    end

    // Traza dinámica (+TRACE=<archivo>): ciclo a ciclo, cada registro escrito
    // (valor anterior y nuevo), cada escritura en memoria, cada cambio de
    // ESTADO, cada salto tomado y cada excepción. run_program.py le agrega el
    // texto del bundle.
    string  trace_path;
    integer trace_fd = 0;
    integer ciclo = 1;          // ciclo 1: el bundle 0 está en IF; llega a WB en el ciclo 4
    logic [31:0] wb_pc = 0;     // PC del bundle en WB: estaba en EX el ciclo anterior

    always @(posedge clk) begin
        ciclo <= reset ? 1 : ciclo + 1;
        wb_pc <= DUT.ex_pc;
    end

    always @(negedge clk) begin
        if (trace_fd && !reset) begin
            for (int p = 0; p < 5; p++)
                if (DUT.wb_we[p] && DUT.wb_waddr[p] != 5'd0)
                    $fdisplay(trace_fd, "%0d REG %08x %0d %08x %08x", ciclo, wb_pc, DUT.wb_waddr[p],
                              DUT.REGFILE.regs[DUT.wb_waddr[p]], DUT.wb_wdata[p]);
            if (DUT.CRYPTO.auth_we_d || DUT.CRYPTO.init_clr_d)     // ESTADO se escribe al final de WB
                $fdisplay(trace_fd, "%0d ESTADO %08x %b%b %b%b", ciclo, wb_pc, DUT.CRYPTO.init, DUT.CRYPTO.auth,
                          DUT.CRYPTO.init_clr_d ? 1'b0 : DUT.CRYPTO.init,
                          DUT.CRYPTO.auth_we_d ? DUT.CRYPTO.auth_d : DUT.CRYPTO.auth);
            if (DUT.mem_we)
                $fdisplay(trace_fd, "%0d MEM %08x %08x %08x %04b", ciclo, DUT.ex_pc, DUT.mem_addr,
                          DUT.mem_wdata, DUT.mem_be);
            if (DUT.crypto_mem_we)
                $fdisplay(trace_fd, "%0d MEM %08x %08x %08x 1111", ciclo, DUT.ex_pc, DUT.crypto_mem_addr,
                          DUT.crypto_mem_wdata);
            if (DUT.crypto_fault)
                $fdisplay(trace_fd, "%0d TRAP %08x %08x", ciclo, DUT.ex_pc, TRAP_VECTOR);
            else if (DUT.branch_flush)
                $fdisplay(trace_fd, "%0d JUMP %08x %08x", ciclo, DUT.ex_pc, DUT.bru_target_pc);
        end
    end

    initial begin
        if (!$value$plusargs("MEM=%s", mem_path) ||
            !$value$plusargs("REGDUMP=%s", dump_path) ||
            !$value$plusargs("BUNDLES=%d", bundles))
            $fatal(1, "[FAIL] faltan +MEM, +REGDUMP o +BUNDLES");
        if (!$value$plusargs("MEMDUMP=%s", data_dump_path) ||
            !$value$plusargs("CYCLES=%d", cycles))
            $fatal(1, "[FAIL] faltan MEMDUMP o CYCLES");
        if ($value$plusargs("TRACE=%s", trace_path)) begin
            trace_fd = $fopen(trace_path, "w");
            if (!trace_fd) $fatal(1, "[FAIL] no se puede escribir la traza");
        end
        // La memoria tiene IMEM_BUNDLES entradas. Se reservan 4 ciclos para
        // completar IF -> ID -> EX -> WB -> REGFILE antes de salir de ella.
        if (bundles < 1 || bundles > IMEM_BUNDLES - 4)
            $fatal(1, "[FAIL] esta prueba admite 1..%0d bundles de programa", IMEM_BUNDLES - 4);
        if ($value$plusargs("VCD=%s", wave_path)) begin
            $dumpfile(wave_path);
            $dumpvars(0, tb_assembled_program);
        end

        // instruction_memory ejecuta su initial en t=0; cargar después.
        #1;
        for (int i = 0; i < IMEM_BUNDLES; i++) DUT.IMEM.memory[i] = 128'b0;
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
        if (trace_fd) $fclose(trace_fd);
        $finish;
    end

    initial begin
        #1000100;
        $fatal(1, "[FAIL] tiempo máximo excedido");
    end
endmodule
