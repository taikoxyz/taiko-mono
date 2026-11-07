import DerivationProofs
open TaikoSpec.Derivation
example : Statements.DerivationSafety := Proofs.derivation_safety
example : Statements.HeaderSafety := Proofs.header_safety
example : Statements.ForcedInclusionSafety := Proofs.forced_inclusion_safety
example : Statements.Claims := Proofs.claims
