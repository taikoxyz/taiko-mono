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
  i.headAfter.val - w.head.val ≤ i.lastHeight.val - w.checkpoint.height ∧ i.recipient ≠ 0 ∧
  i.rewardRecipient ≠ 0

theorem validate_bounds (w : World) (i : LandInput) (h : validate w i = none) : Bounds w i := by
  unfold validate at h
  split_ifs at h; simp_all [Bounds]

theorem successful_checks (w : World) (i : LandInput) (x : ExternalOutcomes)
    (h : (execLandSteps w i x).error = none) :
    validate w i = none ∧ environmentCheck x.environment i = none := by
  unfold execLandSteps at h
  split at h <;> simp_all [finish]
  split at h <;> simp_all

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

theorem execPayment_root (w : World) (i : LandInput) (x : ExternalOutcomes) (j : Journal World)
    (st : List Stage) (s : Option LandStatement) : (execPayment w i x j st s).journal.rollback = j.rollback := by
  unfold execPayment; split <;> rfl

theorem execReward_root (w : World) (i : LandInput) (x : ExternalOutcomes) (j : Journal World)
    (st : List Stage) (s : Option LandStatement) : (execReward w i x j st s).journal.rollback = j.rollback := by
  unfold execReward; split
  · rfl
  · rw [execPayment_root]; rfl

theorem execReward_statement (w : World) (i : LandInput) (x : ExternalOutcomes) (j : Journal World)
    (st : List Stage) (s : Option LandStatement) : (execReward w i x j st s).statement = s := by
  unfold execReward execPayment; split
  · rfl
  · split <;> rfl

theorem checked_journal_root (w : World) (i : LandInput) (x : ExternalOutcomes) :
    (execChecked w i x).journal.rollback = w := by
  simp only [execChecked]
  split_ifs
  all_goals first | rfl | exact (execReward_root _ _ _ _ _ _).trans rfl

theorem execPayment_success (w : World) (i : LandInput) (x : ExternalOutcomes) (j : Journal World)
    (st : List Stage) (s : Option LandStatement) (h : (execPayment w i x j st s).error = none) :
    paymentFails w i x = false ∧ (execPayment w i x j st s).journal.current = paymentEffect w i j.current := by
  unfold execPayment at h ⊢
  split at h
  · simp [finish] at h
  · rename_i ok; simp only [Bool.not_eq_true] at ok
    exact ⟨ok, by simp [finish, Journal.update, Journal.current, ok]⟩

theorem execReward_success (w : World) (i : LandInput) (x : ExternalOutcomes) (j : Journal World)
    (st : List Stage) (s : Option LandStatement) (h : (execReward w i x j st s).error = none) :
    w.rewardCommitments (rewardId w i x) = 0 ∧ paymentFails w i x = false ∧
    (execReward w i x j st s).journal.current = paymentEffect w i (recordReward w i x j.current) := by
  unfold execReward at h ⊢
  split at h
  · simp [finish] at h
  · rename_i fresh
    have pay := execPayment_success w i x _ _ _ h
    simp only [bne_iff_ne, ne_eq, Decidable.not_not] at fresh
    refine ⟨fresh, pay.1, ?_⟩
    rw [ite_cond_eq_false _ _ (by simp [fresh])]
    exact pay.2

/-- Successful late execution: every check passed and the committed world is the exact
composition of the pre-verifier writes, the reward record and the payment/unlock. -/
theorem checked_success (w : World) (i : LandInput) (x : ExternalOutcomes)
    (h : (execChecked w i x).error = none) :
    x.signalAuthorized = true ∧ i.lastStateRoot ≠ 0 ∧ i.lastBlockHash ≠ 0 ∧
    x.verifierReturnsNormally = true ∧ w.rewardCommitments (rewardId w i x) = 0 ∧
    paymentFails w i x = false ∧
    (execChecked w i x).journal.current = paymentEffect w i (recordReward w i x (preVerifier w i)) := by
  simp only [execChecked] at h ⊢
  split_ifs at h ⊢
  all_goals first | (simp [finish] at h; done) | skip
  all_goals
    obtain ⟨fresh, ok, cur⟩ := execReward_success w i x _ _ _ h
    clear h
    refine ⟨?_, ?_, ?_, ?_, fresh, ok, cur.trans ?_⟩
    all_goals simp_all [Journal.update, Journal.current, preVerifier]

