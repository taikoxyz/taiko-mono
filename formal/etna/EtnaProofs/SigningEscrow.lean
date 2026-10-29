import EtnaModel.SigningEscrow
import EtnaProofs.Lifecycle
import EtnaProofs.Signer

namespace Etna.Design.SigningEscrow
open ProtocolState

/-- Every retained confirmation either comes from the input bond with a nonincreased exit,
or is a confirmation made now against actual slot 284. Covers all decoded edit variants. -/
theorem edit_confirmation_origin {r : RegistryHistory.State} {inbox : State}
    {now c : Nat} {b out : Staking.Bond} {action : RegistryHistory.Edit}
    (ok : RegistryHistory.editBond r inbox now b action = some out)
    (confirmed : out.confirmedAt = some c) :
    (b.confirmedAt = some c ∧ out.exitAt ≤ b.exitAt) ∨
      (c = now ∧ out.exitAt ≤ inbox.snapshot) := by
  cases action with
  | requestExit caller =>
    simp only [RegistryHistory.editBond,Staking.requestExit] at ok
    split at ok
    · rename_i guard
      cases ok
      exact Or.inl ⟨confirmed,by dsimp only; omega⟩
    · contradiction
  | confirm =>
    simp only [RegistryHistory.editBond,Staking.confirmExit] at ok
    split at ok
    · rename_i guard
      cases old : b.confirmedAt with
      | none =>
        simp only [old,Option.some.injEq] at ok
        subst out
        exact Or.inr ⟨by simpa using confirmed.symm,guard.2.2.2.2⟩
      | some atL1 =>
        simp only [old,Option.some.injEq] at ok
        subst out
        exact Or.inl ⟨by simpa [old] using confirmed,Nat.le_refl _⟩
    · contradiction
  | withdraw caller =>
    cases old : b.confirmedAt with
    | none => simp [RegistryHistory.editBond,Staking.withdraw,old] at ok
    | some atL1 =>
      simp only [RegistryHistory.editBond,Staking.withdraw,old] at ok
      split at ok
      · simp only [Option.map_some,Option.some.injEq] at ok
        subst out
        contradiction
      · contradiction
  | topUp caller amount =>
    simp only [RegistryHistory.editBond,Staking.topUp] at ok
    split at ok
    · cases ok; exact Or.inl ⟨confirmed,Nat.le_refl _⟩
    · contradiction
  | activateTopUp =>
    simp only [RegistryHistory.editBond,Staking.activateTopUp] at ok
    split at ok
    · cases ok; exact Or.inl ⟨confirmed,Nat.le_refl _⟩
    · contradiction
  | forfeit key incident validUntil timestamp owner externalOK =>
    simp only [RegistryHistory.editBond,Staking.forfeit] at ok
    split at ok
    · simp only [Option.map_some,Option.some.injEq] at ok
      subst out
      exact Or.inl ⟨confirmed,Nat.min_le_left _ _⟩
    · contradiction
  | slash a b sigA sigB =>
    simp only [RegistryHistory.editBond] at ok
    split at ok
    · unfold Staking.slashDouble at ok
      split at ok
      · simp only [Option.map_some,Option.some.injEq] at ok
        subst out
        exact Or.inl ⟨confirmed,Nat.min_le_left _ _⟩
      · contradiction
    · contradiction
  | forceExit =>
    simp only [RegistryHistory.editBond] at ok
    split at ok
    · cases ok; exact Or.inl ⟨confirmed,Nat.min_le_left _ _⟩
    · contradiction
  | recheck snapshot =>
    simp only [RegistryHistory.editBond,Option.some.injEq] at ok
    subst out
    unfold Staking.rollbackBySnapshot at confirmed ⊢
    cases old : b.confirmedAt <;> simp only [old] at confirmed ⊢
    · contradiction
    · split at confirmed
      · contradiction
      · rename_i guard
        simp only [ite_eq_right guard]
        exact Or.inl ⟨by simpa [old] using confirmed,Nat.le_refl _⟩

/-- Rollback never creates or backdates a confirmation. -/
theorem recheck_confirmation_origin (b : Staking.Bond) (snapshot c : Nat)
    (confirmed : (Staking.rollbackBySnapshot snapshot b).confirmedAt = some c) :
    b.confirmedAt = some c := by
  unfold Staking.rollbackBySnapshot at confirmed
  split at confirmed
  · split at confirmed
    · contradiction
    · exact confirmed
  · exact confirmed

private theorem registry_register_clock {r t : RegistryHistory.State} {key owner amount now : Nat}
    (ok : RegistryHistory.register r key owner amount now = some t)
    (before : ∀ id c, (r.slots id).confirmedAt = some c → c ≤ now) :
    ∀ id c, (t.slots id).confirmedAt = some c → c ≤ now := by
  unfold RegistryHistory.register at ok
  split at ok
  · cases ok
    intro id c confirmed
    change (if id = (RegistryHistory.allocation r).1 then
      (⟨key,owner,amount,now+r.activationDelay,Staking.noExit,false,none,0,0⟩ : Staking.Bond)
      else r.slots id).confirmedAt = some c at confirmed
    by_cases same : id = (RegistryHistory.allocation r).1
    · simp [same] at confirmed
    · exact before id c (by simpa [same] using confirmed)
  · contradiction

/-- No lifecycle/registry/recovery/rollback interleaving can manufacture a future clock. -/
theorem step_clocked {w t : World} (change : Step w t) (before : Clocked w) : Clocked t := by
  have time := step_clock_monotone change
  cases change with
  | landing => exact fun id c h => Nat.le_trans (before id c h) time
  | registration _ ok => exact registry_register_clock ok (fun id c h => Nat.le_trans (before id c h) time)
  | @modification s id now action _ _ ok =>
    obtain ⟨_,_,bond,changed,rfl⟩ := RegistryHistory.edit_success ok
    intro query c confirmed
    by_cases same : query = id
    · subst query
      have present : bond.confirmedAt = some c := by
        simpa [registered,RegistryHistory.finish,RegistryHistory.writeSlot] using confirmed
      rcases edit_confirmation_origin changed present with old | fresh
      · exact Nat.le_trans (before _ c old.1) time
      · change c ≤ now
        omega
    · exact Nat.le_trans (before query c (by
        simpa [registered,RegistryHistory.finish,RegistryHistory.writeSlot,same] using confirmed)) time
  | enqueue => exact fun id c h => Nat.le_trans (before id c h) time
  | sweep => exact fun id c h => Nat.le_trans (before id c h) time
  | recovery =>
    intro id c confirmed
    simp only [recovered,RegistryHistory.forceExclusions,RegistryHistory.finish] at confirmed
    split at confirmed
    · exact Nat.le_trans (before id c confirmed) time
    · exact Nat.le_trans (before id c confirmed) time
  | invalidation => exact fun id c h => Nat.le_trans (before id c h) time
  | rollback =>
    intro id c confirmed
    exact Nat.le_trans (before id c (recheck_confirmation_origin _ _ c confirmed)) time

/-- Arbitrary original protocol traces, with every Step constructor included. -/
theorem trace_clocked {w t : World} (trace : Trace w t) (before : Clocked w) : Clocked t := by
  induction trace with
  | refl => exact before
  | step _ change ih => exact step_clocked change ih

