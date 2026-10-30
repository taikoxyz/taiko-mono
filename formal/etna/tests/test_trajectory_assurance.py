"""Kernel mutations of the independently recorded principal-flow categories.

These mutations keep valid Lean definitions but remove money movements from the
observer. They must fail its conservation proof, rather than pass by defining
receipts from the resulting balance difference.
"""
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


def combined_accounting():
    imports, bodies = [], []
    for library in ('EtnaModel', 'EtnaProofs'):
        lines = (ROOT/library/'Accounting.lean').read_text().splitlines()
        end = 0
        while end < len(lines) and lines[end].startswith('import '):
            imports.append(lines[end])
            end += 1
        bodies.append('\n'.join(lines[end:]))
    return '\n'.join(dict.fromkeys(i for i in imports if i != 'import EtnaModel.Accounting'))+'\n'+'\n'.join(bodies)


class PrincipalFlowKernelTests(unittest.TestCase):
    def compile(self, source):
        with tempfile.NamedTemporaryFile(dir=ROOT/'.scratch', suffix='.lean', mode='w') as file:
            file.write(source)
            file.flush()
            return subprocess.run(['lake', 'env', 'lean', file.name], cwd=ROOT, capture_output=True, text=True)

    def rejected(self, original, replacement):
        source = combined_accounting()
        self.assertIn(original, source)
        result = self.compile(source.replace(original, replacement, 1))
        self.assertNotEqual(result.returncode, 0, 'an omitted cash flow must break the proof')
        output = result.stdout+result.stderr
        self.assertIn('error:', output)
        self.assertNotIn('already been declared', output)
        self.assertNotIn('unknown module prefix', output)
        self.assertNotIn('unexpected token', output)

    def test_actual_accounting_proofs_compile(self):
        result = self.compile(combined_accounting())
        self.assertEqual(result.returncode, 0, result.stdout+result.stderr)
        self.assertEqual(result.stdout+result.stderr, '')

    def test_omitted_top_up_input_is_rejected(self):
        self.rejected('(fun out => (out,⟨amount,0,0,0⟩))', '(fun out => (out,Flow.zero))')

    def test_omitted_withdrawal_payout_is_rejected(self):
        self.rejected('(fun (out,amount) => (out,⟨0,amount,0,0⟩))', '(fun (out,_) => (out,Flow.zero))')

    def test_omitted_bounty_is_rejected(self):
        self.rejected('(fun (out,bounty,sink) => (out,⟨0,0,bounty,sink⟩))',
                      '(fun (out,_,sink) => (out,⟨0,0,0,sink⟩))')

    def test_omitted_slash_sink_is_rejected(self):
        self.rejected('(fun (out,bounty,sink) => (out,⟨0,0,bounty,sink⟩))',
                      '(fun (out,bounty,_) => (out,⟨0,0,bounty,0⟩))')

    def test_omitted_forfeiture_sink_is_rejected(self):
        self.rejected('(fun (out,penalty) => (out,⟨0,0,0,penalty⟩))', '(fun (out,_) => (out,Flow.zero))')

    def test_failed_call_cannot_count_a_deposit(self):
        self.rejected('(failed : Rejected w) : Step w w Flow.zero',
                      '(failed : Rejected w) : Step w w ⟨1,0,0,0⟩')

    def test_rollback_cannot_recreate_a_deposit(self):
        self.rejected('Step w (ProtocolState.applyRollback w trusted snapshot now) Flow.zero',
                      'Step w (ProtocolState.applyRollback w trusted snapshot now) ⟨1,0,0,0⟩')
