import EtnaWitnesses.NonVacuity.CurrentAgreement

namespace Etna.CurrentAgreementRegression
open Etna.Design Etna.Design.Current Protocol
open _root_.Etna.Design.Current.Protocol.NonVacuity (env registry source genesis first block pol)
open _root_.Etna.Design.Current.Protocol.HonestAgreement

example : Etna.Statements.Current.Premises env registry honestEngine := premises
example : ProtocolFinality.HonestExecutions honestEngine env (source env) := honest_executions _

-- This is a real phase archive, with a round-0 nonnil precommit and its retained lock.
example : (honestEngine.execution 0 1).actions 7 0 =
    { prevote := some (some 201),precommit := some (some 201) } ∧
    (honestEngine.execution 0 1).locks 7 0 = none ∧
    (honestEngine.execution 0 1).locks 7 1 = some (0,201) ∧
    (honestEngine.execution 0 1).locks 7 2 = some (0,201) := by decide +kernel

example : ¬ (honestEngine.execution 0 1).precommits 7 0 (some 202) := by
  rintro ⟨_,impossible⟩
  cases impossible

example : ∀ round, ¬ (honestEngine.execution 0 1).precommits 7 round none := by
  rintro round ⟨_,impossible⟩
  cases impossible

-- The concrete active committee has a genuine prevote quorum before its precommit.
example : Locking.PoLC pol.consensus.unit (Consensus.activeAt pol.consensus 1).members
    (honestEngine.execution 0 1) 0 (some 201) :=
  polc _ _ _ (positive_committee NonVacuity.first_valid.commit)

-- Apply the proved all-chain agreement conclusion to the actual nonempty first chain.
example : [block] ≠ [] ∧ Finality.HeaderAgreement [first] [first] := by
  refine ⟨by simp,?_⟩
  exact current_agreement genesis [block] [block] 2 2 (by decide +kernel) first_chain first_chain

end Etna.CurrentAgreementRegression