/-- A stronger transport lemma for provenance bounds; only a fresh confirmation may
introduce the present L1 block. Registration/reuse and withdrawal introduce no clock. -/
theorem step_confirmation_predicate {w t : World} {P : Nat → Prop}
    (change : Step w t)
    (before : ∀ id c, (w.registry.slots id).confirmedAt = some c → P c)
    (fresh : P t.l1Block) : ∀ id c, (t.registry.slots id).confirmedAt = some c → P c := by
  cases change with
  | landing => exact before
  | @registration s key owner amount now _ ok =>
    unfold RegistryHistory.register at ok
    split at ok
    · cases ok
      intro id c confirmed
      change (if id = (RegistryHistory.allocation w.registry).1 then (⟨key,owner,amount,now+w.registry.activationDelay,Staking.noExit,false,none,0,0⟩ : Staking.Bond) else w.registry.slots id).confirmedAt = some c at confirmed
      split at confirmed
      · contradiction
      · exact before id c confirmed
    · contradiction
  | @modification s id now action _ _ ok =>
    obtain ⟨_,_,bond,changed,rfl⟩ := RegistryHistory.edit_success ok
    intro query c confirmed
    by_cases same : query = id
    · subst query
      have present : bond.confirmedAt = some c := by
        simpa [registered,RegistryHistory.finish,RegistryHistory.writeSlot] using confirmed
      rcases edit_confirmation_origin changed present with old | new
      · exact before id c old.1
      · rw [new.1]
        exact fresh
    · exact before query c (by
        simpa [registered,RegistryHistory.finish,RegistryHistory.writeSlot,same] using confirmed)
  | enqueue => exact before
  | sweep => exact before
  | recovery =>
    intro id c confirmed
    simp only [recovered,RegistryHistory.forceExclusions,RegistryHistory.finish] at confirmed
    split at confirmed <;> exact before id c confirmed
  | invalidation => exact before
  | rollback => exact fun id c confirmed => before id c (recheck_confirmation_origin _ _ c confirmed)

/-- No confirmation in an initially unconfirmed deployment can predate that deployment,
including after clearing/reconfirmation or release/re-registration. -/
theorem trace_confirmation_lower_bound {w t : World} (trace : Trace w t)
    (initial : ∀ id, (w.registry.slots id).confirmedAt = none) :
    ∀ id c, (t.registry.slots id).confirmedAt = some c → w.l1Block ≤ c := by
  induction trace with
  | refl => intro id c present; rw [initial id] at present; contradiction
  | step prior change ih =>
    exact step_confirmation_predicate change ih (trace_clock_monotone (.step prior change))

/-- The exceptional rollback rechecks every confirmation even without a trusted snapshot. -/
theorem rollback_covered (w : World) (cp : Checkpoint) (snapshot now : Nat) :
    Covered (applyRollback w cp snapshot now) := by
  intro id c confirmed
  have result := Staking.rollbackBySnapshot_keeps_only_covered snapshot c (w.registry.slots id) confirmed
  change (Staking.rollbackBySnapshot snapshot (w.registry.slots id)).exitAt ≤ snapshot
  unfold Staking.rollbackBySnapshot
  split
  · split <;> exact result
  · exact result

/-- Coverage transport needs only snapshot growth for nonrollback edges, not a live-stake
hypothesis. Verifier rollback establishes coverage independently by its exact recheck. -/
theorem step_covered {w t : World} (change : Step w t) (update : SnapshotUpdate w t)
    (before : Covered w) : Covered t := by
  rcases update with growth | ⟨cp,snapshot,now,rfl⟩
  · cases change with
    | landing => exact fun id c h => Nat.le_trans (before id c h) growth
    | @registration s key owner amount now _ ok =>
      unfold RegistryHistory.register at ok
      split at ok
      · cases ok
        intro id c confirmed
        change (if id = (RegistryHistory.allocation w.registry).1 then (⟨key,owner,amount,now+w.registry.activationDelay,Staking.noExit,false,none,0,0⟩ : Staking.Bond) else w.registry.slots id).confirmedAt = some c at confirmed
        split at confirmed
        · contradiction
        · rename_i different
          have bound := before id c confirmed
          change (if id = (RegistryHistory.allocation w.registry).1 then
            (⟨key,owner,amount,now+w.registry.activationDelay,Staking.noExit,false,none,0,0⟩ : Staking.Bond)
            else w.registry.slots id).exitAt ≤ w.inbox.snapshot
          rw [ite_eq_right different]
          exact bound
      · contradiction
    | @modification s id now action _ _ ok =>
      obtain ⟨_,_,bond,changed,rfl⟩ := RegistryHistory.edit_success ok
      intro query c confirmed
      by_cases same : query = id
      · subst query
        have present : bond.confirmedAt = some c := by
          simpa [registered,RegistryHistory.finish,RegistryHistory.writeSlot] using confirmed
        have goal : bond.exitAt ≤ w.inbox.snapshot := by
          rcases edit_confirmation_origin changed present with old | new
          · exact Nat.le_trans old.2 (before id c old.1)
          · exact new.2
        simpa [registered,RegistryHistory.finish,RegistryHistory.writeSlot] using goal
      · simpa [registered,RegistryHistory.finish,RegistryHistory.writeSlot,same] using
          before query c (by simpa [registered,RegistryHistory.finish,RegistryHistory.writeSlot,same] using confirmed)
    | enqueue => exact fun id c h => Nat.le_trans (before id c h) growth
    | sweep => exact fun id c h => Nat.le_trans (before id c h) growth
    | @recovery s a r owner externalOK _ ok =>
      have snapshot : s.inbox.snapshot = w.inbox.snapshot :=
        (Recovery.recovery_preserves_settled_prefix ok).2.2.2.2.2.1
      intro id c confirmed
      simp only [recovered,RegistryHistory.forceExclusions,RegistryHistory.finish] at confirmed ⊢
      rw [snapshot]
      by_cases applies : Recovery.exclusionApplies a.exclusions id (w.registry.slots id).key = true
      · simp only [applies,ite_true,Staking.exclude] at confirmed ⊢
        exact Nat.le_trans (Nat.min_le_left _ _) (before id c confirmed)
      · simp only [applies] at confirmed ⊢
        exact before id c confirmed
    | invalidation => exact fun id c h => Nat.le_trans (before id c h) growth
    | rollback => exact rollback_covered _ _ _ _
  · exact rollback_covered _ _ _ _

/-- Projection: the snapshot refinement changes none of the underlying operations. -/
theorem snapshot_trace_projects {w t : World} (trace : SnapshotTrace w t) : Trace w t := by
  induction trace with
  | refl => exact .refl _
  | step _ change _ ih => exact .step ih change

/-- Full trajectory coverage under the explicit, escrow-independent snapshot condition. -/
theorem trace_covered {w t : World} (trace : SnapshotTrace w t) (before : Covered w) : Covered t := by
  induction trace with
  | refl => exact before
  | step _ change snapshots ih => exact step_covered change snapshots ih

