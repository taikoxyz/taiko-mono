import EtnaModel.RegistryHistory
import EtnaProofs.Staking
import EtnaProofs.Recovery

/-! Proofs about `EtnaModel.RegistryHistory`. -/
namespace Etna.Design.RegistryHistory

theorem same_block_single_checkpoint (now : Nat) (a b : List Committee.Entry) (history : List Snapshot) :
    recordSnapshot now b (recordSnapshot now a history) = recordSnapshot now b history := by
  cases history with
  | nil => simp [recordSnapshot]
  | cons head rest => by_cases same : head.block = now <;> simp [recordSnapshot,same]

theorem record_head (now : Nat) (es : List Committee.Entry) (history : List Snapshot) :
    (recordSnapshot now es history).head? = some ⟨now,es⟩ := by
  cases history <;> simp [recordSnapshot]
  split <;> rfl

theorem historical_cutoff_preserved (history : List Snapshot) (now cutoff : Nat)
    (es : List Committee.Entry) (past : cutoff < now) :
    latestSnapshot (recordSnapshot now es history) cutoff = latestSnapshot history cutoff := by
  cases history with
  | nil => simp [recordSnapshot,latestSnapshot,show ¬now ≤ cutoff by omega]
  | cons head rest =>
    by_cases same : head.block = now
    · simp [recordSnapshot,latestSnapshot,same,show ¬now ≤ cutoff by omega]
    · simp [recordSnapshot,latestSnapshot,same,show ¬now ≤ cutoff by omega]

theorem snapshot_is_at_or_before {history : List Snapshot} {cutoff : Nat} {cp : Snapshot}
    (found : latestSnapshot history cutoff = some cp) : cp ∈ history ∧ cp.block ≤ cutoff := by
  have mem := List.mem_of_find?_eq_some found
  have pred := List.find?_some found
  exact ⟨mem,of_decide_eq_true pred⟩

theorem snapshot_is_latest {history : List Snapshot} {cutoff : Nat} {cp : Snapshot}
    (ordered : Ordered history) (found : latestSnapshot history cutoff = some cp) :
    ∀ candidate ∈ history, candidate.block ≤ cutoff → candidate.block ≤ cp.block := by
  induction history with
  | nil => simp [latestSnapshot] at found
  | cons head rest ih =>
    simp only [Ordered,List.pairwise_cons] at ordered
    by_cases due : head.block ≤ cutoff
    · have eq : head = cp := by simpa [latestSnapshot,List.find?_cons,due] using found
      subst cp
      intro candidate member _
      rcases List.mem_cons.mp member with rfl | tail
      · omega
      · have less := ordered.1 candidate tail
        omega
    · have tail : latestSnapshot rest cutoff = some cp := by
        simpa [latestSnapshot,List.find?_cons,due] using found
      intro candidate member within
      rcases List.mem_cons.mp member with rfl | member
      · omega
      · exact ih ordered.2 tail candidate member within

theorem finish_used_keys (before after : State) (now : Nat) :
    (finish before now after).usedKeys = after.usedKeys := rfl

theorem registered_identity {s t : State} {key owner amount now : Nat}
    (ok : register s key owner amount now = some t) :
    key ∉ s.usedKeys ∧ t.usedKeys = key :: s.usedKeys ∧
    (t.slots (allocation s).1).key = key ∧ (t.slots (allocation s).1).confirmedAt = none := by
  unfold register at ok
  split at ok
  · rename_i allowed
    cases ok
    refine ⟨allowed.2.2.1,rfl,?_,?_⟩ <;> simp [finish,writeSlot,allocation]
  · contradiction

theorem register_preserves_keys {s t : State} {key owner amount now : Nat}
    (before : KeysValid s) (ok : register s key owner amount now = some t) : KeysValid t := by
  have fresh := registered_identity ok
  unfold register at ok
  split at ok
  · rename_i allowed
    cases ok
    refine ⟨allowed.2.2.2.2.2.2.2.2.1,?_⟩
    change (key :: s.usedKeys).Nodup
    exact List.nodup_cons.mpr ⟨fresh.1,before.2⟩
  · contradiction

