import EtnaModel.Current

namespace Etna.Design.Current
namespace Rules

theorem schedule_rules_result {c : Control} {s t : Schedule} {caller now rule time : Nat}
    (ok : scheduleRules c s caller now rule time = some t) :
    t.active = (if s.time ≤ now then s.next else s.active) ∧ t.next = rule ∧
    t.time = time ∧ t.stopTime = s.stopTime ∧ t.stopGrid = s.stopGrid ∧ fits t := by
  unfold scheduleRules at ok
  dsimp only at ok
  split at ok
  next guard =>
    cases Option.some.inj ok
    exact ⟨rfl,rfl,rfl,rfl,rfl,guard.2.2.2.2.2.2⟩
  next => simp at ok

theorem schedule_stop_result {c : Control} {s t : Schedule} {caller now time grid : Nat}
    (ok : scheduleStop c s caller now time grid = some t) :
    t.active = s.active ∧ t.next = s.next ∧ t.time = s.time ∧
    t.stopTime = time ∧ t.stopGrid = grid ∧ fits t := by
  unfold scheduleStop at ok
  dsimp only at ok
  split at ok
  next guard =>
    cases Option.some.inj ok
    exact ⟨rfl,rfl,rfl,rfl,rfl,guard.2.2.2.2.2⟩
  next => simp at ok

theorem rules_require_owner {c : Control} {s t : Schedule} {caller now rule time : Nat}
    (ok : scheduleRules c s caller now rule time = some t) :
    c.initialized = true ∧ caller = c.owner ∧ now+c.maxAge ≤ time := by
  unfold scheduleRules at ok
  dsimp only at ok
  split at ok
  next guard => exact ⟨guard.1,guard.2.1,guard.2.2.2.2.1⟩
  next => simp at ok

theorem stop_requires_owner {c : Control} {s t : Schedule} {caller now time grid : Nat}
    (ok : scheduleStop c s caller now time grid = some t) :
    c.initialized = true ∧ caller = c.owner ∧
    (time = 0 ∧ grid = 0 ∨ now+c.maxAge ≤ time ∧ 0 < grid ∧ 0 < c.grid ∧ grid % c.grid = 0) := by
  unfold scheduleStop at ok
  dsimp only at ok
  split at ok
  next guard => exact ⟨guard.1,guard.2.1,guard.2.2.2.1⟩
  next => simp at ok

theorem trace_fields_fit {c : Control} {s t : Schedule}
    (trace : Trace c s t) (initial : fits s) : fits t := by
  induction trace with
  | refl => exact initial
  | rules _ _ _ _ _ ok _ => exact (schedule_rules_result ok).2.2.2.2.2
  | stop _ _ _ _ _ ok _ => exact (schedule_stop_result ok).2.2.2.2.2

theorem preserves_visible_window {c : Control} {s t : Schedule} {caller now rule time stamp : Nat}
    (ok : scheduleRules c s caller now rule time = some t)
    (lower : now ≤ stamp) (upper : stamp < now+c.maxAge) : select t stamp = select s stamp := by
  unfold scheduleRules at ok
  dsimp only at ok
  split at ok
  next guard =>
    cases Option.some.inj ok
    simp only [select, replacement]
    have before : ¬ time ≤ stamp := by omega
    simp only [before, ↓reduceIte]
    by_cases past : s.time ≤ now
    · have seen : s.time ≤ stamp := by omega
      simp [past, seen]
    · have pending : now+c.maxAge < s.time := guard.2.2.1.resolve_left past
      have unseen : ¬ s.time ≤ stamp := by omega
      simp [past, unseen]
  next => simp at ok

theorem recover_clears_stop {s t : Schedule} {rule : Nat}
    (ok : recover s rule = some t) : t.stopTime = 0 ∧ t.stopGrid = 0 := by
  unfold recover at ok
  split at ok
  next => cases Option.some.inj ok; exact ⟨rfl,rfl⟩
  next =>
    split at ok
    next => cases Option.some.inj ok; exact ⟨rfl,rfl⟩
    next => simp at ok
