"""Current complete-block queue journal and its actual local-service evidence."""
from pathlib import Path
import re
import subprocess
import tempfile
import unittest
import os


def setUpModule():
    if os.environ.get('ETNA_FULL_TESTS') != '1':
        raise unittest.SkipTest('mutation suite: set ETNA_FULL_TESTS=1 (CI job etna-formal-full)')

ROOT = Path(__file__).resolve().parents[1]


def layers():
    model_paths = ('EtnaModel/CurrentProtocol.lean', 'EtnaModel/CurrentJournal.lean')
    support_paths = tuple(f'EtnaModel/{name}.lean' for name in
                          ('CurrentProtocolFinality', 'CurrentEconomics', 'CurrentMetadata'))
    bridge_paths = tuple(f'EtnaProofs/{name}.lean' for name in
                         ('CurrentReference', 'CurrentHistory', 'CurrentProtocolFinality',
                          'CurrentEconomics', 'CurrentMetadata', 'CurrentFootprintHistory',
                          'CurrentCertificate', 'CurrentSettlement'))
    final_paths = ('EtnaProofs/CurrentJournal.lean', 'tests/CurrentJournal.lean')
    paths = model_paths + support_paths + bridge_paths + final_paths
    cloned = {path.removesuffix('.lean').replace('/', '.') for path in paths}
    imports, bodies = [], {}
    for path in paths:
        body = []
        for line in (ROOT / path).read_text().splitlines():
            if line.startswith('import '):
                if line.removeprefix('import ') not in cloned:
                    imports.append(line)
            else:
                body.append(line)
        text = '\n'.join(body)
        for namespace in ('Protocol', 'Journal', 'ProtocolFinality', 'Economics'):
            text = re.sub(r'\b' + namespace + r'\b', namespace + 'Mutation', text)
        bodies[path] = text
    bridge = '\n'.join(bodies[path] for path in support_paths + bridge_paths)
    return ('\n'.join(dict.fromkeys(imports)) + '\n',
            *(bodies[path] for path in model_paths), bridge,
            *(bodies[path] for path in final_paths))


class CurrentJournalTests(unittest.TestCase):
    def compile(self, source):
        with tempfile.NamedTemporaryFile(dir=ROOT / '.scratch', suffix='.lean', mode='w') as file:
            file.write(source)
            file.flush()
            return subprocess.run(['lake', 'env', 'lean', file.name], cwd=ROOT,
                                  capture_output=True, text=True, timeout=90)

    def test_kernel_regressions(self):
        result = subprocess.run(['lake', 'env', 'lean', 'tests/CurrentJournal.lean'],
                                cwd=ROOT, capture_output=True, text=True, timeout=90)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(result.stdout + result.stderr, '')

    def test_unchanged_mutation_layers_compile(self):
        result = self.compile('\n'.join(layers()))
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(result.stdout + result.stderr, '')

    def reject(self, old, new):
        imports, protocol, journal, settlement, proofs, fixture = layers()
        self.assertEqual(protocol.count(old), 1, old)
        changed = protocol.replace(old, new)
        result = self.compile(imports + changed + '\n' + journal)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(result.stdout + result.stderr, '')
        result = self.compile(imports + changed + '\n' + journal + '\n' + settlement + '\n' + proofs + '\n' + fixture)
        self.assertNotEqual(result.returncode, 0, 'unchanged evidence accepted semantic mutant')
        errors = [line for line in (result.stdout + result.stderr).splitlines() if 'error:' in line]
        self.assertTrue(errors)
        for accidental in ('already been declared', 'unknown module prefix', 'unexpected token', 'Unknown identifier'):
            self.assertNotIn(accidental, errors[0])


MUTATIONS = [
    ('land_frontier_lookup', 'checkpoint := cp,records := writeRecord w.inbox.records cp,',
     'checkpoint := cp,records := w.inbox.records,'),
    ('rollback_retains_frontier', 'r ∉ w.activeRecords ∨ r.height ≤ trusted.height',
     'r ∉ w.activeRecords ∨ r.height < trusted.height'),
    ('actual_storage_opening', 'decide ((witness.index,witness.stored) ∈ s.queue)',
     'decide ((witness.index,witness.stored) ∈ s.queue ∨ True)'),
    ('admission_clock', 'env.time w.number,w.number⟩', 'env.time (w.number+1),w.number⟩'),
    ('end_block_upper_bound', 'List.range\' w.number (number-w.number)',
     'List.range\' w.number (number-w.number+1)'),
    ('same_block_tail', '.map (snapshot env w)',
     '.map (snapshot env {w with queue := w.queue.take 1})'),
    ('clear_keeps_metadata', 'then Forced.clear (emptyHash env) e else e',
     'then { (Forced.clear (emptyHash env) e) with timestamp := 0 } else e'),
    ('rollback_head', 'head := trusted.cursor,snapshot', 'head := w.inbox.tail,snapshot'),
    ('sweep_preserves_queue', '(Forced.sweep w.inbox transfer).map fun inbox => { w with inbox := inbox }',
     '(Forced.sweep w.inbox transfer).map fun inbox => { w with inbox := inbox,queue := [] }'),
    ('clearing_new_generation', 'generation := w.inbox.generation+1,', 'generation := w.inbox.generation,'),
]


def mutation_test(old, new):
    def test(self):
        self.reject(old, new)
    return test


for name, old, new in MUTATIONS:
    setattr(CurrentJournalTests, 'test_mutation_' + name, mutation_test(old, new))
