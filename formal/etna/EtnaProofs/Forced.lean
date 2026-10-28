import EtnaModel.Forced
import EtnaProofs.Common

namespace Etna.Design.Forced

theorem step_one_or_zero {c tail anchor delay next : Nat} {w : Option Witness} {x : Singleton}
    (ok : step c tail anchor delay w x = .accepted next) : next = c ∨ next = c+1 := by
  cases x <;> simp only [step] at ok <;> (repeat' split at ok) <;> simp_all

theorem step_tail_bound {c tail anchor delay next : Nat} {w : Option Witness} {x : Singleton}
    (before : c ≤ tail) (ok : step c tail anchor delay w x = .accepted next) : next ≤ tail := by
  by_cases pending : c < tail
  · have := step_one_or_zero ok
    omega
  · simp only [step,show c ≥ tail by omega,ite_true] at ok
    split at ok <;> simp_all

theorem no_missing_head (c tail anchor delay : Nat) (x : Singleton) (pending : c < tail) :
    step c tail anchor delay none x = .rejected := by simp [step,show ¬c ≥ tail by omega]

theorem overdue_waits_for_execution (c tail anchor delay : Nat) (w : Witness)
    (pending : c < tail) (identity : w.index = c) (auth : w.storageAuthenticated = true)
    (omitted : ¬(w.firstHash = some w.stored.txHash ∧ w.firstCanonical = true ∧ w.firstBytes ≤ 8192))
    (due : w.stored.timestamp+delay ≤ anchor)
    (hash : w.rawHash = w.stored.txHash) (size : w.rawBytes ≤ 8192)
    (valid : w.canonical = true) :
    step c tail anchor delay (some w) .unavailable = .waiting := by
  simp [step,show ¬c ≥ tail by omega,identity,auth,omitted,show ¬anchor < w.stored.timestamp+delay by omega,
    hash,show ¬w.rawBytes > 8192 by omega,valid]

/-- §7.2 cleared entry: once recovery rewrote txHash to keccak256(""), the witness carries
empty raw bytes, which are not a canonical transaction; when due the cursor advances by
exactly one without any EL build, whatever the EL would say. -/
theorem cleared_entry_skipped_when_due (c tail anchor delay : Nat) (w : Witness) (x : Singleton)
    (emptyHash : Hash) (pending : c < tail) (identity : w.index = c) (auth : w.storageAuthenticated = true)
    (cleared : w.stored.txHash = emptyHash) (raw : w.rawBytes = 0) (rawHash : w.rawHash = emptyHash)
    (notCanonical : w.canonical = false) (due : w.stored.timestamp+delay ≤ anchor) :
    step c tail anchor delay (some w) x = .accepted (c+1) := by
  simp [step,show ¬c ≥ tail by omega,identity,auth,raw,rawHash,cleared,
    show ¬anchor < w.stored.timestamp+delay by omega,notCanonical]

/-- Before it is due a cleared entry waits like any other: clearing never consumes early. -/
theorem cleared_entry_waits_before_due (c tail anchor delay : Nat) (w : Witness) (x : Singleton)
    (emptyHash : Hash) (pending : c < tail) (identity : w.index = c) (auth : w.storageAuthenticated = true)
    (cleared : w.stored.txHash = emptyHash) (raw : w.rawBytes = 0)
    (neverFirst : ¬(w.firstHash = some emptyHash ∧ w.firstCanonical = true))
    (early : anchor < w.stored.timestamp+delay) :
    step c tail anchor delay (some w) x = .accepted c := by
  have notIncluded : ¬(w.firstHash = some w.stored.txHash ∧ w.firstCanonical = true ∧ w.firstBytes ≤ 8192) := by
    rw [cleared]; intro h; exact neverFirst ⟨h.1,h.2.1⟩
  simp [step,show ¬c ≥ tail by omega,identity,auth,raw,notIncluded,early]

theorem overdue_from_block_time (blockTime anchorTime submitted delay maxAge : Nat)
    (age : blockTime-anchorTime ≤ maxAge) (anchorBefore : anchorTime ≤ blockTime)
    (late : submitted+delay+maxAge ≤ blockTime) : submitted+delay ≤ anchorTime := by omega

theorem enqueue_conserves {s t : State} {raw paid : Nat} {refund : Bool}
    (ok : enqueue s raw paid refund = some t) (before : FeeConserved s) : FeeConserved t := by
  dsimp only [enqueue] at ok
  split at ok
  · cases ok
    simp only [FeeConserved] at *
    omega
  · contradiction

theorem sweep_conserves {s t : State} {transfer : Bool}
    (ok : sweep s transfer = some t) (before : FeeConserved s) :
    FeeConserved t ∧ t.ethBalance = 0 ∧ t.swept = s.swept+s.ethBalance := by
  unfold sweep at ok
  split at ok
  · cases ok
    refine ⟨?_,rfl,rfl⟩
    simp only [FeeConserved] at *
    omega
  · contradiction

/-- Sweeping changes no FI entry, queue position, checkpoint, record or generation. -/
theorem sweep_frames_protocol {s t : State} {transfer : Bool}
    (ok : sweep s transfer = some t) :
    t.head = s.head ∧ t.tail = s.tail ∧ t.checkpoint = s.checkpoint ∧ t.records = s.records ∧
    t.snapshot = s.snapshot ∧ t.generation = s.generation ∧ t.signals = s.signals := by
  unfold sweep at ok
  split at ok
  · cases ok
    exact ⟨rfl,rfl,rfl,rfl,rfl,rfl,rfl⟩
  · contradiction

theorem sweep_transfer_failure_atomic (s : State) : sweep s false = none := by
  simp [sweep]

theorem extra_eth_conserved (s : State) (amount : Nat) (before : FeeConserved s) :
    FeeConserved (extraETH s amount) ∧ (extraETH s amount).feeAdmissions = s.feeAdmissions := by
  constructor
  · simp only [FeeConserved, extraETH] at *
    omega
  · rfl

theorem clear_preserves_admission_metadata (emptyHash : Hash) (e : Entry) :
    (clear emptyHash e).timestamp = e.timestamp ∧ (clear emptyHash e).l1Block = e.l1Block := ⟨rfl,rfl⟩

end Etna.Design.Forced