/-- Every successful payout has a real recorded confirmation and the full fixed registry
delay; with trajectory coverage its exit is excluded by the current stored snapshot. -/
theorem withdrawal_window {w : World} {id caller now : Nat} {out : Staking.Bond} {amount : Nat}
    (covered : Covered w)
    (ok : Staking.withdraw w.inbox (w.registry.slots id) caller now w.registry.withdrawalDelay = some (out,amount)) :
    ∃ c, (w.registry.slots id).confirmedAt = some c ∧
      c+w.registry.withdrawalDelay ≤ now ∧ (w.registry.slots id).exitAt ≤ w.inbox.snapshot ∧
      amount = (w.registry.slots id).balance ∧ out.balance = 0 := by
  obtain ⟨c,present,delay,payout,_,_,_⟩ := Staking.withdraw_waits_for_confirmation ok
  exact ⟨c,present,delay,covered id c present,payout,(Staking.withdrawal_clears_principal ok).2.1⟩

/-- A halt before coverage cannot pre-consume the evidence clock: no unconfirmed entry
can be withdrawn at any block, however much L1 time has passed. -/
theorem unconfirmed_never_withdraws (s : State) (b : Staking.Bond) (caller now delay : Nat)
    (absent : b.confirmedAt = none) : Staking.withdraw s b caller now delay = none := by
  simp [Staking.withdraw,absent]

/-- Except for clearing a withdrawn entry to key zero, an edit keeps identity and
can only move its exit earlier. No live-bond premise is needed. -/
theorem edit_key_exit {r : RegistryHistory.State} {inbox : State} {now key : Nat}
    {b out : Staking.Bond} {action : RegistryHistory.Edit}
    (nonzero : key ≠ 0) (ok : RegistryHistory.editBond r inbox now b action = some out)
    (identity : out.key = key) : b.key = key ∧ out.exitAt ≤ b.exitAt := by
  cases action with
  | requestExit caller =>
    simp only [RegistryHistory.editBond,Staking.requestExit] at ok
    split at ok
    · rename_i guard
      cases ok
      exact ⟨identity,by dsimp only; omega⟩
    · contradiction
  | confirm =>
    simp only [RegistryHistory.editBond,Staking.confirmExit] at ok
    split at ok
    · cases old : b.confirmedAt <;> simp only [old,Option.some.injEq] at ok <;>
        subst out <;> exact ⟨identity,Nat.le_refl _⟩
    · contradiction
  | withdraw caller =>
    cases old : b.confirmedAt with
    | none => simp [RegistryHistory.editBond,Staking.withdraw,old] at ok
    | some atL1 =>
      simp only [RegistryHistory.editBond,Staking.withdraw,old] at ok
      split at ok
      · simp only [Option.map_some,Option.some.injEq] at ok
        subst out
        exact False.elim (nonzero identity.symm)
      · contradiction
  | topUp caller amount =>
    simp only [RegistryHistory.editBond,Staking.topUp] at ok
    split at ok
    · cases ok; exact ⟨identity,Nat.le_refl _⟩
    · contradiction
  | activateTopUp =>
    simp only [RegistryHistory.editBond,Staking.activateTopUp] at ok
    split at ok
    · cases ok; exact ⟨identity,Nat.le_refl _⟩
    · contradiction
  | forfeit key incident validUntil timestamp owner externalOK =>
    simp only [RegistryHistory.editBond,Staking.forfeit] at ok
    split at ok
    · simp only [Option.map_some,Option.some.injEq] at ok
      subst out
      exact ⟨identity,Nat.min_le_left _ _⟩
    · contradiction
  | slash a b sigA sigB =>
    simp only [RegistryHistory.editBond] at ok
    split at ok
    · unfold Staking.slashDouble at ok
      split at ok
      · simp only [Option.map_some,Option.some.injEq] at ok
        subst out
        exact ⟨identity,Nat.min_le_left _ _⟩
      · contradiction
    · contradiction
  | forceExit =>
    simp only [RegistryHistory.editBond] at ok
    split at ok
    · cases ok; exact ⟨identity,Nat.min_le_left _ _⟩
    · contradiction
  | recheck snapshot =>
    simp only [RegistryHistory.editBond,Option.some.injEq] at ok
    subst out
    cases old : b.confirmedAt with
    | none => simpa [Staking.rollbackBySnapshot,old] using And.intro identity (Nat.le_refl b.exitAt)
    | some atL1 =>
      by_cases covered : snapshot < b.exitAt <;>
        simpa [Staking.rollbackBySnapshot,old,covered] using And.intro identity (Nat.le_refl b.exitAt)

private theorem recheck_exit_key (b : Staking.Bond) (snapshot : Nat) :
    (Staking.rollbackBySnapshot snapshot b).key = b.key ∧
    (Staking.rollbackBySnapshot snapshot b).exitAt = b.exitAt := by
  unfold Staking.rollbackBySnapshot
  split <;> (try split) <;> exact ⟨rfl,rfl⟩

private theorem register_excluded {r t : RegistryHistory.State} {key cutoff fresh owner amount now : Nat}
    (used : key ∈ r.usedKeys) (excluded : Excluded key cutoff r)
    (ok : RegistryHistory.register r fresh owner amount now = some t) : Excluded key cutoff t := by
  have different : fresh ≠ key := by
    intro same
    have absent := (RegistryHistory.registered_identity ok).1
    exact absent (same ▸ used)
  unfold RegistryHistory.register at ok
  split at ok
  · cases ok
    intro id bound identity
    change id < (RegistryHistory.allocation r).2.2 at bound
    by_cases same : id = (RegistryHistory.allocation r).1
    · have found : fresh = key := by
        change (if id = (RegistryHistory.allocation r).1 then _ else r.slots id).key = key at identity
        simpa [same] using identity
      exact False.elim (different found)
    · have old := (RegistryHistory.allocation_covers_new_id r id bound).resolve_left same
      have found : (r.slots id).key = key := by
        change (if id = (RegistryHistory.allocation r).1 then _ else r.slots id).key = key at identity
        simpa [same] using identity
      change (if id = (RegistryHistory.allocation r).1 then _ else r.slots id).exitAt ≤ cutoff
      rw [ite_eq_right same]
      exact excluded id old found
  · contradiction

