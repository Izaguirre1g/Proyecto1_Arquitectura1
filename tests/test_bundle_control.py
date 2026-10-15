import unittest
from tools.assembler import AssemblyError, assemble_source
from tools.bundle_linear import bundle_linear
from tools.bundle_control import bundle_control


class ControlBundlerTests(unittest.TestCase):
    def test_linear_output_is_preserved(self):
        source = 'sumai x4,x0,1\ncargai x5,x3,0\nsuma x4,x4,x5\n'
        self.assertEqual(bundle_control(source), bundle_linear(source))

    def test_loop_targets_padding(self):
        program = assemble_source(bundle_control(
            'sumai x4,x0,3\npaso:\nrestai x4,x4,1\nigualno x4,x0,paso\n'))
        branch = program.bundles[-1].instructions[2]
        index = branch.target // 16
        self.assertEqual(program.bundles[index].word, 0)
        self.assertEqual(program.bundles[index + 1].word, 0)
        self.assertNotEqual(program.bundles[index + 2].word, 0)

    def test_return_is_scheduled_after_ra_load(self):
        program = assemble_source(bundle_control('cargai x1,x2,0\nsyer x0,x1,0\n'))
        self.assertTrue(program.bundles[-1].instructions[2].indirect)
        self.assertEqual([b.index for b in program.bundles if b.word], [0, 3])

    def test_far_forward_conditional_uses_direct_jump(self):
        source = 'igualsi x4,x0,fin\n' + 'sumai x5,x0,1\n' * 30 + 'fin:\nnop\n'
        output = bundle_control(source)
        self.assertIn('igualno x4, x0, __bc_skip_', output)
        self.assertIn('sye x0, fin', output)
        assemble_source(output)

    def test_far_backward_conditional_uses_direct_jump(self):
        source = 'inicio:\nsumai x4,x0,1\n' + 'sumai x5,x0,1\n' * 30 + 'igualno x4,x0,inicio\n'
        output = bundle_control(source)
        self.assertIn('igualsi x4, x0, __bc_skip_', output)
        self.assertIn('sye x0, inicio', output)
        assemble_source(output)

    def test_invalid_control_is_rejected(self):
        for source in ('sye x0,ausente', 'a:\na:\nnop', 'vcr 256',
                       'nop | nop | nop | nop'):
            with self.subTest(source=source), self.assertRaises(AssemblyError):
                bundle_control(source)


if __name__ == '__main__':
    unittest.main()
