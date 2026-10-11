#!/usr/bin/env python3
# =============================================================================
#  tools/load_file.py
#
#  Descripción
# -----------------------------------------------------------------------------
#  Carga un archivo binario o hexadecimal dentro de un archivo .mem compatible
#  con $readmemh de Verilog. Permite inicializar la memoria de instrucciones
#  (rtl/instruction_memory.sv) o la memoria de datos (rtl/memory.sv) con datos
#  externos.
#
#  Uso
# -----------------------------------------------------------------------------
#  python tools/load_file.py <input> [--base 0x0] [--output salida.mem] [--size 65536]
#
#  Argumentos
# -----------------------------------------------------------------------------
#    <input>                Ruta al archivo de entrada. Si termina en .hex se
#                           interpreta como texto hex (un valor por línea o
#                           separados por espacios/comas). Cualquier otro archivo
#                           (texto, imágenes, binarios) se carga tal cual, byte
#                           por byte.
#    --base <addr>          Dirección base donde comienza la carga (default 0x0).
#                           Los bytes del archivo se escriben desde esta
#                           dirección en forma ascendente.
#    --output <ruta>         Ruta del .mem a producir (default <input>.mem).
#    --size <bytes>         Tamaño total de la imagen de memoria (default 65536).
#                           El archivo .mem se rellena con ceros hasta este
#                           tamaño para que $readmemh no lea basura.
#    --word-width            32 (palabras de 32 bits little-endian, una por línea
#                           en el .mem) o 8 (un byte por línea). Default 32.
#
#  Formato .mem generado
# -----------------------------------------------------------------------------
#  El archivo contiene una dirección de palabra (en hex) por línea. Las palabras
#  no escritas explícitamente se rellenan con 0. El ancho depende de
#  --word-width:
#     8:  dos caracteres hexadecimales (00..FF)
#    32:  ocho caracteres hexadecimales (00000000..FFFFFFFF)
#
#  Ejemplos
# ----------------------------------------------------------------------------
#  1. Cargar un binario en la dirección 0x0 de la memoria de instrucciones:
#       python tools/load_file.py programa.bin --base 0x0 --output build/prog.mem
#
#  2. Cargar un archivo hex a partir de 0x4000 (datos):
#       python tools/load_file.py datos.hex --base 0x4000 --output build/data.mem
#
#  3. Generar imagen completa de 16 KB con bytes little-endian:
#       python tools/load_file.py imagen.bin --size 16384 --word-width 8
#
# =============================================================================

import argparse
import os
import sys


def parse_hex_text(text):
    """Interpreta un archivo de texto hexadecimal.

    Acepta líneas con uno o varios valores hexadecimales por línea, separados
    por espacios, comas, tabs o saltos de línea. Ignora líneas que comienzan
    con '#' (comentarios) y líneas vacías.
    """
    bytes_out = []
    for raw_line in text.splitlines():
        # Quitar comentario al final de la línea
        if '#' in raw_line:
            raw_line = raw_line.split('#', 1)[0]
        line = raw_line.strip()
        if not line:
            continue
        for token in line.replace(',', ' ').split():
            token = token.strip()
            if not token:
                continue
            # Aceptar prefijos 0x y prefijos con _ (0x12_34)
            token = token.replace('_', '')
            try:
                value = int(token, 16)
            except ValueError as exc:
                raise ValueError(
                    f"token hexadecimal inválido: {token!r}"
                ) from exc
            if value < 0 or value > 0xFFFFFFFF:
                raise ValueError(f"valor fuera de rango: {value}")
            # Si el valor es <= 0xFF lo tratamos como byte; si no, lo
            # desempaquetamos little-endian en 4 bytes.
            if value <= 0xFF:
                bytes_out.append(value & 0xFF)
            else:
                for shift in (0, 8, 16, 24):
                    bytes_out.append((value >> shift) & 0xFF)
    return bytes_out


