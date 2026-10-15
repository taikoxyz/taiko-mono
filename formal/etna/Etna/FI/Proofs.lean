module
public import Etna.FI.Model
public import Mathlib.Tactic
@[expose] public section
namespace Etna.FI

/-- FI-01: inclusive widened deadline, including sums larger than u64. -/
theorem fi01_due (timestamp delay anchor : Word64) :
    isDue timestamp.val delay.val anchor.val = true ↔ timestamp.val + delay.val ≤ anchor.val := by
  simp [isDue]

theorem fi01_sum_bound (timestamp delay : Word64) : timestamp.val + delay.val < 2^128 :=
  Etna.word64_add_fits128 timestamp delay

/-- FI-02: complete witness presence/index truth table. -/
theorem fi02_pending (cursor tail : Nat) (witness : Option Nat) :
    pending cursor tail witness = .ok true ↔ cursor < tail ∧ witness = some cursor := by
  cases witness with
  | none => simp [pending]; split <;> simp_all
  | some got =>
    by_cases h : tail ≤ cursor <;> by_cases e : got = cursor <;> simp [pending, h, e]; omega

/-- MPT soundness is applied to the authenticated anchor's root and exact ordered slots. -/
theorem fi02_authenticated (a : Authentication) (c : Context) (w : Witness)
    (context : ContextEvidence a c)
    (verified : a.verify c.stateRoot c.inbox (entrySlots a.slot c.cursor.val)
      w.entry w.proof = true) :
    a.storageEntry (a.committedRoot c.anchorHash) c.inbox
      (entrySlots a.slot c.cursor.val) = some w.entry := by
  rw [← context.root]
  exact a.sound _ _ _ _ _ verified

theorem fi02_bad_proof_rejects (a : Authentication) (codec : Codec) (c : Context)
    (w : Witness) (txs : List Bytes) (pendingBound : c.cursor.val < c.tail.val)
    (index : w.index = c.cursor.val)
    (rejected : a.verify c.stateRoot c.inbox (entrySlots a.slot c.cursor.val)
      w.entry w.proof = false) : evaluate a codec c (some w) txs = .error .malformed := by
  simp [evaluate, pending, Nat.not_le.mpr pendingBound, index, rejected, Bind.bind,
    Except.bind]

/-- Authentication and witness presence/index precede all scalar classifier branches. -/
theorem fi02_evaluate_authenticated (a : Authentication) (codec : Codec) (c : Context)
    (w : Witness) (txs : List Bytes) (pendingBound : c.cursor.val < c.tail.val)
    (index : w.index = c.cursor.val)
    (verified : a.verify c.stateRoot c.inbox (entrySlots a.slot c.cursor.val)
      w.entry w.proof = true) :
    evaluate a codec c (some w) txs = classify (scalarFacts codec c w txs) := by
  simp [evaluate, pending, Nat.not_le.mpr pendingBound, index, verified, Bind.bind,
    Except.bind]

/-- The prechecked includes the redundant preimage checks; a matching head cannot bypass them. -/
theorem fi03_included_iff (f : ForcedFacts)
    (prechecked : checkPreimage f.preimageLen f.preimageHashMatches = .ok ()) :
    classify f = .ok (.included f.cursor) ↔ f.firstMatches = true := by
  simp only [classify, prechecked]
  by_cases hf : f.firstMatches = true <;>
    by_cases hd : isDue f.timestamp f.delay f.anchorTimestamp = true <;>
    cases hh : f.preimageHashMatches <;> cases hc : f.preimageCanonical <;>
    simp [Bind.bind, Pure.pure, Except.bind, Except.pure,
       hf, hd]

theorem fi03_head_binding (codec : Codec) (entry : Entry) (txs : List Bytes) :
    firstMatches codec entry txs = true ↔
      ∃ head rest, txs = head :: rest ∧ head.length ≤ 8192 ∧
        codec.canonical head = true ∧ codec.hash head = entry.digest := by
  cases txs <;> simp [firstMatches, and_assoc]

/-- Complete inclusion contract: authenticated storage and all preceding checks, then actual head. -/
theorem fi03_authenticated_inclusion (a : Authentication) (codec : Codec) (c : Context)
    (w : Witness) (txs : List Bytes) (context : ContextEvidence a c)
    (pendingBound : c.cursor.val < c.tail.val) (index : w.index = c.cursor.val)
    (verified : a.verify c.stateRoot c.inbox (entrySlots a.slot c.cursor.val)
      w.entry w.proof = true)
    (prechecked : checkPreimage w.preimage.length (decide (codec.hash w.preimage = w.entry.digest)) = .ok ()) :
    a.storageEntry (a.committedRoot c.anchorHash) c.inbox (entrySlots a.slot c.cursor.val) = some w.entry ∧
    (evaluate a codec c (some w) txs = .ok (.included c.cursor.val) ↔
      ∃ head rest, txs = head :: rest ∧ head.length ≤ 8192 ∧ codec.canonical head = true ∧
        codec.hash head = w.entry.digest) := by
  constructor
  · exact fi02_authenticated a c w context verified
  · rw [fi02_evaluate_authenticated a codec c w txs pendingBound index verified]
    change classify (scalarFacts codec c w txs) = .ok (.included (scalarFacts codec c w txs).cursor) ↔ _
    rw [fi03_included_iff _ prechecked]
    exact fi03_head_binding codec w.entry txs

