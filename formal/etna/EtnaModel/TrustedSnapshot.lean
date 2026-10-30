import EtnaModel.SigningEscrow

/-! Section 8 "Verifier failure": the rollback must restore slot 284 to the value the last
trusted landing wrote, or the initialization value. `SnapshotTrusted` is the condition the
confirmed-key exclusion needs: slot 284 is not ahead of the cutoff of the committee active at
lastCheckpoint in a given context. The model does not prove that the spec's duty implies it,
since after a rollback the context is rebuilt from the restored World. An untrusted rollback
can break it. -/
namespace Etna.Design.SigningEscrow
open ProtocolState

/-- Slot 284 is not ahead of the selection cutoff of the committee active at lastCheckpoint in
the consensus context `ctx`. -/
def SnapshotTrusted (ctx : Consensus.Context) (w : World) : Prop :=
  w.inbox.snapshot ≤ (Consensus.activeAt ctx w.inbox.checkpoint.height).cutoff

end Etna.Design.SigningEscrow