/-- Once a lifetime key is excluded at a bound, no operation can resurrect it, including
withdrawal/reuse, top-ups, recovery exclusions and verifier rollback. -/
theorem step_excluded {w t : World} {key cutoff : Nat} (change : Step w t)
    (nonzero : key ≠ 0) (used : key ∈ w.registry.usedKeys)
    (excluded : Excluded key cutoff w.registry) : Excluded key cutoff t.registry := by
  cases change with
  | landing => exact excluded
  | registration _ ok => exact register_excluded used excluded ok
  | @modification s id now action _ _ ok =>
    obtain ⟨_,_,bond,changed,rfl⟩ := RegistryHistory.edit_success ok
    intro query bound identity
    by_cases same : query = id
    · subst query
      have found : bond.key = key := by simpa [registered,RegistryHistory.finish,RegistryHistory.writeSlot] using identity
      have effects := edit_key_exit nonzero changed found
      have old := excluded id bound effects.1
      simpa [registered,RegistryHistory.finish,RegistryHistory.writeSlot] using Nat.le_trans effects.2 old
    · have found : (w.registry.slots query).key = key := by
        simpa [registered,RegistryHistory.finish,RegistryHistory.writeSlot,same] using identity
      simpa [registered,RegistryHistory.finish,RegistryHistory.writeSlot,same] using excluded query bound found
  | enqueue => exact excluded
  | sweep => exact excluded
  | @recovery s a r owner externalOK _ _ =>
    intro id bound identity
    change id < w.registry.nextId at bound
    change (if Recovery.exclusionApplies a.exclusions id (w.registry.slots id).key then
      Staking.exclude (w.registry.slots id) r.l1Block else w.registry.slots id).key = key at identity
    change (if Recovery.exclusionApplies a.exclusions id (w.registry.slots id).key then
      Staking.exclude (w.registry.slots id) r.l1Block else w.registry.slots id).exitAt ≤ cutoff
    by_cases applies : Recovery.exclusionApplies a.exclusions id (w.registry.slots id).key = true
    · simp only [applies,ite_true,Staking.exclude] at identity ⊢
      exact Nat.le_trans (Nat.min_le_left _ _) (excluded id bound identity)
    · simp only [applies] at identity ⊢
      exact excluded id bound identity
  | invalidation => exact excluded
  | rollback cp snapshot now =>
    intro id bound identity
    have effects := recheck_exit_key (w.registry.slots id) snapshot
    change (Staking.rollbackBySnapshot snapshot (w.registry.slots id)).key = key at identity
    change (Staking.rollbackBySnapshot snapshot (w.registry.slots id)).exitAt ≤ cutoff
    rw [effects.2]
    exact excluded id bound (effects.1 ▸ identity)

/-- A temporal lifetime result over every original protocol trace. -/
theorem trace_excluded {w t : World} {key cutoff : Nat} (trace : Trace w t)
    (nonzero : key ≠ 0) (used : key ∈ w.registry.usedKeys)
    (excluded : Excluded key cutoff w.registry) : Excluded key cutoff t.registry := by
  induction trace with
  | refl => exact excluded
  | step prior change ih => exact step_excluded change nonzero (trace_keeps_used_keys prior key used) ih


private theorem entries_excluded {key floor : Nat} {r : RegistryHistory.State}
    (excluded : Excluded key floor r) {e : Committee.Entry} (member : e ∈ RegistryHistory.entries r)
    (identity : e.key = key) : e.exitAt ≤ floor := by
  obtain ⟨id,range,rfl⟩ := List.mem_map.mp member
  exact excluded id (List.mem_range.mp range) identity

private theorem record_lookup_due (history : List RegistryHistory.Snapshot) (now cutoff : Nat)
    (entries : List Committee.Entry) (due : now ≤ cutoff) :
    RegistryHistory.latestSnapshot (RegistryHistory.recordSnapshot now entries history) cutoff =
      some ⟨now,entries⟩ := by
  cases history with
  | nil => simp [RegistryHistory.recordSnapshot,RegistryHistory.latestSnapshot,due]
  | cons cp rest =>
    by_cases same : cp.block = now <;>
      simp [RegistryHistory.recordSnapshot,RegistryHistory.latestSnapshot,same,due]

/-- Current snapshot consistency connects a state-level exclusion to every lookup whose
cutoff is at or beyond that state's clock. Earlier cutoffs retain their historical meaning. -/
theorem history_excluded_of_current {r : RegistryHistory.State} {key floor : Nat}
    (excluded : Excluded key floor r) (current : RegistryHistory.CurrentSnapshot r)
    (clock : RegistryHistory.lastBlock r ≤ floor) : HistoryExcluded key floor r := by
  intro cutoff afterFloor e member identity
  cases history : r.history with
  | nil => simp [HistoricalContext.registryAt,RegistryHistory.latestSnapshot,history] at member
  | cons cp rest =>
    have entries : cp.entries = RegistryHistory.entries r := by
      simpa [RegistryHistory.CurrentSnapshot,history] using current
    have due : cp.block ≤ cutoff := by
      have prior : cp.block ≤ floor := by simpa [RegistryHistory.lastBlock,history] using clock
      omega
    have found : e ∈ RegistryHistory.entries r := by
      simpa [HistoricalContext.registryAt,RegistryHistory.latestSnapshot,history,due,entries] using member
    exact Nat.le_trans (entries_excluded excluded found identity) afterFloor

private theorem finish_history_excluded {before after : RegistryHistory.State} {key floor now : Nat}
    (old : HistoryExcluded key floor before) (excluded : Excluded key floor after) :
    HistoryExcluded key floor (RegistryHistory.finish before now after) := by
  intro cutoff afterFloor e member identity
  by_cases equal : RegistryHistory.entries after = RegistryHistory.entries before
  · exact old cutoff afterFloor e (by simpa [HistoricalContext.registryAt,RegistryHistory.finish,equal] using member) identity
  · by_cases due : now ≤ cutoff
    · have lookup := record_lookup_due before.history now cutoff (RegistryHistory.entries after) due
      have found : e ∈ RegistryHistory.entries after := by
        simpa [HistoricalContext.registryAt,RegistryHistory.finish,equal,lookup] using member
      exact Nat.le_trans (entries_excluded excluded found identity) afterFloor
    · have lookup := RegistryHistory.historical_cutoff_preserved before.history now cutoff
        (RegistryHistory.entries after) (by omega)
      exact old cutoff afterFloor e (by simpa [HistoricalContext.registryAt,RegistryHistory.finish,equal,lookup] using member) identity

/-- History exclusion is preserved through actual registry checkpoints, release/reuse,
recovery and rollback. Old snapshots remain accessible but cannot resurrect a key at a
later cutoff. This uses lifetime-key uniqueness and no present-escrow premise. -/
theorem step_history_excluded {w t : World} {key floor : Nat} (change : Step w t)
    (nonzero : key ≠ 0) (used : key ∈ w.registry.usedKeys)
    (excluded : Excluded key floor w.registry) (history : HistoryExcluded key floor w.registry) :
    HistoryExcluded key floor t.registry := by
  have nextExcluded := step_excluded change nonzero used excluded
  cases change with
  | landing => exact history
  | registration _ ok =>
    unfold RegistryHistory.register at ok
    split at ok
    · cases ok
      exact finish_history_excluded history nextExcluded
    · contradiction
  | modification _ _ ok =>
    obtain ⟨_,_,_,_,rfl⟩ := RegistryHistory.edit_success ok
    exact finish_history_excluded history nextExcluded
  | enqueue => exact history
  | sweep => exact history
  | recovery => exact finish_history_excluded history nextExcluded
  | invalidation => exact history
  | rollback => exact history

/-- Arbitrary original-machine interleavings, including slot reuse. -/
theorem trace_history_excluded {w t : World} {key floor : Nat} (trace : Trace w t)
    (nonzero : key ≠ 0) (used : key ∈ w.registry.usedKeys)
    (excluded : Excluded key floor w.registry) (history : HistoryExcluded key floor w.registry) :
    HistoryExcluded key floor t.registry := by
  induction trace with
  | refl => exact history
  | step prior change ih =>
    exact step_history_excluded change nonzero (trace_keeps_used_keys prior key used)
      (trace_excluded prior nonzero used excluded) ih