/-- Exact historic bytes require only separation for this admitted/candidate pair. -/
theorem fi03_exact_bytes (codec : Codec) (admitted candidate : Bytes)
    (separated : LocallySeparated codec.hash admitted candidate)
    (sameHash : codec.hash admitted = codec.hash candidate) : admitted = candidate := by
  by_contra h
  exact separated h sameHash

/-- FI-04/05: full classifier branches after the required preimage prechecked. -/
theorem classify_branches (f : ForcedFacts)
    (prechecked : checkPreimage f.preimageLen f.preimageHashMatches = .ok ()) :
    classify f =
      if f.firstMatches then .ok (.included f.cursor)
      else if isDue f.timestamp f.delay f.anchorTimestamp then
        if f.preimageHashMatches then
          if f.preimageCanonical then .ok (.needsSkip f.cursor)
          else .ok (.skippedInvalid f.cursor)
        else .error .hashMismatch
      else .ok .ordinary := by
  simp [classify, prechecked, Bind.bind, Pure.pure,
    Except.bind, Except.pure]

theorem fi04_predue (f : ForcedFacts)
    (prechecked : checkPreimage f.preimageLen f.preimageHashMatches = .ok ())
    (head : f.firstMatches = false)
    (early : f.anchorTimestamp < f.timestamp + f.delay) : classify f = .ok .ordinary := by
  rw [classify_branches f prechecked]
  simp [head, isDue, Nat.not_le.mpr early]

theorem fi05_due_skip (f : ForcedFacts)
    (prechecked : checkPreimage f.preimageLen f.preimageHashMatches = .ok ())
    (head : f.firstMatches = false) (due : f.timestamp + f.delay ≤ f.anchorTimestamp)
    (hash : f.preimageHashMatches = true) :
    classify f = .ok (if f.preimageCanonical then .needsSkip f.cursor else .skippedInvalid f.cursor) := by
  rw [classify_branches f prechecked]
  cases h : f.preimageCanonical <;> simp [head, isDue, due, hash]

/-- FI-06: all failure outcomes reject without exposing a consumed index. -/
theorem fi06_resolve (index : Nat) (outcome : SingletonOutcome) :
    resolve (.needsSkip index) outcome = .ok (some index) ↔ outcome = .completedEmpty := by
  cases outcome <;> simp [resolve]

theorem fi06_completed_context (request : BuildRequest) (response : BuildResponse) :
    singletonOutcome request response = .completedEmpty ↔ response = .completed request [] := by
  cases response with
  | unavailable => simp [singletonOutcome]
  | malformed => simp [singletonOutcome]
  | completed actual retained =>
    by_cases h : actual = request <;> cases retained <;> simp [singletonOutcome, h]

theorem fi06_execution_evidence (execution : Execution) (c : Context) (tx : Bytes)
    (empty : singletonOutcome (singletonRequest c tx)
      (execution.run (singletonRequest c tx)) = .completedEmpty) :
    execution.validExecution ⟨c.parent, c.attributes, c.anchorHash, [tx]⟩ [] := by
  have h := (fi06_completed_context _ _).mp empty
  exact execution.sound _ _ _ h

/-- FI-07: an authenticated 48-bit tail leaves ample room for checked u64 advancement. -/
theorem fi07_advance (cursor : Word64) (tail : Word48) (pendingBound : cursor.val < tail.val) :
    advance cursor.val (some cursor.val) = .ok (cursor.val + 1) ∧ cursor.val + 1 < 2^64 := by
  have ht := tail.isLt
  have bound : cursor.val + 1 < 2^64 := by omega
  constructor
  · simp [advance]; omega
  · exact bound

theorem valid_step_count {before after : Nat} {consumed : Option Nat}
    (step : ValidStep before after consumed) :
    after = before + (if consumed.isSome then 1 else 0) := by
  have h := step.advancement
  cases consumed with
  | none => simpa [advance] using h.symm
  | some index =>
    simp only [advance] at h
    split at h
    · contradiction
    · split at h
      · simpa using h.symm
      · contradiction

theorem fi07_trace_count {before after : Nat} {steps : List (Option Nat)}
    (trace : ValidTrace before steps after) : after = before + consumptionCount steps := by
  induction trace with
  | nil cursor => simp [consumptionCount]
  | @cons before middle after consumed rest step trace ih =>
    rw [ih, valid_step_count step]
    cases consumed <;> simp [consumptionCount, Nat.add_assoc, Nat.add_comm]

