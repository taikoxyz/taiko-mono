import EtnaStatements.Environment
import EtnaStatements.Premises
import EtnaStatements.Claims

/-! Etna statements: the premise record and the headline claims, stated over `EtnaModel`
without proofs. `Environment` fixes what the L1 contracts do not (guest relations, submitted
landings), `Premises` lists every assumption, and `Claims` is fund safety, accountable finality
and forced-inclusion integrity. -/
