"""Compile-first model/fixture mutations for start, rollback and fence fields.

These assertions exercise each fence conjunct on raw synthetic Unzen records;
they do not recompile proofs or establish each guard independently necessary on
reachable traces. Reachable finalizedHash and checkpointHash are always equal,
so their two equality guards imply one another. A nonzero switching start hash
also rules out the initial, checkpointExists=false Unzen state. The checkpoint
height guard is not implied by the others: the fixture reaches a start whose hash
and stateRoot match an Unzen checkpoint at another height. Substantive
switching derivations are recompiled in test_current_switching_proof_mutations.
"""
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


def sources():
    current = (ROOT / 'EtnaModel/Current.lean').read_text()
    fence = current.split('def firstLanding ', 1)[1].split('\nstructure Origin', 1)[0]
    fence = ('namespace Etna.Design.Current.FirstFenceMutation\nopen Start\n'
             'def firstLanding ' + fence + '\nend Etna.Design.Current.FirstFenceMutation\n')
    lines = (ROOT / 'EtnaModel/CurrentProtocol.lean').read_text().splitlines()
    imports = []
    while lines and lines[0].startswith('import '):
        imports.append(lines.pop(0))
    model = '\n'.join(lines).replace('Start.firstLanding', 'FirstFenceMutation.firstLanding')
    fixture = '\n'.join(line for line in (ROOT / 'tests/CurrentGuards.lean').read_text().splitlines()
                        if not line.startswith('import '))
    rename = lambda text: re.sub(r'\bProtocol\b', 'GuardMutationProtocol', text)
    return '\n'.join(imports) + '\n', rename(fence + model), rename(fixture)


class CurrentGuardTests(unittest.TestCase):
    def compile(self, source):
        (ROOT / '.scratch').mkdir(exist_ok=True)
        with tempfile.NamedTemporaryFile(dir=ROOT / '.scratch', suffix='.lean', mode='w') as file:
            file.write(source)
            file.flush()
            return subprocess.run(['lake', 'env', 'lean', file.name], cwd=ROOT,
                                  capture_output=True, text=True, timeout=120)

    def test_unmodified_guard_fixture_compiles(self):
        imports, model, fixture = sources()
        result = self.compile(imports + model + '\n' + fixture)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(result.stdout + result.stderr, '')

    def reject(self, old, new):
        imports, model, fixture = sources()
        self.assertEqual(model.count(old), 1, old)
        mutant = model.replace(old, new, 1)
        result = self.compile(imports + mutant)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        result = self.compile(imports + mutant + '\n' + fixture)
        self.assertNotEqual(result.returncode, 0, 'unchanged executable guard assertions accepted mutant')
        errors = [line for line in (result.stdout + result.stderr).splitlines() if 'error:' in line]
        self.assertTrue(errors, result.stdout + result.stderr)
        for accidental in ('already been declared', 'unknown module prefix', 'unexpected token', 'Unknown identifier'):
            self.assertNotIn(accidental, errors[0])

    def test_once_only_origin_guard(self):
        self.reject('w.start = none ∧ w.inbox.generation = 0', 'w.inbox.generation = 0')

    def test_origin_waits_for_fork_time(self):
        self.reject('env.core.forkTime ≤ env.time w.number', 'True')

    def test_correction_opens_new_generation(self):
        self.reject('(env.time w.number) (w.inbox.generation+1))', '(env.time w.number) w.inbox.generation)')

    def test_correction_stays_closed_after_rollback(self):
        self.reject('w.everLanded = false ∧', 'True ∧')

    def test_rollback_snapshot_pair_guard(self):
        self.reject('(trusted,snapshot) ∈ w.activeSnapshots', 'True')

    def test_rollback_filters_newer_signals(self):
        self.reject('w.inbox.signals.filter (fun s => s.height ≤ trusted.height)', 'w.inbox.signals')

    def test_fence_next_proposal(self):
        self.reject('u.nextProposal = u.finalizedProposal+1', 'u.nextProposal = u.nextProposal')

    def test_fence_finalized_hash(self):
        self.reject('u.finalizedHash = hash', 'u.finalizedHash = u.finalizedHash')

    def test_fence_checkpoint_exists(self):
        self.reject('u.checkpointExists = true', 'u.checkpointExists = u.checkpointExists')

    def test_fence_checkpoint_height(self):
        self.reject('u.checkpointHeight = start', 'u.checkpointHeight = u.checkpointHeight')

    def test_fence_checkpoint_hash(self):
        self.reject('u.checkpointHash = hash', 'u.checkpointHash = u.checkpointHash')

    def test_fence_checkpoint_root(self):
        self.reject('u.checkpointRoot = root', '(u.checkpointRoot = root ∨ u.checkpointRoot ≠ root)')


if __name__ == '__main__':
    unittest.main()