theorem edited_keys_unchanged {s t : State} {inbox : Etna.Design.State} {id now : Nat} {action : Edit}
    (ok : edit s inbox id now action = some t) : t.usedKeys = s.usedKeys ∧ t.nextId = s.nextId := by
  unfold edit at ok
  split at ok
  · cases h : editBond s inbox now (s.slots id) action with
    | none => simp [h] at ok
    | some b => simp only [h,Option.map_some,Option.some.injEq] at ok; subst t; exact ⟨rfl,rfl⟩
  · contradiction

theorem stale_evidence_rejected (r : State)
    (inbox : Etna.Design.State) (now : Nat) (bond : Staking.Bond)
    (sigA sigB : Nat) (a b : Staking.Vote)
    (invalid : r.verify bond.key a sigA = false) :
    editBond r inbox now bond (.slash a b sigA sigB) = none := by
  simp [editBond,invalid]

theorem slash_verifies_stored_key {r : State}
    {inbox : Etna.Design.State} {now : Nat} {bond out : Staking.Bond}
    {sigA sigB : Nat} {a b : Staking.Vote}
    (ok : editBond r inbox now bond (.slash a b sigA sigB) = some out) :
    r.verify bond.key a sigA = true ∧ r.verify bond.key b sigB = true := by
  simp only [editBond] at ok
  split at ok
  · rename_i valid
    exact ⟨valid.1,valid.2.1⟩
  · contradiction

/-- Successful slashing derives every double-sign condition, the stored-key signatures,
the Inbox's own initialization and the full-stake effect; deployment and generation come
from the registry's Inbox, never from the caller. -/
theorem slash_success_double_sign {r : State}
    {inbox : Etna.Design.State} {now : Nat} {bond out : Staking.Bond}
    {sigA sigB : Nat} {a b : Staking.Vote}
    (ok : editBond r inbox now bond (.slash a b sigA sigB) = some out) :
    r.verify bond.key a sigA = true ∧ r.verify bond.key b sigB = true ∧
    a.domain = inbox.domain ∧ b.domain = inbox.domain ∧ a.generation = b.generation ∧
    a.generation ≤ inbox.generation ∧ a.height = b.height ∧ a.round = b.round ∧ a.kind = b.kind ∧
    (a.kind = 1 ∨ a.kind = 2) ∧ a.blockId ≠ b.blockId ∧
    Staking.inboxInitialized inbox = true ∧ bond.released = false ∧ 0 < bond.stake ∧ r.slashBountyBps ≤ 10000 ∧
    out = { bond with stake := 0,exitAt := min bond.exitAt now } := by
  simp only [editBond] at ok
  split at ok
  · rename_i valid
    have sign := of_decide_eq_true valid.2.2
    unfold Staking.slashDouble at ok
    split at ok
    · rename_i guard
      simp only [Option.map_some,Option.some.injEq] at ok
      exact ⟨valid.1,valid.2.1,sign.1,sign.2.1,sign.2.2.1,sign.2.2.2.1,sign.2.2.2.2.1,sign.2.2.2.2.2.1,
        sign.2.2.2.2.2.2.1,sign.2.2.2.2.2.2.2.1,sign.2.2.2.2.2.2.2.2,guard.1,guard.2.1,guard.2.2.1,guard.2.2.2,ok.symm⟩
    · simp at ok
  · contradiction

