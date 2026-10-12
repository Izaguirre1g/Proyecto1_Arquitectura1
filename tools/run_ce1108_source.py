#!/usr/bin/env python3
"""Fuente BAL -> módulos reales de CE1108 -> bundles -> procesador VLIW."""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys

if __package__:
    from .assembler import AssemblyError, assemble_source, integer
    from .bundle_linear import bundle_linear
    from .run_program import ROOT, SimulationError, run_logged, run_program, tool
else:
    from assembler import AssemblyError, assemble_source, integer
    from bundle_linear import bundle_linear
    from run_program import ROOT, SimulationError, run_logged, run_program, tool


MODULES = ('src/generacion_basica.c', 'src/lexer.c', 'src/token.c',
           'Analisis_Sintactico/parser.c', 'Analisis_Sintactico/puente_lexer.c',
           'Analisis_Sintactico/ast.c', 'Analisis_Semantico/symbol_table.c')
HEADERS = ('include/ast.h', 'include/lexer.h', 'include/token.h',
           'include/generacion_basica.h', 'include/sintactico.h',
           'include/symbol_table.h', 'src/lexer_flex.h',
           'Analisis_Sintactico/parser.h', 'src/lexer.l')


def compile_driver(compiler_root: Path, work: Path, include_dirs=()) -> Path:
    compiler_root = compiler_root.resolve()
    required = [compiler_root / p for p in MODULES + HEADERS]
    missing = [str(p) for p in required if not p.is_file()]
    if missing:
        raise SimulationError('faltan módulos de CE1108; use feat-analisis-semantico:\n' + '\n'.join(missing))
    work.mkdir(parents=True, exist_ok=True)
    generated = work / 'lexer_flex.c'
    run_logged([tool('FLEX', 'flex'), '-o', str(generated), str(compiler_root/'src/lexer.l')],
               ROOT, work/'flex.log', 30)
    executable = work/'ce1108_source'
    command = [tool('CC', 'cc'), '-std=c11', '-Wall', '-Wextra', '-Wpedantic', '-Werror', '-O2',
               '-I', str(compiler_root/'include'), '-I', str(compiler_root/'src')]
    for path in include_dirs:
        command.extend(['-I', str(Path(path).resolve())])
    command.extend([str(ROOT/'tools/ce1108_source.c'),
                    *[str(compiler_root/p) for p in MODULES], str(generated), '-o', str(executable)])
    run_logged(command, ROOT, work/'driver_compile.log', 30)
    return executable


def read_memory_expected(path: Path) -> dict[int, int]:
    raw = json.loads(path.read_text(encoding='utf-8'))
    if not isinstance(raw, dict) or not raw:
        raise SimulationError('se requiere un JSON no vacío de direcciones y valores esperados')
    result = {}
    for key, value in raw.items():
        address = integer(key)
        if isinstance(value, bool) or not isinstance(value, (str, int)):
            raise SimulationError('valor esperado inválido')
        number = integer(value) if isinstance(value, str) else value
        if address in result or address % 4 or not 0 <= address <= 65532:
            raise SimulationError('dirección repetida, no alineada o fuera de memoria')
        if not -(1 << 31) <= number <= 0xffffffff:
            raise SimulationError('valor esperado fuera de 32 bits')
        result[address] = number & 0xffffffff
    return result


def run_source(compiler_root: Path, source: Path, expected_path: Path,
               work: Path, include_dirs=()) -> dict[int, int]:
    compiler_root, source, work = compiler_root.resolve(), source.resolve(), work.resolve()
    expected_path = expected_path.resolve()
    if work == source.parent or work in source.parents or work == expected_path.parent or work in expected_path.parents:
        raise SimulationError('fuente y expectativas deben estar fuera del directorio de salidas')
    if work == compiler_root or compiler_root in work.parents:
        raise SimulationError('las salidas deben quedar fuera del repositorio de CE1108')
    expected = read_memory_expected(expected_path)
    content = source.read_bytes()
    if len(content) > 1048576:
        raise SimulationError('fuente mayor de 1 MiB')
    executable = compile_driver(compiler_root, work, include_dirs)
    snapshot = work/'source.bal'
    snapshot.write_bytes(content)
    expected_snapshot = work/'expected.memory.json'
    expected_snapshot.write_bytes(expected_path.read_bytes())
    linear = run_logged([str(executable), str(snapshot)], ROOT, work/'generation.log', 30)
    (work/'program.linear').write_text(linear, encoding='utf-8')
    bundled = bundle_linear(linear)
    bundled += '__ce1108_fin: nop | nop | sye x0,__ce1108_fin | nop\n'
    program = assemble_source(bundled)
    asm = work/'source_program.asm'
    asm.write_text(bundled, encoding='utf-8')
    (work/'program.bin').write_bytes(program.binary())
    commit = subprocess.run(['git', '-C', str(compiler_root), 'rev-parse', 'HEAD'],
                            capture_output=True, text=True, check=False)
    architecture_commit = subprocess.run(['git', '-C', str(ROOT), 'rev-parse', 'HEAD'], capture_output=True, text=True, check=False)
    provenance = {'status': 'pending', 'architecture_commit': architecture_commit.stdout.strip() if architecture_commit.returncode == 0 else None,
                  'driver_sha256': hashlib.sha256((ROOT/'tools/ce1108_source.c').read_bytes()).hexdigest(), 'compiler_commit': commit.stdout.strip() if commit.returncode == 0 else None,
                  'source_sha256': hashlib.sha256(content).hexdigest(), 'bundles': len(program.bundles),
                  'modules_sha256': {p: hashlib.sha256((compiler_root/p).read_bytes()).hexdigest()
                                     for p in MODULES + HEADERS},
                  'expected_memory': {hex(a): hex(v) for a, v in expected.items()},
                  'initialization': 'gp y variables inicializados por el código generado; sin precarga del testbench'}
    evidence = work/'evidence.json'
    evidence.write_text(json.dumps(provenance, indent=2, ensure_ascii=False) + '\n', encoding='utf-8')
    registers = run_program(asm, work, {3: 0x4000}, vcd=True, expected_memory=expected,
                            cycles=len(program.bundles) + 12)
    provenance['status'] = 'PASS'
    evidence.write_text(json.dumps(provenance, indent=2, ensure_ascii=False) + '\n', encoding='utf-8')
    return registers


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--compiler-root', required=True, type=Path)
    parser.add_argument('--input', required=True, type=Path)
    parser.add_argument('--expect-memory', required=True, type=Path)
    parser.add_argument('--workdir', type=Path, default=ROOT/'build/ce1108_fuente')
    parser.add_argument('--include-dir', action='append', type=Path, default=[Path(p) for p in os.environ.get('CE1108_INCLUDE_DIRS', '').split(os.pathsep) if p], help='ruta adicional de cabeceras C')
    args = parser.parse_args()
    try:
        run_source(args.compiler_root, args.input, args.expect_memory, args.workdir, args.include_dir)
    except (OSError, ValueError, SimulationError) as exc:
        print(f'Error: {exc}', file=sys.stderr)
        return 1
    print('[PASS] fuente BAL -> lexer/parser/símbolos/generador CE1108 -> binario -> RTL')
    print('gp y las variables fueron inicializados por el programa, sin precarga del testbench.')
    print(f'Evidencia, memoria y ondas: {args.workdir.resolve()}')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
