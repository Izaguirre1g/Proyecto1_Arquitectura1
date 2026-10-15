#!/usr/bin/env python3
"""Coloca la salida lineal de CE1108 en bundles, con dos NOP entre instrucciones."""
import argparse
from pathlib import Path
import re
import sys

if __package__:
    from .assembler import AssemblyError, assemble_source, encode_instruction
else:
    from assembler import AssemblyError, assemble_source, encode_instruction


def bundle_linear(source: str) -> str:
    rows = []
    for line, raw in enumerate(source.splitlines(), 1):
        code = re.split(r'#|;|//', raw, maxsplit=1)[0].strip()
        if not code:
            continue
        try:
            ins = encode_instruction(code)
            if ins.slot not in (0, 1):
                raise AssemblyError('el adaptador lineal sólo admite ALU y LSU')
            slots = ['nop'] * 4
            slots[ins.slot] = code
            if rows:
                rows.extend(['nop', 'nop'])
            rows.append(' | '.join(slots))
        except AssemblyError as exc:
            raise AssemblyError(f'línea {line}: {exc}') from exc
    output = '\n'.join(rows) + '\n'
    assemble_source(output)
    return output


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--input', required=True, type=Path)
    parser.add_argument('--output', required=True, type=Path)
    args = parser.parse_args()
    try:
        if args.input.resolve() == args.output.resolve():
            raise AssemblyError('la entrada y salida deben ser distintas')
        output = bundle_linear(args.input.read_text(encoding='utf-8'))
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(output, encoding='utf-8')
    except (OSError, ValueError) as exc:
        print(f'Error: {exc}', file=sys.stderr)
        return 1
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