/-- Conversely, admissible evidence always succeeds: any past generation of this deployment
(including after recovery), either vote type, no committee-membership premise. -/
theorem slash_of_double_sign {r : State}
    {inbox : Etna.Design.State} {now : Nat} {bond : Staking.Bond} {sigA sigB : Nat} {a b : Staking.Vote}
    (signedA : r.verify bond.key a sigA = true) (signedB : r.verify bond.key b sigB = true)
    (domainA : a.domain = inbox.domain) (domainB : b.domain = inbox.domain)
    (generation : a.generation = b.generation) (past : a.generation ≤ inbox.generation)
    (height : a.height = b.height) (round : a.round = b.round) (kind : a.kind = b.kind)
    (vote : a.kind = 1 ∨ a.kind = 2) (conflict : a.blockId ≠ b.blockId)
    (initialized : Staking.inboxInitialized inbox = true) (live : bond.released = false)
    (staked : 0 < bond.stake) (cap : r.slashBountyBps ≤ 10000) :
    editBond r inbox now bond (.slash a b sigA sigB) =
      some { bond with stake := 0,exitAt := min bond.exitAt now } := by
  have evidence : Staking.doubleSign inbox.domain inbox.generation a b = true :=
    decide_eq_true ⟨domainA,domainB,generation,past,height,round,kind,vote,conflict⟩
  simp [editBond,Staking.slashDouble,signedA,signedB,evidence,initialized,live,staked,cap]

theorem lifetime_key_cannot_register_again (s : State) (key owner amount now : Nat)
    (used : key ∈ s.usedKeys) : register s key owner amount now = none := by
  simp [register,RegisterAllowed,used]

theorem rollback_keeps_registry_history (s : State) (snapshot : Nat) :
    (recheckAll s snapshot).history = s.history ∧ (recheckAll s snapshot).usedKeys = s.usedKeys ∧
    (recheckAll s snapshot).nextId = s.nextId := ⟨rfl,rfl,rfl⟩

theorem edit_success {s t : State} {inbox : Etna.Design.State} {id now : Nat} {action : Edit}
    (ok : edit s inbox id now action = some t) :
    id < s.nextId ∧ lastBlock s ≤ now ∧ ∃ bond, editBond s inbox now (s.slots id) action = some bond ∧
      t = finish s now { writeSlot s id bond with
        free := if bond.released && !(s.slots id).released then s.free ++ [id] else s.free } := by
  unfold edit at ok
  split at ok
  · rename_i guard
    cases h : editBond s inbox now (s.slots id) action with
    | none => simp [h] at ok
    | some bond =>
      simp only [h,Option.map_some,Option.some.injEq] at ok
      exact ⟨guard.1,guard.2,bond,rfl,ok.symm⟩
  · contradiction

/-- Registry-level slashing uses the stored occupant key, the registry's own verifier and
bounty, and the Inbox passed by the transition; the slot loses its whole stake. -/
theorem edit_slash_double_sign {s t : State} {inbox : Etna.Design.State} {id now : Nat}
    {a b : Staking.Vote} {sigA sigB : Nat}
    (ok : edit s inbox id now (.slash a b sigA sigB) = some t) :
    s.verify (s.slots id).key a sigA = true ∧ s.verify (s.slots id).key b sigB = true ∧
    Staking.doubleSign inbox.domain inbox.generation a b = true ∧
    Staking.inboxInitialized inbox = true ∧ (s.slots id).released = false ∧ 0 < (s.slots id).stake ∧
    (t.slots id).stake = 0 ∧ (t.slots id).key = (s.slots id).key ∧ (t.slots id).exitAt ≤ now := by
  obtain ⟨_,_,bond,changed,rfl⟩ := edit_success ok
  have facts := slash_success_double_sign changed
  have evidence : Staking.doubleSign inbox.domain inbox.generation a b = true :=
    decide_eq_true ⟨facts.2.2.1,facts.2.2.2.1,facts.2.2.2.2.1,facts.2.2.2.2.2.1,facts.2.2.2.2.2.2.1,
      facts.2.2.2.2.2.2.2.1,facts.2.2.2.2.2.2.2.2.1,facts.2.2.2.2.2.2.2.2.2.1,facts.2.2.2.2.2.2.2.2.2.2.1⟩
  obtain ⟨signedA,signedB,_,_,_,_,_,_,_,_,_,initialized,live,staked,_,rfl⟩ := facts
  refine ⟨signedA,signedB,evidence,initialized,live,staked,?_,?_,?_⟩ <;>
    simp [finish,writeSlot,Nat.min_le_right]