/-- A covered confirmation establishes a permanent historical exclusion barrier at the
current L1 block. The identity premise is lifetime-key uniqueness, not a bond/escrow premise.
`floor` is deliberately the confirmation state's clock; proving the smaller effective-exit
boundary would additionally need authenticated ordering of exit-setting history. -/
theorem confirmed_key_excluded_forever {w t : World} {id c key : Nat}
    (trace : Trace w t) (confirmed : (w.registry.slots id).confirmedAt = some c)
    (covered : Covered w) (below : w.inbox.snapshot ≤ w.l1Block)
    (_identity : (w.registry.slots id).key = key) (nonzero : key ≠ 0)
    (unique : ∀ other, other < w.registry.nextId → (w.registry.slots other).key = key → other = id)
    (used : key ∈ w.registry.usedKeys) (current : RegistryHistory.CurrentSnapshot w.registry)
    (clock : RegistryHistory.lastBlock w.registry ≤ w.l1Block) :
    HistoryExcluded key w.l1Block t.registry := by
  have excluded : Excluded key w.l1Block w.registry := by
    intro other range matching
    have same := unique other range matching
    subst other
    exact Nat.le_trans (covered id c confirmed) below
  exact trace_history_excluded trace nonzero used excluded (history_excluded_of_current excluded current clock)

/-- At a later authenticated selection cutoff, a confirmed lifetime key cannot return,
even if its old slot has been released and reused by an unrelated key. -/
theorem selected_excludes_confirmed_key {s : State} {registry : RegistryHistory.State}
    {cfg : HistoricalContext.Parameters} {archive : List Nat} {ctx : Consensus.Context}
    {key floor h : Nat} (built : HistoricalContext.build s registry cfg archive = some ctx)
    (history : HistoryExcluded key floor registry) (later : floor ≤ (Consensus.activeAt ctx h).cutoff) :
    ∀ e ∈ (Consensus.activeAt ctx h).members, e.key ≠ key := by
  intro e member identity
  have selected : e ∈ Committee.chosen ctx.unit ctx.minimum (Consensus.activeAt ctx h).cutoff ctx.nMax
      (ctx.registry (Consensus.activeAt ctx h).cutoff) := by
    have records : (Consensus.activeAt ctx h).members =
        Committee.chosen ctx.unit ctx.minimum (Consensus.activeAt ctx h).cutoff ctx.nMax
          (ctx.registry (Consensus.activeAt ctx h).cutoff) := by
      unfold Consensus.activeAt
      dsimp only
      split <;> rfl
    exact records ▸ member
  have eligible := Committee.chosen_eligible _ _ _ _ _ e selected
  have lookup : ctx.registry (Consensus.activeAt ctx h).cutoff =
      HistoricalContext.registryAt registry (Consensus.activeAt ctx h).cutoff := by
    rw [(HistoricalContext.build_success built).2]
    rfl
  have excluded := history _ later e (lookup ▸ eligible.1) identity
  omega


/-- Every successful signature preserves retirement; switching only adds retired domains,
and session opening preserves the entire list. -/
theorem signer_step_retirement {s t : Signer.State} (change : SignerStep s t) :
    ∀ generation ∈ s.retired, generation ∈ t.retired := by
  cases change with
  | sign ok =>
    unfold Signer.sign at ok
    split at ok
    · split at ok
      · split at ok
        · split at ok
          · cases ok; exact fun _ h => h
          · contradiction
        · split at ok
          · cases ok; exact fun _ h => h
          · contradiction
      · split at ok
        · cases ok; exact fun _ h => h
        · contradiction
    · contradiction
  | switch =>
    unfold Signer.switchDomain
    split
    · exact fun _ h => List.mem_cons_of_mem _ h
    · exact fun _ h => h
  | session => exact fun _ h => h

/-- Retirement survives arbitrary signing/session/recovery interleavings. This is the
signer's generation-domain guarantee; authenticating recovery/trust remains external. -/
theorem signer_trace_retirement {s t : Signer.State} (trace : SignerTrace s t) :
    ∀ generation ∈ s.retired, generation ∈ t.retired := by
  induction trace with
  | refl => exact fun _ h => h
  | step _ change ih => exact fun generation h => signer_step_retirement change generation (ih generation h)

/-- A retired full chain-id generation never signs again, however later sessions open. -/
theorem retired_generation_never_revives {s t : Signer.State} (trace : SignerTrace s t)
    (r : Signer.Request) (signature : Hash) (persisted : Bool)
    (retired : r.generation ∈ s.retired) : Signer.sign t r signature persisted = none :=
  Signer.retired_cannot_sign t r signature persisted (signer_trace_retirement trace r.generation retired)


/-- Empty registry has no allocated identity, hence no duplicate lifetime key. -/
theorem empty_keys_well_formed : KeysWellFormed RegistryHistory.empty := by
  constructor <;> intros <;> simp_all [RegistryHistory.empty]

private theorem keys_of_projection {r t : RegistryHistory.State}
    (before : KeysWellFormed r) (count : t.nextId = r.nextId)
    (projection : ∀ id, (t.slots id).key ≠ 0 → (t.slots id).key = (r.slots id).key)
    (used : ∀ key ∈ r.usedKeys, key ∈ t.usedKeys) : KeysWellFormed t := by
  constructor
  · intro id range nonzero
    have identity := projection id nonzero
    rw [identity]
    exact used _ (before.allocated id (count ▸ range) (identity ▸ nonzero))
  · intro key nonzero i ri j rj ki kj
    have ni : (t.slots i).key ≠ 0 := ki ▸ nonzero
    have nj : (t.slots j).key ≠ 0 := kj ▸ nonzero
    exact before.unique key nonzero i (count ▸ ri) j (count ▸ rj)
      ((projection i ni).symm.trans ki) ((projection j nj).symm.trans kj)

