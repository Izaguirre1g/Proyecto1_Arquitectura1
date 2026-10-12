#!/usr/bin/env python3
# =============================================================================
#  tools/load_file.py
#
#  Descripción
# -----------------------------------------------------------------------------
#  Carga un archivo binario o hexadecimal dentro de un archivo .mem compatible
#  con $readmemh de Verilog. Sirve para inicializar la memoria de datos
#  (rtl/memory.sv) con datos externos. La memoria de instrucciones usa bundles
#  de 128 bits: su .mem lo genera tools/assembler.py.
#
#  Uso
# -----------------------------------------------------------------------------
#  python3 tools/load_file.py --input archivo --output memory.mem --address 0x1000
#                              [--size 65536] [--word-width 32]
#
#  Argumentos
# -----------------------------------------------------------------------------
#    --input <ruta>         Ruta al archivo de entrada. Si termina en .hex se
#                           interpreta como texto hex (un valor por línea o
#                           separados por espacios/comas). Cualquier otro archivo
#                           (texto, imágenes, binarios) se carga tal cual, byte
#                           por byte. (Requerido)
#    --output <ruta>        Ruta del .mem a producir. (Requerido)
#    --address <addr>       Dirección base donde comienza la carga (default 0x0).
#                           Los bytes del archivo se escriben desde esta
#                           dirección en forma ascendente.
#    --size <bytes>         Tamaño total de la imagen de memoria (default 65536).
#                           El archivo .mem se rellena con ceros hasta este
#                           tamaño para que $readmemh no lea basura.
#    --word-width           32 (palabras de 32 bits little-endian, una por línea
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
#  1. Cargar un archivo en la dirección 0x200 de la memoria de datos:
#       python3 tools/load_file.py --input mensaje.txt --address 0x200 \
#                                     --output build/datos.mem
#
#  2. Cargar un archivo hex a partir de 0x4000 (datos):
#       python3 tools/load_file.py --input datos.hex --address 0x4000 \
#                                     --output build/data.mem
#
#  3. Generar imagen completa de 16 KB con un byte por línea (no sirve para
#     memory.sv, que lee palabras de 32 bits):
#       python3 tools/load_file.py --input imagen.bin --address 0x0 \
#                                     --output build/imagen.mem \
#                                     --size 16384 --word-width 8
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
        description="Carga un archivo al .mem Verilog usado por la memoria de datos"
    )
    # Interfaz de la especificacion del proyecto (Sec. 5.4.3):
    # ./load_file.py --input archivo.txt --output memory.mem --address 0x1000
    parser.add_argument("--input", required=True,
                        help="Ruta al archivo de entrada (.hex = texto hex; "
                             "cualquier otro = binario byte por byte)")
    parser.add_argument("--output", required=True,
                        help="Ruta del .mem a generar (compatible con "
                             "$readmemh)")
    parser.add_argument("--address", default="0x0",
                        help="Direccion base de carga (default 0x0)")
    parser.add_argument("--size", type=int, default=65536,
                        help="Tamano total de la imagen de memoria "
                             "(default 65536)")
    parser.add_argument("--word-width", type=int, default=32,
                        help="Ancho en bits por linea del .mem (default 32)")
    args = parser.parse_args()

    address = int(args.address, 0)

    image, size = load_file(args.input, base=address, size=args.size,
                            word_width=args.word_width)

    os.makedirs(os.path.dirname(os.path.abspath(args.output)) or ".", exist_ok=True)
    write_mem(image, args.output, size, args.word_width)

    print(f"[load_file] {len(image)} bytes cargados en {args.output} "
          f"(address=0x{address:x}, tamano=0x{size:x})")


if __name__ == "__main__":
    main()