/-- confirmExit and slashDoubleSign fail while the Inbox itself is uninitialized, whatever
the call arguments; registration is unaffected. -/
theorem uninitialized_inbox_blocks_edits {s : State} {inbox : Etna.Design.State} {id now : Nat} {action : Edit}
    (uninitialized : Staking.inboxInitialized inbox = false)
    (gated : action = .confirm ∨ ∃ a b sigA sigB, action = .slash a b sigA sigB) :
    edit s inbox id now action = none := by
  cases h : edit s inbox id now action with
  | none => rfl
  | some t =>
    obtain ⟨_,_,bond,changed,_⟩ := edit_success h
    rcases gated with rfl | ⟨a,b,sigA,sigB,rfl⟩
    · have := (Staking.confirmation_requires_coverage changed).1
      simp [uninitialized] at this
    · have := (slash_success_double_sign changed).2.2.2.2.2.2.2.2.2.2.2.1
      simp [uninitialized] at this

theorem edit_live_identity {r : State} {inbox : Etna.Design.State} {now : Nat} {before after : Staking.Bond} {action : Edit}
    (ok : editBond r inbox now before action = some after) (live : after.released = false) :
    before.released = false ∧ after.key = before.key := by
  cases action with
  | requestExit caller =>
    simp only [editBond,Staking.requestExit] at ok
    split at ok
    · rename_i guard
      cases ok
      exact ⟨guard.2.1,rfl⟩
    · contradiction
  | confirm =>
    simp only [editBond,Staking.confirmExit] at ok
    split at ok
    · rename_i can
      cases h : before.confirmedAt <;> simp only [h,Option.some.injEq] at ok <;> subst after
      all_goals exact ⟨can.2.2.1,rfl⟩
    · contradiction
  | withdraw caller =>
    cases h : Staking.withdraw inbox before caller now r.withdrawalDelay with
    | none => simp [editBond,h] at ok
    | some result =>
      rcases result with ⟨out,amount⟩
      have released := (Staking.withdraw_waits_for_confirmation h)
      simp only [editBond,h,Option.map_some,Option.some.injEq] at ok
      subst after
      obtain ⟨_,_,_,_,_,free,_⟩ := released
      simp [free] at live
  | slash a b sigA sigB =>
    simp only [editBond] at ok
    split at ok
    · unfold Staking.slashDouble at ok
      split at ok
      · rename_i guard
        simp only [Option.map_some,Option.some.injEq] at ok
        subst after
        exact ⟨guard.2.1,rfl⟩
      · simp at ok
    · contradiction
  | forceExit =>
    simp only [editBond] at ok
    split at ok
    · rename_i guard
      cases ok
      exact ⟨guard,rfl⟩
    · contradiction
  | recheck snapshot =>
    cases hb : before.confirmedAt with
    | none =>
      simp only [editBond,Staking.rollbackBySnapshot,hb,Option.some.injEq] at ok
      subst after
      exact ⟨live,rfl⟩
    | some atL1 =>
      simp only [editBond,Staking.rollbackBySnapshot,hb] at ok
      split at ok <;> cases ok <;> exact ⟨live,rfl⟩

theorem edited_preserves_keys {s t : State} {inbox : Etna.Design.State} {id now : Nat} {action : Edit}
    (before : KeysValid s) (ok : edit s inbox id now action = some t) : KeysValid t := by
  obtain ⟨used,count⟩ := edited_keys_unchanged ok
  exact ⟨count ▸ before.1,used ▸ before.2⟩

