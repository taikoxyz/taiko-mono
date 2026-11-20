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

-- A nonzero current root and a failed beacon read both close writes, even for the syncer.
example : save ⟨1,true⟩ (some 9) [] 1 7 8 2 = none := by decide
example : save ⟨1,true⟩ none [] 1 7 8 2 = none := by decide
example : save ⟨1,true⟩ (some 0) [] 1 7 8 2 = some [⟨8,2,1,7⟩] := by decide
example : save ⟨1,true⟩ (some 0) [] 2 7 8 2 = none := by decide
example : save ⟨1,false⟩ none [] 1 7 8 2 = some [⟨8,2,1,7⟩] := by decide

-- The saved root wins on a collision. Missing checkpoints can fall back only on L2.
example : stateRoot ⟨1,true⟩ (fun _ => some 9) [⟨8,2,1,7⟩] 8 = some 2 := by decide
example : stateRoot ⟨1,true⟩ (fun _ => some 9) [] limit48 = some 9 := by decide
example : stateRoot ⟨1,true⟩ (fun _ => some 0) [] 8 = none := by decide
example : stateRoot ⟨1,true⟩ (fun _ => none) [] 8 = none := by decide
example : stateRoot ⟨1,false⟩ (fun _ => some 9) [] 8 = none := by decide

end Etna.CurrentBridgeRegression
