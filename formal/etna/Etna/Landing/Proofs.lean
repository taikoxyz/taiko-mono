module
public import Etna.Landing.Model
public import Etna.Landing.Statement
public section
set_option maxHeartbeats 4000000
namespace Etna.Landing

def Bounds (w : World) (i : LandInput) : Prop :=
  w.checkpoint.height < i.lastHeight.val ∧
  i.lastHeight.val - w.checkpoint.height ≤ w.maxBatchBlocks ∧ i.lastHeight.val < 2 ^ 48 ∧
  w.head.val ≤ i.headAfter.val ∧ i.headAfter.val ≤ w.tail.val ∧
  i.headAfter.val - w.head.val ≤ i.lastHeight.val - w.checkpoint.height ∧ i.recipient ≠ 0

theorem validate_bounds (w : World) (i : LandInput) (h : validate w i = none) : Bounds w i := by
  unfold validate at h
  split_ifs at h <;> simp_all [Bounds]

theorem successful_checks (w : World) (i : LandInput) (x : ExternalOutcomes)
    (h : (execLandSteps w i x).error = none) :
    validate w i = none ∧ environmentCheck x.environment i = none := by
  unfold execLandSteps at h
  split at h <;> simp_all [finish]
  split at h <;> simp_all [finish]

theorem bounds_preserved (w : World) (i : LandInput) (x : ExternalOutcomes)
    (h : (execLandSteps w i x).error = none) : Bounds w i :=
  validate_bounds w i (successful_checks w i x h).1

theorem fee_sum_bound (fee : Nat → Word64) (before after : Nat) :
    fees fee before after ≤ (after - before) * (2 ^ 64 - 1) := by
  unfold fees
  have aux : ∀ xs : List Nat, (xs.map fun n => (fee n).val).sum ≤ xs.length * (2 ^ 64 - 1) := by
    intro xs
    induction xs with
    | nil => simp
    | cons a xs ih =>
      simp only [List.map_cons, List.sum_cons, List.length_cons]
      have hf := (fee a).isLt
      omega
  have h := aux ((List.range (after - before)).map (before + ·))
  simpa [List.map_map, Function.comp_def] using h

theorem fees_uint256 (fee : Nat → Word64) (before after : Word48) :
    fees fee before.val after.val < 2 ^ 112 ∧
    fees fee before.val after.val * 1000000000 < 2 ^ 142 ∧
    fees fee before.val after.val * 1000000000 < 2 ^ 256 := by
  have h := fee_sum_bound fee before.val after.val
  have ha := after.isLt
  omega

/-- Monotone successful heads make consecutive half-open consumed intervals disjoint. -/
theorem intervals_disjoint (a b c index : Nat) (_hab : a ≤ b) (_hbc : b ≤ c)
    (first : a ≤ index ∧ index < b) : ¬ (b ≤ index ∧ index < c) := by omega

theorem journal_rollback_write (j : Journal α) (next : α) :
    (Journal.write j next).rollback = j.rollback := rfl

theorem checked_journal_root (w : World) (i : LandInput) (x : ExternalOutcomes) :
    (execChecked w i x).journal.rollback = w := by
  simp [execChecked, finish, Journal.update, Journal.rollback]
  split_ifs <;> rfl

theorem execution_journal_root (w : World) (i : LandInput) (x : ExternalOutcomes) :
    (execLandSteps w i x).journal.rollback = w := by
  unfold execLandSteps
  split
  · simp only [finish]
    split <;> rfl
  · split
    · rfl
    · exact checked_journal_root w i x

/-- EVM journal semantics is the explicit external bridge. Inside this semantics every
failure, including after SignalService/events, restores the complete business world. -/
theorem rollback_atomic (w : World) (i : LandInput) (x : ExternalOutcomes) (e : Error)
    (failed : (execLandSteps w i x).error = some e) :
    (runTransaction w (execLandSteps w i x)).world = w := by
  simp [runTransaction, failed, execution_journal_root]

theorem same_inbox_reentry (w : World) (locked : w.guard = true) :
    nestedGuard w.inbox w = some .reentrant := by simp [nestedGuard, locked]

theorem other_inbox_not_locked (w : World) (other : Address) (h : other ≠ w.inbox) :
    nestedGuard other w = none := by simp [nestedGuard, h]

