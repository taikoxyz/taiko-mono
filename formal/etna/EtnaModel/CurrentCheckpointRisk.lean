import EtnaModel.CurrentStakeRisk
import EtnaModel.CurrentCoherentCustody

namespace Etna.Design.Current.CheckpointRisk
open Protocol

/-- Exceptional verifier-failure rollback is outside normal node execution. -/
def OrdinaryCall : Call → Prop
  | .rollback _ _ _ => False
  | _ => True

/-- Actual calls/nodes excluding only the exceptional verifier-failure rollback.
Snapshot order is proved from authenticated accepted guest ancestry below. -/
inductive RollbackFreeRun (env : Environment) : World → World → Prop
  | refl (w : World) : RollbackFreeRun env w w
  | call {first w : World} (prior : RollbackFreeRun env first w) (call : Call)
      (ordinary : OrdinaryCall call) : RollbackFreeRun env first (Protocol.transact env w call)
  | node {first w : World} (prior : RollbackFreeRun env first w) (after : Node)
      (valid : NodeEvent env w after) : RollbackFreeRun env first {w with node := after}

/-- Internal projection recording STAKE-4.1-29's decoded storage order. The proof
below derives this projection from `RollbackFreeRun` and authenticated accepted
guest ancestry; callers of the public risk theorem supply only that raw trajectory. -/
inductive NormalRun (env : Environment) : World → World → Prop
  | refl (w : World) : NormalRun env w w
  | call {first w : World} (prior : NormalRun env first w) (call : Call)
      (ordinary : OrdinaryCall call)
      (snapshot : w.inbox.snapshot ≤ (Protocol.transact env w call).inbox.snapshot) :
      NormalRun env first (Protocol.transact env w call)
  | node {first w : World} (prior : NormalRun env first w) (after : Node)
      (valid : NodeEvent env w after) : NormalRun env first {w with node := after}

/-- The current pair comes from its actual writer and an actual subsequent execution
suffix. This is stronger source provenance than an unrelated matching writer. -/
def CurrentSource (env : Environment) (initial w : World) : Prop :=
  ∃ before call after, NormalRun env initial before ∧ execute env before call = some after ∧
    Protocol.Custody.writesCheckpoint call = true ∧ NormalRun env initial after ∧
    after.start.isSome = true ∧ NormalRun env after w ∧
    after.inbox.checkpoint = w.inbox.checkpoint ∧ after.inbox.snapshot = w.inbox.snapshot

/-- Decoded current-generation EL ancestry admitted by the node's latest-checkpoint
forkchoice fence. The split identifies the physical header at the actual checkpoint;
its hash is compared with raw Inbox storage before any committee cutoff is derived. -/
structure Candidate (env : Environment) (w : World) (h : Nat) where
  root : Header
  beforeCheckpoint : List Header
  afterCheckpoint : List Header
  rootHeight : root.height = (config w).originHeight
  linked : Archive.Linked env.headerParent root (beforeCheckpoint ++ afterCheckpoint)
  hashes : ∀ header ∈ root :: (beforeCheckpoint ++ afterCheckpoint), HashBound env header
  checkpointHeight : (Archive.terminal root beforeCheckpoint).height = w.inbox.checkpoint.height
  checkpointHash : (Archive.terminal root beforeCheckpoint).elHash = w.inbox.checkpoint.elHash
  terminalHeight : (Archive.terminal root (beforeCheckpoint ++ afterCheckpoint)).height = h
  ready : Finality.Ready (config w) w.registry.registry (beforeCheckpoint ++ afterCheckpoint) h
  reference : Nat
  closedReference : reference < w.number
  originBeforeReference : (config w).originBlock ≤ reference
  anchorBounds : ∀ header ∈ beforeCheckpoint ++ afterCheckpoint, header.anchor.number ≤ reference

def Candidate.headers {env : Environment} {w : World} {h : Nat} (candidate : Candidate env w h) : List Header :=
  candidate.beforeCheckpoint ++ candidate.afterCheckpoint

end Etna.Design.Current.CheckpointRisk
