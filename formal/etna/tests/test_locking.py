"""Kernel-checked locking derivation, type-correct mutations, and an actual fork witness."""
from pathlib import Path
import subprocess
import tempfile
import re
import unittest

ROOT = Path(__file__).resolve().parents[1]


def combined(model_only=False):
    imports, bodies = [], []
    for library in (('EtnaModel',) if model_only else ('EtnaModel', 'EtnaProofs')):
        lines = (ROOT/library/'Locking.lean').read_text().splitlines()
        end = 0
        while end < len(lines) and lines[end].startswith('import '):
            imports.append(lines[end])
            end += 1
        bodies.append('\n'.join(lines[end:]).replace('Etna.Design.Locking', 'Etna.Design.LockingMutation'))
    return '\n'.join(dict.fromkeys(imports))+'\n'+'\n'.join(bodies)


# Only the modeled floor guard is changed. This fixture has all honest power:
# B prevotes at round 0, A commits at 1, then stale B/0 unlocks A/1 and B commits at 2.
# It does not appeal to a conflicting-commit axiom or to the theorem layer.
STALE_CERTIFICATE_FORK = r'''
namespace Etna.Design.LockingMutationCounterexample
open LockingMutation

def members : List Committee.Entry := [⟨1,1,0,1000⟩,⟨2,1,0,1000⟩,⟨3,1,0,1000⟩,⟨4,1,0,1000⟩]
def keys : List Hash := [1,2,3,4]
def honest (_ : Hash) : Bool := true
def action (_ r : Nat) : RoundAction :=
  match r with
  | 0 => { prevote := some (some 10) }
  | 1 => { prevote := some (some 20), precommit := some (some 20) }
  | 2 => { prevote := some (some 10), precommit := some (some 10), justification := some (0,some 10) }
  | _ => {}
def execution : Execution where
  prevotes := fun k r v => (action k r).prevote = some v
  precommits := fun k r v => (action k r).precommit = some v
  actions := action
  locks := fun _ r => match r with
    | 0 | 1 => none
    | 2 => some (1,20)
    | _ => some (2,10)

private theorem c0 : PoLC 1 members execution 0 (some 10) :=
  ⟨keys,by unfold Quorum; decide +kernel,by intro k _; rfl⟩
private theorem c1 : PoLC 1 members execution 1 (some 20) :=
  ⟨keys,by unfold Quorum; decide +kernel,by intro k _; rfl⟩
private theorem c2 : PoLC 1 members execution 2 (some 10) :=
  ⟨keys,by unfold Quorum; decide +kernel,by intro k _; rfl⟩
private theorem rules : HonestRules 1 members honest true execution := by
  constructor
  · intro k _; rfl
  · intro k _ r
    cases r with
    | zero => simp [RoundStep,UnlockAllowed,afterPrevote,VoteAllowed,execution,action]
    | succ r => cases r with
      | zero => simpa [RoundStep,UnlockAllowed,afterPrevote,VoteAllowed,execution,action] using c1
      | succ r => cases r with
        | zero =>
          simp only [RoundStep,UnlockAllowed,afterPrevote,VoteAllowed,execution,action]
          refine ⟨⟨1,20,rfl,?_,by decide,c0,by decide,Or.inl (by trivial)⟩,?_,c2,by trivial⟩
          · trivial
          · intro v _; trivial
        | succ r => simp [RoundStep,UnlockAllowed,afterPrevote,execution,action]
  · intro k _ r v pv; exact pv
  · intro k _ r v pc; exact pc

-- Real incompatible quorum commits, under the mutated actual lower-level rules.
example : HonestRules 1 members honest true execution ∧ Minority 1 members honest ∧
    Commit 1 members execution 1 20 ∧ Commit 1 members execution 2 10 ∧ (20 : Hash) ≠ 10 :=
  ⟨rules,by unfold Minority; decide +kernel,
    ⟨keys,by unfold Quorum; decide +kernel,by intro k _; rfl⟩,
    ⟨keys,by unfold Quorum; decide +kernel,by intro k _; rfl⟩,by decide⟩
end Etna.Design.LockingMutationCounterexample
'''