end Rules

namespace Registry

theorem registration_issues_fresh {s t : State} {key owner amount now id : Nat}
    (ok : register s key owner amount now = some (t,id)) :
    id = s.nextId ∧ t.nextId = s.nextId+1 ∧ t.keyId key = some id := by
  unfold register at ok
  split at ok
  · simp at ok
  dsimp only at ok
  split at ok
  next =>
    have pair := Prod.mk.inj (Option.some.inj ok)
    obtain ⟨rfl,rfl⟩ := pair
    exact ⟨rfl,rfl,by simp⟩
  next => simp at ok

theorem modify_preserves_identity_counter {s t : State} {id : Nat} {f : Bond → Option Bond}
    (ok : modify s id f = some t) : t.nextId = s.nextId ∧ t.keyId = s.keyId := by
  unfold modify at ok
  split at ok
  next =>
    cases h : s.bonds id <;> simp only [h, Option.bind_none, Option.bind_some] at ok
    next => contradiction
    next b =>
      cases hf : f b <;> simp only [hf, Option.map_none, Option.map_some] at ok
      next => contradiction
      next v => cases Option.some.inj ok; exact ⟨rfl,rfl⟩
  next => simp at ok

theorem unissued_modify_rejected (s : State) (id : Nat) (f : Bond → Option Bond)
    (unissued : s.nextId ≤ id) : modify s id f = none := by
  simp [modify, Nat.not_lt.mpr unissued]

theorem unissued_withdraw_rejected (s : State) (id caller now delay : Nat)
    (unissued : s.nextId ≤ id) : withdraw s id caller now delay = none := by
  simp [withdraw, Nat.not_lt.mpr unissued]

theorem withdrawal_identity (b : Bond) :
    (withdrawn b).value.key = b.value.key ∧ (withdrawn b).value.exitAt = b.value.exitAt ∧
    (withdrawn b).value.released = true ∧ (withdrawn b).slot = none := by
  exact ⟨rfl,rfl,rfl,rfl⟩

theorem withdrawal_preserves_counter {s t : State} {id caller now delay payout : Nat}
    (ok : withdraw s id caller now delay = some (t,payout)) :
    t.nextId = s.nextId ∧ t.keyId = s.keyId := by
  unfold withdraw at ok
  split at ok
  next =>
    cases h : s.bonds id <;> simp only [h, Option.bind_none, Option.bind_some] at ok
    next => contradiction
    next b =>
      cases hc : b.value.confirmedAt <;> simp only [hc] at ok
      next => contradiction
      next atL1 =>
        split at ok
        next => cases Option.some.inj ok; exact ⟨rfl,rfl⟩
        next => simp at ok
  next => simp at ok

theorem trace_issuance_monotone {s t : State} (trace : Trace s t) : s.nextId ≤ t.nextId := by
  induction trace with
  | refl => exact Nat.le_refl _
  | registration _ _ _ _ _ _ ok ih => have h := registration_issues_fresh ok; omega
  | modification _ _ _ ok ih => have h := modify_preserves_identity_counter ok; omega
  | withdrawal _ _ _ _ _ _ ok ih => have h := withdrawal_preserves_counter ok; omega
end Registry

namespace Start

theorem grid_offset {start grid height : Nat} (ok : onGrid start grid height = true) :
    start ≤ height ∧ (height-start) % grid = 0 := by
  simp only [onGrid, decide_eq_true_eq] at ok
  exact ok.2

theorem first_landing_fenced {start hash root : Nat} {u : Unzen}
    (ok : firstLanding true start start hash root u = true) :
    u.nextProposal = u.finalizedProposal+1 ∧ u.finalizedHash = hash ∧
    u.checkpointExists = true ∧ u.checkpointHeight = start ∧ u.checkpointHash = hash ∧ u.checkpointRoot = root := by
  simpa [firstLanding] using ok

