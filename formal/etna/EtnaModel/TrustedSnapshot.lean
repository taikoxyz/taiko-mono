import EtnaModel.SigningEscrow

/-! Section 8 "Verifier failure": the rollback must restore slot 284 to the value the last
trusted landing wrote, or the initialization value. A trusted landing writes exactly the
selection cutoff of the committee active at its checkpoint, so a trusted snapshot is never
ahead of that cutoff. An untrusted rollback can break this. -/
namespace Etna.Design.SigningEscrow
open ProtocolState

/-- Slot 284 is not ahead of the selection cutoff of the committee active at lastCheckpoint in
the consensus context `ctx`. -/
def SnapshotTrusted (ctx : Consensus.Context) (w : World) : Prop :=
  w.inbox.snapshot ≤ (Consensus.activeAt ctx w.inbox.checkpoint.height).cutoff

end Etna.Design.SigningEscrow
