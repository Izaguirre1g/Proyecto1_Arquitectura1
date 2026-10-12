/*
================================================================================
 Módulo: instruction_memory

 Descripción:
 ------------------------------------------------------------------------------
 Memoria de instrucciones del procesador.

 Recibe el PC y entrega el bundle VLIW correspondiente.

 Cada posición almacena un bundle de BUNDLE_W bits (128). Tiene DEPTH
 posiciones (por defecto IMEM_BUNDLES = 1024, es decir 16 KB).

 Carga del programa:
     Al iniciar la simulación toda la memoria queda en NOP (0). Si se indica
     un archivo con el plusarg +IMEM=<archivo.mem>, se carga con $readmemh:
     una línea por bundle, 32 dígitos hexadecimales, con el slot CRIPTO en
     los bits altos y el slot ALU en los bajos (el formato .mem que genera
     tools/assembler.py).

         vvp sim.vvp +IMEM=build/programa.mem
         make <testbench> PLUSARGS="+IMEM=build/programa.mem"

     Los testbenches también pueden escribir memory[] por jerarquía después
     del tiempo 0.

 Direccionamiento:
     El índice es address[...:4] (el PC avanza BUNDLE_BYTES = 16 por bundle).
     Una dirección fuera de la memoria vuelve a empezar desde el inicio.

================================================================================
*/
`include "isa_defs.sv"

module instruction_memory #(

    parameter int DEPTH = IMEM_BUNDLES          // cantidad de bundles
) (

    input  logic [31:0]          address,

    output logic [BUNDLE_W-1:0]  instruction_bundle
);


localparam int OFFSET_W = $clog2(BUNDLE_BYTES);  // 4: bits de byte dentro del bundle
localparam int INDEX_W  = $clog2(DEPTH);

logic [BUNDLE_W-1:0] memory [0:DEPTH-1];

string program_file;
int    program_bundles;


// Cuenta las líneas del archivo que empiezan con un dígito hexadecimal (los
// bundles), para cargar con $readmemh exactamente ese rango. -1 si no existe.
function automatic int count_bundles(input string path);

    integer           fd, r;
    reg [8*512-1:0]   line;
    reg [7:0]         c;
    int               n;

    n  = 0;
    fd = $fopen(path, "r");

    if (fd == 0)
        return -1;

    while (!$feof(fd)) begin

        r = $fgets(line, fd);

        if (r > 0) begin

            c = line[8*r-1 -: 8];               // primer carácter de la línea
            if ((c >= "0" && c <= "9") || (c >= "a" && c <= "f") || (c >= "A" && c <= "F"))
                n++;
        end
    end

    $fclose(fd);
    return n;
endfunction


initial begin

    for (int i = 0; i < DEPTH; i++)
        memory[i] = '0;                          // NOP en los 4 slots

    if ($value$plusargs("IMEM=%s", program_file)) begin

        program_bundles = count_bundles(program_file);

        if (program_bundles < 0)
            $fatal(1, "[IMEM] no se encontró el programa %s", program_file);
        else if (program_bundles > DEPTH)
            $fatal(1, "[IMEM] %s tiene %0d bundles; la memoria admite %0d",
                   program_file, program_bundles, DEPTH);
        else if (program_bundles > 0)
            $readmemh(program_file, memory, 0, program_bundles - 1);

        $display("[IMEM] %0d bundles cargados desde %s", program_bundles, program_file);
    end
end


// Lectura combinacional. Con assign la salida se actualiza también cuando
// cambia el contenido de la memoria (por ejemplo, si un testbench escribe el
// programa con el PC ya en 0).
assign instruction_bundle = memory[address[INDEX_W+OFFSET_W-1:OFFSET_W]];


endmodule
