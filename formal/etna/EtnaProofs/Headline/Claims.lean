import EtnaProofs.Headline.AccountableFinality
import EtnaProofs.Headline.ForcedInclusion
import EtnaProofs.Headline.FundSafety

/-! The three headline claims together (`Etna.Statements.Claims`): fund safety, accountable
finality and forced-inclusion integrity, each under the same premise record. -/
namespace Etna.Proofs
open Etna.Statements

/-- H1, H2 and H3 together: see `Etna.Statements.Claims`. -/
theorem claims : Claims := ⟨fund_safety, accountable_finality, forced_inclusion_integrity⟩

end Etna.Proofs