theorem origin_written_once (s : State) (caller now l1Block height hash root : Nat)
    (written : s.start ≠ none) : setOrigin s caller now l1Block height hash root = none := by
  simp [setOrigin, written]

theorem correction_new_generation {s t : State} {owner authenticated : Bool}
    {checkpoint height hash root l1Block now : Nat}
    (ok : correct s owner authenticated checkpoint height hash root l1Block now = some t) :
    t.generation = s.generation+1 ∧ ∀ g, g ≤ s.generation → t.origins g = s.origins g := by
  unfold correct at ok
  cases h : s.start <;> simp only [h, Option.bind_none, Option.bind_some] at ok
  next => contradiction
  next old =>
    split at ok
    next =>
      cases Option.some.inj ok
      refine ⟨rfl,?_⟩
      intro g prior
      have ne : g ≠ s.generation+1 := by omega
      simp [ne]
    next => simp at ok
end Start

namespace Import

theorem authenticated_conflict_halts {c : Candidate} {generation : Nat}
    (same : c.generation = generation) (height : c.origin ≤ c.height)
    (auth : c.checkpointAuthenticated = true) (final : c.checkpointFinalized = true)
    (data : c.dataHashAuthenticated = true) (valState : c.valStateAuthenticated = true)
    (conflict : c.envelopeEL ≠ c.checkpointEL) : inspect c generation = .halt := by
  simp [inspect, same, Nat.not_lt.mpr height, auth, final, data, valState, conflict]

/-- For s > o, a preimage that hashes to the finalized record's validator-state hash but whose
set for s + 1 differs from header(s)'s next_validators_hash is an authenticated contradiction. -/
theorem next_validators_conflict_halts {c : Candidate} {generation : Nat}
    (same : c.generation = generation) (windowed : c.origin < c.height)
    (auth : c.checkpointAuthenticated = true) (final : c.checkpointFinalized = true)
    (data : c.dataHashAuthenticated = true) (valState : c.valStateAuthenticated = true)
    (conflict : c.nextValidatorsMatch = false) : inspect c generation = .halt := by
  simp [inspect, same, Nat.not_lt.mpr (Nat.le_of_lt windowed), windowed, auth, final, data, valState, conflict]

/-- For s > o, with the window available and authenticated, a committee derived under 4.3
whose keys and powers differ from the matching preimage's set is an authenticated
contradiction. -/
theorem committee_conflict_halts {c : Candidate} {generation : Nat}
    (same : c.generation = generation) (windowed : c.origin < c.height)
    (auth : c.checkpointAuthenticated = true) (final : c.checkpointFinalized = true)
    (data : c.dataHashAuthenticated = true) (valState : c.valStateAuthenticated = true)
    (envelope : c.envelopeEL = c.checkpointEL) (next : c.nextValidatorsMatch = true)
    (material : c.materialAvailable = true) (metadata : c.metadataAuthenticated = true)
    (conflict : c.committeesMatch = false) : inspect c generation = .halt := by
  simp [inspect, same, Nat.not_lt.mpr (Nat.le_of_lt windowed), windowed, auth, final, data, valState, envelope,
    next, material, metadata, conflict]

theorem unfinalized_checkpoint_retries {c : Candidate} {generation : Nat}
    (same : c.generation = generation) (height : c.origin ≤ c.height)
    (auth : c.checkpointAuthenticated = true) (data : c.dataHashAuthenticated = true)
    (valState : c.valStateAuthenticated = true)
    (unfinalized : c.checkpointFinalized = false) : inspect c generation = .retry := by
  simp [inspect, same, Nat.not_lt.mpr height, auth, data, valState, unfinalized]

theorem invalid_data_rejected (c : Candidate) (generation : Nat)
    (invalid : c.dataHashAuthenticated = false) : inspect c generation = .reject := by
  simp [inspect, invalid]

/-- For s > o, a validator-state preimage that does not hash to the record's value is only an
invalid candidate, even when the record is finalized and every other check would pass. -/
theorem invalid_val_state_rejected (c : Candidate) (generation : Nat)
    (windowed : c.origin < c.height)
    (invalid : c.valStateAuthenticated = false) : inspect c generation = .reject := by
  simp [inspect, windowed, invalid]

