#!/usr/bin/env python3
# =============================================================================
#  tools/extract_data.py
#
#  Descripción
# -----------------------------------------------------------------------------
#  Extrae un rango de memoria desde un archivo .mem o un volcado de la memoria
#  del procesador, y lo convierte a un archivo .bin (binario) o .hex (texto
#  hexadecimal). Complementa a tools/load_file.py.
#
#  El caso de uso principal es: después de una simulación que vuelca la memoria
#  con $writememh, esta herramienta saca un rango para revisarlo o procesarlo
#  (por ejemplo, guardar la salida cifrada como un archivo).
#
#  Uso
# -----------------------------------------------------------------------------
#  python3 tools/extract_data.py --memory <file> --address 0x0 --size N
#                                  --output <file>  [--format bin|hex]
#
#  Argumentos
# -----------------------------------------------------------------------------
#    --memory <ruta>        Volcado de memoria de donde extraer: una palabra
#                           hexadecimal de 32 bits por línea, con los bytes en
#                           little-endian (el formato de $readmemh y
#                           $writememh), sin importar la extensión. Se ignoran
#                           las líneas vacías y los comentarios. (Requerido)
#    --address <addr>       Direccion inicial (default 0x0).
#    --size <bytes>         Cantidad de bytes a extraer (default 64).
#    --output <ruta>        Archivo de salida (default stdout en hex).
#    --format bin|hex       Formato de salida. Si no se indica, es bin cuando
#                           --output termina en .bin y hex en otro caso.
#
#  Ejemplos
# ----------------------------------------------------------------------------
#  1. Sacar 256 bytes a partir de 0x4000 del dump de memoria, en binario:
#       python3 tools/extract_data.py --memory build/data.mem --address 0x4000 \
#              --size 256 --format bin --output out.bin
#
#  2. Sacar 16 bytes a partir de 0x0 en hexadecimal (stdout):
#       python3 tools/extract_data.py --memory build/data.mem --address 0x0 \
#              --size 16
#
#  =============================================================================

import argparse
import os
import sys


def parse_mem_words(path):
    """Lee un .mem de palabras de 32 bits little-endian (formato $readmemh)."""
    words = []
    with open(path, 'r') as f:
        for raw_line in f:
            line = raw_line.strip()
            if not line or line.startswith('#') or line.startswith('//'):
                continue
            line = line.replace('_', '')
            try:
                value = int(line, 16)
            except ValueError:
                continue
            words.append(value & 0xFFFFFFFF)
    return words


def main():
    parser = argparse.ArgumentParser(
        description="Extrae un rango de memoria y lo convierte a binario o hex"
    )
    # Interfaz de la especificacion del proyecto (Sec. 5.4.3):
    # ./extract_data.py --memory memory_dump.txt --address 0x1000 --size 4096
    #                     --output resultado.bin
    parser.add_argument("--memory", required=True,
                        help="Ruta al archivo .mem / dump de entrada")
    parser.add_argument("--address", default="0x0",
                        help="Direccion inicial (default 0x0)")
    parser.add_argument("--size", type=int, default=64,
                        help="Cantidad de bytes a extraer (default 64)")
    parser.add_argument("--output", default=None,
                        help="Archivo de salida (default stdout en hex)")
    parser.add_argument("--format", choices=["hex", "bin"],
                        help="Formato de salida (default: bin si --output termina en .bin, si no hex)")
    args = parser.parse_args()
    if args.format is None:
        args.format = "bin" if args.output and args.output.lower().endswith(".bin") else "hex"

    address = int(args.address, 0)
    if address < 0:
        sys.stderr.write("[extract_data] ERROR: --address debe ser >= 0\n")
        sys.exit(1)

    # 1) Leer el archivo de entrada
    words = parse_mem_words(args.memory)
    bytes_mem = bytearray()
    for word in words:
        for shift in (0, 8, 16, 24):
            bytes_mem.append((word >> shift) & 0xFF)

    # 2) Sacar el rango pedido
    if address >= len(bytes_mem):
        sys.stderr.write(
            f"[extract_data] WARNING: la direccion 0x{address:x} esta fuera del archivo "
            f"(tamano {len(bytes_mem)} bytes)\n"
        )
        extracted = bytearray()
    else:
        end = min(address + args.size, len(bytes_mem))
        extracted = bytes_mem[address:end]

    # 3) Emitir
    if args.format == "bin":
        data = bytes(extracted)
    else:
        data = (",".join(f"{b:02x}" for b in extracted)).encode("ascii") + b"\n"

    if args.output:
        os.makedirs(os.path.dirname(os.path.abspath(args.output)) or ".", exist_ok=True)
        with open(args.output, "wb") as f:
            f.write(data)
        print(f"[extract_data] {len(extracted)} bytes extraídos a {args.output}")
    else:
        if args.format == "bin":
            sys.stdout.buffer.write(data)
        else:
            sys.stdout.write(data.decode("ascii"))


if __name__ == "__main__":
    main()