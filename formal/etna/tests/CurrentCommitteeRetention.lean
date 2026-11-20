import EtnaProofs.CurrentCheckpointRisk
open Etna.Design Etna.Design.Current Protocol CheckpointRisk
example {env : Environment} {registry : RegistryMachine.State} {w : World} {h : Nat}
    (genesis : RegistryMachine.Genesis registry)
    (run : RollbackFreeRun env (empty env registry) w) (started : w.start.isSome = true)
    (primitive : Custody.Primitives env) (sound : VerifierSound env (empty env registry))
    (candidate : Candidate env w h)
    (elected : Consensus.ElectionValid (policy env w candidate.headers candidate.reference).consensus
      (Consensus.activeAt (policy env w candidate.headers candidate.reference).consensus h)) :
    ∀ entry ∈ (Consensus.activeAt (policy env w candidate.headers candidate.reference).consensus h).members,
      ∃ id, StakeRisk.Retained w.registry.registry (Finality.cutoff (config w) candidate.headers h) id entry.key :=
  committee_retained_of_candidate genesis run started primitive sound candidate elected