/-- A snapshot at s = o takes the existing 8.4 genesis path (DATA-5.4-1): the start record
does not hold this generation's validator state, so the decision does not depend on the three
validator-state checks. -/
theorem genesis_path_ignores_val_state (c : Candidate) (generation : Nat)
    (start : c.height = c.origin) (valState nextSet committees : Bool) :
    inspect { c with valStateAuthenticated := valState
                     nextValidatorsMatch := nextSet
                     committeesMatch := committees } generation = inspect c generation := by
  simp [inspect, start]

theorem publish_boundary {c : Candidate} {generation unsettled : Nat} {signer : Signer.State}
    {durable : Bool} {installed : Installed}
    (ok : publish c generation unsettled signer durable = some installed) :
    durable = true ∧ installed.signer = signer ∧ installed.trusted = false ∧
    installed.headerNumbers =
      List.range' (retainedFrom c unsettled) (c.height+1-retainedFrom c unsettled) := by
  unfold publish at ok
  split at ok
  next guard => cases Option.some.inj ok; exact ⟨guard.1,rfl,rfl,rfl⟩
  next => simp at ok
end Import
end Etna.Design.Current

namespace Etna.Design.Current.Registry

theorem registration_retains_keys {s t : State} {key owner amount now id oldKey oldId : Nat}
    (ok : register s key owner amount now = some (t,id))
    (registered : s.keyId oldKey = some oldId) : t.keyId oldKey = some oldId := by
  unfold register at ok
  split at ok
  · simp at ok
  dsimp only at ok
  split at ok
  next guard =>
    have different : oldKey ≠ key := by
      intro same
      subst oldKey
      simp [guard.1] at registered
    obtain ⟨rfl,rfl⟩ := Prod.mk.inj (Option.some.inj ok)
    simpa [different] using registered
  next => simp at ok

theorem trace_keys_permanent {s t : State} (trace : Trace s t) (key id : Nat)
    (registered : s.keyId key = some id) : t.keyId key = some id := by
  induction trace with
  | refl => exact registered
  | registration _ _ _ _ _ _ ok ih => exact registration_retains_keys ok ih
  | modification _ _ _ ok ih => simpa [(modify_preserves_identity_counter ok).2] using ih
  | withdrawal _ _ _ _ _ _ ok ih => simpa [(withdrawal_preserves_counter ok).2] using ih

private theorem firstEmpty_some {s : State} : ∀ {count slot found : Nat},
    firstEmpty s slot count = some found →
      slot ≤ found ∧ found < slot+count ∧ s.slots found = none ∧
        ∀ lower, slot ≤ lower → lower < found → s.slots lower ≠ none
  | 0, _, _, ok => by simp [firstEmpty] at ok
  | count+1, slot, found, ok => by
    unfold firstEmpty at ok
    split at ok
    next empty =>
      cases Option.some.inj ok
      exact ⟨Nat.le_refl _,by omega,empty,fun _ low high => by omega⟩
    next held =>
      obtain ⟨low,high,empty,lower⟩ := firstEmpty_some ok
      refine ⟨by omega,by omega,empty,fun i above below => ?_⟩
      by_cases same : i = slot
      · subst i; exact held
      · exact lower i (by omega) below

private theorem firstEmpty_none {s : State} : ∀ {count slot : Nat},
    firstEmpty s slot count = none → ∀ i, slot ≤ i → i < slot+count → s.slots i ≠ none
  | 0, _, _, _, _, high => by omega
  | count+1, slot, ok, i, low, high => by
    unfold firstEmpty at ok
    split at ok
    next => simp at ok
    next held =>
      by_cases same : i = slot
      · subst i; exact held
      · exact firstEmpty_none ok i (by omega) (by omega)