def parse_binary(data):
    """Interpreta un archivo binario: cada byte se toma en orden."""
    return list(data)


def load_file(input_path, base=0, size=65536, word_width=32):
    """Lee el archivo de entrada y devuelve la imagen de memoria como dict
    {dirección_byte: byte}.

    El parámetro ``base`` indica la dirección de inicio. Si el archivo
    excede ``size - base``, los sobrantes se descartan (con un warning).
    """
    if not os.path.isfile(input_path):
        raise FileNotFoundError(input_path)

    with open(input_path, 'rb') as f:
        raw = f.read()

    # Sólo .hex se interpreta como texto hexadecimal; cualquier otro archivo
    # (.txt, imágenes, binarios) se carga byte por byte.
    is_text_hex = input_path.lower().endswith('.hex')
    try:
        if is_text_hex:
            text = raw.decode('utf-8')
            data_bytes = parse_hex_text(text)
        else:
            data_bytes = parse_binary(raw)
    except ValueError as exc:
        sys.stderr.write(f"[load_file] {input_path}: {exc}\n")
        sys.exit(1)

    image = {}
    end_addr = base + len(data_bytes)
    if base >= size:
        sys.stderr.write(
            f"[load_file] ERROR: la base 0x{base:x} está fuera del rango "
            f"de la imagen (tamaño 0x{size:x}).\n"
        )
        return image, size
    if end_addr > size:
        overflow = end_addr - size
        sys.stderr.write(
            f"[load_file] WARNING: el archivo excede el tamaño de memoria por "
            f"{overflow} bytes; se truncará.\n"
        )
        data_bytes = data_bytes[: size - base]

    for offset, byte in enumerate(data_bytes):
        image[base + offset] = byte & 0xFF

    return image, size


def write_mem(image, output_path, size, word_width):
    """Escribe la imagen en formato .mem compatible con $readmemh."""
    with open(output_path, 'w') as f:
        if word_width == 8:
            # Un byte por línea, en orden ascendente de dirección.
            for addr in range(size):
                byte = image.get(addr, 0)
                f.write(f"{byte:02x}\n")
        elif word_width == 32:
            # Una palabra de 32 bits por línea, little-endian.
            for word_addr in range(size // 4):
                base = word_addr * 4
                b0 = image.get(base + 0, 0)
                b1 = image.get(base + 1, 0)
                b2 = image.get(base + 2, 0)
                b3 = image.get(base + 3, 0)
                word = b0 | (b1 << 8) | (b2 << 16) | (b3 << 24)
                f.write(f"{word:08x}\n")
        else:
            raise ValueError(f"word_width no soportado: {word_width}")


def main():
    parser = argparse.ArgumentParser(
        description="Carga un archivo binario o hexadecimal a un .mem Verilog"
    )
    parser.add_argument("input", help="Archivo de entrada (cualquier formato; .hex = texto hexadecimal)")
    parser.add_argument("--base", default="0x0",
                        help="Dirección base de carga (default 0x0)")
    parser.add_argument("--output", default=None,
                        help="Ruta del .mem a generar (default <input>.mem)")
    parser.add_argument("--size", type=int, default=65536,
                        help="Tamaño total de la imagen (default 65536)")
    parser.add_argument("--word-width", type=int, default=32,
                        help="Ancho en bits por línea del .mem (8 o 32)")
    args = parser.parse_args()

    base = int(args.base, 0)
    output = args.output if args.output else os.path.splitext(args.input)[0] + ".mem"

    image, size = load_file(args.input, base=base, size=args.size,
                            word_width=args.word_width)

    os.makedirs(os.path.dirname(os.path.abspath(output)) or ".", exist_ok=True)
    write_mem(image, output, size, args.word_width)

    print(f"[load_file] {len(image)} bytes cargados en {output} "
          f"(base=0x{base:x}, tamaño=0x{size:x})")


if __name__ == "__main__":
    main()