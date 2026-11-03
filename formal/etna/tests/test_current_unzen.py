"""Ordinary Unzen proofs must advance and link to their stored endpoint."""
from pathlib import Path
import re
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


def sources():
    imports, bodies = ['import EtnaProofs.CurrentEncoding'], []
    for name in ('CurrentProtocol', 'CurrentCustody', 'CurrentCoherentCustody', 'CurrentUnzen'):
        lines = (ROOT / f'EtnaModel/{name}.lean').read_text().splitlines()
        while lines and lines[0].startswith('import '):
            line = lines.pop(0)
            if not any(
                    line == f'import EtnaModel.{n}' for n in
                    ('CurrentProtocol', 'CurrentCustody', 'CurrentCoherentCustody', 'CurrentUnzen')):
                imports.append(line)
        bodies.append('\n'.join(lines))
    fixture = (ROOT / 'tests/CurrentUnzen.lean').read_text()
    fixture = '\n'.join(line for line in fixture.splitlines() if not line.startswith('import '))
    fixture = re.sub(r'example : Custody.LegacyPrefix env wrongStart :=\n'
                     r'  Custody.trace_legacy_prefix primitives extension wrong_start_reachable\n', '', fixture)
    fixture = re.sub(r'example : Custody.LegacyPrefix longerEnv longerExtended10 :=\n'
                     r'  Custody.trace_legacy_prefix \(env := longerEnv\)\n'
                     r'    ⟨primitives.genesis,primitives.separation,primitives.unzen⟩ extension longer_extension_reachable\n', '', fixture)
    rename = lambda text: re.sub(r'\bProtocol\b', 'UnzenMutationProtocol', text)
    return '\n'.join(dict.fromkeys(imports)) + '\n', rename('\n'.join(bodies)), rename(fixture)


class CurrentUnzenTests(unittest.TestCase):
    def compile(self, source):
        (ROOT / '.scratch').mkdir(exist_ok=True)
        with tempfile.NamedTemporaryFile(dir=ROOT / '.scratch', suffix='.lean', mode='w') as file:
            file.write(source)
            file.flush()
            return subprocess.run(['lake', 'env', 'lean', file.name], cwd=ROOT,
                                  capture_output=True, text=True, timeout=120)

    def test_joint_primitive_replay_and_parent_regressions(self):
        result = subprocess.run(['lake', 'env', 'lean', 'tests/CurrentUnzen.lean'], cwd=ROOT,
                                capture_output=True, text=True, timeout=120)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(result.stdout + result.stderr, '')

    def test_external_upgrade_history_refinement(self):
        result = subprocess.run(['lake', 'env', 'lean', 'tests/CurrentGovernance.lean'], cwd=ROOT,
                                capture_output=True, text=True, timeout=120)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(result.stdout + result.stderr, '')

    def test_unmodified_mutation_fixture_compiles(self):
        imports, model, evidence = sources()
        result = self.compile(imports + model + '\n' + evidence)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(result.stdout + result.stderr, '')

    def test_all_fourteen_premises_switch_and_two_lane_theorem(self):
        result = subprocess.run(['lake', 'env', 'lean', 'tests/CurrentSwitch.lean'], cwd=ROOT,
                                capture_output=True, text=True, timeout=120)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(result.stdout + result.stderr, '')

    def reject(self, old, new):
        imports, model, evidence = sources()
        self.assertEqual(model.count(old), 1, old)
        mutant = model.replace(old, new, 1)
        result = self.compile(imports + mutant)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        result = self.compile(imports + mutant + '\n' + evidence)
        self.assertNotEqual(result.returncode, 0, 'unchanged evidence accepted the weakened Unzen lane')
        errors = [line for line in (result.stdout + result.stderr).splitlines() if 'error:' in line]
        self.assertTrue(errors, result.stdout + result.stderr)
        for accidental in ('already been declared', 'unknown module prefix', 'unexpected token', 'Unknown identifier'):
            self.assertNotIn(accidental, errors[0])

    def test_replaying_finalized_proposal_is_rejected(self):
        self.reject('w.unzen.finalizedProposal < proposal ∧ proposal < w.unzen.nextProposal',
                    'w.unzen.finalizedProposal ≤ proposal ∧ proposal < w.unzen.nextProposal')

    def test_higher_proposal_still_requires_the_stored_parent(self):
        self.reject('env.unzenParent w.unzen.finalizedProposal proposal h proof = w.unzen.finalizedHash ∧',
                    'True ∧')


if __name__ == '__main__':
    unittest.main()
