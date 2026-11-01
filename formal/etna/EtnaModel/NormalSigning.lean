import EtnaModel.SigningBridge
import EtnaModel.BackPressure

/-! Normal protocol provenance for exit/signing composition. Landings retain their actual
batch and construction witnesses. Every other ordinary operation uses the original
constructor; no verifier-failure rollback, cutoff conclusion or key exclusion is a field. -/
namespace Etna.Design.NormalSigning
open ProtocolState SigningBridge

/-- Ordinary runs whose accepted landings have a valid batch under the deployment's own
construction and a source for the prior snapshot in that history. The reference bound is
an explicit guest/history interface contract, also used by the existing SoundStep. -/
inductive Run : World → World → Prop
  | refl (w : World) : Run w w
  | landing {first w : World} {s : State} {i : LandInput} {leaves : List Leaf} {e : LandingEnv}
      {r template : BlockValidity.Rules} {parent : BlockValidity.Header}
      {blocks : List BlockValidity.Block} {blobs : List Hash} {archive : List Nat}
      (prior : Run first w) (time : w.l1Block ≤ e.blockNumber)
      (accepted : Etna.Design.land w.inbox i leaves e = some s)
      (built : Deployment.build w w.inbox.configuration archive template = some r)
      (valid : Settlement.BatchValid r parent blocks blobs)
      (binding : e.certificate = Settlement.statement r parent blocks blobs)
      (source : SnapshotSource w.inbox r.consensus)
      (reference : i.activeCommitteeSnapshot ≤ i.l1ReferenceBlockNumber) :
      Run first (landed w s e.blockNumber)
  | other {first w t : World} (prior : Run first w) (change : OrdinaryStep w t)
      (settled : t.inbox.checkpoint.height ≤ w.inbox.checkpoint.height) : Run first t

/-- Confirmation provenance is either on the same replay, or retained across an actual
normal recovery. In the latter case its old header need not occur after the new origin.
Both paths use original ordinary operations; the current origin/generation are bound to
that recovery, not chosen independently of it. Multiple recoveries use the last one. -/
inductive ConfirmationSource (confirmed view : World) (p : TrustedPrefix view) : Prop
  | replay (later : OrdinaryTrace confirmed view) (seen : IncludedCheckpoint confirmed p) :
      ConfirmationSource confirmed view p
  | recovery {before : World} {s : Recovery.World} {a : Recovery.Request} {origin : Origin}
      {owner externalOK : Bool} (beforeRecovery : OrdinaryTrace confirmed before)
      (time : before.l1Block ≤ origin.l1Block)
      (accepted : Recovery.recover (recoveryView before) a before.adapters.recovery origin owner externalOK = some s)
      (afterRecovery : OrdinaryTrace (recovered before a origin s) view)
      (generation : view.inbox.generation = before.inbox.generation+1)
      (originKept : view.inbox.origin = origin) : ConfirmationSource confirmed view p

end Etna.Design.NormalSigning
