import EtnaModel
import EtnaStatements.Current

/-! Etna statements: the premise record and the headline claims, stated over `EtnaModel`
without proofs. `Environment` fixes what the L1 contracts do not (guest relations, submitted
landings), `Premises` lists every assumption, and `Claims` is fund safety, accountable finality
and forced-inclusion integrity. -/

/-! Version scope: Current modules define the current decoded machine and its conditional
H1–H3 claims. Other modules retain the archived pre-2026-11-03 semantics; their headline
theorems are historical. See README.md for exact boundaries. -/
