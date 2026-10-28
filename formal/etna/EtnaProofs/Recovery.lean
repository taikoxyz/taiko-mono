import EtnaModel.Recovery
import EtnaProofs.Landing
import EtnaProofs.Staking
import EtnaProofs.Forced

namespace Etna.Design.Recovery

theorem recover_success {w t : World} {a : Request} {cfg : Config} {r : Origin} {owner ext : Bool}
    (ok : recover w a cfg r owner ext = some t) : Allowed w a cfg r owner ∧ t = applyRecovery w a cfg r := by
  simp only [recover] at ok
  split at ok
  · rename_i h
    exact ⟨h.1,(Option.some.inj ok).symm⟩
  · contradiction

theorem recover_of_allowed {w : World} {a : Request} {cfg : Config} {r : Origin}
    (h : Allowed w a cfg r true) : recover w a cfg r true true = some (applyRecovery w a cfg r) := by
  simp [recover, h]

/-- Recovery reads the stored deployment: the epoch of c uses the initialized L and the R
election uses the stored vp_unit/s_min/n_max opening; neither is a call parameter, and both
stay unchanged. -/
theorem recovery_uses_stored_deployment {w t : World} {a : Request} {cfg : Config} {r : Origin} {owner ext : Bool}
    (ok : recover w a cfg r owner ext = some t) :
    3 ≤ w.inbox.epochLen ∧
    t.schedule = Committee.recoverySchedule ⟨w.inbox.checkpoint.height/w.inbox.epochLen,r.l1Block,
      (Committee.election w.inbox.configuration.unit w.inbox.configuration.minimum r.l1Block w.inbox.configuration.nMax
        ((excludedRegistry w a.exclusions r.l1Block).map Prod.snd)).getD []⟩ ∧
    t.inbox.epochLen = w.inbox.epochLen ∧ t.inbox.configuration = w.inbox.configuration := by
  obtain ⟨h,rfl⟩ := recover_success ok
  exact ⟨h.2.2.2.2.2.2.2.2.1,rfl,rfl,rfl⟩

theorem recovery_preserves_settled_prefix {w t : World} {a : Request} {cfg : Config} {r : Origin} {owner ext : Bool}
    (ok : recover w a cfg r owner ext = some t) :
    t.inbox.checkpoint = w.inbox.checkpoint ∧ t.inbox.records = w.inbox.records ∧
    t.inbox.head = w.inbox.head ∧ t.inbox.tail = w.inbox.tail ∧ t.inbox.signals = w.inbox.signals ∧
    t.inbox.snapshot = w.inbox.snapshot ∧ t.inbox.ethBalance = w.inbox.ethBalance ∧
    t.schedule.pending = none := by
  obtain ⟨_,rfl⟩ := recover_success ok
  exact ⟨rfl,rfl,rfl,rfl,rfl,rfl,rfl,rfl⟩

theorem recovery_fixes_origin {w t : World} {a : Request} {cfg : Config} {r : Origin} {owner ext : Bool}
    (ok : recover w a cfg r owner ext = some t) :
    t.inbox.generation = w.inbox.generation+1 ∧ t.inbox.origin = r ∧
    r.height = w.inbox.checkpoint.height ∧
    t.inbox.origins = w.inbox.origins ++ [(t.inbox.generation,r)] := by
  obtain ⟨h,rfl⟩ := recover_success ok
  exact ⟨rfl,rfl,h.2.2.2.2.2.1,rfl⟩

/-- A recovery starts at the current checkpoint, so its origin is a grid point whenever c is
(`land_on_grid`; block 0 is one). -/
theorem recovery_origin_on_grid {w t : World} {a : Request} {cfg : Config} {r : Origin} {owner ext : Bool}
    (ok : recover w a cfg r owner ext = some t) (grid : w.inbox.checkpoint.height % w.inbox.gridK = 0) :
    t.inbox.origin.height % t.inbox.gridK = 0 := by
  have h := (recovery_fixes_origin ok)
  obtain ⟨_,rfl⟩ := recover_success ok
  rw [h.2.1, h.2.2.1]
  exact grid

