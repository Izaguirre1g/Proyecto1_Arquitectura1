`timescale 1ns/1ps

/*
================================================================================
 Testbench: tb_archivo

 Descripción:
 ------------------------------------------------------------------------------
 Cifra y descifra un archivo real en el procesador. Lo ejecuta "make archivo"
 (ver Makefile), que antes prepara los archivos de entrada:

     tools/assembler.py   examples/cifrar_archivo.asm    -> cifrar.mem
     tools/assembler.py   examples/descifrar_archivo.asm -> descifrar.mem
     tools/load_file.py   --input <archivo> --address 0x200 -> datos.mem

 Pasos:
   1. Carga datos.mem en la memoria de datos y escribe en 0x100..0x11F la
      contraseña, la candidata, la dirección de fin (0x200 + tamaño
      redondeado a 8 bytes) y la llave.
   2. Ejecuta el programa de cifrado hasta su bucle final (sye x0, fin) y
      guarda la memoria en cifrado.mem con $writememh.
   3. Aplica reset (borra el banco y la bóveda; la memoria de datos se
      mantiene), ejecuta el programa de descifrado y guarda descifrado.mem.
   4. Verifica que ningún programa generó una excepción, que el cifrado
      cambió el archivo, que no se tocó la memoria después del archivo y que
      el descifrado devolvió exactamente el original.

 Después, "make archivo" extrae cifrado.bin y descifrado.bin con
 tools/extract_data.py y compara descifrado.bin con el archivo original.

 Con +SOLO_DESCIFRAR ("make descifrar") el archivo cargado ya viene cifrado:
 solo se ejecuta el programa de descifrado, se verifica que no haya
 excepciones ni cambios fuera del archivo y se guarda descifrado.mem.

 Plusargs:
     +CIFRAR=<.mem>  +DESCIFRAR=<.mem>  +DATOS=<.mem>  +BYTES=<tamaño en bytes>
     +K0=<hex> ... +K3=<hex>  llave (K0 es la de la primera ronda); si no se
                     indica, se usa la llave fija de los ejemplos
     +SOLO_DESCIFRAR solo descifra (no necesita +CIFRAR)
     +MAXCICLOS=<n>  límite de ciclos por programa (por defecto 1000000)

================================================================================
*/

`include "isa_defs.sv"


module tb_archivo;

// El archivo más grande (64 KB menos 0x200) necesita unos 165 000 ciclos por
// programa; el watchdog de tb_utils.svh debe cubrir los dos programas.
`define TB_TIMEOUT 50000000
`include "tb_utils.svh"


logic clk;
logic reset;

top DUT (
    .clk(clk),
    .reset(reset),
    .debug_result(),
    .debug_rd(),
    .debug_write()
);

always #5 clk = ~clk;


// ============================================================================
// Contraseña fija y llave (por defecto, la de los ejemplos de docs)
// ============================================================================

localparam logic [31:0] BASE = 32'h200;
localparam logic [31:0] PWD  = 32'h5EC2_E7A1;

logic [3:0][31:0] key;

string  cifrar_file, descifrar_file, datos_file;
integer bytes, max_cycles;
logic [31:0] fin;

logic [31:0] original [0:DMEM_BYTES/4-1];     // memoria de datos antes de cifrar


// Carga un programa en la memoria de instrucciones (el resto queda en NOP)
task automatic load_program(input string path);

    int n;

    for (int i = 0; i < IMEM_BUNDLES; i++)
        DUT.IMEM.memory[i] = '0;

    n = DUT.IMEM.count_bundles(path);
    if (n <= 0)
        $fatal(1, "[FAIL] no se pudo leer el programa %s", path);

    $readmemh(path, DUT.IMEM.memory, 0, n - 1);
    $display("tb_archivo: programa %s (%0d bundles)", path, n);
endtask