/-- Successful landing in terms of the steps; used by every post-state theorem below. -/
theorem landing_success (w : World) (i : LandInput) (x : ExternalOutcomes)
    (h : (execLandSteps w i x).error = none) :
    validate w i = none ∧ environmentCheck x.environment i = none ∧
    (execChecked w i x).error = none ∧
    (execLandSteps w i x).journal.current = paymentEffect w i (recordReward w i x (preVerifier w i)) ∧
    (runTransaction w (execLandSteps w i x)).world = paymentEffect w i (recordReward w i x (preVerifier w i)) := by
  have checks := successful_checks w i x h
  have reduce : execLandSteps w i x = execChecked w i x := by simp only [execLandSteps, checks.1, checks.2]
  rw [reduce] at h ⊢
  have cur := (checked_success w i x h).2.2.2.2.2.2
  exact ⟨checks.1, checks.2, h, cur, by simp [runTransaction, h, cur]⟩

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
  rw [(checked_success w i x h).2.2.2.2.2.2]
  simp only [paymentEffect, recordReward, preVerifier, feeWei]
  split_ifs <;> simp_all

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
  exact ⟨hb.2.2.2.2.2.2.1, (successful_poststate w i x h).2.2.2⟩

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
  simp only [execLandSteps, valid, env, execChecked]
  split_ifs
  all_goals first | rfl | exact execReward_statement _ _ _ _ _ _

theorem statement_recipient_from_input (w : World) (i : LandInput) (x : ExternalOutcomes) :
    (computedStatement w i x).recipient = natWord i.recipient.val := rfl

theorem statement_copied_caller (w : World) (i : LandInput) (x : ExternalOutcomes) (caller : Address) :
    computedStatement w { i with caller := caller } x = computedStatement w i x := rfl

theorem every_word_independent (a b : LandStatement) (field : Fin 20)
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
  rw [(checked_success w i x h).2.2.2.2.2.2]
  simp only [paymentEffect, recordReward, preVerifier]
  split_ifs <;> rfl

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
       .batchLanded (w.checkpoint.height+1) i.lastHeight.val i.lastBlockHash i.lastStateRoot i.reference.val i.caller,
       .rewardRecorded (rewardId w i x) i.rewardRecipient i.baseFeeAmount.val w.generation.val
         w.checkpoint.height w.checkpoint.blockHash i.lastHeight.val i.lastBlockHash] ++
      (if i.headAfter ≠ w.head then
        [.consumed w.head.val i.headAfter.val (fees w.fee w.head.val i.headAfter.val * 1000000000) i.recipient]
       else []) := by
  rw [(checked_success w i x h).2.2.2.2.2.2]
  simp only [paymentEffect, recordReward, preVerifier, feeWei]
  split_ifs <;> simp_all [List.append_assoc]

/-- External callback frame, deliberately restricted to protected Inbox/config/queue fields.
It is an application premise about external execution, not an arbitrary proposition field
or an assumption that the entire desired poststate already holds. -/
def CallbackFrame (before after : World) : Prop :=
  before.inbox = after.inbox ∧ before.l1ChainId = after.l1ChainId ∧
  before.l2ChainId = after.l2ChainId ∧ before.registry = after.registry ∧
  before.generation = after.generation ∧ before.config = after.config ∧
  before.maxBatchBlocks = after.maxBatchBlocks ∧ before.checkpoint = after.checkpoint ∧
  before.head = after.head ∧ before.tail = after.tail ∧ before.fee = after.fee ∧ before.guard = after.guard ∧
  before.rewardCommitments = after.rewardCommitments

theorem callback_frame_preserves_bounds (before after : World) (i : LandInput)
    (frame : CallbackFrame before after) (bounds : Bounds before i) : Bounds after i := by
  rcases frame with ⟨_, _, _, _, _, _, hmax, hcp, hhead, htail, _, _, _⟩
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

/-- Compose the two local collision assumptions with actual model serialization.
The byte hash is the same primitive on both calls. Context/height/etc equality is
recovered only for the twenty encoded fields, while the inner theorem also
recovers the complete ordered nonzero prefixes, including their lengths. -/
theorem composed_statement_blob_binding
    (outerHash : Vector Byte 640 → Word256)
    (w₁ w₂ : World) (i₁ i₂ : LandInput) (x₁ x₂ : ExternalOutcomes)
    (samePrimitive : x₁.keccakBlobBytes = x₂.keccakBlobBytes)
    (innerSeparation : LocalInnerHashSeparation x₁.keccakBlobBytes
      (actualBlobs x₁.environment) (actualBlobs x₂.environment))
    (outerSeparation : LocalHashSeparation outerHash
      (computedStatement w₁ i₁ x₁) (computedStatement w₂ i₂ x₂))
    (matched : outerHash (encodeStatement (computedStatement w₁ i₁ x₁)) =
      outerHash (encodeStatement (computedStatement w₂ i₂ x₂))) :
    computedStatement w₁ i₁ x₁ = computedStatement w₂ i₂ x₂ ∧
    actualBlobs x₁.environment = actualBlobs x₂.environment := by
  have statementEqual := hash_binding outerHash _ _ outerSeparation matched
  refine ⟨statementEqual, ?_⟩
  have commitmentEqual := congrArg LandStatement.blobCommitment statementEqual
  change natWord (x₁.keccakBlobBytes (serializeBlobPrefix (actualBlobs x₁.environment))).val =
    natWord (x₂.keccakBlobBytes (serializeBlobPrefix (actualBlobs x₂.environment))).val at commitmentEqual
  have hashEqual := natWord_injective _ _ (Fin.isLt _) (Fin.isLt _) commitmentEqual
  have hashEqual' : x₁.keccakBlobBytes (serializeBlobPrefix (actualBlobs x₁.environment)) =
      x₂.keccakBlobBytes (serializeBlobPrefix (actualBlobs x₂.environment)) := Fin.ext hashEqual
  rw [← samePrimitive] at hashEqual'
  exact inner_hash_binding _ _ _ innerSeparation hashEqual'