theorem edit_preserves_identities {s t : State} {inbox : Etna.Design.State} {id now : Nat} {action : Edit}
    (before : IdentitiesValid s) (ok : edit s inbox id now action = some t) : IdentitiesValid t := by
  obtain ⟨bound,_,bond,changed,rfl⟩ := edit_success ok
  intro i range live
  by_cases same : i = id
  · subst i
    have isLive : bond.released = false := by simpa [finish,writeSlot] using live
    have identity := edit_live_identity changed isLive
    have used := before id bound identity.1
    simpa [finish,writeSlot,identity.2] using used
  · have wasLive : (s.slots i).released = false := by simpa [finish,writeSlot,same] using live
    simpa [finish,writeSlot,same] using before i range wasLive

theorem allocation_covers_new_id (s : State) (i : Nat) (range : i < (allocation s).2.2) :
    i = (allocation s).1 ∨ i < s.nextId := by
  cases h : s.free <;> simp [allocation,h] at * <;> omega

theorem register_preserves_identities {s t : State} {key owner amount now : Nat}
    (before : IdentitiesValid s) (ok : register s key owner amount now = some t) : IdentitiesValid t := by
  unfold register at ok
  split at ok
  · cases ok
    intro i range live
    change i < (allocation s).2.2 at range
    rcases allocation_covers_new_id s i range with same | old
    · simp [finish,writeSlot,allocation,same]
    · by_cases same : i = (allocation s).1
      · simp [finish,writeSlot,allocation,same]
      · simp only [allocation] at same
        have prior : (s.slots i).released = false := by simpa [finish,writeSlot,allocation,same] using live
        have used := before i old prior
        simp only [finish,writeSlot]
        simp [same,used]
  · contradiction

theorem record_preserves_order (history : List Snapshot) (now : Nat) (es : List Committee.Entry)
    (ordered : Ordered history) (time : ((history.head?).getD default).block ≤ now) :
    Ordered (recordSnapshot now es history) := by
  cases history with
  | nil => simp [Ordered,recordSnapshot]
  | cons head rest =>
    change head.block ≤ now at time
    have parts := List.pairwise_cons.mp ordered
    by_cases same : head.block = now
    · simp only [recordSnapshot,same,ite_true,Ordered,List.pairwise_cons]
      exact ⟨by intro old mem; have := parts.1 old mem; omega,parts.2⟩
    · simp only [recordSnapshot,same,ite_false,Ordered,List.pairwise_cons]
      refine ⟨?_,parts⟩
      intro old mem
      rcases List.mem_cons.mp mem with rfl | tail
      · omega
      · have := parts.1 old tail
        omega

theorem finish_preserves_order (s t : State) (now : Nat) (ordered : Ordered s.history)
    (time : lastBlock s ≤ now) : Ordered (finish s now t).history := by
  unfold finish
  split
  · exact ordered
  · exact record_preserves_order s.history now (entries t) ordered time

theorem recheck_preserves_entries (s : State) (snapshot : Nat) : entries (recheckAll s snapshot) = entries s := by
  unfold entries
  apply List.map_congr_left
  intro id _
  simp only [recheckAll,Staking.rollbackBySnapshot]
  split <;> (try split) <;> rfl

theorem registry_view_entries (s : State) : (registryView s).map Prod.snd = entries s := by
  simp [registryView,entries,List.map_map]

theorem exclusions_match_registry_view (s : State) (xs : List Recovery.Exclusion) (now : Nat) :
    registryView (forceExclusions s xs now) =
      (registryView s).map (fun (id,e) =>
        (id,if Recovery.exclusionApplies xs id e.key then { e with exitAt := min e.exitAt now } else e)) := by
  simp only [registryView,forceExclusions,finish,List.map_map]
  apply List.map_congr_left
  intro id _
  by_cases excluded : Recovery.exclusionApplies xs id (s.slots id).key = true <;>
    simp [excluded,Staking.toEntry,Staking.exclude]