private theorem register_keys_well_formed {r t : RegistryHistory.State} {fresh owner amount now : Nat}
    (before : KeysWellFormed r) (ok : RegistryHistory.register r fresh owner amount now = some t) :
    KeysWellFormed t := by
  have absent := (RegistryHistory.registered_identity ok).1
  unfold RegistryHistory.register at ok
  split at ok
  · cases ok
    have keyAt : ∀ id, (if id = (RegistryHistory.allocation r).1 then
        (⟨fresh,owner,amount,now+r.activationDelay,Staking.noExit,false,none,0,0⟩ : Staking.Bond)
        else r.slots id).key =
        if id = (RegistryHistory.allocation r).1 then fresh else (r.slots id).key := by
      intro id
      split <;> rfl
    constructor
    · intro id range nonzero
      change id < (RegistryHistory.allocation r).2.2 at range
      change (if id = (RegistryHistory.allocation r).1 then
        (⟨fresh,owner,amount,now+r.activationDelay,Staking.noExit,false,none,0,0⟩ : Staking.Bond)
        else r.slots id).key ≠ 0 at nonzero
      change (if id = (RegistryHistory.allocation r).1 then
        (⟨fresh,owner,amount,now+r.activationDelay,Staking.noExit,false,none,0,0⟩ : Staking.Bond)
        else r.slots id).key ∈ fresh :: r.usedKeys
      rw [keyAt] at nonzero ⊢
      change (if id = (RegistryHistory.allocation r).1 then fresh else (r.slots id).key) ∈ fresh :: r.usedKeys
      by_cases same : id = (RegistryHistory.allocation r).1
      · simp [same]
      · simp only [same,ite_false] at nonzero ⊢
        exact List.mem_cons_of_mem _ (before.allocated id
          ((RegistryHistory.allocation_covers_new_id r id range).resolve_left same) nonzero)
    · intro key nonzero i ri j rj ki kj
      change i < (RegistryHistory.allocation r).2.2 at ri
      change j < (RegistryHistory.allocation r).2.2 at rj
      change (if i = (RegistryHistory.allocation r).1 then
        (⟨fresh,owner,amount,now+r.activationDelay,Staking.noExit,false,none,0,0⟩ : Staking.Bond)
        else r.slots i).key = key at ki
      change (if j = (RegistryHistory.allocation r).1 then
        (⟨fresh,owner,amount,now+r.activationDelay,Staking.noExit,false,none,0,0⟩ : Staking.Bond)
        else r.slots j).key = key at kj
      rw [keyAt] at ki kj
      by_cases si : i = (RegistryHistory.allocation r).1
      · by_cases sj : j = (RegistryHistory.allocation r).1
        · exact si.trans sj.symm
        · have freshKey : fresh = key := by simpa [si] using ki
          have oldKey : (r.slots j).key = key := by simpa [sj] using kj
          have oldUsed := before.allocated j
            ((RegistryHistory.allocation_covers_new_id r j rj).resolve_left sj) (oldKey ▸ nonzero)
          exact False.elim (absent (freshKey ▸ oldKey ▸ oldUsed))
      · by_cases sj : j = (RegistryHistory.allocation r).1
        · have freshKey : fresh = key := by simpa [sj] using kj
          have oldKey : (r.slots i).key = key := by simpa [si] using ki
          have oldUsed := before.allocated i
            ((RegistryHistory.allocation_covers_new_id r i ri).resolve_left si) (oldKey ▸ nonzero)
          exact False.elim (absent (freshKey ▸ oldKey ▸ oldUsed))
        · exact before.unique key nonzero i
            ((RegistryHistory.allocation_covers_new_id r i ri).resolve_left si) j
            ((RegistryHistory.allocation_covers_new_id r j rj).resolve_left sj)
            (by simpa [si] using ki) (by simpa [sj] using kj)
  · contradiction

/-- Allocated nonzero keys are globally lifetime-unique in every original machine step. -/
theorem step_keys_well_formed {w t : World} (change : Step w t)
    (before : KeysWellFormed w.registry) : KeysWellFormed t.registry := by
  have used := step_keeps_used_keys change
  cases change with
  | landing => exact before
  | registration _ ok => exact register_keys_well_formed before ok
  | @modification s id now action _ _ ok =>
    obtain ⟨_,_,bond,changed,rfl⟩ := RegistryHistory.edit_success ok
    refine keys_of_projection before ?_ ?_ used
    · rfl
    intro query nonzero
    by_cases same : query = id
    · subst query
      have nz : bond.key ≠ 0 := by simpa [registered,RegistryHistory.finish,RegistryHistory.writeSlot] using nonzero
      have found := (edit_key_exit nz changed rfl).1
      simpa [registered,RegistryHistory.finish,RegistryHistory.writeSlot] using found.symm
    · simp [registered,RegistryHistory.finish,RegistryHistory.writeSlot,same]
  | enqueue => exact before
  | sweep => exact before
  | @recovery s a r owner externalOK _ _ =>
    refine keys_of_projection before ?_ ?_ used
    · rfl
    intro id _
    change (if Recovery.exclusionApplies a.exclusions id (w.registry.slots id).key then
      Staking.exclude (w.registry.slots id) r.l1Block else w.registry.slots id).key = (w.registry.slots id).key
    split <;> rfl
  | invalidation => exact before
  | rollback cp snapshot now =>
    exact keys_of_projection before rfl (fun id _ => (recheck_exit_key (w.registry.slots id) snapshot).1) used

/-- Lifetime uniqueness is derived from empty registration/lifecycle, not assumed by Core. -/
theorem trace_keys_well_formed {w t : World} (trace : Trace w t)
    (before : KeysWellFormed w.registry) : KeysWellFormed t.registry := by
  induction trace with
  | refl => exact before
  | step _ change ih => exact step_keys_well_formed change ih

theorem empty_trace_keys_well_formed {w t : World} (trace : Trace w t)
    (empty : w.registry = RegistryHistory.empty) : KeysWellFormed t.registry :=
  trace_keys_well_formed trace (empty ▸ empty_keys_well_formed)

/-- Empty-start corollary: confirmation plus the authenticated clock/snapshot boundary
permanently removes the lifetime key from later-cutoff historical elections. Its slot need
not remain live or keep that key after confirmation. -/
theorem empty_start_confirmed_exclusion {initial w t : World} {id c : Nat}
    (prior : Trace initial w) (empty : initial.registry = RegistryHistory.empty)
    (suffix : Trace w t) (range : id < w.registry.nextId)
    (confirmed : (w.registry.slots id).confirmedAt = some c)
    (nonzero : (w.registry.slots id).key ≠ 0) (covered : Covered w)
    (below : w.inbox.snapshot ≤ w.l1Block) (current : RegistryHistory.CurrentSnapshot w.registry)
    (clock : RegistryHistory.lastBlock w.registry ≤ w.l1Block) :
    HistoryExcluded (w.registry.slots id).key w.l1Block t.registry := by
  have keys := empty_trace_keys_well_formed prior empty
  apply confirmed_key_excluded_forever suffix confirmed covered below rfl nonzero
  · intro other bound matching
    exact keys.unique _ nonzero other bound id range matching rfl
  · exact keys.allocated id range nonzero
  · exact current
  · exact clock