class LockingKernelTests(unittest.TestCase):
    def compile(self, source):
        with tempfile.NamedTemporaryFile(dir=ROOT/'.scratch', suffix='.lean', mode='w') as file:
            file.write(source)
            file.flush()
            return subprocess.run(['lake', 'env', 'lean', file.name], cwd=ROOT,
                                  capture_output=True, text=True)

    def silent(self, source):
        result = self.compile(source)
        self.assertEqual(result.returncode, 0, result.stdout+result.stderr)
        self.assertEqual(result.stdout+result.stderr, '')

    def rejected(self, old, new):
        model = combined(model_only=True)
        self.assertEqual(model.count(old), 1)
        self.silent(model.replace(old, new, 1))
        source = combined()
        body = model[model.index('namespace Etna.Design.LockingMutation'):]
        self.assertEqual(source.count(body), 1)
        source = source.replace(body, body.replace(old, new, 1), 1)
        result = self.compile(source)
        output = result.stdout+result.stderr
        self.assertNotEqual(result.returncode, 0, 'semantic guard removal must break unchanged proofs')
        self.assertIn('error:', output)
        for incidental in ('unexpected token', 'Unknown identifier', 'already been declared', 'unknown module prefix'):
            self.assertNotIn(incidental, output)

    def test_unmodified_model_proofs_and_fixtures_are_silent(self):
        for source in (combined(model_only=True), combined(), (ROOT/'tests/Locking.lean').read_text()):
            self.silent(source)

    def test_unlock_certificate_cannot_precede_lock(self):
        self.rejected('lr ≤ q ∧ q < r', 'True ∧ q < r')

    def test_unlock_certificate_must_strictly_precede_prevote(self):
        self.rejected('lr ≤ q ∧ q < r', 'lr ≤ q ∧ q ≤ r')

    def test_nonnil_precommit_requires_current_round_polc(self):
        self.rejected('cert r (some b) ∧ after = some (r,b)', 'True ∧ after = some (r,b)')

    def test_nil_unlock_requires_nil_polc(self):
        self.rejected('(action.nilCertificate = true → cert r none)', '(action.nilCertificate = true → True)')

    def test_nil_voting_and_nil_unlock_modes_cannot_be_mixed(self):
        self.rejected('v = some b ∨ (nilUnlock = false ∧ v = none)', 'v = some b ∨ (nilUnlock = nilUnlock ∧ v = none)')

    def test_nil_unlock_cannot_precede_own_prevote(self):
        self.rejected('VoteAllowed nilUnlock (afterPrevote before action) v',
                      'VoteAllowed nilUnlock (if action.nilCertificate then none else afterPrevote before action) v')

    def test_nonnil_attribution_cannot_accept_nil_event(self):
        self.rejected('∀ v ∈ votes, e.precommits v.key r (some b)',
                      '∀ v ∈ votes, e.precommits v.key r (some b) ∨ e.precommits v.key r none')

    def test_archive_prefix_must_include_queried_header(self):
        self.rejected('then t*cfg.epochLen-2+1 else 0', 'then t*cfg.epochLen-2 else 0')

    def test_instance_identity_includes_generation(self):
        self.rejected('a.domain = b.domain ∧ a.generation = b.generation ∧ a.origin = b.origin',
                      'a.domain = b.domain ∧ True ∧ a.origin = b.origin')

    def test_removing_lock_floor_admits_real_all_honest_fork(self):
        model = combined(model_only=True)
        changed = model.replace('lr ≤ q ∧ q < r', 'True ∧ q < r')
        self.silent(changed)
        self.silent(changed+STALE_CERTIFICATE_FORK)
        # The identical concrete run cannot satisfy the original guarded model.
        result = self.compile(model+STALE_CERTIFICATE_FORK)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('error:', result.stdout+result.stderr)
        self.assertIn('1 ≤ 0', result.stdout+result.stderr)

    def test_every_normalized_observation_is_an_actual_event(self):
        original = (ROOT/'EtnaWitnesses/Regressions/Locking.lean').read_text().replace(
            'Etna.Design.LockingRegression', 'Etna.Design.LockingObservationMutation')
        changed = original.replace('(2,3,1)]', '(2,5,1)]', 1)
        self.assertNotEqual(original, changed)
        # Original pairwise/order checks and two named votes miss this nonexistent event.
        old_checks = re.sub(r'theorem interleaving_all_actual .*?(?=\ndef cfg)', '', changed, flags=re.S)
        self.silent(old_checks)
        # The new unchanged quantified check covers the sixth observation too.
        result = self.compile(changed)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('error:', result.stdout+result.stderr)
        self.assertNotIn('Unknown identifier', result.stdout+result.stderr)