private theorem firstEmpty_full {s : State} : ∀ {count slot : Nat},
    (∀ i, slot ≤ i → i < slot+count → s.slots i ≠ none) → firstEmpty s slot count = none
  | 0, _, _ => rfl
  | count+1, slot, full => by
    unfold firstEmpty
    rw [ite_eq_right (full slot (Nat.le_refl _) (by omega))]
    exact firstEmpty_full fun i low high => full i (by omega) (by omega)

/-- STAKE-4.1-14a: admission finds no slot exactly when all 4096 slots are held. -/
theorem admission_none_iff_full (s : State) :
    admissionSlot s = none ↔ ∀ slot, slot < 4096 → s.slots slot ≠ none :=
  ⟨fun none slot bound => firstEmpty_none none slot (Nat.zero_le _) (by omega),
   fun full => firstEmpty_full fun i _ bound => full i (by omega)⟩

/-- STAKE-4.1-14a, LIMIT-12-11: with every slot held, registration fails whatever the amount,
also when a holder's balance is zero; it replaces nobody. -/
theorem register_full_rejected (s : State) (key owner amount now : Nat)
    (full : ∀ slot, slot < 4096 → s.slots slot ≠ none) : register s key owner amount now = none := by
  unfold register
  rw [(admission_none_iff_full s).mpr full]

/-- STAKE-4.1-14a: a successful registration takes a slot below 4096 that was empty before the
call while every lower slot was held. The new bond holds it, and every other slot and bond is
unchanged: admission never moves or removes another bond. -/
theorem register_takes_lowest_empty {s t : State} {key owner amount now id : Nat}
    (ok : register s key owner amount now = some (t,id)) :
    ∃ slot, slot < 4096 ∧ s.slots slot = none ∧ (∀ lower, lower < slot → s.slots lower ≠ none) ∧
      t.slots slot = some id ∧ (t.bonds id).map Bond.slot = some (some slot) ∧
      (∀ other, other ≠ slot → t.slots other = s.slots other) ∧
      (∀ other, other ≠ id → t.bonds other = s.bonds other) := by
  unfold register at ok
  split at ok
  · simp at ok
  rename_i slot found
  dsimp only at ok
  split at ok
  next =>
    obtain ⟨rfl,rfl⟩ := Prod.mk.inj (Option.some.inj ok)
    obtain ⟨_,bound,empty,lower⟩ := firstEmpty_some found
    exact ⟨slot,by omega,empty,fun i below => lower i (Nat.zero_le _) below,by simp,
      by simp [updateBond],fun other ne => by simp [ne],fun other ne => by simp [updateBond,ne]⟩
  next => simp at ok
end Etna.Design.Current.Registry

namespace Etna.Design.Current.Start

theorem trace_generations_monotone {s t : State} (trace : Trace s t) : s.generation ≤ t.generation := by
  induction trace with
  | refl => exact Nat.le_refl _
  | correction _ _ _ _ _ _ _ _ _ ok ih => have h := correction_new_generation ok; omega

theorem trace_origins_retained {s t : State} (trace : Trace s t) (g : Nat)
    (prior : g ≤ s.generation) : t.origins g = s.origins g := by
  induction trace with
  | refl => rfl
  | correction history _ _ _ _ _ _ _ _ ok ih =>
    have bound := trace_generations_monotone history
    have preserve := (correction_new_generation ok).2 g (by omega)
    exact preserve.trans ih
end Etna.Design.Current.Start

namespace Etna.Design.Current.Rules

theorem covered_batch_keeps_every_ruleset (implemented : List Nat) (s : Schedule)
    (timestamps : List Nat) (covered : covers implemented s timestamps = true) :
    ∀ t, t ∈ timestamps → select s t ∈ implemented := by
  induction timestamps with
  | nil => simp
  | cons head rest ih =>
    simp only [covers, List.all_cons, Bool.and_eq_true, decide_eq_true_eq] at covered
    intro t member
    cases List.mem_cons.mp member with
    | inl same => simpa [same] using covered.1
    | inr tail => exact ih covered.2 t tail
end Etna.Design.Current.Rules