/-- Any newly changed nonzero occupant exit is written no earlier than the editing
transaction: a requested exit is delayed; forced reductions use exactly now or retain old. -/
theorem edit_exit_time {r : RegistryHistory.State} {inbox : State} {now : Nat}
    {b out : Staking.Bond} {action : RegistryHistory.Edit}
    (ok : RegistryHistory.editBond r inbox now b action = some out) (nonzero : out.key ≠ 0) :
    out.exitAt = b.exitAt ∨ now ≤ out.exitAt := by
  cases action with
  | requestExit caller =>
    simp only [RegistryHistory.editBond,Staking.requestExit] at ok
    split at ok
    · cases ok
      right
      change now ≤ max (now+r.exitDelay) (b.activeFrom+r.exitDelay)
      omega
    · contradiction
  | confirm =>
    simp only [RegistryHistory.editBond,Staking.confirmExit] at ok
    split at ok
    · cases old : b.confirmedAt <;> simp only [old,Option.some.injEq] at ok <;> subst out <;> exact Or.inl rfl
    · contradiction
  | withdraw caller =>
    cases old : b.confirmedAt with
    | none => simp [RegistryHistory.editBond,Staking.withdraw,old] at ok
    | some atL1 =>
      simp only [RegistryHistory.editBond,Staking.withdraw,old] at ok
      split at ok
      · simp only [Option.map_some,Option.some.injEq] at ok
        subst out
        exact False.elim (nonzero rfl)
      · contradiction
  | topUp caller amount =>
    simp only [RegistryHistory.editBond,Staking.topUp] at ok
    split at ok
    · cases ok; exact Or.inl rfl
    · contradiction
  | activateTopUp =>
    simp only [RegistryHistory.editBond,Staking.activateTopUp] at ok
    split at ok
    · cases ok; exact Or.inl rfl
    · contradiction
  | forfeit key incident validUntil timestamp owner externalOK =>
    simp only [RegistryHistory.editBond,Staking.forfeit] at ok
    split at ok
    · simp only [Option.map_some,Option.some.injEq] at ok
      subst out
      change min b.exitAt now = b.exitAt ∨ now ≤ min b.exitAt now
      omega
    · contradiction
  | slash a b sigA sigB =>
    simp only [RegistryHistory.editBond] at ok
    split at ok
    · unfold Staking.slashDouble at ok
      split at ok
      · simp only [Option.map_some,Option.some.injEq] at ok
        subst out
        change min _ now = _ ∨ now ≤ min _ now
        omega
      · contradiction
    · contradiction
  | forceExit =>
    simp only [RegistryHistory.editBond] at ok
    split at ok
    · cases ok
      change min b.exitAt now = b.exitAt ∨ now ≤ min b.exitAt now
      omega
    · contradiction
  | recheck snapshot =>
    simp only [RegistryHistory.editBond,Option.some.injEq] at ok
    subst out
    exact Or.inl (recheck_exit_key b snapshot).2

/-- A finite nonzero post-slot either keeps the old identity/exit, or its new exit is
at or beyond this step's L1 clock. Fresh registration never has a finite exit. -/
theorem step_exit_link {w t : World} (change : Step w t) (id : Nat)
    (range : id < t.registry.nextId) (nonzero : (t.registry.slots id).key ≠ 0)
    (finite : (t.registry.slots id).exitAt ≠ Staking.noExit) :
    (id < w.registry.nextId ∧ (t.registry.slots id).key = (w.registry.slots id).key ∧
      (t.registry.slots id).exitAt = (w.registry.slots id).exitAt) ∨
      t.l1Block ≤ (t.registry.slots id).exitAt := by
  cases change with
  | landing => exact Or.inl ⟨range,rfl,rfl⟩
  | registration _ ok =>
    unfold RegistryHistory.register at ok
    split at ok
    · cases ok
      change id < (RegistryHistory.allocation w.registry).2.2 at range
      change (if id = (RegistryHistory.allocation w.registry).1 then _ else w.registry.slots id).exitAt ≠ Staking.noExit at finite
      by_cases same : id = (RegistryHistory.allocation w.registry).1
      · simp [same] at finite
      · left
        refine ⟨(RegistryHistory.allocation_covers_new_id _ _ range).resolve_left same,?_,?_⟩
        · change (if id = (RegistryHistory.allocation w.registry).1 then _ else w.registry.slots id).key = _
          rw [ite_eq_right same]
        · change (if id = (RegistryHistory.allocation w.registry).1 then _ else w.registry.slots id).exitAt = _
          rw [ite_eq_right same]
    · contradiction
  | @modification s target now action _ _ ok =>
    obtain ⟨_,_,bond,changed,rfl⟩ := RegistryHistory.edit_success ok
    by_cases same : id = target
    · subst id
      have nz : bond.key ≠ 0 := by simpa [registered,RegistryHistory.finish,RegistryHistory.writeSlot] using nonzero
      have identity := (edit_key_exit nz changed rfl).1
      rcases edit_exit_time changed nz with unchanged | current
      · left
        exact ⟨range,by simpa [registered,RegistryHistory.finish,RegistryHistory.writeSlot] using identity.symm,
          by simpa [registered,RegistryHistory.finish,RegistryHistory.writeSlot] using unchanged⟩
      · right
        simpa [registered,RegistryHistory.finish,RegistryHistory.writeSlot] using current
    · left
      refine ⟨range,?_,?_⟩ <;> simp [registered,RegistryHistory.finish,RegistryHistory.writeSlot,same]
  | enqueue => exact Or.inl ⟨range,rfl,rfl⟩
  | sweep => exact Or.inl ⟨range,rfl,rfl⟩
  | @recovery s a r owner externalOK _ _ =>
    change id < w.registry.nextId at range
    by_cases applies : Recovery.exclusionApplies a.exclusions id (w.registry.slots id).key = true
    · by_cases earlier : (w.registry.slots id).exitAt ≤ r.l1Block
      · left
        exact ⟨range,by simp [recovered,RegistryHistory.forceExclusions,RegistryHistory.finish,applies,Staking.exclude],
          by simpa [recovered,RegistryHistory.forceExclusions,RegistryHistory.finish,applies,Staking.exclude] using Nat.min_eq_left earlier⟩
      · right
        change r.l1Block ≤ (if Recovery.exclusionApplies a.exclusions id (w.registry.slots id).key then
          Staking.exclude (w.registry.slots id) r.l1Block else w.registry.slots id).exitAt
        simp only [applies,ite_true,Staking.exclude]
        omega
    · left
      refine ⟨range,?_,?_⟩ <;> simp [recovered,RegistryHistory.forceExclusions,RegistryHistory.finish,applies]
  | invalidation => exact Or.inl ⟨range,rfl,rfl⟩
  | rollback cp snapshot now => exact Or.inl ⟨range,(recheck_exit_key _ snapshot).1,(recheck_exit_key _ snapshot).2⟩

private theorem excluded_of_unique {r : RegistryHistory.State} {id : Nat}
    (keys : KeysWellFormed r) (range : id < r.nextId) (nonzero : (r.slots id).key ≠ 0) :
    Excluded (r.slots id).key (r.slots id).exitAt r := by
  intro other bound identity
  have same := keys.unique _ nonzero other bound id range identity rfl
  subst other
  exact Nat.le_refl _

/-- Exact effective-exit visibility, including cutoffs before confirmation: exit-setting
operations write no later than their new effective exit. Min reductions either preserve
an existing barrier or establish a new barrier at their own checkpoint. -/
theorem step_exit_visible {w t : World} (change : Step w t)
    (core : Core w) (keys : KeysWellFormed w.registry) (visible : ExitVisible w.registry) :
    ExitVisible t.registry := by
  have nextCore := step_preserves_core core change
  have nextKeys := step_keys_well_formed change keys
  intro id range nonzero finite
  rcases step_exit_link change id range nonzero finite with old | fresh
  · have oldNonzero : (w.registry.slots id).key ≠ 0 := old.2.1 ▸ nonzero
    have oldFinite : (w.registry.slots id).exitAt ≠ Staking.noExit := old.2.2 ▸ finite
    have oldHistory := visible id old.1 oldNonzero oldFinite
    have retained := step_history_excluded change oldNonzero (keys.allocated id old.1 oldNonzero)
      (excluded_of_unique keys old.1 oldNonzero) oldHistory
    simpa only [old.2.1,old.2.2] using retained
  · exact history_excluded_of_current (excluded_of_unique nextKeys range nonzero)
      nextCore.registry.current (Nat.le_trans nextCore.registry.clock fresh)

