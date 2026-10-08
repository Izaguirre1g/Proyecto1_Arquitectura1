#!/usr/bin/env python3
# =============================================================================
#  tools/extract_data.py
#
#  Descripción
# -----------------------------------------------------------------------------
#  Extrae un rango de memoria desde un archivo .mem o un dump de la memoria
#  del procesador, y lo convierte a un archivo .bin (binario) o .hex (texto
#  hexadecimal). Complementa a tools/load_file.py.
#
#  El caso de uso principal es: después de correr una simulación que produce
#  un dump de memoria (por ejemplo en formato .mem o en un dump textual del
#  testbench), esta herramienta saca un sub-rango para inspeccionar o
# post-tra-atar (por ejemplo, cargar la salida cifrada en otra herramienta).
#
#  Uso
# -----------------------------------------------------------------------------
#  python tools/extract_data.py <input> --base 0x0 --size N [--output salida.bin]
#           [--format bin|hex] [--little-endian]
#
#  Argumentos
# -----------------------------------------------------------------------------
#    <input>                Ruta al archivo .mem o .hex de donde extraer.
#                           - Si termina en .mem se interpreta como archivo
#                               compatible con $readmemh (palabras de 32 bits
#                               little-endian, una por línea) o bytes (un
#                               byte por línea).
#                           - En cualquier otro caso se interpreta como texto
#                               hexadecimal libre.
#    --base <addr>          Dirección inicial (default 0x0).
#    --size <bytes>         Cantidad de bytes a extraer (default 64).
#    --output <ruta>         Archivo de salida (default stdout en hex).
#    --format bin|hex        Formato de salida (default hex).
#    --little-endian        Cuando --format hex, emite 2 bytes por palabra
#                           en little-endian (default: lo mismo).
#    --mem-width 32|8       Ancho de los valores en el .mem de entrada.
#                           Default 32 (palabras little-endian).
#
#  Ejemplos
# ----------------------------------------------------------------------------
#  1. Sacar 256 bytes a partir de 0x4000 del dump de memoria, en binario:
#       python tools/extract_data.py build/data.mem --base 0x4000 --size 256
#              --format bin --output out.bin
#
#  2. Sacar 16 bytes a partir de 0x0 en hexadecimal (stdout):
#       python tools/extract_data.py build/data.mem --base 0x0 --size 16
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


def parse_mem_bytes(path):
    """Lee un .mem de bytes (un byte por línea)."""
    bytes_out = []
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
            bytes_out.append(value & 0xFF)
    return bytes_out


def main():
    parser = argparse.ArgumentParser(
        description="Extrae un rango de memoria y lo convierte a binario o hex"
    )
    parser.add_argument("input", help="Archivo .mem de entrada")
    parser.add_argument("--base", default="0x0",
                        help="Dirección inicial (default 0x0)")
    parser.add_argument("--size", type=int, default=64,
                        help="Cantidad de bytes a extraer (default 64)")
    parser.add_argument("--output", default=None,
                        help="Archivo de salida (default stdout)")
    parser.add_argument("--format", default="hex", choices=["hex", "bin"],
                        help="Formato de salida (default hex)")
    parser.add_argument("--mem-width", type=int, default=32, choices=[8, 32],
                        help="Ancho de los valores en el .mem (default 32)")
    args = parser.parse_args()

    base = int(args.base, 0)
    if base < 0:
        sys.stderr.write("[extract_data] ERROR: --base debe ser >= 0\n")
        sys.exit(1)

    # 1) Leer el archivo de entrada
    if args.mem_width == 32:
        words = parse_mem_words(args.input)
        bytes_mem = bytearray()
        for word in words:
            for shift in (0, 8, 16, 24):
                bytes_mem.append((word >> shift) & 0xFF)
    else:
        bytes_mem = bytearray(parse_mem_bytes(args.input))

    # 2) Sacar el rango pedido
    if base >= len(bytes_mem):
        sys.stderr.write(
            f"[extract_data] WARNING: la base 0x{base:x} está fuera del archivo "
            f"(tamaño {len(bytes_mem)} bytes)\n"
        )
        extracted = bytearray()
    else:
        end = min(base + args.size, len(bytes_mem))
        extracted = bytes_mem[base:end]

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