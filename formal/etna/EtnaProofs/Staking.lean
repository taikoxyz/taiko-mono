import EtnaModel.Staking
import EtnaProofs.Committee

namespace Etna.Design.Staking

theorem reused_slot_starts_unconfirmed {slot out : Bond} {key owner stake now delay : Nat}
    (ok : register slot key owner stake now delay = some out) :
    slot.released = true ∧ out.confirmedAt = none ∧ out.exitAt = noExit ∧ out.owner = owner ∧
    now < out.activeFrom := by
  unfold register at ok
  split at ok
  · rename_i h
    cases ok
    exact ⟨h.1,rfl,rfl,rfl,by have := h.2; simp only; omega⟩
  · contradiction

theorem exit_set_once (b : Bond) (caller now delay : Nat) (set : b.exitSet = true) :
    requestExit b caller now delay = none := by
  have : b.exitAt ≠ noExit := by simpa [Bond.exitSet] using set
  simp [requestExit, this]

theorem confirmation_idempotent (s : State) (b : Bond) (atL1 now : Nat)
    (can : Confirmable s b) (record : b.confirmedAt = some atL1) :
    confirmExit s b now = some b := by
  simp [confirmExit, can, record]

theorem confirmation_requires_coverage {s : State} {b out : Bond} {now : Nat}
    (ok : confirmExit s b now = some out) :
    inboxInitialized s = true ∧ b.exitAt ≠ noExit ∧ b.exitAt ≤ s.snapshot ∧
    (out = b ∨ (b.confirmedAt = none ∧ out = { b with confirmedAt := some now })) := by
  unfold confirmExit at ok
  split at ok
  · rename_i can
    refine ⟨can.1, can.2.2.2.1, can.2.2.2.2, ?_⟩
    cases h : b.confirmedAt with
    | some _ => simp only [h] at ok; cases ok; exact Or.inl rfl
    | none => simp only [h] at ok; cases ok; exact Or.inr ⟨rfl,rfl⟩
  · contradiction

/-- Before the Inbox is initialized, confirmExit fails (so nothing can be withdrawn). -/
theorem confirm_requires_inbox_init (s : State) (b : Bond) (now : Nat)
    (uninitialized : inboxInitialized s = false) : confirmExit s b now = none := by
  simp [confirmExit, Confirmable, uninitialized]

theorem withdraw_waits_for_confirmation {s : State} {b out : Bond} {caller now delay amount : Nat}
    (ok : withdraw s b caller now delay = some (out,amount)) :
    ∃ atL1, b.confirmedAt = some atL1 ∧ atL1+delay ≤ now ∧
      amount = b.stake ∧ out.confirmedAt = none ∧ out.released = true ∧ out.stake = 0 := by
  cases h : b.confirmedAt with
  | none => simp [withdraw,h] at ok
  | some atL1 =>
    simp only [withdraw,h] at ok
    split at ok
    · rename_i can
      cases ok
      exact ⟨atL1,rfl,can.2.2.1,rfl,rfl,rfl,rfl⟩
    · contradiction

theorem positive_payout_owner {s : State} {b out : Bond} {caller now delay amount : Nat}
    (ok : withdraw s b caller now delay = some (out,amount)) (positive : 0 < b.stake) :
    caller = b.owner := by
  cases h : b.confirmedAt with
  | none => simp [withdraw,h] at ok
  | some atL1 =>
    simp only [withdraw,h] at ok
    split at ok
    · rename_i can
      rcases can.2.2.2.2 with zero | owner
      · omega
      · exact owner
    · contradiction

/-- Withdrawal does not re-read the landed snapshot (4.1 "提款时无需复查"). -/
theorem withdraw_ignores_snapshot (s : State) (b : Bond) (caller now delay x : Nat) :
    withdraw { s with snapshot := x } b caller now delay = withdraw s b caller now delay := by
  cases h : b.confirmedAt with
  | none => simp [withdraw, h]
  | some atL1 => simp only [withdraw, h]; rfl

/-- Recovery's `excludedRegistry` applies exactly this update to the election's view. -/
theorem exclude_matches_recovery (b : Bond) (r : Nat) :
    toEntry (exclude b r) = { toEntry b with exitAt := min (toEntry b).exitAt r } := rfl

/-- After an exclusion at R the exit is set, so no later requestExit can move it later. -/
theorem exclusion_blocks_later_request (b : Bond) (r caller now delay : Nat) (bounded : r < noExit) :
    requestExit (exclude b r) caller now delay = none := by
  apply exit_set_once
  simp only [Bond.exitSet, exclude, bne_iff_ne, ne_eq]
  omega

theorem exclusion_keeps_stake (b : Bond) (r : Nat) :
    (exclude b r).stake = b.stake ∧ (exclude b r).exitAt ≤ r ∧ (exclude b r).exitAt ≤ b.exitAt ∧
    (exclude b r).owner = b.owner ∧ (exclude b r).confirmedAt = b.confirmedAt :=
  ⟨rfl,Nat.min_le_right _ _,Nat.min_le_left _ _,rfl,rfl⟩

