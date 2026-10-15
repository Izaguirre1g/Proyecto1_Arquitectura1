"""Pruebas de la integración por fuente con los módulos externos de CE1108."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

from tools.run_ce1108_source import compile_driver, run_source
from tools.run_program import SimulationError

ROOT = Path(__file__).resolve().parents[1]
COMPILER = os.environ.get('CE1108_ROOT')
INCLUDES = [Path(p) for p in os.environ.get('CE1108_INCLUDE_DIRS', '').split(os.pathsep) if p]


@unittest.skipUnless(COMPILER, 'defina CE1108_ROOT para usar los módulos del compilador')
class SourceIntegrationTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.temp = tempfile.TemporaryDirectory()
        cls.addClassCleanup(cls.temp.cleanup)
        cls.work = Path(cls.temp.name)
        cls.compiler = Path(COMPILER)
        cls.driver = compile_driver(cls.compiler, cls.work/'driver', INCLUDES)

    def generate(self, body):
        source = self.work/'input.bal'
        source.write_text('create_funk #declare_infinite_void# main() { ' + body + ' }')
        return subprocess.run([str(self.driver), str(source)], capture_output=True, text=True)

    def test_bad_sources_emit_no_program(self):
        cases = [
            'a * declare_int : 1; a * declare_int : 2;',
            'r * declare_int : ausente gauss 1;',
            'a * declare_int : a gauss 1;',
            'a * declare_int;',
            'a * declare_int : declare_true;',
            'a * declare_int : 2 euclides 0;',
            'a * declare_int : 2 descartes neumann 1;',
            'a * declare_int : 1; whale (a < 3) { a : a gauss 1; }',
            'a * declare_int : 1',
            'a * declare_text : "hola";',
            'a * declare_int : 1; a[0] : 2;',
        ]
        for body in cases:
            with self.subTest(body=body):
                result = self.generate(body)
                self.assertNotEqual(result.returncode, 0)
                self.assertEqual(result.stdout, '')
                self.assertTrue(result.stderr)

    def test_alternative_source_reaches_real_memory(self):
        folder = self.work/'alternative'
        folder.mkdir()
        source, expected = folder/'input.bal', folder/'expected.json'
        source.write_text('create_funk #declare_infinite_void# main() { '
                          'a * declare_int : 20; b * declare_int : 7; '
                          'r * declare_int : a neumann b; r : r gauss 2; '
                          'valido * declare_boolean : r == 15; }')
        expected.write_text('{"0x4000":20,"0x4004":7,"0x4008":15,"0x400c":1}')
        registers = run_source(self.compiler, source, expected, folder/'out', INCLUDES)
        self.assertEqual(registers[3], 0x4000)
        self.assertTrue((folder/'out/program.bin').is_file())
        self.assertTrue((folder/'out/program.vcd').is_file())

    def test_wrong_result_fails(self):
        folder = self.work/'wrong'
        folder.mkdir()
        expected = folder/'expected.json'
        expected.write_text('{"0x4008":99}')
        with self.assertRaisesRegex(SimulationError, 'resultados incorrectos'):
            run_source(self.compiler, ROOT/'examples/ce1108_programa.bal', expected,
                       folder/'out', INCLUDES)
        self.assertIn('"status": "pending"', (folder/'out/evidence.json').read_text())

    def test_signed_division_and_remainder(self):
        folder = self.work/'division'
        folder.mkdir()
        source, expected = folder/'input.bal', folder/'expected.json'
        source.write_text('create_funk #declare_infinite_void# main() { '
                          'a * declare_int : neumann 17; b * declare_int : 5; '
                          'q * declare_int : a euclides b; r * declare_int : a euler b; '
                          'limite * declare_int : neumann 2147483648; '
                          'uno * declare_int : neumann 1; '
                          'q2 * declare_int : limite euclides uno; '
                          'r2 * declare_int : limite euler uno; }')
        expected.write_text('{"0x4000":-17,"0x4004":5,"0x4008":-3,"0x400c":-2,'
                            '"0x4010":-2147483648,"0x4014":-1,'
                            '"0x4018":-2147483648,"0x401c":0}')
        run_source(self.compiler, source, expected, folder/'out', INCLUDES, cycles=20000)

    def test_power_with_negative_base_and_overflow(self):
        folder = self.work/'power'
        folder.mkdir()
        source, expected = folder/'input.bal', folder/'expected.json'
        source.write_text('create_funk #declare_infinite_void# main() { '
                          'a * declare_int : neumann 2; '
                          'p * declare_int : a descartes 3; '
                          'q * declare_int : 2 descartes 31; '
                          'cero * declare_int : 0 descartes 0; }')
        expected.write_text('{"0x4000":-2,"0x4004":-8,"0x4008":-2147483648,"0x400c":1}')
        run_source(self.compiler, source, expected, folder/'out', INCLUDES, cycles=40000)

    def test_variable_zero_divisor_does_not_write_result(self):
        folder = self.work/'zero'
        folder.mkdir()
        source, expected = folder/'input.bal', folder/'expected.json'
        source.write_text('create_funk #declare_infinite_void# main() { '
                          'a * declare_int : 17; b * declare_int : 0; '
                          'r * declare_int : 99; r : a euclides b; '
                          'despues * declare_int : 55; }')
        expected.write_text('{"0x4000":17,"0x4004":0,"0x4008":99,"0x400c":0}')
        run_source(self.compiler, source, expected, folder/'out', INCLUDES, cycles=12000)

    def test_variable_negative_exponent_does_not_write_result(self):
        folder = self.work/'negative_power'
        folder.mkdir()
        source, expected = folder/'input.bal', folder/'expected.json'
        source.write_text('create_funk #declare_infinite_void# main() { '
                          'a * declare_int : 2; b * declare_int : neumann 1; '
                          'r * declare_int : 99; r : a descartes b; '
                          'despues * declare_int : 55; }')
        expected.write_text('{"0x4000":2,"0x4004":-1,"0x4008":99,"0x400c":0}')
        run_source(self.compiler, source, expected, folder/'out', INCLUDES, cycles=12000)

    def test_original_source_program(self):
        run_source(self.compiler, ROOT/'examples/ce1108_programa.bal',
                   ROOT/'examples/ce1108_programa.memory.json', self.work/'original', INCLUDES)


if __name__ == '__main__':
    unittest.main()