theorem exclusions_preserve_registry (s : State) (xs : List Recovery.Exclusion) (now : Nat)
    (keys : KeysValid s) (identities : IdentitiesValid s) (ordered : Ordered s.history)
    (time : lastBlock s ≤ now) :
    KeysValid (forceExclusions s xs now) ∧ IdentitiesValid (forceExclusions s xs now) ∧
    Ordered (forceExclusions s xs now).history := by
  refine ⟨keys,?_,finish_preserves_order s _ now ordered time⟩
  intro id bound live
  by_cases excluded : Recovery.exclusionApplies xs id (s.slots id).key = true
  · have oldLive : (s.slots id).released = false := by
      simpa [forceExclusions,finish,excluded,Staking.exclude] using live
    simpa [forceExclusions,finish,excluded,Staking.exclude] using identities id bound oldLive
  · have oldLive : (s.slots id).released = false := by
      simpa [forceExclusions,finish,excluded] using live
    simpa [forceExclusions,finish,excluded] using identities id bound oldLive

theorem finish_block_bound (s t : State) (now : Nat) (time : lastBlock s ≤ now) :
    lastBlock (finish s now t) ≤ now := by
  unfold finish
  split
  · exact time
  · unfold lastBlock
    rw [record_head]
    exact Nat.le_refl _

theorem finish_preserves_past (s t : State) (now cutoff : Nat) (past : cutoff < now) :
    latestSnapshot (finish s now t).history cutoff = latestSnapshot s.history cutoff := by
  unfold finish
  split
  · rfl
  · exact historical_cutoff_preserved s.history now cutoff (entries t) past

theorem register_preserves_past {s t : State} {key owner amount now cutoff : Nat}
    (ok : register s key owner amount now = some t) (past : cutoff < now) :
    latestSnapshot t.history cutoff = latestSnapshot s.history cutoff := by
  unfold register at ok
  split at ok
  · cases ok
    exact finish_preserves_past s _ now cutoff past
  · contradiction

theorem edit_preserves_past {s t : State} {inbox : Etna.Design.State} {id now cutoff : Nat} {action : Edit}
    (ok : edit s inbox id now action = some t) (past : cutoff < now) :
    latestSnapshot t.history cutoff = latestSnapshot s.history cutoff := by
  obtain ⟨_,_,bond,_,rfl⟩ := edit_success ok
  exact finish_preserves_past s _ now cutoff past

theorem later_trace_preserves_snapshot {cutoff : Nat} {s t : State} (trace : FutureTrace cutoff s t) :
    latestSnapshot t.history cutoff = latestSnapshot s.history cutoff := by
  induction trace with
  | refl => rfl
  | registration _ past ok ih => exact (register_preserves_past ok past).trans ih
  | modification _ past ok ih => exact (edit_preserves_past ok past).trans ih
  | recovery _ _ _ past ih => exact (finish_preserves_past _ _ _ _ past).trans ih
  | rollback _ _ ih => exact ih

theorem entries_length (s : State) : (entries s).length = s.nextId := by simp [entries]

theorem finish_current_snapshot (s t : State) (now : Nat) (current : CurrentSnapshot s) :
    CurrentSnapshot (finish s now t) := by
  unfold finish
  split
  · rename_i same
    rcases current with head | empty
    · exact Or.inl (by simpa only [entries] using head.trans (congrArg some same.symm))
    · right
      refine ⟨?_,empty.2⟩
      have sizes := congrArg List.length same
      simp only [entries_length] at sizes
      exact sizes.trans empty.1
  · left
    simp only [record_head,Option.map_some]
    rfl

theorem recheck_current_snapshot (s : State) (snapshot : Nat) (current : CurrentSnapshot s) :
    CurrentSnapshot (recheckAll s snapshot) := by
  rcases current with head | empty
  · left
    change (s.history.head?).map Snapshot.entries = some (entries (recheckAll s snapshot))
    rw [recheck_preserves_entries]
    exact head
  · exact Or.inr empty

theorem step_never_releases_key {s t : State} (step : Step s t) : ∀ key ∈ s.usedKeys, key ∈ t.usedKeys := by
  cases step with
  | registration ok =>
    have used := (registered_identity ok).2.1
    intro key mem
    rw [used]
    exact List.mem_cons_of_mem _ mem
  | modification ok => rw [(edited_keys_unchanged ok).1]; exact fun _ h => h
  | rollback => exact fun _ h => h

