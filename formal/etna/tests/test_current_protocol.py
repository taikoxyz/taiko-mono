"""Current app trust and funded initial state reject compilable weakened models."""
import importlib.util
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
# Loaded by path so this module also runs alone (`python3 -m unittest tests.test_current_protocol`).
_FINALITY = importlib.util.spec_from_file_location('current_protocol_finality_sources',
                                                   ROOT/'tests/test_current_protocol_finality.py')
_finality = importlib.util.module_from_spec(_FINALITY)
_FINALITY.loader.exec_module(_finality)
finality_sources = _finality.sources


def node_sources():
    model = (ROOT / 'EtnaModel/CurrentProtocol.lean').read_text()
    fixture = (ROOT / 'tests/CurrentProtocol.lean').read_text().replace(
        'import EtnaModel.CurrentProtocol', '')
    return tuple(re.sub(r'\bProtocol\b', 'ProtocolMutation', source)
                 for source in (model, fixture))


class CurrentProtocolTests(unittest.TestCase):
    def compile(self, source):
        # No shared olean writes: these tests can run alongside the repository audit.
        with tempfile.NamedTemporaryFile(dir=ROOT / '.scratch', suffix='.lean', mode='w') as file:
            file.write(source)
            file.flush()
            return subprocess.run(['lake', 'env', 'lean', file.name], cwd=ROOT,
                                  capture_output=True, text=True, timeout=120)

    def assert_compiles(self, source):
        result = self.compile(source)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(result.stdout + result.stderr, '')

    def assert_evidence_rejects(self, model, evidence, old, new, at=None):
        self.assertEqual(model.count(old), 1, old)
        changed = model.replace(old, new)
        self.assert_compiles(changed)
        result = self.compile(changed + '\n' + evidence)
        self.assertNotEqual(result.returncode, 0, 'unchanged fixture accepted semantic mutant')
        errors = [line for line in (result.stdout + result.stderr).splitlines() if 'error:' in line]
        self.assertTrue(errors, result.stdout + result.stderr)
        for accidental in ('already been declared', 'unknown module prefix',
                           'unexpected token', 'Unknown identifier'):
            self.assertNotIn(accidental, errors[0])
        if at is not None:
            # Name each failing example by the comment line above it; the intended one must fail.
            lines, rejected = (changed + '\n' + evidence).splitlines(), set()
            for error in errors:
                location = re.search(r'\.lean:(\d+):\d+: error:', error)
                self.assertIsNotNone(location, error)
                rejected.add(next(line for line in reversed(lines[:int(location.group(1))])
                                  if line.startswith('-- ')))
            self.assertIn(at, rejected, result.stdout + result.stderr)

    def test_renamed_node_fixture(self):
        self.assert_compiles('\n'.join(node_sources()))

    def test_trust_requires_initialized_inbox(self):
        self.assert_evidence_rejects(*node_sources(),
            'w.initialized = true ∧ ∃ start, w.start = some start ∧',
            'w.initialized = w.initialized ∧ ∃ start, w.start = some start ∧')

    def test_trust_requires_authenticated_origin_hash(self):
        self.assert_evidence_rejects(*node_sources(),
            'env.headerHash p = p.elHash ∧',
            'env.headerHash p = env.headerHash p ∧')

    def test_switching_trust_requires_unzen_origin(self):
        self.assert_evidence_rejects(*node_sources(),
            'env.unzenRoot p ∧ env.startImplementation p.stateRoot = true',
            'True ∧ env.startImplementation p.stateRoot = true')

    # SPEC 8.3 has no planned-stop check (START-10.1-14e, vector 14e.k): re-adding any part of
    # the old stop check to `recover`'s upgrade branch must break the structural-recovery
    # regression in tests/CurrentProtocol.lean.
    def test_structural_recovery_needs_no_planned_stop(self):
        self.assert_evidence_rejects(*node_sources(),
            'parameters.valid = true ∧ a.rules ≠ 0 ∧',
            'parameters.valid = true ∧ a.rules ≠ 0 ∧ w.schedule.stopTime ≠ 0 ∧')

    def test_structural_recovery_needs_no_stop_in_effect(self):
        self.assert_evidence_rejects(*node_sources(),
            'parameters.valid = true ∧ a.rules ≠ 0 ∧',
            'parameters.valid = true ∧ a.rules ≠ 0 ∧ '
            'w.schedule.stopTime ≤ env.timestampOf w.inbox.checkpoint.elHash ∧')

    def test_structural_recovery_needs_no_stop_grid(self):
        self.assert_evidence_rejects(*node_sources(),
            'parameters.valid = true ∧ a.rules ≠ 0 ∧',
            'parameters.valid = true ∧ a.rules ≠ 0 ∧ '
            '(w.inbox.checkpoint.height-start.height) % w.schedule.stopGrid = 0 ∧')

    # The five guards left on a structural recovery each reject one variant in the
    # structural-recovery regression; removing a guard must break that variant's example.
    def test_structural_recovery_needs_valid_parameters(self):
        self.assert_evidence_rejects(*node_sources(),
            'parameters.valid = true ∧ a.rules ≠ 0 ∧',
            'a.rules ≠ 0 ∧',
            at='-- A structural recovery installs only valid parameters: K = 1 with forcedDelay = 0 is refused.')

    def test_structural_recovery_keeps_genesis_cutoff(self):
        self.assert_evidence_rejects(*node_sources(),
            'parameters.genesisCutoff = w.inbox.genesisCutoff) then',
            'True) then',
            at='-- genesisCutoff is fixed at initialization (PARAM-11-4): valid parameters that change it are refused.')

    def test_structural_recovery_needs_nonzero_rules(self):
        self.assert_evidence_rejects(*node_sources(),
            'parameters.valid = true ∧ a.rules ≠ 0 ∧',
            'parameters.valid = true ∧',
            at='-- 14e.g: a structural recovery must name a new ruleset.')

    def test_recovery_rules_must_be_next_ruleset(self):
        # `Rules.recover` inlined without its `rules = s.next+1` check.
        self.assert_evidence_rejects(*node_sources(),
            '(Rules.recover w.schedule a.rules).bind fun schedule =>',
            '(if a.rules = 0 then Rules.recover w.schedule 0 else if a.rules < limit48 then '
            'some (Rules.Schedule.mk a.rules a.rules 0 0 0) else none).bind fun schedule =>',
            at='-- `rules` must be nextRules + 1; nextRules + 2 skips a ruleset number.')

    def test_structural_recovery_grid_uses_installed_k(self):
        # Checking the grid with the K before the upgrade is the 14e.h bug; dropping the check
        # entirely accepts a superset, so this fixture rejects that too.
        self.assert_evidence_rejects(*node_sources(),
            'Start.onGrid start.height inbox.gridK w.inbox.checkpoint.height = true ∧',
            'Start.onGrid start.height w.inbox.gridK w.inbox.checkpoint.height = true ∧',
            at='-- RECOV-8.3-3a with the installed K (14e.h): K = 3 is valid, but 2 − 0 is not a multiple of 3.')

    def test_initial_token_funding_is_reachable(self):
        imports, protocol, model, proofs, fixture = finality_sources()
        evidence = '\n'.join((model, proofs, fixture))
        self.assert_compiles(imports + protocol + '\n' + evidence)
        self.assert_evidence_rejects(imports + protocol, evidence,
            '⟨registry,env.initialToken⟩',
            '⟨registry,⟨fun _ => 0,fun _ _ => 0⟩⟩')


if __name__ == '__main__':
    unittest.main()
