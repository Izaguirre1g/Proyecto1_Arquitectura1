/* Prueba de una main con el generador de funciones real de Compiladores. */
#include "sintactico.h"
#include "semantic.h"
#include "memory.h"
#include "generacion_adaptador.h"
#include <stdlib.h>
#include <string.h>

static int generar(const Ast *ast, FILE *salida) {
    const AstNodo *f = ast->raiz ? ast->raiz->primer_hijo : NULL;
    const AstNodo *id = f ? f->primer_hijo : NULL;
    const AstNodo *tipo = id ? id->siguiente : NULL;
    const AstNodo *params = tipo ? tipo->siguiente : NULL;
    if (!f || f->siguiente || f->tipo != AST_FUNCION || !id || !id->texto ||
        strcmp(id->texto, "main") || !tipo || !tipo->texto ||
        strcmp(tipo->texto, "declare_infinite_void") || !params || params->primer_hijo) {
        fputs("Se requiere una sola main void sin parametros.\n", stderr);
        return 1;
    }
    SimTabla tabla = {0};
    if (sim_inicializar(&tabla) != SIM_OK) return 1;
    MemProyectoMapa mapa = {0};
    int estado = analizar_semantica(ast, &tabla, "fuente.bal", stderr);
    if (!estado && mem_asignar_proyecto(&tabla, 0x4000, 65536, 1020, &mapa) != MEM_PROYECTO_OK)
        estado = 1;
    if (!estado) {
        /* gp=0x4000 y sp=0x8000; la llamada fija ra con PC+16. */
        fputs("sumai x3, x0, 1\ncizqi x3, x3, 14\n"
              "sumai x2, x0, 1\ncizqi x2, x2, 15\n"
              "sye x1, __demo_main\n"
              "sumai x4, x0, 1\nguardap x3, x4, 0\n"
              "sye x0, __demo_done\n__demo_main:\n", salida);
        estado = gd_generar_funcion(f, &tabla, mapa.marco_maximo_bytes,
                                    NULL, NULL, salida, stderr);
        if (!estado) fputs("__demo_done:\nsye x0, __demo_done\n", salida);
    }
    sim_liberar(&tabla);
    return estado;
}

int main(int argc, char **argv) {
    if (argc != 2) return 2;
    FILE *entrada = fopen(argv[1], "rb");
    if (!entrada) return 2;
    char *fuente = malloc(1048577);
    if (!fuente) { fclose(entrada); return 2; }
    size_t n = fread(fuente, 1, 1048577, entrada);
    int error = ferror(entrada) || n > 1048576;
    fclose(entrada);
    if (error) { free(fuente); return 2; }
    Ast ast = {0};
    int estado = construir_ast(fuente, n, argv[1], stderr, &ast);
    free(fuente);
    FILE *salida = tmpfile();
    if (!salida) { ast_liberar(&ast); return 2; }
    if (!estado) estado = generar(&ast, salida);
    if (!estado && (fflush(salida) || fseek(salida, 0, SEEK_SET))) estado = 2;
    if (!estado) {
        char bloque[4096];
        while ((n = fread(bloque, 1, sizeof(bloque), salida)) != 0)
            if (fwrite(bloque, 1, n, stdout) != n) { estado = 2; break; }
        if (ferror(salida) || fflush(stdout)) estado = 2;
    }
    fclose(salida);
    ast_liberar(&ast);
    return estado;
}