/-- The stored snapshot is always below the current L1 block (`land_snapshot_below_block`),
so every newly set exit lies strictly above it: confirming an exit always needs a later
landing whose committee cutoff covers it. -/
theorem requested_exit_not_yet_covered {b out : Bond} {caller now delay snapshot : Nat}
    (below : snapshot < now) (ok : requestExit b caller now delay = some out) : snapshot < out.exitAt := by
  unfold requestExit at ok
  split at ok
  · cases ok
    show snapshot < max (now+delay) (b.activeFrom+delay)
    omega
  · contradiction

theorem excluded_exit_not_yet_covered (b : Bond) (r snapshot : Nat) (below : snapshot < r)
    (prior : snapshot < b.exitAt) : snapshot < (exclude b r).exitAt := by
  show snapshot < min b.exitAt r
  omega

theorem fraction_bounded (remaining bps : Nat) (cap : bps ≤ 10000) : fraction remaining bps ≤ remaining := by
  have h := Nat.div_le_div_right (c := 10000) (Nat.mul_le_mul_left remaining cap)
  simpa [fraction] using h

theorem double_sign_conserves {inbox : State} {b out : Bond} {now bps bounty sink : Nat}
    (ok : slashDouble inbox b now bps = some (out,bounty,sink)) :
    bounty+sink = b.stake ∧ out.stake = 0 ∧ out.exitAt ≤ now ∧ out.exitAt ≤ b.exitAt ∧
    out.key = b.key ∧ out.confirmedAt = b.confirmedAt := by
  unfold slashDouble at ok
  split at ok
  · rename_i h
    cases ok
    have := fraction_bounded b.stake bps h.2.2.2
    exact ⟨by omega,rfl,Nat.min_le_right _ _,Nat.min_le_left _ _,rfl,rfl⟩
  · contradiction

theorem slashed_exit_not_yet_covered {inbox : State} {b out : Bond} {now bps bounty sink snapshot : Nat}
    (below : snapshot < now) (prior : snapshot < b.exitAt)
    (ok : slashDouble inbox b now bps = some (out,bounty,sink)) : snapshot < out.exitAt := by
  unfold slashDouble at ok
  split at ok
  · cases ok
    show snapshot < min b.exitAt now
    omega
  · contradiction

theorem slash_requires_inbox_init (inbox : State) (b : Bond) (now bps : Nat)
    (uninitialized : inboxInitialized inbox = false) : slashDouble inbox b now bps = none := by
  simp [slashDouble, uninitialized]

theorem slashed_bond_still_waits (inbox s : State) (b out : Bond) (now bps bounty sink caller later delay : Nat)
    (ok : slashDouble inbox b now bps = some (out,bounty,sink)) (unconfirmed : b.confirmedAt = none) :
    withdraw s out caller later delay = none := by
  have h := (double_sign_conserves ok).2.2.2.2.2
  simp [withdraw, h, unconfirmed]

/-- Block numbers cannot order transactions inside one L1 block: a confirmation recorded in
the last trusted landing's own block survives `rollbackAfter`, even if it relied on an
untrusted landing later in that block. This is why §8 re-checks against the snapshot. -/
theorem rollbackAfter_keeps_same_block (b : Bond) (x : Nat) (record : b.confirmedAt = some x) :
    rollbackAfter x b = b := by
  simp [rollbackAfter, record]

/-- Every confirmation that survives `rollbackBySnapshot` is justified by the trusted
snapshot, whatever happened inside any L1 block. -/
theorem rollbackBySnapshot_keeps_only_covered (restored atL1 : Nat) (b : Bond)
    (kept : (rollbackBySnapshot restored b).confirmedAt = some atL1) : b.exitAt ≤ restored := by
  unfold rollbackBySnapshot at kept
  cases h : b.confirmedAt with
  | none => simp [h] at kept
  | some x =>
    simp only [h] at kept
    split at kept
    · simp at kept
    · omega

/-- Conversely, a confirmation the restored snapshot covers is kept unchanged; under sound
history every confirmation made before the first untrusted landing is of this kind. -/
theorem rollbackBySnapshot_keeps_covered (restored : Nat) (b : Bond) (covered : b.exitAt ≤ restored) :
    rollbackBySnapshot restored b = b := by
  unfold rollbackBySnapshot
  cases h : b.confirmedAt with
  | none => rfl
  | some _ => simp [show ¬ restored < b.exitAt by omega]

theorem evidence_domain {deployment : Domain} {generation : Nat} {a b : Vote}
    (ok : doubleSign deployment generation a b = true) :
    a.domain = deployment ∧ b.domain = deployment ∧ a.generation = b.generation ∧ a.generation ≤ generation := by
  have h := of_decide_eq_true ok
  exact ⟨h.1,h.2.1,h.2.2.1,h.2.2.2.1⟩

end Etna.Design.Staking
