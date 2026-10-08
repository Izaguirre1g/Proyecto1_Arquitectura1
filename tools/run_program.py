#!/usr/bin/env python3
"""Ensambla y ejecuta programas ALU/LSU/BRU sobre cpu_top."""

from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys

if __package__:
    from .assembler import AssemblyError, assemble_source, integer, register
else:
    from assembler import AssemblyError, assemble_source, integer, register


ROOT = Path(__file__).resolve().parents[1]
MAX_RUN_BUNDLES = 28


class SimulationError(RuntimeError):
    """Fallo de compilación, simulación o comparación de resultados."""


def tool(variable: str, default: str) -> str:
    name = os.environ.get(variable, default)
    found = shutil.which(name)
    if not found:
        raise SimulationError(f"no se encontró {name}; instale Icarus Verilog (iverilog y vvp)")
    return found


def read_expected(path: Path) -> dict[int, int]:
    raw = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(raw, dict) or not raw:
        raise SimulationError("el archivo esperado debe ser un objeto JSON no vacío: {\"x1\": 7}")
    result = {}
    for key, value in raw.items():
        reg = register(key)
        if reg in result:
            raise SimulationError(f"x{reg} aparece más de una vez usando distintos alias")
        if isinstance(value, bool) or not isinstance(value, (str, int)):
            raise SimulationError(f"valor esperado inválido para {key}")
        number = integer(value) if isinstance(value, str) else value
        if not -(1 << 31) <= number <= (1 << 32) - 1:
            raise SimulationError(f"valor esperado de {key} fuera de 32 bits")
        result[reg] = number & 0xffffffff
    return result


def run_logged(command: list[str], cwd: Path, log: Path, timeout: int) -> str:
    try:
        result = subprocess.run(command, cwd=cwd, stdout=subprocess.PIPE,
                                stderr=subprocess.STDOUT, timeout=timeout, check=False)
    except subprocess.TimeoutExpired as exc:
        output = (exc.stdout or b"").decode("utf-8", errors="replace")
        log.write_text(output, encoding="utf-8")
        raise SimulationError(f"tiempo máximo excedido; consulte {log}") from exc
    output = result.stdout.decode("utf-8", errors="replace")
    log.write_text(output, encoding="utf-8")
    if result.returncode or "[FAIL]" in output:
        detail = "\n".join(output.splitlines()[-12:])
        raise SimulationError(f"falló {Path(command[0]).name}; consulte {log}\n{detail}")
    return output


