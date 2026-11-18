import EtnaProofs

/-! The bridge's read path (`EtnaModel/CurrentBridge.lean`): what `Backed` asks, that an accepted
rollback revokes every derived authorization in the same step, the RECOV-8-27a vectors that
the revocation decides, and the L2 `SignalService`'s checkpoint cutoff and root source. -/
namespace Etna.CurrentBridgeRegression
open Etna.Design Etna.Design.Current Etna.Design.Current.Protocol Etna.Design.Current.Bridge

-- Pin `Backed`: every cached signal and every `RETRIABLE` message was proven against the root of
-- a checkpoint the L1 SignalService still holds (an Unzen one or an Etna landing's).
example (verify : Hash → Hash → Hash → Bool) (w : World) (b : Bridge.State) :
    Backed verify w b = ∀ a ∈ b.cached ++ b.retriable, (∃ s ∈ w.legacySignals ++ w.inbox.signals,
      s.height = a.height ∧ s.stateRoot = a.root) ∧ ∃ proof, verify a.root a.slot proof = true := rfl

-- The revocation clears the cache and every `RETRIABLE` message, and keeps completed messages,
-- so a fee already paid is not paid again (27a.h).
example (b : Bridge.State) : revoke b = { b with cached := [], retriable := [] } := rfl
example (b : Bridge.State) : (revoke b).done = b.done := rfl

-- An accepted rollback revokes in the same step (RECOV-8-26); no step revokes otherwise.
example (env : Environment) (verify : Hash → Hash → Hash → Bool) (w : World) (b : Bridge.State)
    (caller snapshot : Nat) (trusted : Checkpoint) (accepted : (rollback env w caller trusted snapshot).isSome = true) :
    Step env verify (w,b) (transact env w (.rollback caller trusted snapshot),revoke b) := by
  have step := Step.call (env := env) (verify := verify) w b (.rollback caller trusted snapshot)
  simp only [rolledBack,accepted,↓reduceIte] at step
  exact step
example (env : Environment) (w : World) (a : Landing) : rolledBack env w (.land a) = false := rfl

-- 27a.a and 27a.c: after the revocation, an empty proof and a retry are refused.
example (verify : Hash → Hash → Hash → Bool) (w : World) (b : Bridge.State) (slot : Hash) (delivered : Bool) :
    execute verify w (revoke b) (.processCached slot delivered) = none ∧
      execute verify w (revoke b) (.retry slot delivered) = none :=
  revoked_needs_proof verify w b slot delivered

-- 27a.b and 27a.d: proven again against a checkpoint the L1 SignalService holds, a revoked
-- message is `NEW` again and completes.
example (verify : Hash → Hash → Hash → Bool) (w : World) (b : Bridge.State) (slot root proof : Hash)
    (height : Nat) (held : checkpointRoot w height = some root) (valid : verify root slot proof = true)
    (fresh : slot ∉ b.done) :
    execute verify w (revoke b) (.process slot height proof true) =
      some { revoke b with done := slot :: b.done } := by
  simp [Bridge.execute,prove,held,valid,settle,revoke,fresh]

-- A proof against a height with no held checkpoint is refused, whatever the adapter says.
example (verify : Hash → Hash → Hash → Bool) (w : World) (b : Bridge.State) (slot proof : Hash) (height : Nat)
    (absent : checkpointRoot w height = none) :
    execute verify w b (.receive slot height proof) = none := by
  simp [Bridge.execute,prove,absent]

-- The L2 SignalService: from `beaconRootsFrom` on, no checkpoint is saved, even by the syncer.
example (c : L2Config) (store : List Saved) (timestamp blockId : Nat) (root : Hash)
    (fork : c.beaconRootsFrom ≠ 0) (after : c.beaconRootsFrom ≤ timestamp) :
    save c store c.syncer timestamp blockId root = none := by
  have closed : ¬ (c.beaconRootsFrom = 0 ∨ timestamp < c.beaconRootsFrom) := by omega
  simp [save,checkpointsOpen,closed]
-- Before it, the syncer saves and other callers do not; L1 (`beaconRootsFrom` = 0) never closes.
example (c : L2Config) (store : List Saved) (timestamp blockId : Nat) (root : Hash)
    (before : timestamp < c.beaconRootsFrom) (nonzero : root ≠ 0) :
    save c store c.syncer timestamp blockId root = some (⟨blockId,root,c.syncer,timestamp⟩ :: store) := by
  simp [save,checkpointsOpen,before,nonzero]
example (c : L2Config) (store : List Saved) (caller timestamp blockId : Nat) (root : Hash)
    (other : caller ≠ c.syncer) : save c store caller timestamp blockId root = none := by
  simp [save,other]
example (syncer timestamp : Nat) : checkpointsOpen ⟨syncer,0⟩ timestamp = true := rfl

-- Before the fork a root comes from the checkpoint store, never from EIP-4788.
example (c : L2Config) (beacon : Nat → Option Hash) (timestamp blockId : Nat)
    (before : timestamp < c.beaconRootsFrom) :
    stateRoot c beacon [] timestamp blockId = none := by
  simp [stateRoot,checkpointsOpen,before]

end Etna.CurrentBridgeRegression