// Aplica reset, ejecuta hasta el bucle final (un sye que salta a sí mismo)
// y devuelve los ciclos usados
task automatic run_until_end(input string name, output int cycles);

    @(negedge clk);
    reset = 1;
    repeat (2) @(negedge clk);
    reset = 0;

    cycles = 0;
    while (!(DUT.branch_flush && DUT.bru_target_pc == DUT.ex_pc) && cycles < max_cycles) begin

        @(negedge clk);
        cycles++;
    end

    check_true({name, ": llegó al final del programa"}, cycles < max_cycles);
    check({name, ": sin excepciones"}, DUT.trap_count, 32'd0);
endtask


initial begin

    int   cycles_enc, cycles_dec;
    int   changed, wrong, outside, k_given;
    bit   solo_descifrar;
    logic [31:0] k;

    clk   = 0;
    reset = 1;

    solo_descifrar = $test$plusargs("SOLO_DESCIFRAR");

    if ((!solo_descifrar && !$value$plusargs("CIFRAR=%s", cifrar_file)) ||
        !$value$plusargs("DESCIFRAR=%s", descifrar_file) ||
        !$value$plusargs("DATOS=%s", datos_file) ||
        !$value$plusargs("BYTES=%d", bytes))
        $fatal(1, "[FAIL] faltan +CIFRAR, +DESCIFRAR, +DATOS o +BYTES (use make archivo o make descifrar)");

    if (!$value$plusargs("MAXCICLOS=%d", max_cycles))
        max_cycles = 1000000;

    fin = BASE + ((bytes + 7) / 8) * 8;

    if (bytes <= 0 || fin > DMEM_BYTES)
        $fatal(1, "[FAIL] el archivo debe medir entre 1 y %0d bytes", DMEM_BYTES - BASE);

    key = {32'hC3D2_E1F0, 32'h8796_A5B4, 32'h4B5A_6978, 32'h0F1E_2D3C};

    // Llave por parámetro: las 4 palabras o ninguna
    k_given = 0;
    if ($value$plusargs("K0=%h", k)) begin key[0] = k; k_given++; end
    if ($value$plusargs("K1=%h", k)) begin key[1] = k; k_given++; end
    if ($value$plusargs("K2=%h", k)) begin key[2] = k; k_given++; end
    if ($value$plusargs("K3=%h", k)) begin key[3] = k; k_given++; end

    if (k_given != 0 && (k_given != 4 || $isunknown(key)))
        $fatal(1, "[FAIL] la llave necesita 4 palabras hexadecimales: +K0 +K1 +K2 +K3");

    if (solo_descifrar && bytes % 8 != 0)
        $display("tb_archivo: aviso: un archivo cifrado con Feistel4 mide un múltiplo de 8 bytes");

    // Esperar la inicialización de las memorias
    #1;


    tb_section("1. Carga del archivo");

    $readmemh(datos_file, DUT.DMEM.mem);

    DUT.DMEM.mem[32'h100 >> 2] = PWD;           // contraseña inicial
    DUT.DMEM.mem[32'h104 >> 2] = PWD;           // candidata
    DUT.DMEM.mem[32'h108 >> 2] = fin;           // fin del archivo
    for (int i = 0; i < 4; i++)
        DUT.DMEM.mem[(32'h110 >> 2) + i] = key[i];

    for (int a = 0; a < DMEM_BYTES / 4; a++)
        original[a] = DUT.DMEM.mem[a];

    $display("tb_archivo: %0d bytes en 0x%0h..0x%0h (%0d bloques)", bytes, BASE, fin - 1,
             (fin - BASE) / 8);
    $display("tb_archivo: llave K0..K3 = %08h %08h %08h %08h", key[0], key[1], key[2], key[3]);


    if (solo_descifrar) begin

        tb_section("2. Descifrado");

        load_program(descifrar_file);
        run_until_end("descifrado", cycles_dec);
        $writememh("descifrado.mem", DUT.DMEM.mem);

        outside = 0;
        for (int a = fin / 4; a < DMEM_BYTES / 4; a++)
            if (DUT.DMEM.mem[a] !== original[a])
                outside++;

        check("palabras modificadas después del archivo", outside, 0);
        $display("tb_archivo: descifrado en %0d ciclos", cycles_dec);
    end
    else begin

        tb_section("2. Cifrado");

        load_program(cifrar_file);
        run_until_end("cifrado", cycles_enc);
        $writememh("cifrado.mem", DUT.DMEM.mem);

        changed = 0;
        for (int a = BASE / 4; a < fin / 4; a++)
            if (DUT.DMEM.mem[a] !== original[a])
                changed++;

        check_true("el cifrado cambió el archivo", changed > 0);


        tb_section("3. Descifrado");

        load_program(descifrar_file);
        run_until_end("descifrado", cycles_dec);
        $writememh("descifrado.mem", DUT.DMEM.mem);


        tb_section("4. Comparación con el original");

        wrong   = 0;
        outside = 0;

        for (int a = BASE / 4; a < fin / 4; a++)
            if (DUT.DMEM.mem[a] !== original[a])
                wrong++;

        for (int a = fin / 4; a < DMEM_BYTES / 4; a++)
            if (DUT.DMEM.mem[a] !== original[a])
                outside++;

        check("palabras del archivo distintas al original", wrong, 0);
        check("palabras modificadas después del archivo", outside, 0);

        $display("tb_archivo: cifrado en %0d ciclos, descifrado en %0d ciclos", cycles_enc, cycles_dec);
    end


    tb_finish("tb_archivo");
end

endmodule
