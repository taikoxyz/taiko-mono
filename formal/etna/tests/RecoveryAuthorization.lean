import EtnaWitnesses.Counterexamples.StaleDaoAuthorization

open Etna.Design Etna.Design.StaleDaoAuthorization

-- A verifier-failure rollback must never make this old authorization executable again.
example : ProtocolState.recover rolledBack request origin true true = none := by decide +kernel
