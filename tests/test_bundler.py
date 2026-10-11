"""Adaptación de la salida lineal del generador de CE1108."""
from pathlib import Path
import unittest
from tools.assembler import AssemblyError, MAX_BUNDLES, assemble_source, SPECS, LSU_OPS, BRU_OPS, CRYPTO_OPS
from tools.bundle_linear import bundle_linear

ROOT = Path(__file__).resolve().parents[1]


class BundlerTests(unittest.TestCase):
    def test_example_matches_actual_compiler_output(self):
        source = (ROOT/'examples/ce1108.linear').read_text()
        output = bundle_linear(source)
        self.assertEqual(output, (ROOT/'examples/ce1108.asm').read_text())
        program = assemble_source(output)
        active = [(b.index, i.slot, i.text) for b in program.bundles for i in b.instructions if i.word]
        self.assertEqual([row[0] for row in active], [0, 3, 6, 9, 12, 15])
        self.assertEqual([row[1] for row in active], [1, 1, 0, 0, 0, 1])
        self.assertEqual([row[2] for row in active], source.splitlines())

    def test_control_crypto_and_bundles_rejected(self):
        for source in ('sye x0,0', 'vcr 256', 'nop | nop | nop | nop', '# vacío'):
            with self.assertRaises(AssemblyError):
                bundle_linear(source)

    def test_capacity(self):
        # n instrucciones ocupan 3n - 2 bundles (dos NOP entre cada una)
        n = (MAX_BUNDLES + 2) // 3
        self.assertEqual(len(assemble_source(bundle_linear('sumai x4,x0,1\n' * n)).bundles), 3 * n - 2)
        with self.assertRaises(AssemblyError):
            bundle_linear('sumai x4,x0,1\n' * (n + 1))

    def test_examples_cover_the_33_defined_instructions(self):
        used = set()
        for path in (ROOT/'examples').glob('*.asm'):
            for bundle in assemble_source(path.read_text()).bundles:
                used.update(i.text.split()[0] for i in bundle.instructions)
        required = set(SPECS) | set(LSU_OPS) | set(BRU_OPS) | set(CRYPTO_OPS) | {'sye'}
        self.assertEqual(len(required), 33)
        self.assertFalse(required - used, required - used)


if __name__ == '__main__':
    unittest.main()
