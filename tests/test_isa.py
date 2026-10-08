"""Campos LSU/BRU/cripto, saltos y conflictos entre slots."""
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

from tools.assembler import AssemblyError, assemble_source, encode_instruction

ROOT = Path(__file__).resolve().parents[1]


class IsaTests(unittest.TestCase):
    def test_fixed_words(self):
        cases = {
            'guardap x3,x4,-4': 0x920327fc,
            'guardab x3,x4,-4': 0x922327fc,
            'cargai x5,x3,4': 0x93032804,
            'cargabai x5,x3,4': 0x93232804,
            'igualsi x4,x5,-16': 0x82242ff0,
            'igualno x4,x5,-16': 0x82442ff0,
            'menora x4,x5,-16': 0x82842ff0,
            'mayoroigual x4,x5,-16': 0x83042ff0,
            'sye x1,32': 0x96010020,
            'fsl x6,x2,1,3': 0x040e6100,
            'fsli x6,x2,1,3': 0x042e6100,
            'ell 2,2,x4,x6': 0x04544300,
            'vcr 0x2000': 0x04640000,
            'camcon 0x10,7': 0x04800207,
            'setpwd x5': 0x04a00005,
        }
        for source, expected in cases.items():
            with self.subTest(source=source):
                self.assertEqual(encode_instruction(source).word, expected)

    def test_official_named_crypto_operands(self):
        pairs = [('fsl RK=3, rd=6, LK=1, r1=2', 'fsl x6,x2,1,3'),
                 ('ell LK=2,off=2,rs1=4,rs2=6', 'ell 2,2,x4,x6'),
                 ('vcr dir_cand=0x2000', 'vcr 0x2000'),
                 ('camcom dir=0x10,imm=7', 'camcon 0x10,7'),
                 ('setpwd rs=5', 'setpwd x5')]
        for left, right in pairs:
            self.assertEqual(encode_instruction(left).word, encode_instruction(right).word)

    def test_crypto_restrictions(self):
        invalid = ['fsl x0,x2,0,0', 'fsli x31,x2,0,0', 'fsl x2,x3,0,0',
                   'fsl x2,x4,4,0', 'fsl x2,x4,0,-1', 'ell 0,1,x2,x4',
                   'ell 0,3,x2,x4', 'ell 0,0,x1,x4', 'vcr 65536',
                   'vcr -1', 'camcon 0,32', 'setpwd rs=32',
                   'fsl rd=2,r1=4,LK=0,LK=1', 'setpwd bad=5']
        for source in invalid:
            with self.subTest(source=source), self.assertRaises(AssemblyError):
                encode_instruction(source)
        self.assertEqual(encode_instruction('fsl x30,x30,3,3').writes, (30, 31))
        self.assertEqual(encode_instruction('vcr 65535').word & 31, 0)

    def test_memory_immediate_limits(self):
        for name in ('guardap', 'guardab', 'cargai', 'cargabai'):
            for offset in (-1024, 1023):
                self.assertEqual(encode_instruction(f'{name} x2,x4,{offset}').word & 2047, offset & 2047)
            for offset in (-1025, 1024):
                with self.assertRaises(AssemblyError):
                    encode_instruction(f'{name} x2,x4,{offset}')

    def test_jump_limits_and_alignment(self):
        for source in ('sye x1,-32768', 'sye x1,32752', 'igualsi x1,x2,-1024', 'igualsi x1,x2,1008'):
            encode_instruction(source)
        for source in ('sye x1,32768', 'sye x1,-32784', 'igualsi x1,x2,1024', 'sye x1,4'):
            with self.assertRaises(AssemblyError):
                encode_instruction(source)

    def test_labels_forward_backward_and_pc_relative(self):
        program = assemble_source('start: nop | nop | sye x0,end | nop\nnop\nend: nop | nop | igualsi x0,x0,start | nop')
        self.assertEqual(program.bundles[0].instructions[2].word & 65535, 32)
        self.assertEqual(program.bundles[2].instructions[2].word & 2047, 2016)
        for source in ('a: nop\na: nop', 'nop | nop | sye x0,missing | nop',
                       'nop | nop | sye x0,end | nop\nend:', 'nop | nop | sye x0,-16 | nop'):
            with self.assertRaises(AssemblyError):
                assemble_source(source)

    def test_slot_layout_and_binary_order(self):
        source = 'suma x5,x2,x3 | guardap x0,x4,256 | igualno x0,x0,0 | vcr 256'
        bundle = assemble_source(source)
        expected = '046020008240000092002100d50510c0'
        self.assertEqual(bundle.memory_text(), expected + '\n')
        self.assertEqual(bundle.binary(), bytes.fromhex(expected)[::-1])
        for source in ('cargai x1,x2,0 | nop | nop | nop', 'nop | nop | vcr 0 | nop'):
            with self.assertRaises(AssemblyError):
                assemble_source(source)

    def test_cross_slot_raw_waw_including_pair_high_register(self):
        for source in ('sumai x4,x0,1 | guardap x0,x4,0 | nop | nop',
                       'sumai x4,x0,1 | cargai x4,x0,0 | nop | nop',
                       'sumai x7,x0,1 | nop | nop | fsl x6,x2,0,0',
                       'sumai x3,x0,1 | nop | nop | fsl x6,x2,0,0'):
            with self.subTest(source=source), self.assertRaises(AssemblyError):
                assemble_source(source)

    def test_raw_across_taken_jump_and_backedge(self):
        for source in ('sumai x4,x0,1 | nop | sye x0,target | nop\nnop\nnop\ntarget: mov x5,x4 | nop | nop | nop',
                       'loop: sumai x4,x4,1 | nop | igualno x0,x0,loop | nop'):
            with self.assertRaisesRegex(AssemblyError, 'RAW'):
                assemble_source(source)
        assemble_source('sumai x4,x0,1 | nop | sye x0,target | nop\ntarget: nop\nnop\nmov x5,x4 | nop | nop | nop')

    def test_cli_binary_and_no_overwriting_input(self):
        with tempfile.TemporaryDirectory() as folder:
            folder = Path(folder)
            source, mem, binary = folder/'p.asm', folder/'p.mem', folder/'p.bin'
            source.write_text('nop')
            cmd = [sys.executable, str(ROOT/'tools/assembler.py'), '--input', str(source), '--output', str(mem), '--binary']
            result = subprocess.run(cmd + [str(binary)], capture_output=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(binary.read_bytes(), bytes(16))
            result = subprocess.run(cmd + [str(source)], capture_output=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertEqual(source.read_text(), 'nop')

    def test_all_examples_assemble(self):
        for path in sorted((ROOT/'examples').glob('*.asm')):
            with self.subTest(path=path.name):
                assemble_source(path.read_text())


if __name__ == '__main__':
    unittest.main()
