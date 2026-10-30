import EtnaProofs.Headline.ChainOfCustody

/-! H1, fund safety (`Etna.Statements.FundSafety`): the trace invariant `chain_of_custody`
without its hash binding. Each retained record's header comes from block 0's header through
consecutive segments of blocks valid under the rules the deployment builds for the record's
generation, each segment starting at the very header where the one before ended, and every
SignalService state root is such a header's. -/
namespace Etna.Proofs
open Etna.Design Etna.Statements

/-- H1, fund safety: see `Etna.Statements.FundSafety`. -/
theorem fund_safety : FundSafety := by
  intro env w0 premises w run
  obtain ⟨H,records,signals⟩ := chain_of_custody premises run
  exact ⟨H,fun child mem => ⟨(records child mem).1,(records child mem).2.2⟩,signals⟩

end Etna.Proofs
