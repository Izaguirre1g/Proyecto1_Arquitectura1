"""Main del compilador combinado, ejecutada en el procesador real."""
import json
import math
import os
from pathlib import Path
import tempfile
import unittest
from tools.run_ce1108_source import run_source
from tools.run_program import SimulationError

COMPILER = os.environ.get('CE1108_ROOT')
INCLUDES = [Path(p) for p in os.environ.get('CE1108_INCLUDE_DIRS', '').split(os.pathsep) if p]


@unittest.skipUnless(COMPILER, 'defina CE1108_ROOT con ambas ramas de Compiladores combinadas')
class CompilerFunctionTests(unittest.TestCase):
    def test_factorials_return_and_restore_stack(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            compiler = Path(COMPILER)
            original = (compiler/'examples/factorial.bal').read_text()
            for n in (0, 1, 5, 7, 12):
                with self.subTest(n=n):
                    folder = root/str(n)
                    folder.mkdir()
                    source, expected = folder/'input.bal', folder/'expected.json'
                    self.assertIn('n * declare_int : 5;', original)
                    source.write_text(original.replace('n * declare_int : 5;', f'n * declare_int : {n};', 1))
                    expected.write_text(json.dumps({'0xfff4': n, '0xfff8': math.factorial(n),
                                                    '0xfffc': 2 if n <= 1 else n + 1}))
                    registers = run_source(compiler, source, expected, folder/'out', INCLUDES,
                                           cycles=20000, functions=True)
                    self.assertEqual(registers[2], 0x10000)
                    proof = json.loads((folder/'out/evidence.json').read_text())
                    self.assertEqual(proof['status'], 'PASS')
                    self.assertEqual(proof['expected_memory']['0x4000'], '0x1')
                    self.assertEqual(registers[1], int(proof['expected_registers']['x1'], 16))

    def test_incorrect_factorial_is_rejected(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            expected = root/'expected.json'
            expected.write_text('{"0xfff8":119}')
            with self.assertRaisesRegex(SimulationError, 'resultados incorrectos'):
                run_source(Path(COMPILER), Path(COMPILER)/'examples/factorial.bal', expected,
                           root/'out', INCLUDES, cycles=20000, functions=True)

    def test_runtime_trap_does_not_count_as_successful_return(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            source, expected = root/'input.bal', root/'expected.json'
            source.write_text('create_funk #declare_infinite_void# main() { '
                              'a * declare_int : 17; b * declare_int : 0; '
                              'r * declare_int : a euclides b; }')
            expected.write_text('{"0xfff4":17}')
            with self.assertRaisesRegex(SimulationError, r'mem\[0x4000\]'):
                run_source(Path(COMPILER), source, expected, root/'out', INCLUDES,
                           cycles=20000, functions=True)


if __name__ == '__main__':
    unittest.main()
