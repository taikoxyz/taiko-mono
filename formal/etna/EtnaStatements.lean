import EtnaStatements.Environment
import EtnaStatements.Premises
import EtnaStatements.Claims

/-! Etna statements: the premise record and the headline claims, stated over `EtnaModel`
without proofs. `Environment` fixes what the L1 contracts do not (guest relations, submitted
landings), `Premises` lists every assumption, and `Claims` is fund safety, accountable finality
and forced-inclusion integrity. -/

/-! Version scope: only Etna.Design.Current models the selected current rules. Other
declarations retain the archived pre-2026-11-03 semantics; their headline theorems are
not claims about the whole latest protocol. See README.md. -/