theorem fi07_trace_bound {before after : Nat} {steps : List (Option Nat)}
    (initial : before < 2^64) (trace : ValidTrace before steps after) : after < 2^64 := by
  induction trace with
  | nil => exact initial
  | @cons before middle after consumed rest step trace ih =>
    apply ih
    have hc := valid_step_count step
    cases consumed with
    | none => simpa using hc ▸ initial
    | some index =>
      have hp := step.pendingBound (by simp)
      have ht := step.context.tail.isLt
      simp only [Option.isSome_some, ↓reduceIte] at hc
      omega

theorem fi07_count_le_blocks (steps : List (Option Nat)) : consumptionCount steps ≤ steps.length := by
  exact List.length_filter_le _ _

/-- A successful scalar chain can consume only its parent cursor, never another index. -/
theorem fi07_consumed_index (f : ForcedFacts) (d : Decision) (o : SingletonOutcome) (index : Nat)
    (classified : classify f = .ok d) (resolved : resolve d o = .ok (some index)) : index = f.cursor := by
  unfold classify at classified
  cases hp : checkPreimage f.preimageLen f.preimageHashMatches with
  | error e => simp [hp, Bind.bind, Except.bind] at classified
  | ok u =>
    cases u
    simp only [hp, Bind.bind, Except.bind] at classified
    split at classified
    · cases classified; simpa [resolve] using resolved.symm
    · split at classified
      · split at classified
        · split at classified
          · cases classified; cases o <;> simp_all [resolve]
          · cases classified; simpa [resolve] using resolved.symm
        · contradiction
      · cases classified; simp [resolve] at resolved

/-- FI-08 compares separate hot and cold reducers from checked cache evidence.
    Authentication, deterministic execution, payload validity/settlement and durable success
    remain explicit adapter boundaries, not a claim of equal availability. -/
theorem fi08_success_equivalence (a : Authentication) (codec : Codec) (execution : Execution)
    (c : Context) (w : Option Witness) (txs : List Bytes) (cache : CacheEntry) (envelope : Bytes)
    (usable : cacheUsable cache c envelope = true)
    (evidence : CacheEvidence a codec execution c w txs cache) :
    finalizeCached cache c envelope = execute a codec execution c w txs := by
  simp [finalizeCached, execute, usable, evidence.classified, evidence.executed,
    Bind.bind, Except.bind]

theorem fi08_commit_reopen {Store : Type} (store : DurableStore Store)
    (a : Authentication) (codec : Codec) (execution : Execution)
    (c : Context) (w : Option Witness) (txs : List Bytes) (cache : CacheEntry) (envelope : Bytes)
    (usable : cacheUsable cache c envelope = true)
    (evidence : CacheEvidence a codec execution c w txs cache)
    (beforeHot beforeCold afterHot afterCold : Store) (hotCursor coldCursor : Nat)
    (hotSuccess : finalizeCached cache c envelope = .ok hotCursor)
    (coldSuccess : execute a codec execution c w txs = .ok coldCursor)
    (hotCommitted : store.write beforeHot hotCursor = .ok afterHot)
    (coldCommitted : store.write beforeCold coldCursor = .ok afterCold) :
    hotCursor = coldCursor ∧ store.reopen afterHot = store.reopen afterCold := by
  have same := fi08_success_equivalence a codec execution c w txs cache envelope usable evidence
  rw [hotSuccess, coldSuccess] at same
  have cursors := Except.ok.inj same
  exact ⟨cursors, by rw [store.roundtrip _ _ _ hotCommitted,
    store.roundtrip _ _ _ coldCommitted, cursors]⟩

theorem fi08_cache_context (cache : CacheEntry) (c : Context) (envelope : Bytes) :
    cacheUsable cache c envelope = true ↔ cache.context = c ∧ cache.envelope = envelope := by
  simp [cacheUsable]

/-- FI-09: no expiry while both anchor times remain due. -/
theorem fi09_no_expiry (f : ForcedFacts) (later : Nat)
    (due : f.timestamp + f.delay ≤ f.anchorTimestamp)
    (stillDue : f.timestamp + f.delay ≤ later) :
    classify {f with anchorTimestamp := later} = classify f := by
  simp [classify, isDue, due, stillDue]

/-- Non-vacuity examples use finite, consistent scalar facts. -/
theorem ordinary_example : pending 0 0 none = .ok false := by rfl

theorem predue_include_example :
    classify ⟨0, 10, 10, 11, 0, false, false, true⟩ = .ok (.included 0) := by rfl

theorem due_invalid_example :
    classify ⟨0, 10, 10, 20, 0, true, false, false⟩ = .ok (.skippedInvalid 0) := by rfl

theorem due_empty_example :
    classify ⟨0, 10, 10, 20, 0, true, true, false⟩ = .ok (.needsSkip 0) ∧
    resolve (.needsSkip 0) .completedEmpty = .ok (some 0) := by constructor <;> rfl
end Etna.FI
