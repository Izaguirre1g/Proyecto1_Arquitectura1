"""Pruebas desde fuente .asm hasta el banco de registros del top real."""

import json
import os
from pathlib import Path
import shutil
import tempfile
import unittest

from tools.run_program import MAX_RUN_BUNDLES, SimulationError, read_expected, run_program


ROOT = Path(__file__).resolve().parents[1]
HAVE_ICARUS = (shutil.which(os.environ.get("IVERILOG", "iverilog")) and
               shutil.which(os.environ.get("VVP", "vvp")))


@unittest.skipUnless(HAVE_ICARUS, "requiere iverilog y vvp para ejecutar el RTL")
class CpuProgramTests(unittest.TestCase):
    def execute(self, source: str, expected: dict[int, int]):
        with tempfile.TemporaryDirectory() as directory:
            directory = Path(directory)
            asm = directory / "input.asm"
            asm.write_text(source, encoding="utf-8")
            return run_program(asm, directory / "build", expected, vcd=False)

    def test_all_18_instructions_and_pseudos(self):
        with tempfile.TemporaryDirectory() as directory:
            expected = read_expected(ROOT / "examples/alu_isa.expected.json")
            registers = run_program(ROOT / "examples/alu_isa.asm", Path(directory), expected)
            self.assertEqual(len(registers), 32)
            self.assertTrue((Path(directory) / "program.vcd").is_file())

    def test_memory_program(self):
        with tempfile.TemporaryDirectory() as directory:
            run_program(ROOT / "examples/lsu_isa.asm", Path(directory),
                        read_expected(ROOT / "examples/lsu_isa.expected.json"),
                        vcd=False, expected_memory={256: 127, 260: 255}, cycles=80)

    def test_branch_program(self):
        with tempfile.TemporaryDirectory() as directory:
            run_program(ROOT / "examples/bru_isa.asm", Path(directory),
                        read_expected(ROOT / "examples/bru_isa.expected.json"),
                        vcd=False, cycles=80)

    def test_two_nop_bundles_between_producer_and_consumer(self):
        source = (ROOT / "examples/dependencias.asm").read_text()
        self.execute(source, {0: 0, 4: 7, 5: 7})

    def test_immediate_signed_limits_and_logic(self):
        source = "\n".join(["sumai x1,x0,-1024 | nop | nop | nop",
                            "sumai x2,x0,1023 | nop | nop | nop",
                            "xori x3,x0,-1 | nop | nop | nop",
                            "andi x4,x1,-1 | nop | nop | nop",
                            "restai x5,x2,-1024 | nop | nop | nop"])
        self.execute(source, {1: 0xfffffc00, 2: 1023, 3: 0xffffffff, 4: 0xfffffc00, 5: 2047})

    def test_shift_amount_reduced_modulo_32(self):
        source = "\n".join(["sumai x1,x0,-8 | nop | nop | nop", "nop", "nop",
                            "cizqi x2,x1,32 | nop | nop | nop",
                            "caderi x3,x1,2047 | nop | nop | nop",
                            "cderi x4,x1,2047 | nop | nop | nop"])
        self.execute(source, {1: 0xfffffff8, 2: 0xfffffff8, 3: 0xffffffff, 4: 1})

    def test_latest_write_and_self_update(self):
        source = "\n".join(["sumai x1,x0,7 | nop | nop | nop", "nop", "nop",
                            "sumai x1,x1,1 | nop | nop | nop", "nop", "nop",
                            "mov x31,x1 | nop | nop | nop"])
        self.execute(source, {1: 8, 31: 8})

    def test_last_bundle_reaches_writeback_at_capacity_limit(self):
        source = "nop\n" * (MAX_RUN_BUNDLES - 1) + "sumai x31,x0,99 | nop | nop | nop\n"
        self.execute(source, {0: 0, 31: 99})

    def test_mixed_program_with_crypto(self):
        # examples/mixto.asm: las 4 unidades y las 6 instrucciones cripto
        with tempfile.TemporaryDirectory() as directory:
            run_program(ROOT / "examples/mixto.asm", Path(directory),
                        {10: 7, 11: 0, 12: 1}, vcd=False,
                        expected_memory={0x100: 14, 0x104: 42}, cycles=60)

    def test_incorrect_expected_result_is_an_error(self):
        with self.assertRaisesRegex(SimulationError, "resultados incorrectos"):
            self.execute("sumai x1,x0,7 | nop | nop | nop", {1: 8})

    def test_run_capacity_does_not_silently_drop_instructions(self):
        with self.assertRaisesRegex(SimulationError, f"{MAX_RUN_BUNDLES} bundles"):
            self.execute("nop\n" * (MAX_RUN_BUNDLES + 1), {0: 0})


class ExpectedDataTests(unittest.TestCase):
    def read_json(self, content):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "expected.json"
            path.write_text(json.dumps(content))
            return read_expected(path)

    def test_signed_and_unsigned_32_bit_values(self):
        self.assertEqual(self.read_json({"x1": -2147483648, "x2": "0xffffffff"}),
                         {1: 0x80000000, 2: 0xffffffff})

    def test_invalid_expected_data(self):
        for value in ([], {}, {"x32": 1}, {"x1": True}, {"x1": 4294967296},
                      {"ra": 1, "x1": 2}, {"x1": "0xzz"}):
            with self.subTest(value=value), self.assertRaises((ValueError, SimulationError)):
                self.read_json(value)


if __name__ == "__main__":
    unittest.main()