theorem reference_and_blobs (e : Environment) (r : Word64) (route : ReferenceRoute) (hash : Word256)
    (h : referenceHash e r = .ok (route, hash)) :
    r.val < e.blockNumber ∧ e.blockNumber - r.val ≤ 8191 ∧ hash ≠ 0 ∧
    (route = .blockhash → e.blockNumber - r.val ≤ 256 ∧ hash = e.blockHash) ∧
    (route = .history → 256 < e.blockNumber - r.val ∧ e.historySuccess = true ∧
      e.historyLength = 32 ∧ hash = e.historyHash) := by
  unfold referenceHash at h
  split_ifs at h <;> simp_all
  all_goals rcases h with ⟨rfl, rfl⟩
  all_goals simp_all
  all_goals omega

theorem blobs_from_environment (e : Environment) :
    actualBlobs e = e.blobHashes.takeWhile (· != 0) := rfl

theorem environment_success_nonempty (e : Environment) (i : LandInput)
    (h : environmentCheck e i = none) : actualBlobs e ≠ [] := by
  unfold environmentCheck at h
  split at h <;> simp_all

theorem successful_poststate (w : World) (i : LandInput) (x : ExternalOutcomes)
    (h : (execChecked w i x).error = none) :
    (execChecked w i x).journal.current.head = i.headAfter ∧
    (execChecked w i x).journal.current.checkpoint = ⟨i.lastHeight.val, i.lastBlockHash⟩ ∧
    (execChecked w i x).journal.current.guard = false ∧
    (execChecked w i x).journal.current.transfers = w.transfers ++
      (if i.headAfter ≠ w.head ∧ 0 < fees w.fee w.head.val i.headAfter.val * 1000000000 then
        [⟨i.recipient, fees w.fee w.head.val i.headAfter.val * 1000000000⟩] else []) := by
  simp only [execChecked, finish, Journal.update, Journal.current] at h ⊢
  split_ifs at h ⊢ <;> simp_all

/-- LAND-03: exactly the bound recipient/amount is appended to the transfer-instruction
ledger. No claim is made about its final balance after it runs arbitrary callbacks. -/
theorem recipient_bound (w : World) (i : LandInput) (x : ExternalOutcomes)
    (h : (execLandSteps w i x).error = none) : i.recipient ≠ 0 ∧
    (execLandSteps w i x).journal.current.transfers = w.transfers ++
      (if i.headAfter ≠ w.head ∧ 0 < fees w.fee w.head.val i.headAfter.val * 1000000000 then
        [⟨i.recipient, fees w.fee w.head.val i.headAfter.val * 1000000000⟩] else []) := by
  have checks := successful_checks w i x h
  have hb := bounds_preserved w i x h
  simp only [execLandSteps, checks.1, checks.2] at h ⊢
  exact ⟨hb.2.2.2.2.2.2, (successful_poststate w i x h).2.2.2⟩

theorem committed_head (w : World) (i : LandInput) (x : ExternalOutcomes)
    (h : (execLandSteps w i x).error = none) :
    (runTransaction w (execLandSteps w i x)).world.head = i.headAfter := by
  simp only [runTransaction, h, Option.isSome_none, Bool.false_eq_true, ↓reduceIte]
  have checks := successful_checks w i x h
  simp only [execLandSteps, checks.1, checks.2] at h ⊢
  exact (successful_poststate w i x h).1

theorem successive_no_double_consumption (w : World) (i : LandInput) (x : ExternalOutcomes)
    (j : LandInput) (y : ExternalOutcomes)
    (first : (execLandSteps w i x).error = none)
    (_second : (execLandSteps (runTransaction w (execLandSteps w i x)).world j y).error = none)
    (index : Nat) (consumed : w.head.val ≤ index ∧ index < i.headAfter.val) :
    ¬ ((runTransaction w (execLandSteps w i x)).world.head.val ≤ index ∧ index < j.headAfter.val) := by
  rw [committed_head w i x first]
  omega

/-- Changing only msg.sender changes the lander event, never the recipient instruction. -/
theorem copied_calldata_recipient (i : LandInput) (caller : Address) :
    ({ i with caller := caller } : LandInput).recipient = i.recipient := rfl

theorem statement_is_constructed (w : World) (i : LandInput) (x : ExternalOutcomes)
    (valid : validate w i = none) (env : environmentCheck x.environment i = none) :
    (execLandSteps w i x).statement = some (computedStatement w i x) := by
  simp only [execLandSteps, valid, env, execChecked, finish]
  split_ifs <;> rfl