theorem recover_preserves_grid {w t : World} {a : Request} {cfg : Config} {r : Origin} {owner ext : Bool}
    (ok : recover w a cfg r owner ext = some t) (grid : OnGrid w.inbox) : OnGrid t.inbox := by
  obtain ⟨_,rfl⟩ := recover_success ok
  exact grid

/-- 8.3 replay: a recovery changes the generation, so the same authorization fails again. -/
theorem replay_rejected {w t : World} {a : Request} {cfg : Config} {r : Origin} {owner ext : Bool}
    (ok : recover w a cfg r owner ext = some t) (next : Origin) (owner' ext' : Bool) :
    recover t a cfg next owner' ext' = none := by
  have old := (recover_success ok).1.2.2.1
  have changed := (recovery_fixes_origin ok).1
  apply ite_eq_right
  intro h
  have same := h.1.2.2.1
  omega

/-- Any landing advances c, which voids every authorization bound to the old c. -/
theorem stale_checkpoint_rejected (w : World) (a : Request) (cfg : Config) (r : Origin) (owner ext : Bool)
    (moved : a.checkpoint ≠ w.inbox.checkpoint.height) : recover w a cfg r owner ext = none := by
  apply ite_eq_right
  intro h
  exact moved h.1.2.2.2.1

theorem landing_voids_authorization {s t : State} {i : LandInput} {win : List Leaf} {e : LandingEnv}
    (landed : land s i win e = some t) (w : World) (a : Request) (cfg : Config) (r : Origin) (owner ext : Bool)
    (bound : a.checkpoint = s.checkpoint.height) (current : w.inbox = t) :
    recover w a cfg r owner ext = none := by
  apply stale_checkpoint_rejected
  have := (land_extends_checkpoint landed).1
  rw [current]
  omega

theorem external_failure_atomic (w : World) (a : Request) (cfg : Config) (r : Origin) (owner : Bool) :
    recover w a cfg r owner false = none := by simp [recover]

/-- Exclusions are forced exits only: no registry stake changes. -/
theorem exclusion_keeps_stakes (w : World) (xs : List Exclusion) (r : Nat) :
    (excludedRegistry w xs r).map (fun p => (p.1,p.2.stake)) = w.registry.map (fun p => (p.1,p.2.stake)) := by
  simp only [excludedRegistry, List.map_map]
  apply List.map_congr_left
  intro p _
  by_cases h : exclusionApplies xs p.1 p.2.key = true <;> simp [h]

/-- An excluded entry exits at or before R, so it is never eligible in R's election. -/
theorem excluded_not_eligible_at_r (r unit minimum : Nat) (e : Committee.Entry) :
    Committee.eligible unit minimum r { e with exitAt := min e.exitAt r } = false := by
  simp only [Committee.eligible, decide_eq_false_iff_not]
  omega

/-- Why recovery need not touch confirmed exits: a confirmed exit has exitAt ≤ the landed
snapshot, which is below every later L1 block under sound proofs (`land_snapshot_below_block`),
in particular below R; every member of R's election exits after R, hence after the landed
snapshot. -/
theorem confirmed_exit_not_reselected (w : World) (a : Request) (r : Origin)
    (before : w.inbox.snapshot < r.l1Block)
    (members : List Committee.Entry) (elected : selection w a r = some members) :
    ∀ m ∈ members, w.inbox.snapshot < m.exitAt := by
  intro m mem
  unfold selection at elected
  rw [Committee.election_chosen elected] at mem
  have := (Committee.chosen_eligible _ _ _ _ _ m mem).2.2.1
  omega

/-- Given that the stored snapshot is below R (true when it came from any earlier landing,
`land_snapshot_below_block`), the recovery committee's cutoff R and every later normal
cutoff max(anchor, R) dominate it, so slot 284 does not decrease across a recovery. -/
theorem recovery_snapshot_dominates {w t : World} {a : Request} {cfg : Config} {r : Origin} {owner ext : Bool}
    (ok : recover w a cfg r owner ext = some t) (before : w.inbox.snapshot < r.l1Block) (d : Nat) :
    t.inbox.snapshot < t.schedule.current.cutoff ∧
    t.schedule.current.cutoff ≤ Committee.normalCutoff d t.inbox.origin.l1Block := by
  obtain ⟨_,rfl⟩ := recover_success ok
  exact ⟨before, Committee.normalCutoff_ge_origin d r.l1Block⟩

