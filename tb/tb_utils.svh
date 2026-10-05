/*
================================================================================
 Archivo: tb_utils.svh

 Descripción:
 ------------------------------------------------------------------------------
 Utilidades comunes para que los testbenches del proyecto sean
 autoverificables y tengan el mismo formato de salida. Se incluye DENTRO del
 módulo del testbench:

     module tb_modulo;

         `include "tb_utils.svh"
         ...
         initial begin
             $dumpfile("tb_modulo.vcd");
             $dumpvars(0, tb_modulo);
             ...
             check("suma 10+5", result, 32'd15);
             ...
             tb_finish("tb_modulo");
         end
     endmodule

 Contenido:
 ------------------------------------------------------------------------------
 - tb_checks, tb_errors      contadores de verificaciones y de fallos.
 - tb_section(nombre)        imprime el encabezado de un grupo de pruebas.
 - check(nombre, obt, esp)   compara dos valores de hasta 32 bits con !==,
                             de modo que un X o Z en el valor obtenido también
                             cuenta como fallo.
 - check_true(nombre, cond)  verifica que una condición sea 1.
 - tb_finish(nombre)         imprime el resumen y termina la simulación:
                               [PASS] nombre ...  -> $finish (código de salida 0)
                               [FAIL] nombre ...  -> $fatal  (código de salida 1)
 - Watchdog: si la simulación supera `TB_TIMEOUT unidades de tiempo, termina
   con [FAIL]. Para cambiarlo, definir la macro antes del `include.

 Plusargs (make tb_x PLUSARGS=+verbose):
 ------------------------------------------------------------------------------
 - +verbose  imprime también las verificaciones que pasan.

 El Makefile usa las líneas [PASS] / [FAIL] y el código de salida para el
 resumen de make sim.

================================================================================
*/

`ifndef TB_TIMEOUT
`define TB_TIMEOUT 1000000
`endif


int tb_checks = 0;
int tb_errors = 0;

bit tb_verbose = 1'b0;


initial begin

    if($test$plusargs("verbose"))
        tb_verbose = 1'b1;
end


// Watchdog

initial begin

    #(`TB_TIMEOUT);

    $display("[FAIL] %m: la simulación superó %0d unidades de tiempo", `TB_TIMEOUT);

    $fatal(1, "timeout");
end


task automatic tb_section(input string name);

    $display("--- %s", name);
endtask


task automatic check(input string name, input logic [31:0] got, input logic [31:0] exp);

    tb_checks++;

    if(got !== exp) begin

        tb_errors++;

        $display("  [FAIL] %s: obtenido=0x%08h esperado=0x%08h", name, got, exp);
    end
    else if(tb_verbose)

        $display("  [ ok ] %s = 0x%08h", name, got);
endtask


task automatic check_true(input string name, input logic cond);

    tb_checks++;

    if(cond !== 1'b1) begin

        tb_errors++;

        $display("  [FAIL] %s", name);
    end
    else if(tb_verbose)

        $display("  [ ok ] %s", name);
endtask


task automatic tb_finish(input string name);

    if(tb_errors == 0) begin

        $display("[PASS] %s: %0d verificaciones correctas", name, tb_checks);

        $finish;
    end
    else begin

        $display("[FAIL] %s: %0d de %0d verificaciones fallaron", name, tb_errors, tb_checks);

        $fatal(1, "%s terminó con errores", name);
    end
endtask