theorem statement_recipient_from_input (w : World) (i : LandInput) (x : ExternalOutcomes) :
    (computedStatement w i x).recipient = natWord i.recipient.val := rfl

theorem statement_copied_caller (w : World) (i : LandInput) (x : ExternalOutcomes) (caller : Address) :
    computedStatement w { i with caller := caller } x = computedStatement w i x := rfl

theorem every_word_independent (a b : LandStatement) (field : Fin 18)
    (changed : (words a)[field.val] ≠ (words b)[field.val]) :
    encodeStatement a ≠ encodeStatement b := by
  intro same
  have equal := (statement_complete a b).mp same
  subst b
  exact changed rfl

/-- Authentic environment content is a separate, concrete relation; checked source
window/length rules alone do not authenticate historical data. -/
def AuthenticEnvironment (e : Environment) (reference : Word64) (currentBlock : Nat)
    (canonicalBlockHash : Nat → Word256) (transactionBlobs : List Word256) : Prop :=
  e.blockNumber = currentBlock ∧ e.blockHash = canonicalBlockHash reference.val ∧
  (e.historySuccess = true → e.historyLength = 32 → e.historyHash = canonicalBlockHash reference.val) ∧
  e.blobHashes = transactionBlobs

theorem authenticated_reference_content (e : Environment) (r : Word64) (currentBlock : Nat)
    (canonicalBlockHash : Nat → Word256) (transactionBlobs : List Word256)
    (authentic : AuthenticEnvironment e r currentBlock canonicalBlockHash transactionBlobs)
    (route : ReferenceRoute) (hash : Word256) (accepted : referenceHash e r = .ok (route,hash)) :
    hash = canonicalBlockHash r.val := by
  have result := reference_and_blobs e r route hash accepted
  cases route with
  | blockhash => exact (result.2.2.2.1 rfl).2.trans authentic.2.1
  | history =>
    have history := result.2.2.2.2 rfl
    exact history.2.2.2.trans (authentic.2.2.1 history.2.1 history.2.2.1)

theorem authenticated_blob_prefix (e : Environment) (r : Word64) (currentBlock : Nat)
    (canonicalBlockHash : Nat → Word256) (transactionBlobs : List Word256)
    (authentic : AuthenticEnvironment e r currentBlock canonicalBlockHash transactionBlobs) :
    actualBlobs e = transactionBlobs.takeWhile (· != 0) := by
  simp [actualBlobs, authentic.2.2.2]

/-- Concrete SignalService committed checkpoint under successful execution. -/
theorem successful_signal_checkpoint (w : World) (i : LandInput) (x : ExternalOutcomes)
    (h : (execChecked w i x).error = none) :
    (execChecked w i x).journal.current.signal =
      w.signal ++ [⟨i.lastHeight.val, i.lastBlockHash, i.lastStateRoot⟩] := by
  simp only [execChecked, finish, Journal.update, Journal.current] at h ⊢
  split_ifs at h ⊢ <;> simp_all

/-- Cumulative fees split exactly at any monotone intermediate head. -/
theorem fee_interval_add (fee : Nat → Word64) (a b c : Nat) (hab : a ≤ b) (hbc : b ≤ c) :
    fees fee a c = fees fee a b + fees fee b c := by
  unfold fees
  rw [show c-a = (b-a)+(c-b) by omega, List.range_add, List.map_append, List.sum_append]
  congr 1
  simp only [List.map_map, Function.comp_def]
  congr 1
  apply List.map_congr_left
  intro index _
  congr 2
  omega

theorem blob_prefix_nonzero (e : Environment) : ∀ hash ∈ actualBlobs e, hash ≠ 0 := by
  have all := List.all_takeWhile (l := e.blobHashes) (p := fun x => x != 0)
  rw [List.all_eq_true] at all
  intro hash member
  simpa using all hash member

/-- Named generic EVM journal law, independent of Landing inputs or desired postconditions.
The interpreter materializes all nested journal effects on commit and unwinds on abort. -/
def EvmJournalLaw (materialize : Journal World → Bool → World) : Prop :=
  ∀ journal, materialize journal true = journal.current ∧ materialize journal false = journal.rollback