/-- The committed checkpoint is the proven endpoint. -/
theorem committed_checkpoint (w : World) (i : LandInput) (x : ExternalOutcomes)
    (accepted : (execLandSteps w i x).error = none) :
    (runTransaction w (execLandSteps w i x)).world.checkpoint = ⟨i.lastHeight.val, i.lastBlockHash⟩ := by
  rw [(landing_success w i x accepted).2.2.2.2]
  simp only [paymentEffect, recordReward, preVerifier]
  split_ifs <;> rfl

/-- LAND-09: a successful landing found its reward slot empty and committed exactly one
commitment, at the batch id of the receipt built from the parent read before landing, the
stored generation, both chain ids, the executing proxy and the proven outputs. -/
theorem reward_recorded_exact (w : World) (i : LandInput) (x : ExternalOutcomes)
    (accepted : (execLandSteps w i x).error = none) :
    w.rewardCommitments (rewardId w i x) = 0 ∧
    (runTransaction w (execLandSteps w i x)).world.rewardCommitments =
      Function.update w.rewardCommitments (rewardId w i x) (rewardCommitment w i x) ∧
    receiptOf w i = ⟨w.l1ChainId, w.l2ChainId, w.inbox, w.generation, w.checkpoint.height,
      w.checkpoint.blockHash, i.lastHeight.val, i.lastBlockHash, i.rewardRecipient, i.baseFeeAmount⟩ := by
  have success := landing_success w i x accepted
  refine ⟨(checked_success w i x success.2.2.1).2.2.2.2.1, ?_, rfl⟩
  rw [success.2.2.2.2]
  simp only [paymentEffect, recordReward, preVerifier]
  split_ifs <;> rfl

/-- The verified statement carries every receipt field: a sound proof binds the recorded
recipient and amount, not only the endpoints. -/
theorem receipt_statement_words (w : World) (i : LandInput) (x : ExternalOutcomes) :
    (computedStatement w i x).l1ChainId = natWord (receiptOf w i).l1ChainId.val ∧
    (computedStatement w i x).l2ChainId = natWord (receiptOf w i).l2ChainId.val ∧
    (computedStatement w i x).inbox = natWord (receiptOf w i).inbox.val ∧
    (computedStatement w i x).generation = natWord (receiptOf w i).generation.val ∧
    (computedStatement w i x).parentHeight = natWord (receiptOf w i).parentHeight ∧
    (computedStatement w i x).parentHash = natWord (receiptOf w i).parentHash.val ∧
    (computedStatement w i x).lastHeight = natWord (receiptOf w i).lastHeight ∧
    (computedStatement w i x).lastBlockHash = natWord (receiptOf w i).lastBlockHash.val ∧
    (computedStatement w i x).rewardRecipient = natWord (receiptOf w i).recipient.val ∧
    (computedStatement w i x).baseFeeAmount = natWord (receiptOf w i).amount.val :=
  ⟨rfl, rfl, rfl, rfl, rfl, rfl, rfl, rfl, rfl, rfl⟩

/-- Successful landings under one fixed Keccak primitive, with their receipts in order. -/
inductive RewardTrace (keccak : List Byte → Word256) : World → List Receipt → World → Prop where
  | nil (w : World) : RewardTrace keccak w [] w
  | cons {w : World} {rest : List Receipt} {final : World} (i : LandInput) (x : ExternalOutcomes)
      (primitive : x.keccakRewardBytes = keccak)
      (accepted : (execLandSteps w i x).error = none)
      (tail : RewardTrace keccak (runTransaction w (execLandSteps w i x)).world rest final) :
      RewardTrace keccak w (receiptOf w i :: rest) final

