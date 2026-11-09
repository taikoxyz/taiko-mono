"""H4 (recoverability) in the headline audit: premise and hypothesis use, the consensus-honesty
dependency contract, and the mandatory joint-premise witness, trap witness and trap escape.

The statement pins live in tests/CurrentRecovery.lean, the proof pins in
tests/CurrentRecoveryProof.lean, the trap pins in tests/CurrentRecoveryTrap.lean and the joint
witness pins in tests/CurrentRecoveryWitness.lean; the audit replays all four.
"""
from copy import deepcopy
import importlib.util
import json
from pathlib import Path
import re
import unittest
from unittest import mock

ROOT = Path(__file__).resolve().parents[1]


def load(name, path):
    spec = importlib.util.spec_from_file_location(name, ROOT/path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


AUDIT = load('current_recovery_audit', 'scripts/audit_proofs.py')
SURFACE = load('current_recovery_surface', 'scripts/review_surface.py')
# Reuse the headline harness (one compiled EtnaAudit library, `checked` bodies).
HEADLINES = load('current_recovery_headlines', 'tests/test_current_headlines.py')

H4 = 'Etna.Design.Current.Headlines.recoverability'
RECOVERY_PREMISES = 'Etna.Statements.Current.RecoveryPremises'
LIVE_AT = 'Etna.Statements.Current.LiveAt'
JOINT = 'Etna.Design.Current.Protocol.RecoveryNonVacuity.all_premises_satisfiable'
TRAP = 'Etna.Design.Current.Protocol.RollbackGridTrap.rollback_grid_trap'
ESCAPE = 'Etna.Design.Current.Protocol.RollbackGridTrap.rollback_grid_escape'
# Every field of H4's own premise record, then every conjunct of its per-state hypothesis.
RECOVERY_FIELDS = ('toFundPremises', 'recoveryClock', 'recoveryCatalogueHash', 'proofComplete', 'payloadLive',
                   'unzenStart')
LIVE_FIELDS = ('generation', 'nonce', 'rules', 'height', 'window', 'ruleset', 'unzen')


_HARNESS = HEADLINES.CurrentHeadlineTests.__dict__


class CurrentRecoveryAuditTests(unittest.TestCase):
    # The headline harness: one compiled EtnaAudit library and `checked` Lean bodies.
    setUpClass = _HARNESS['setUpClass']
    tearDownClass = _HARNESS['tearDownClass']
    compile = _HARNESS['compile']
    checked = _HARNESS['checked']
    assert_success = _HARNESS['assert_success']

    def test_every_recovery_premise_and_hypothesis_is_used(self):
        self.assertEqual(AUDIT.CURRENT_HEADLINES[H4], 'Etna.Statements.Current.Recoverability')
        self.assertEqual(AUDIT.CURRENT_RECOVERY_PREMISES, (RECOVERY_PREMISES, H4))
        self.assertEqual(AUDIT.CURRENT_LIVE_HYPOTHESES, (LIVE_AT, H4))
        checks = AUDIT.render_headline_check()
        self.assertEqual(len(checks), 5)
        for structure in (RECOVERY_PREMISES, LIVE_AT):
            line = (f'run_elab _root_.EtnaAudit.checkPremiseUse {AUDIT.lean_string(structure)} '
                    f'{AUDIT.lean_string(H4)}')
            self.assertIn(line, checks)
        result = self.checked('\n'.join(checks[3:]))
        self.assert_success(result, silent=False)
        uses, rest = AUDIT.premise_uses(result.stdout + result.stderr)
        expected = {f'RecoveryPremises.{f}': [H4] for f in RECOVERY_FIELDS}
        expected.update({f'LiveAt.{f}': [H4] for f in LIVE_FIELDS})
        self.assertEqual(uses, expected)
        self.assertEqual(rest.strip(), '')

    def test_h4_rests_on_no_consensus_honesty(self):
        body = '''run_elab do
  let reached ← EtnaAudit.dependencies [`Etna] [`Etna.Statements.Current.Recoverability]
  for forbidden in [`Etna.Statements.Current.Premises,
      `Etna.Design.Locking.HonestRules, `Etna.Design.Locking.Minority,
      `Etna.Design.Current.ProtocolFinality.HonestExecutions,
      `Etna.Design.Current.ProtocolFinality.VoteAttribution] do
    unless (← Lean.getEnv).contains forbidden do
      throwError "unknown probe constant {forbidden}"
    if reached.contains forbidden then
      throwError "H4 must not depend on {forbidden}"
'''
        self.assert_success(self.checked(body))
        # The probe sees a dependency hidden behind a new name.
        hidden = '''def Etna.CurrentRecoveryProbe.HiddenHonesty : Prop :=
  Etna.Statements.Current.Recoverability ∧ ∀ engine env w,
    Etna.Design.Current.ProtocolFinality.HonestExecutions engine env w
'''
        changed = body.replace('[`Etna.Statements.Current.Recoverability]', '[`Etna.CurrentRecoveryProbe.HiddenHonesty]')
        result = self.checked(hidden + changed)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('H4 must not depend on', result.stdout + result.stderr)

    def test_trap_and_joint_witness_tuples(self):
        # The joint realization is a premise profile; the trap and its escape realize no
        # premise record.
        self.assertIn(JOINT, AUDIT.CURRENT_PROFILE_WITNESSES)
        for name in (TRAP, ESCAPE):
            self.assertNotIn(name, AUDIT.CURRENT_PROFILE_WITNESSES)
            self.assertIn(name, AUDIT.CURRENT_TRAP_WITNESSES)

    def test_trap_and_joint_witness_are_mandatory(self):
        manifest = json.loads((ROOT/'manifests/design.json').read_text())
        AUDIT.validate_contract(manifest)
        for name in (JOINT, TRAP, ESCAPE, H4):
            with self.subTest(name=name):
                changed = deepcopy(manifest)
                changed['theorems'] = [e for e in changed['theorems'] if e['declaration'] != name]
                # The witnesses are also current plumbing, which validate_contract requires on
                # its own; take the name out of UNSOURCED so only the mandatory headline and
                # witness tuples can reject the removal.
                with mock.patch.dict(AUDIT.COVERAGE.UNSOURCED):
                    AUDIT.COVERAGE.UNSOURCED.pop(name, None)
                    with self.assertRaisesRegex(ValueError, 'missing manifest entry: ' + re.escape(name)):
                        AUDIT.validate_contract(changed)

    def test_h4_and_the_witnesses_are_lock_roots(self):
        roots = SURFACE.roots()
        for name in (H4, JOINT, TRAP, ESCAPE):
            self.assertIn(name, roots)
        self.assertEqual(len(roots), len(set(roots)))
        lock = json.loads((ROOT/'review-surface.lock.json').read_text())
        self.assertEqual(lock['roots'], roots)
        for name in ('Etna.Statements.Current.Recoverability', RECOVERY_PREMISES, LIVE_AT,
                     'Etna.Statements.Current.RecoverableAt', 'Etna.Design.Current.Protocol.RecoveryCall'):
            self.assertIn(name, lock['constants'])


if __name__ == '__main__':
    unittest.main()
