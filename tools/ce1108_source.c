/* Adaptador de la demo: usa los módulos de CE1108 sin cambiar sus interfaces. */
#include "sintactico.h"
#include "generacion_basica.h"
#include "symbol_table.h"

#include <stdlib.h>
#include <string.h>

static int error_nodo(const AstNodo *n, const char *mensaje) {
    fprintf(stderr, "%zu:%zu: integración CE1108: %s\n",
            n ? n->ubicacion.first_line : 0,
            n ? n->ubicacion.first_column : 0, mensaje);
    return 0;
}

static const AstNodo *hijo(const AstNodo *n, unsigned indice) {
    const AstNodo *h = n ? n->primer_hijo : NULL;
    while (h && indice--) h = h->siguiente;
    return h;
}

static int resolver(void *datos, const AstNodo *id, GbReferencia *ref) {
    SimTabla *tabla = datos;
    SimSimbolo *s = sim_buscar(tabla, id->texto);
    if (!s || s->clase != SIM_VARIABLE) return 0;
    int destino = id->padre && id == id->padre->primer_hijo &&
                  (id->padre->tipo == AST_DECLARACION || id->padre->tipo == AST_ASIGNACION);
    /* bytes=0 hasta emitir la inicialización: no permite leer la propia variable. */
    if (!destino && s->bytes == 0) return 0;
    if (s->tipo != SIM_TIPO_INT && s->tipo != SIM_TIPO_BOOLEAN) return 0;
    *ref = (GbReferencia){s->tipo == SIM_TIPO_INT ? GB_ENTERO : GB_BOOLEANO,
                          3, (int)s->desplazamiento, 1};
    return 1;
}

static int generar_programa(const Ast *ast, FILE *salida) {
    const AstNodo *f = hijo(ast->raiz, 0);
    const AstNodo *nombre = hijo(f, 0), *tipo = hijo(f, 1);
    const AstNodo *parametros = hijo(f, 2), *bloque = hijo(f, 3);
    if (!ast->raiz || ast->raiz->tipo != AST_PROGRAMA || !f || f->siguiente ||
        f->tipo != AST_FUNCION || !nombre || !nombre->texto || strcmp(nombre->texto, "main") ||
        !tipo || !tipo->texto || strcmp(tipo->texto, "declare_infinite_void") ||
        !parametros || parametros->tipo != AST_PARAMETROS || parametros->primer_hijo ||
        !bloque || bloque->tipo != AST_BLOQUE || bloque->siguiente || !bloque->primer_hijo)
        return error_nodo(f, "se admite una sola función main void, sin parámetros y no vacía");

    SimTabla tabla = {0};
    if (sim_inicializar(&tabla) != SIM_OK) return error_nodo(f, "no se pudo crear la tabla de símbolos");
    if (sim_entrar_ambito(&tabla, "main") != SIM_OK) {
        sim_liberar(&tabla);
        return error_nodo(f, "no se pudo crear el ámbito main");
    }
    /* El programa prepara gp por sí mismo. El testbench no precarga variables. */
    fputs("sumai x3, x0, 1\ncizqi x3, x3, 14\n", salida);
    unsigned cantidad = 0;
    int ok = 1;
    for (const AstNodo *n = bloque->primer_hijo; n && ok; n = n->siguiente) {
        SimSimbolo *nuevo = NULL;
        if (n->tipo == AST_DECLARACION) {
            const AstNodo *id = hijo(n, 0), *t = hijo(n, 1), *valor = hijo(n, 2);
            if (!id || id->tipo != AST_IDENTIFICADOR || !id->texto || !t ||
                t->tipo != AST_TIPO || !t->texto || !valor || valor->siguiente) {
                ok = error_nodo(n, "se requiere una declaración escalar inicializada");
                break;
            }
            SimTipo st;
            if (!strcmp(t->texto, "declare_int")) st = SIM_TIPO_INT;
            else if (!strcmp(t->texto, "declare_boolean")) st = SIM_TIPO_BOOLEAN;
            else { ok = error_nodo(t, "sólo se admiten enteros y booleanos"); break; }
            if (cantidad >= 256) { ok = error_nodo(n, "máximo 256 variables"); break; }
            SimResultado r = sim_insertar(&tabla, id->texto, SIM_VARIABLE, st,
                                          id->ubicacion.first_line, id->ubicacion.first_column, &nuevo);
            if (r != SIM_OK) {
                ok = error_nodo(id, r == SIM_DUPLICADO ? "variable duplicada" : "falló la inserción del símbolo");
                break;
            }
            sim_definir_ubicacion(nuevo, SIM_ALMACEN_LOCAL, (long)cantidad * 4, 0);
            ++cantidad;
        } else if (n->tipo != AST_ASIGNACION) {
            ok = error_nodo(n, "esta demo sólo genera declaraciones y asignaciones, sin ciclos ni llamadas");
            break;
        }
        if (gb_generar(n, resolver, &tabla, salida, stderr) != 0) ok = 0;
        else if (nuevo) nuevo->bytes = 4;
    }
    sim_liberar(&tabla);
    return ok && !ferror(salida);
}

int main(int argc, char **argv) {
    if (argc != 2) { fputs("Uso: ce1108_source archivo.bal\n", stderr); return 2; }
    FILE *entrada = fopen(argv[1], "rb");
    if (!entrada) { perror(argv[1]); return 2; }
    if (fseek(entrada, 0, SEEK_END) != 0) { fclose(entrada); return 2; }
    long medida = ftell(entrada);
    if (medida < 0 || medida > 1048576 || fseek(entrada, 0, SEEK_SET) != 0) {
        fputs("Fuente ilegible o mayor de 1 MiB\n", stderr); fclose(entrada); return 2;
    }
    size_t longitud = (size_t)medida;
    char *fuente = malloc(longitud + 1);
    if (!fuente) { fclose(entrada); return 2; }
    size_t leidos = fread(fuente, 1, longitud, entrada);
    int fallo_lectura = ferror(entrada);
    fclose(entrada);
    if (leidos != longitud || fallo_lectura) { free(fuente); return 2; }
    fuente[longitud] = '\0';
    Ast ast = {0};
    int resultado = construir_ast(fuente, longitud, argv[1], stderr, &ast);
    FILE *temporal = NULL;
    if (resultado == 0) {
        temporal = tmpfile();
        if (!temporal) resultado = 2;
        else if (!generar_programa(&ast, temporal)) resultado = 1;
    }
    if (resultado == 0) {
        if (fflush(temporal) != 0 || fseek(temporal, 0, SEEK_SET) != 0) resultado = 2;
        else {
            char buffer[4096]; size_t n;
            while ((n = fread(buffer, 1, sizeof(buffer), temporal)) != 0)
                if (fwrite(buffer, 1, n, stdout) != n) { resultado = 2; break; }
            if (ferror(temporal) || fflush(stdout) != 0) resultado = 2;
        }
    }
    if (temporal) fclose(temporal);
    ast_liberar(&ast);
    free(fuente);
    return resultado;
}
