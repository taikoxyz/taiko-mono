"""The non-vacuity witness and the scope counterexamples build and are audited.

`EtnaWitnesses/NonVacuity` shows the headline premise record is satisfiable by a run that
lands, consumes a forced-inclusion entry and recovers, and that H2's finality hypothesis can
hold; `EtnaWitnesses/Counterexamples` holds one concrete bad run per dropped premise or open
design issue. Every module builds without warnings; every public theorem in them has a
`regression` manifest entry (so none backs a proof claim or changes a clause's status) that
passes the proof audit's exact-type and transitive-axiom checks; and probes pin the facts each
module exists to show, so a weakened restatement of a theorem and its manifest entry still
fails here.
"""
import importlib.util
import json
from pathlib import Path
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[1]


def load(name, path):
    spec = importlib.util.spec_from_file_location(name, ROOT/path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


AUDIT = load('witnesses_audit', 'scripts/audit_proofs.py')

COUNTEREXAMPLES = ['NoVerifierSoundness', 'UntrustedRollback', 'RecoveryCapture', 'ForcedPoisonResubmit',
                   'StaleDaoAuthorization', 'HistoricalEscrow']
MODULES = ['EtnaWitnesses.NonVacuity.Premises'] + [f'EtnaWitnesses.Counterexamples.{n}' for n in COUNTEREXAMPLES]
EXPECTED = {
    'Etna.Design.NonVacuity.premises_satisfiable', 'Etna.Design.NonVacuity.finality_hypothesis_satisfiable',
    'Etna.Design.NonVacuity.byzantine_minority_finality',
    'Etna.Design.NoVerifierSoundness.forged_checkpoint_lands',
    'Etna.Design.UntrustedRollback.untrusted_snapshot_frees_committee_stake',
    'Etna.Design.RecoveryCapture.late_stake_captures_recovery_committee',
    'Etna.Design.ForcedPoisonResubmit.cleared_poison_resubmitted',
    'Etna.Design.StaleDaoAuthorization.stale_authorization_never_revives',
    'Etna.Design.StaleDaoAuthorization.stale_authorization_rejected_on_every_future',
    'Etna.Design.HistoricalEscrow.ordinary_exit_and_historical_validity',
}

# What each module exists to show, restated independently of its manifest entry.
PROBES = '''
open Etna.Design Etna.Statements in
/-- Non-vacuity: some deployment and environment satisfy every premise, and a run under them
has three landing records above block 0's (two in generation 0, one in generation 1), a
recovery (generation 1) and an FI head past an enqueued entry. -/
example : ∃ (w0 : ProtocolState.World) (env : Environment), Premises w0 env ∧ ∃ w, Run env w0 w ∧
    w0.inbox.records.length = 1 ∧ w.inbox.records.map Checkpoint.generation = [1,0,0,0] ∧
    w0.inbox.generation = 0 ∧ w.inbox.generation = 1 ∧ w0.queue = [] ∧ w0.inbox.head = 0 ∧
    (∃ entry, (0,entry) ∈ w.queue) ∧ w.inbox.head = 1 := by
  obtain ⟨w0,env,premises,w,run,genesis,records,g0,g1,queue,head0,entry,head1⟩ := NonVacuity.premises_satisfiable
  refine ⟨w0,env,premises,w,run,?_,?_,g0,g1,queue,head0,entry,head1⟩
  · simpa using congrArg List.length genesis
  · have := congrArg (List.map fun (c : Nat × Nat × Nat) => c.2.1) records
    rw [List.map_map] at this
    exact this

open Etna.Design Etna.Statements in
/-- H2's finality hypothesis is satisfiable with a member of positive power that double-signs. -/
example : ∃ (w0 : ProtocolState.World) (env : Environment) (r : BlockValidity.Rules), Premises w0 env ∧ Built env w0 r ∧
    Equivocates r.consensus r.signature 1 0 9 ∧
    (∀ m ∈ (Consensus.activeAt r.consensus 1).members, (m.key != 9) = true →
      ¬ Equivocates r.consensus r.signature 1 0 m.key) ∧
    0 < Committee.totalPower r.consensus.unit ((Consensus.activeAt r.consensus 1).members.filter fun m => !(m.key != 9)) ∧
    3*Committee.totalPower r.consensus.unit ((Consensus.activeAt r.consensus 1).members.filter fun m => !(m.key != 9)) <
      Committee.totalPower r.consensus.unit (Consensus.activeAt r.consensus 1).members ∧
    ∃ a votes, Consensus.CommitValid r.consensus r.signature 1 0 a votes := by
  obtain ⟨premises,built,double,honest,member,power,commit,_,_⟩ := NonVacuity.byzantine_minority_finality
  exact ⟨_,_,_,premises,built,double,honest,member,power,_,_,commit⟩

open Etna.Design Etna.Statements NoVerifierSoundness in
/-- Without verifier soundness (every other premise field holds) a run violates FundSafety. -/
example : InputsAuthenticated environment ∧ ¬ VerifierSound environment ∧
    ∃ w, Run environment NonVacuity.world0 w ∧ ¬ Safe environment NonVacuity.world0 w := by
  obtain ⟨_,inputs,_,_,_,_,run,_,notSafe,noSound,_⟩ := forged_checkpoint_lands
  exact ⟨inputs,noSound,_,run,notSafe⟩

open Etna.Design Etna.Statements UntrustedRollback in
/-- An untrusted rollback snapshot: two conflicting valid commits by a key whose stake is gone. -/
example : ProtocolState.Trace NonVacuity.world0 worldD ∧ worldB.l1Block ≤ worldB.inbox.snapshot ∧
    (∀ a b sigA sigB, RegistryHistory.edit worldD.registry worldD.inbox 0 18 (.slash a b sigA sigB) = none) ∧
    ∃ r, Built byzantine worldD r ∧ ∃ a b votesA votesB, a ≠ b ∧ Consensus.CommitValid r.consensus r.signature 1 0 a votesA ∧
      Consensus.CommitValid r.consensus r.signature 1 0 b votesB := by
  obtain ⟨trace,above,_,_,_,_,_,slash,built,_,commitA,commitB⟩ := untrusted_snapshot_frees_committee_stake
  exact ⟨trace,above,slash,_,built,_,_,_,_,by decide,commitA,commitB⟩

open Etna.Design Etna.Statements RecoveryCapture in
/-- Late stake: on an initialized deployment, the committee a recovery would elect at authorization
passes 8.1's check (nonempty, every party below 1/3, no late stake), yet a key registered
afterwards holds more than 2/3 of the committee the model elects at R and alone commits. -/
example : Deployment.Genesis deployed NonVacuity.genesisHeader.elHash NonVacuity.genesisHeader.stateRoot ∧
    (∃ intended, Recovery.selection (ProtocolState.recoveryView deployed) request ⟨0,14,14⟩ = some intended ∧
      intended ≠ [] ∧ late ∉ intended ∧ ∀ m ∈ intended,
        3*Committee.power deployed.inbox.configuration.unit m <
          Committee.totalPower deployed.inbox.configuration.unit intended) ∧
    ProtocolState.Trace deployed worldR ∧
    ∃ r, Built attacker worldR r ∧ late ∈ (Consensus.activeAt r.consensus 1).members ∧
      2*Committee.totalPower r.consensus.unit (Consensus.activeAt r.consensus 1).members <
        3*Committee.power r.consensus.unit late ∧
      ∃ votes, votes.map Consensus.Vote.key = [late.key] ∧ Consensus.CommitValid r.consensus r.signature 1 0 666 votes := by
  obtain ⟨genesis,_,intended,honest,_,trace,_,_,share,built,active,commit⟩ := late_stake_captures_recovery_committee
  refine ⟨genesis,⟨parties,intended,by decide,by decide,honest⟩,trace,rulesR,built,?_,?_,[lateVote],rfl,commit⟩
  · rw [active]
    decide
  · rw [active]
    exact share

open Etna.Design Etna.Statements ForcedPoisonResubmit in
/-- Poison resubmission: the blanked transaction is pending again after the recovery. -/
example : ProtocolState.Trace NonVacuity.world0 worldAgain ∧ Blanks worldP worldR 0 poison ∧
    ∃ j e, (j,e) ∈ worldAgain.queue ∧ e.txHash = poison.txHash ∧ worldAgain.inbox.head ≤ j ∧ j < worldAgain.inbox.tail := by
  obtain ⟨trace,blanks,_,_,again,same,head,tail,_⟩ := cleared_poison_resubmitted
  exact ⟨trace,blanks,_,_,again,same,head,tail⟩

open Etna.Design Etna.Statements StaleDaoAuthorization in
/-- Non-revival: the same restored checkpoint and generation still reject the old
authorization because rollback consumed its nonce. -/
example : (∀ r owner externalOK, ProtocolState.recover NoVerifierSoundness.forgedWorld request r owner externalOK = none) ∧
    ProtocolState.Trace NonVacuity.world0 rolledBack ∧
    rolledBack.inbox.checkpoint = NonVacuity.world0.inbox.checkpoint ∧
    ProtocolState.recover rolledBack request origin true true = none ∧
    rolledBack.inbox.recoveryNonce = NonVacuity.world0.inbox.recoveryNonce+1 := by
  obtain ⟨_,voided,checkpoint,_,_,trace,rejected,nonce⟩ := stale_authorization_never_revives
  exact ⟨voided,trace,checkpoint,rejected,nonce⟩

open Etna.Design Etna.Statements StaleDaoAuthorization in
/-- The consumed authorization remains rejected over every future machine trace. -/
example {w : ProtocolState.World} (trace : ProtocolState.Trace rolledBack w)
    (r : Origin) (owner externalOK : Bool) : ProtocolState.recover w request r owner externalOK = none :=
  stale_authorization_rejected_on_every_future trace r owner externalOK
'''


def witness_entries():
    entries = json.loads((ROOT/'manifests/design.json').read_text())['theorems']
    return [e for e in entries if e['module'] in MODULES]


class WitnessTests(unittest.TestCase):
    def test_the_counterexample_modules_exist(self):
        found = sorted(p.stem for p in (ROOT/'EtnaWitnesses/Counterexamples').glob('*.lean'))
        self.assertEqual(found, sorted(COUNTEREXAMPLES))
        root = (ROOT/'EtnaWitnesses.lean').read_text()
        for module in MODULES:
            self.assertIn('import '+module+'\n', root)

    def test_witness_modules_build(self):
        result = subprocess.run(['lake', 'build', *MODULES], cwd=ROOT, text=True, capture_output=True)
        output = result.stdout+result.stderr
        self.assertEqual(result.returncode, 0, output)
        self.assertNotIn('warning', output.lower(), output)

    def test_witness_theorems_are_audited_regressions(self):
        entries = witness_entries()
        names = {e['declaration'] for e in entries}
        self.assertLessEqual(EXPECTED, names)
        for entry in entries:
            self.assertEqual(entry['role'], 'regression', entry['declaration'])
        out = ROOT/'.scratch/witnesses'
        out.mkdir(parents=True, exist_ok=True)
        audit = out/'WitnessesAudit.lean'
        audit.write_text(AUDIT.render_audit(entries, complete=False)+PROBES)
        # Exact manifest types, roles and only the standard axioms (propext, Classical.choice,
        # Quot.sound); the probes must elaborate without any diagnostic.
        AUDIT.check_axioms(entries, AUDIT.check_kernel_file(audit))

    def test_axiom_check_rejects_sorry(self):
        fake = dict(declaration='Etna.Design.NonVacuity.fake', role='regression')
        with self.assertRaisesRegex(ValueError, 'forbidden axioms'):
            AUDIT.check_axioms([fake], "'Etna.Design.NonVacuity.fake' depends on axioms: [propext, sorryAx]")


if __name__ == '__main__':
    unittest.main()