/-- No time shortcut: actual registry history authenticates exit visibility through all
original steps, including same-block replacement, recovery, slash, forfeiture and reuse. -/
theorem trace_exit_visible {w t : World} (trace : Trace w t) (core : Core w)
    (keys : KeysWellFormed w.registry) (visible : ExitVisible w.registry) : ExitVisible t.registry := by
  induction trace with
  | refl => exact visible
  | step prior change ih =>
    exact step_exit_visible change (trace_preserves_core core prior) (trace_keys_well_formed prior keys) ih

/-- Empty-start entry history satisfies the exact effective-exit boundary. -/
theorem empty_trace_exit_visible {w t : World} (trace : Trace w t) (core : Core w)
    (empty : w.registry = RegistryHistory.empty) : ExitVisible t.registry := by
  apply trace_exit_visible trace core (empty ▸ empty_keys_well_formed)
  intro id range
  simp [empty,RegistryHistory.empty] at range

/-- Tightened lifetime theorem: from an empty-start real trajectory, all future
historical selections exclude a finitely exited key at its effective exit E, even when
confirmation is arbitrarily later, and after its slot is released/reused. -/
theorem effective_exit_excluded_forever {initial w t : World} {id : Nat}
    (prior : Trace initial w) (core : Core initial) (empty : initial.registry = RegistryHistory.empty)
    (suffix : Trace w t) (range : id < w.registry.nextId)
    (nonzero : (w.registry.slots id).key ≠ 0) (finite : (w.registry.slots id).exitAt ≠ Staking.noExit) :
    HistoryExcluded (w.registry.slots id).key (w.registry.slots id).exitAt t.registry := by
  have keys := empty_trace_keys_well_formed prior empty
  have history := empty_trace_exit_visible prior core empty id range nonzero finite
  exact trace_history_excluded suffix nonzero (keys.allocated id range nonzero)
    (excluded_of_unique keys range nonzero) history


/-- Deployment may configure arbitrary immutable delays/adapters before registration;
zero allocated slots, rather than equality of every default registry field, is sufficient. -/
theorem unallocated_keys_well_formed (r : RegistryHistory.State) (empty : r.nextId = 0) : KeysWellFormed r := by
  constructor
  · intro id range; omega
  · intro key nonzero i range; omega

theorem unallocated_trace_keys_well_formed {w t : World} (trace : Trace w t)
    (empty : w.registry.nextId = 0) : KeysWellFormed t.registry :=
  trace_keys_well_formed trace (unallocated_keys_well_formed _ empty)

theorem unallocated_trace_exit_visible {w t : World} (trace : Trace w t) (core : Core w)
    (empty : w.registry.nextId = 0) : ExitVisible t.registry := by
  apply trace_exit_visible trace core (unallocated_keys_well_formed _ empty)
  intro id range
  omega

/-- Exact effective-exit exclusion from any configured zero-slot initial registry. -/
theorem unallocated_effective_exit_excluded_forever {initial w t : World} {id : Nat}
    (prior : Trace initial w) (core : Core initial) (empty : initial.registry.nextId = 0)
    (suffix : Trace w t) (range : id < w.registry.nextId)
    (nonzero : (w.registry.slots id).key ≠ 0) (finite : (w.registry.slots id).exitAt ≠ Staking.noExit) :
    HistoryExcluded (w.registry.slots id).key (w.registry.slots id).exitAt t.registry := by
  have keys := unallocated_trace_keys_well_formed prior empty
  have history := unallocated_trace_exit_visible prior core empty id range nonzero finite
  exact trace_history_excluded suffix nonzero (keys.allocated id range nonzero)
    (excluded_of_unique keys range nonzero) history

/-- The fresh-signing selection bridge, stated without hiding lockup in a premise:
authenticated actual signing history must make the selected cutoff at least slot 284.
Then a covered, finitely exited key cannot be authorized, throughout arbitrary later
lifecycle interleavings and after slot reuse. `Built` alone does not supply `cutoff`. -/
theorem confirmed_key_absent_later_cutoff {initial w t : World} {id c h : Nat}
    {cfg : HistoricalContext.Parameters} {archive : List Nat} {ctx : Consensus.Context}
    (prior : Trace initial w) (core : Core initial) (empty : initial.registry.nextId = 0)
    (suffix : Trace w t) (range : id < w.registry.nextId)
    (confirmed : (w.registry.slots id).confirmedAt = some c) (covered : Covered w)
    (nonzero : (w.registry.slots id).key ≠ 0) (finite : (w.registry.slots id).exitAt ≠ Staking.noExit)
    (built : HistoricalContext.build t.inbox t.registry cfg archive = some ctx)
    (cutoff : w.inbox.snapshot ≤ (Consensus.activeAt ctx h).cutoff) :
    ∀ e ∈ (Consensus.activeAt ctx h).members, e.key ≠ (w.registry.slots id).key := by
  have barrier := unallocated_effective_exit_excluded_forever prior core empty suffix range nonzero finite
  exact selected_excludes_confirmed_key built barrier (Nat.le_trans (covered id c confirmed) cutoff)

/-- Full delay remains necessary after arbitrary original trajectories, and an initially
unconfirmed deployment never releases an entry before its starting L1 block plus that delay. -/
theorem trace_withdrawal_lower_bound {w t : World} {id caller now amount : Nat} {out : Staking.Bond}
    (trace : Trace w t) (initial : ∀ i, (w.registry.slots i).confirmedAt = none)
    (ok : Staking.withdraw t.inbox (t.registry.slots id) caller now t.registry.withdrawalDelay = some (out,amount)) :
    w.l1Block+t.registry.withdrawalDelay ≤ now := by
  obtain ⟨c,present,delay,_,_,_,_⟩ := Staking.withdraw_waits_for_confirmation ok
  have lower := trace_confirmation_lower_bound trace initial id c present
  omega

/-- Combine the whole-trajectory clock invariant with the exact successful withdrawal
window. Snapshot coverage remains explicit; no collateral or signer conclusion is assumed. -/
theorem trace_withdrawal_window {w t : World} {id caller now amount : Nat} {out : Staking.Bond}
    (trace : Trace w t) (initial : Clocked w) (covered : Covered t)
    (ok : Staking.withdraw t.inbox (t.registry.slots id) caller now t.registry.withdrawalDelay = some (out,amount)) :
    ∃ c, (t.registry.slots id).confirmedAt = some c ∧ c ≤ t.l1Block ∧
      c+t.registry.withdrawalDelay ≤ now ∧ (t.registry.slots id).exitAt ≤ t.inbox.snapshot ∧
      amount = (t.registry.slots id).balance ∧ out.balance = 0 := by
  obtain ⟨c,present,delay,exit,payout,zero⟩ := withdrawal_window covered ok
  exact ⟨c,present,trace_clocked trace initial id c present,delay,exit,payout,zero⟩


end Etna.Design.SigningEscrow
