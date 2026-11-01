"""Real-kernel mutations of normal recovery provenance, without synthetic assertions."""
from pathlib import Path
import subprocess
import tempfile
import unittest

from test_signing_bridge import combined_bridge

ROOT = Path(__file__).resolve().parents[1]


def combined_normal():
    imports, bodies = [], []
    for library in ('EtnaModel', 'EtnaProofs'):
        lines = (ROOT/library/'NormalSigning.lean').read_text().splitlines()
        end = 0
        while end < len(lines) and lines[end].startswith('import '):
            imports.append(lines[end])
            end += 1
        bodies.append('\n'.join(lines[end:]).replace('Etna.Design.NormalSigning',
                                                     'Etna.Design.NormalSigningMutation'))
    return '\n'.join(dict.fromkeys(imports))+'\n'+'\n'.join(bodies)


class NormalSigningKernelTests(unittest.TestCase):
    def compile(self, source):
        with tempfile.NamedTemporaryFile(dir=ROOT/'.scratch', suffix='.lean', mode='w') as file:
            file.write(source)
            file.flush()
            return subprocess.run(['lake', 'env', 'lean', file.name], cwd=ROOT, capture_output=True, text=True)

    def rejected(self, old, new, source=None):
        source = combined_normal() if source is None else source
        self.assertIn(old, source)
        result = self.compile(source.replace(old, new, 1))
        output = result.stdout+result.stderr
        self.assertNotEqual(result.returncode, 0, 'a real provenance binding must be necessary')
        self.assertIn('error:', output)
        for accidental in ('already been declared', 'unknown module prefix', 'unexpected token'):
            self.assertNotIn(accidental, output)

    def test_complete_normal_composition_compiles_silently(self):
        result = self.compile(combined_normal())
        self.assertEqual(result.returncode, 0, result.stdout+result.stderr)
        self.assertEqual(result.stdout+result.stderr, '')

    def test_recovery_clock_order_cannot_be_omitted(self):
        self.rejected('time : before.l1Block ≤ origin.l1Block', 'time : True')

    def test_actual_recovery_call_cannot_be_omitted(self):
        self.rejected('accepted : Recovery.recover (recoveryView before) a before.adapters.recovery origin owner externalOK = some s',
                      'accepted : True')

    def test_recovery_generation_cannot_be_unbound(self):
        self.rejected('generation : view.inbox.generation = before.inbox.generation+1', 'generation : True')

    def test_recovery_origin_cannot_be_unbound(self):
        self.rejected('originKept : view.inbox.origin = origin', 'originKept : True')

    def test_confirmation_to_recovery_causality_cannot_be_omitted(self):
        self.rejected('beforeRecovery : OrdinaryTrace confirmed before', 'beforeRecovery : True')

    def test_recovery_to_view_causality_cannot_be_omitted(self):
        self.rejected('afterRecovery : OrdinaryTrace (recovered before a origin s) view', 'afterRecovery : True')

    def test_prior_landing_source_cannot_be_omitted(self):
        self.rejected('source : SnapshotSource w.inbox r.consensus', 'source : True')

    def test_landing_reference_contract_cannot_be_omitted(self):
        self.rejected('reference : i.activeCommitteeSnapshot ≤ i.l1ReferenceBlockNumber', 'reference : True')

    def test_early_recovery_clock_cannot_be_omitted(self):
        self.rejected('clock : before.inbox.snapshot < before.l1Block', 'clock : True', combined_bridge())

    def test_early_recovery_stored_snapshot_cannot_be_unbound(self):
        self.rejected('snapshotKept : s.snapshot = before.inbox.snapshot', 'snapshotKept : True', combined_bridge())