theorem rollback_keeps_generation (s : State) (trusted : Checkpoint) (snapshot : Nat) :
    (rollbackInbox s trusted snapshot).generation = s.generation ∧
    (rollbackInbox s trusted snapshot).origin = s.origin ∧
    (rollbackInbox s trusted snapshot).origins = s.origins ∧
    (rollbackInbox s trusted snapshot).tail = s.tail ∧
    (rollbackInbox s trusted snapshot).checkpoint = trusted ∧
    (rollbackInbox s trusted snapshot).head = trusted.cursor ∧
    (rollbackInbox s trusted snapshot).snapshot = snapshot := ⟨rfl,rfl,rfl,rfl,rfl,rfl,rfl⟩

theorem rollback_voids_later (s : State) (trusted : Checkpoint) (snapshot : Nat) :
    (∀ r ∈ (rollbackInbox s trusted snapshot).records, r.height ≤ trusted.height) ∧
    (∀ g ∈ (rollbackInbox s trusted snapshot).signals, g.height ≤ trusted.height) := by
  constructor <;> intro x mem <;> simpa [rollbackInbox] using (List.mem_filter.mp mem).2

/-- When `trusted` is the retained record at its height, the restored checkpoint is again
the slot 285 record at c, so land's frontier check reads consistent data. -/
theorem find_height_filter (t : Checkpoint) :
    ∀ l : List Checkpoint, l.find? (fun r => r.height == t.height) = some t →
      (l.filter (fun r => decide (r.height ≤ t.height))).find? (fun r => r.height == t.height) = some t
  | [], h => by simp at h
  | x :: xs, h => by
    by_cases hx : x.height = t.height
    · have hxt : x = t := by simpa [List.find?_cons, hx] using h
      subst hxt
      simp
    · have rest : xs.find? (fun r => r.height == t.height) = some t := by
        simpa [List.find?_cons, hx] using h
      have ih := find_height_filter t xs rest
      by_cases le : x.height ≤ t.height
      · simp [le, hx, ih]
      · simp [le, ih]

theorem rollback_record_consistent (s : State) (trusted : Checkpoint) (snapshot : Nat)
    (retained : recordAt s trusted.height = some trusted) :
    currentRecord (rollbackInbox s trusted snapshot) = trusted := by
  simp only [currentRecord, recordAt, rollbackInbox] at *
  rw [find_height_filter trusted s.records retained]
  rfl

/-- Restoring to a retained (hence grid) record keeps the state on the grid. -/
theorem rollback_preserves_grid (s : State) (trusted : Checkpoint) (snapshot : Nat)
    (retained : trusted ∈ s.records) (grid : OnGrid s) : OnGrid (rollbackInbox s trusted snapshot) := by
  refine ⟨grid.2 trusted retained, ?_⟩
  intro x mem
  exact grid.2 x (List.mem_filter.mp mem).1

/-- If a recovery had executed above the restored c, its generation's origin lies above c and
nothing can land until the DAO recovers again from the restored c (§8). -/
theorem origin_above_rollback_blocks_landing (s : State) (trusted : Checkpoint) (snapshot : Nat)
    (i : LandInput) (w : List Leaf) (e : LandingEnv) (above : trusted.height < s.origin.height) :
    land (rollbackInbox s trusted snapshot) i w e = none := by
  apply ite_eq_right
  intro h
  have a : s.origin.height ≤ i.parentHeight := h.1.1.2.1
  have b : i.parentHeight ≤ trusted.height := h.1.1.2.2.1
  omega

theorem bootstrap_fixed_origin {s : State} {r : Committee.Record} {b : Bootstrap}
    (ok : bootstrap s r = some b) :
    b.initialHeight = s.origin.height+1 ∧ b.genesisTime = s.origin.timestamp ∧
    b.firstLastBlockId = none ∧ b.firstLastCommit = none ∧
    ∃ cp, recordAt s s.origin.height = some cp ∧ b.appHash = cp.elHash := by
  cases h : recordAt s s.origin.height with
  | none => simp [bootstrap,h] at ok
  | some cp =>
    simp only [bootstrap,h] at ok
    cases ok
    exact ⟨rfl,rfl,rfl,rfl,cp,rfl,rfl⟩

end Etna.Design.Recovery