/-- Trace invariants: heights only grow, every receipt's parent lies in the traversed range,
receipt endpoints are uint64, and every changed slot belongs to a recorded receipt. -/
theorem reward_trace_facts {keccak : List Byte → Word256} {w : World} {rs : List Receipt} {final : World}
    (trace : RewardTrace keccak w rs final) (start : w.checkpoint.height < 2 ^ 64) :
    w.checkpoint.height ≤ final.checkpoint.height ∧ final.checkpoint.height < 2 ^ 64 ∧
    (∀ r ∈ rs, w.checkpoint.height ≤ r.parentHeight ∧ r.parentHeight < final.checkpoint.height ∧
      r.lastHeight < 2 ^ 64) ∧
    (∀ id, final.rewardCommitments id ≠ w.rewardCommitments id → ∃ r ∈ rs, batchId keccak r = id) ∧
    rs.Pairwise (fun a b => a.parentHeight < b.parentHeight) := by
  induction trace with
  | nil => exact ⟨le_rfl, start, by simp, by simp, List.Pairwise.nil⟩
  | @cons w rest final i x primitive accepted tail ih =>
    have cp := committed_checkpoint w i x accepted
    have progress : w.checkpoint.height < i.lastHeight.val := (bounds_preserved w i x accepted).1
    have last := i.lastHeight.isLt
    obtain ⟨mono, top, members, changed, ordered⟩ := ih (by rw [cp]; exact last)
    simp only [cp] at mono members
    refine ⟨by omega, top, ?_, ?_, ?_⟩
    · intro r member
      rcases List.mem_cons.mp member with rfl | member
      · refine ⟨le_rfl, ?_, ?_⟩
        · show w.checkpoint.height < final.checkpoint.height; omega
        · show i.lastHeight.val < 2 ^ 64; exact last
      · have := members r member; exact ⟨by omega, this.2.1, this.2.2⟩
    · intro id different
      have record := (reward_recorded_exact w i x accepted).2.1
      by_cases fresh : id = rewardId w i x
      · exact ⟨receiptOf w i, List.mem_cons_self .., by rw [fresh, rewardId, primitive]⟩
      · have same : (runTransaction w (execLandSteps w i x)).world.rewardCommitments id = w.rewardCommitments id := by
          rw [record, Function.update_of_ne fresh]
        rw [← same] at different
        obtain ⟨r, member, hr⟩ := changed id different
        exact ⟨r, List.mem_cons_of_mem _ member, hr⟩
    · refine List.Pairwise.cons ?_ ordered
      intro r member
      have := (members r member).1
      show w.checkpoint.height < r.parentHeight; omega

/-- LAND-10: from an empty ledger, `RewardAlreadyRecorded` is unreachable. The next landing's
slot is empty whenever its batch preimage is locally separated from each earlier receipt's. -/
theorem reward_slot_fresh {keccak : List Byte → Word256} {w : World} {rs : List Receipt} {final : World}
    (trace : RewardTrace keccak w rs final) (empty : ∀ id, w.rewardCommitments id = 0)
    (start : w.checkpoint.height < 2 ^ 64) (i : LandInput) (x : ExternalOutcomes)
    (primitive : x.keccakRewardBytes = keccak)
    (separation : ∀ r ∈ rs, LocalBatchSeparation keccak (receiptOf final i) r) :
    final.rewardCommitments (rewardId final i x) = 0 := by
  obtain ⟨_, top, members, changed, _⟩ := reward_trace_facts trace start
  by_contra occupied
  obtain ⟨r, member, hr⟩ := changed _ (by rw [empty]; exact occupied)
  have range := members r member
  have last := i.lastHeight.isLt
  apply batch_id_distinct keccak (receiptOf final i) r
    (show final.checkpoint.height < 2 ^ 256 by omega) (by omega)
    (show i.lastHeight.val < 2 ^ 256 by omega) (by omega) (separation r member)
    (show final.checkpoint.height ≠ r.parentHeight by omega)
  rw [hr, rewardId, primitive]

/-- Every receipt of a landing trace has a distinct batch id under pairwise local separation. -/
theorem reward_ids_distinct {keccak : List Byte → Word256} {w : World} {rs : List Receipt} {final : World}
    (trace : RewardTrace keccak w rs final) (start : w.checkpoint.height < 2 ^ 64)
    (separation : rs.Pairwise (LocalBatchSeparation keccak)) :
    rs.Pairwise (fun a b => batchId keccak a ≠ batchId keccak b) := by
  obtain ⟨_, top, members, _, ordered⟩ := reward_trace_facts trace start
  have both := List.Pairwise.and ordered separation
  refine List.Pairwise.imp_of_mem ?_ both
  intro a b ma mb ⟨lt, sep⟩
  have ra := members a ma
  have rb := members b mb
  exact batch_id_distinct keccak a b (by omega) (by omega) (by omega) (by omega) sep (by omega)

end Etna.Landing
