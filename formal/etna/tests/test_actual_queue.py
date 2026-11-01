"""Real semantic guard mutations: weakened models first, unchanged proofs second."""
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


def layers():
    imports, bodies = [], []
    for library in ('EtnaModel', 'EtnaProofs'):
        lines = (ROOT/library/'ActualQueue.lean').read_text().splitlines()
        end = 0
        while end < len(lines) and lines[end].startswith('import '):
            imports.append(lines[end])
            end += 1
        bodies.append('\n'.join(lines[end:]).replace('Etna.Design.ActualQueue',
                                                     'Etna.Design.ActualQueueMutation'))
    return '\n'.join(dict.fromkeys(imports))+'\n', *bodies


class ActualQueueKernelTests(unittest.TestCase):
    def compile(self, source):
        with tempfile.NamedTemporaryFile(dir=ROOT/'.scratch', suffix='.lean', mode='w') as file:
            file.write(source)
            file.flush()
            return subprocess.run(['lake', 'env', 'lean', file.name], cwd=ROOT, capture_output=True, text=True)

    def rejected(self, old, new):
        imports, model, proofs = layers()
        self.assertEqual(model.count(old), 1)
        changed = model.replace(old, new, 1)
        baseline = self.compile(imports+changed)
        self.assertEqual(baseline.returncode, 0, baseline.stdout+baseline.stderr)
        self.assertEqual(baseline.stdout+baseline.stderr, '')
        result = self.compile(imports+changed+'\n'+proofs)
        output = result.stdout+result.stderr
        self.assertNotEqual(result.returncode, 0, 'weakened semantic boundary must invalidate a proof')
        self.assertIn('error:', output)
        first = output.splitlines()[0]
        for accidental in ('already been declared', 'unknown module prefix', 'unexpected token', 'Unknown identifier'):
            self.assertNotIn(accidental, first)
        logs = ROOT/'.scratch/safety-completion/task6-mutants'
        logs.mkdir(parents=True, exist_ok=True)
        (logs/(self._testMethodName+'.log')).write_text(
            'MODEL-ONLY: exit 0, empty diagnostics\nUNCHANGED PROOFS: exit '+str(result.returncode)+'\n'+output)

    def test_unmodified_layers_compile_silently(self):
        result = self.compile('\n'.join(layers()))
        self.assertEqual(result.returncode, 0, result.stdout+result.stderr)
        self.assertEqual(result.stdout+result.stderr, '')

    def test_real_due_recovery_and_local_cursor_regression(self):
        result = self.compile((ROOT/'tests/ActualQueue.lean').read_text())
        self.assertEqual(result.returncode, 0, result.stdout+result.stderr)
        self.assertEqual(result.stdout+result.stderr, '')

    def test_enqueue_must_record_actual_block_time(self):
        self.rejected('(clock : timestamp = time now)', '(clock : True)')

    def test_end_block_cut_must_include_same_block_transactions(self):
        self.rejected('after : ∀ state ∈ laterStates, anchor.number < state.l1Block',
                      'after : ∀ state ∈ laterStates, anchor.number ≤ state.l1Block')

    def test_tail_is_the_opened_storage_tail(self):
        self.rejected('tail : anchor.tail = snapshot.inbox.tail', 'tail : anchor.tail ≤ snapshot.inbox.tail')

    def test_anchor_timestamp_is_the_l1_clock(self):
        self.rejected('timestamp : anchor.timestamp = time anchor.number', 'timestamp : True')

    def test_storage_opens_the_same_historical_queue(self):
        self.rejected('(witness.index,witness.stored) ∈ snapshot.queue ∧ witness.storageAuthenticated = true',
                      'snapshot.queue = snapshot.queue ∧ witness.storageAuthenticated = true')

    def test_rules_bind_the_current_recovery_origin(self):
        self.rejected('rules.consensus.originBlock = current.inbox.origin.l1Block',
                      'rules.consensus.originBlock = rules.consensus.originBlock ∧ current = current')

    def test_raw_hash_must_match_the_actual_bytes(self):
        self.rejected('witness.rawHash = primitive.hashBytes raw', 'True')

    def test_raw_parse_must_match_the_actual_bytes(self):
        self.rejected('witness.canonical = primitive.canonical raw', 'True')

    def test_raw_size_must_match_the_actual_bytes(self):
        self.rejected('witness.rawBytes = raw.length', 'True')

    def test_position_zero_hash_must_match_actual_bytes(self):
        self.rejected('witness.firstHash = first.map primitive.hashBytes', 'True')

    def test_position_zero_parser_must_match_actual_bytes(self):
        self.rejected('witness.firstCanonical = (first.map primitive.canonical).getD false', 'True')

    def test_position_zero_size_must_match_actual_bytes(self):
        self.rejected('witness.firstBytes = (first.map List.length).getD 0', 'True')

    def test_singleton_result_must_match_deterministic_context(self):
        self.rejected('block.singleton = primitive.buildSingleton parent block.header raw',
                      'parent = parent ∧ block.header = block.header')
