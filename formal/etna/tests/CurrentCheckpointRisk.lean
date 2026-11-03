import EtnaProofs.CurrentCheckpointRisk

open Etna.Design Etna.Design.Current Protocol CheckpointRisk

-- The normal raw Protocol trajectory projects to real lifecycle operations; no
-- endpoint economic status is supplied as a projection premise.
example (env : Environment) (registry : RegistryMachine.State) (w : World)
    (run : NormalRun env (empty env registry) w) :
    StakeRisk.NormalTrace (registryWorld env (empty env registry)) (registryWorld env w) :=
  run.registry

-- The current source retains both actual execution segments around the writer.
example (env : Environment) (registry : RegistryMachine.State) (w : World)
    (run : NormalRun env (empty env registry) w) (started : w.start.isSome = true) :
    CurrentSource env (empty env registry) w := run.source started

-- The candidate checks the physical header hash at the actual stored checkpoint.
-- The selection-cutoff inequality is the theorem's conclusion, never a field.
example (env : Environment) (registry : RegistryMachine.State) (w : World) (h : Nat)
    (run : NormalRun env (empty env registry) w) (started : w.start.isSome = true)
    (primitive : Custody.Primitives env) (sound : VerifierSound env (empty env registry))
    (candidate : Candidate env w h) :
    w.inbox.snapshot ≤ Finality.cutoff (config w) candidate.headers h :=
  candidate_snapshot_bound run started primitive sound candidate

example : ¬ OrdinaryCall (.rollback 1 default 0) := by intro impossible; exact impossible

-- Snapshot order itself is derived from actual rollback-free calls and accepted
-- guest ancestry. It is not an admission premise of this public trajectory.
example (env : Environment) (registry : RegistryMachine.State) (w : World)
    (run : RollbackFreeRun env (empty env registry) w)
    (primitive : Custody.Primitives env) (sound : VerifierSound env (empty env registry)) :
    NormalRun env (empty env registry) w := run.normal primitive sound

example (env : Environment) (registry : RegistryMachine.State) (w : World)
    (run : Trace env (empty env registry) w) (initialized : w.initialized = true) :
    env.evidenceWindow ≤ w.registry.registry.config.withdrawalDelay :=
  initialized_evidence_window run initialized

example (env : Environment) (w : World) (h : Nat) (candidate : Candidate env w h) :
    Finality.cutoff (config w) candidate.headers h < w.number := candidate.cutoff_closed