theorem trace_never_releases_key {s t : State} (trace : Trace s t) : ∀ key ∈ s.usedKeys, key ∈ t.usedKeys := by
  induction trace with
  | refl => exact fun _ h => h
  | step _ change ih => exact fun key mem => step_never_releases_key change key (ih key mem)

theorem step_preserves_verifier {s t : State} (change : Step s t) : t.verify = s.verify := by
  cases change with
  | registration ok =>
    unfold register at ok
    split at ok
    · cases ok; rfl
    · contradiction
  | modification ok => obtain ⟨_,_,bond,_,rfl⟩ := edit_success ok; rfl
  | rollback => rfl

theorem trace_preserves_verifier {s t : State} (trace : Trace s t) : t.verify = s.verify := by
  induction trace with
  | refl => rfl
  | step _ change ih => exact (step_preserves_verifier change).trans ih

theorem step_preserves_slash_bounty {s t : State} (change : Step s t) : t.slashBountyBps = s.slashBountyBps := by
  cases change with
  | registration ok =>
    unfold register at ok
    split at ok
    · cases ok; rfl
    · contradiction
  | modification ok => obtain ⟨_,_,bond,_,rfl⟩ := edit_success ok; rfl
  | rollback => rfl

/-- The bounty used by every later slash is the deployment's immutable value. -/
theorem trace_preserves_slash_bounty {s t : State} (trace : Trace s t) : t.slashBountyBps = s.slashBountyBps := by
  induction trace with
  | refl => rfl
  | step _ change ih => exact (step_preserves_slash_bounty change).trans ih

theorem trace_forbids_lifetime_reuse {s t : State} (trace : Trace s t) (key owner amount now : Nat)
    (used : key ∈ s.usedKeys) : register t key owner amount now = none :=
  lifetime_key_cannot_register_again t key owner amount now (trace_never_releases_key trace key used)

theorem recheck_preserves_identities (s : State) (snapshot : Nat) (before : IdentitiesValid s) :
    IdentitiesValid (recheckAll s snapshot) := by
  intro id bound live
  have unchanged : ((recheckAll s snapshot).slots id).released = (s.slots id).released ∧
      ((recheckAll s snapshot).slots id).key = (s.slots id).key := by
    simp only [recheckAll,Staking.rollbackBySnapshot]
    split <;> (try split) <;> exact ⟨rfl,rfl⟩
  rw [unchanged.1] at live
  rw [unchanged.2]
  exact before id bound live

theorem step_preserves_registry {s t : State} (step : Step s t)
    (keys : KeysValid s) (identities : IdentitiesValid s) (ordered : Ordered s.history) :
    KeysValid t ∧ IdentitiesValid t ∧ Ordered t.history := by
  cases step with
  | registration ok =>
    refine ⟨register_preserves_keys keys ok,register_preserves_identities identities ok,?_⟩
    unfold register at ok
    split at ok
    · rename_i allowed
      cases ok
      exact finish_preserves_order _ _ _ ordered allowed.1
    · contradiction
  | modification ok =>
    refine ⟨edited_preserves_keys keys ok,edit_preserves_identities identities ok,?_⟩
    obtain ⟨_,time,bond,_,rfl⟩ := edit_success ok
    exact finish_preserves_order _ _ _ ordered time
  | rollback snapshot =>
    exact ⟨keys,recheck_preserves_identities _ snapshot identities,ordered⟩

theorem trace_preserves_registry {s t : State} (trace : Trace s t)
    (keys : KeysValid s) (identities : IdentitiesValid s) (ordered : Ordered s.history) :
    KeysValid t ∧ IdentitiesValid t ∧ Ordered t.history := by
  induction trace with
  | refl => exact ⟨keys,identities,ordered⟩
  | step _ change ih => exact step_preserves_registry change ih.1 ih.2.1 ih.2.2

end Etna.Design.RegistryHistory