theorem rollback_atomic_evm (materialize : Journal World → Bool → World)
    (evmJournal : EvmJournalLaw materialize) (w : World) (i : LandInput) (x : ExternalOutcomes)
    (e : Error) (failed : (execLandSteps w i x).error = some e) :
    materialize (execLandSteps w i x).journal (execLandSteps w i x).error.isNone = w := by
  simp only [failed, Option.isNone_some]
  rw [(evmJournal _).2, execution_journal_root]

theorem evm_journal_nonvacuity :
    EvmJournalLaw (fun journal committed => if committed then journal.current else journal.rollback) := by
  intro journal
  simp

theorem consumption_event_exact (w : World) (i : LandInput) (x : ExternalOutcomes)
    (h : (execChecked w i x).error = none) :
    (execChecked w i x).journal.current.logs = w.logs ++
      [.checkpointSaved ⟨i.lastHeight.val, i.lastBlockHash, i.lastStateRoot⟩,
       .batchLanded (w.checkpoint.height+1) i.lastHeight.val i.lastBlockHash i.lastStateRoot i.reference.val i.caller] ++
      (if i.headAfter ≠ w.head then
        [.consumed w.head.val i.headAfter.val (fees w.fee w.head.val i.headAfter.val * 1000000000) i.recipient]
       else []) := by
  simp only [execChecked, finish, Journal.update, Journal.current] at h ⊢
  split_ifs at h ⊢ <;> simp_all [List.append_assoc]

/-- External callback frame, deliberately restricted to protected Inbox/config/queue fields.
It is an application premise about external execution, not an arbitrary proposition field
or an assumption that the entire desired poststate already holds. -/
def CallbackFrame (before after : World) : Prop :=
  before.inbox = after.inbox ∧ before.l1ChainId = after.l1ChainId ∧
  before.l2ChainId = after.l2ChainId ∧ before.registry = after.registry ∧
  before.generation = after.generation ∧ before.config = after.config ∧
  before.maxBatchBlocks = after.maxBatchBlocks ∧ before.checkpoint = after.checkpoint ∧
  before.head = after.head ∧ before.tail = after.tail ∧ before.fee = after.fee ∧ before.guard = after.guard

theorem callback_frame_preserves_bounds (before after : World) (i : LandInput)
    (frame : CallbackFrame before after) (bounds : Bounds before i) : Bounds after i := by
  rcases frame with ⟨_, _, _, _, _, _, hmax, hcp, hhead, htail, _, _⟩
  simpa [Bounds, ← hmax, ← hcp, ← hhead, ← htail] using bounds

theorem callback_frame_nonvacuity (w : World) : CallbackFrame w w := by
  simp [CallbackFrame]

/-- Exact consumed-interval payment and monotone committed head, with both arithmetic
bounds. `successive_no_double_consumption` and `fee_interval_add` provide the sequential
non-overlap/composition consequences. -/
theorem fees_exact_once (w : World) (i : LandInput) (x : ExternalOutcomes)
    (accepted : (execLandSteps w i x).error = none) :
    (runTransaction w (execLandSteps w i x)).world.head = i.headAfter ∧
    w.head.val ≤ i.headAfter.val ∧
    (execLandSteps w i x).journal.current.transfers = w.transfers ++
      (if i.headAfter ≠ w.head ∧ 0 < fees w.fee w.head.val i.headAfter.val * 1000000000 then
        [⟨i.recipient, fees w.fee w.head.val i.headAfter.val * 1000000000⟩] else []) ∧
    fees w.fee w.head.val i.headAfter.val < 2 ^ 112 ∧
    fees w.fee w.head.val i.headAfter.val * 1000000000 < 2 ^ 256 := by
  have safe := fees_uint256 w.fee w.head i.headAfter
  exact ⟨committed_head w i x accepted, (bounds_preserved w i x accepted).2.2.2.1,
    (recipient_bound w i x accepted).2, safe.1, safe.2.2⟩

/-- The actual land entrypoint rejects a locked same-account callback before any body
write; saveForcedInclusion uses the same `nestedGuard` entry check in the source map. -/
theorem locked_land_and_save_reject (w : World) (i : LandInput) (x : ExternalOutcomes)
    (locked : w.guard = true) :
    (execLandSteps w i x).error = some .reentrant ∧
    (execLandSteps w i x).journal.current = w ∧ nestedGuard w.inbox w = some .reentrant := by
  simp [execLandSteps, validate, locked, finish, Journal.current, nestedGuard]

end Etna.Landing