def run_program(source: Path, workdir: Path, expected: dict[int, int] | None = None,
                vcd: bool = True, expected_memory: dict[int, int] | None = None,
                cycles: int | None = None) -> dict[int, int]:
    source = source.resolve()
    program = assemble_source(source.read_text(encoding="utf-8"))
    if any(b.instructions[3].word for b in program.bundles):
        raise SimulationError("cpu_top aún no conecta la unidad criptográfica")
    if cycles is not None and not len(program.bundles) + 4 <= cycles <= 100000:
        raise SimulationError("cycles debe cubrir el programa y ser menor o igual a 100000")
    for address, value in (expected_memory or {}).items():
        if address % 4 or not 0 <= address <= 65532 or not 0 <= value <= 0xffffffff:
            raise SimulationError("memoria esperada: direcciones alineadas de 64 KiB y valores de 32 bits")
    if len(program.bundles) > MAX_RUN_BUNDLES:
        raise SimulationError("la prueba sobre la memoria actual admite hasta 28 bundles; "
                              "reserva 4 ciclos de vaciado antes de superar sus 32 entradas")
    compiler, simulator = tool("IVERILOG", "iverilog"), tool("VVP", "vvp")
    workdir = workdir.resolve()
    generated = [workdir / name for name in
                 ("program.mem", "program.lst", "sim.vvp", "compile.log",
                  "sim.log", "registers.txt", "program.vcd", "memory.txt")]
    if source in generated:
        raise SimulationError("el archivo fuente no puede ser una salida dentro del directorio de trabajo")
    workdir.mkdir(parents=True, exist_ok=True)
    memory, listing, binary, compile_log, sim_log, dump, wave, memdump = generated
    memory.write_text(program.memory_text(), encoding="ascii")
    listing.write_text(program.listing_text(), encoding="utf-8")
    # Evitar aceptar un dump viejo si una ejecución nueva no lo produce.
    memdump.unlink(missing_ok=True)
    dump.unlink(missing_ok=True)
    wave.unlink(missing_ok=True)
    rtl = sorted(str(p) for p in (ROOT / "rtl").glob("*.sv"))
    run_logged([compiler, "-g2012", "-Wall", "-Wno-timescale",
                "-I", str(ROOT / "rtl"), "-I", str(ROOT / "tb"),
                "-s", "tb_assembled_program", "-o", str(binary), *rtl,
                str(ROOT / "tests/rtl/tb_assembled_program.sv")],
               ROOT, compile_log, 30)
    command = [simulator, "-n", str(binary), f"+MEM={memory}",
               f"+REGDUMP={dump}", f"+BUNDLES={len(program.bundles)}",
               f"+MEMDUMP={memdump}", f"+CYCLES={cycles or len(program.bundles) + 4}"]
    if vcd:
        command.append(f"+VCD={wave}")
    run_logged(command, workdir, sim_log, 10)
    registers = {}
    for line in dump.read_text(encoding="ascii").splitlines():
        match = re.fullmatch(r"x([0-9]+) ([0-9a-fA-F]{8})", line)
        if not match:
            raise SimulationError(f"dump de registros inválido: {line}")
        reg, value = int(match[1]), int(match[2], 16)
        if reg > 31 or reg in registers:
            raise SimulationError("dump con un registro duplicado o fuera de rango")
        registers[reg] = value
    if set(registers) != set(range(32)):
        raise SimulationError("el dump no contiene exactamente los 32 registros")
    mismatches = [f"x{reg}: obtenido 0x{registers[reg]:08x}, esperado 0x{value:08x}"
                  for reg, value in (expected or {}).items() if registers[reg] != value]
    words = memdump.read_text(encoding="ascii").splitlines()
    if len(words) != 16384 or any(not re.fullmatch(r"[0-9a-fA-F]{8}", w) for w in words):
        raise SimulationError("dump de memoria incompleto o con valores X/Z")
    for address, value in (expected_memory or {}).items():
        actual = int(words[address // 4], 16)
        if actual != value:
            mismatches.append(f"mem[0x{address:04x}]: obtenido 0x{actual:08x}, esperado 0x{value:08x}")
    if mismatches:
        raise SimulationError("resultados incorrectos:\n" + "\n".join(mismatches))
    return registers


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", required=True, type=Path, help="programa ensamblador")
    parser.add_argument("--workdir", type=Path, help="salidas; por defecto build/program_<nombre>")
    parser.add_argument("--expect", type=Path, help="JSON de registros esperados")
    parser.add_argument("--no-vcd", action="store_true", help="omitir la traza VCD")
    parser.add_argument("--expect-memory", type=Path, help='JSON {"0x100": "0x0000007f"}')
    parser.add_argument("--cycles", type=int, help="ciclos de ejecución para programas con saltos")
    args = parser.parse_args(argv)
    workdir = args.workdir or ROOT / "build" / f"program_{args.input.stem}"
    try:
        expected = read_expected(args.expect) if args.expect else None
        expected_memory = None
        if args.expect_memory:
            raw = json.loads(args.expect_memory.read_text(encoding="utf-8"))
            if not isinstance(raw, dict) or not raw:
                raise SimulationError("memoria esperada debe ser un objeto JSON no vacío")
            expected_memory = {}
            for address, value in raw.items():
                if isinstance(value, bool) or not isinstance(value, (str, int)):
                    raise SimulationError("valor de memoria inválido")
                number = integer(address)
                if number in expected_memory:
                    raise SimulationError("dirección de memoria repetida")
                expected_memory[number] = integer(value) if isinstance(value, str) else value
        registers = run_program(args.input, workdir, expected, not args.no_vcd, expected_memory, args.cycles)
    except (OSError, UnicodeError, ValueError, SimulationError) as exc:
        print(f"Error: {exc}", file=sys.stderr)
        return 1
    if expected or expected_memory:
        print(f"[PASS] {len(expected or {})} registros y {len(expected_memory or {})} palabras coinciden")
    else:
        print("[OK] ejecución terminada; use --expect para verificar los resultados")
    for reg, value in registers.items():
        if value:
            print(f"x{reg:<2} = 0x{value:08x}")
    print(f"Memoria, listado, logs y registros: {workdir.resolve()}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
