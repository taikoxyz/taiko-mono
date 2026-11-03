import EtnaModel.CurrentRegistry

namespace Etna.Design.Current.RegistryMachine
set_option linter.unusedSimpArgs false
set_option maxRecDepth 20000

theorem ledger_refl (s : Registry.State) : LedgerStable s s :=
  ⟨Nat.le_refl _,rfl,rfl,fun _ _ h => h,fun _ b _ h => ⟨b,h,rfl⟩⟩
theorem stable_refl (s : State) : Stable s s := ⟨rfl,rfl,rfl,rfl,ledger_refl _⟩

theorem ledger_trans {s t u : Registry.State} (a : LedgerStable s t) (b : LedgerStable t u) :
    LedgerStable s u := by
  refine ⟨Nat.le_trans a.next b.next,b.minimum.trans a.minimum,
    b.activation.trans a.activation,fun k id h => b.keys k id (a.keys k id h),?_⟩
  intro id old bound found
  obtain ⟨mid,hm,hk⟩ := a.bonds id old bound found
  obtain ⟨last,hl,hkl⟩ := b.bonds id mid (Nat.lt_of_lt_of_le bound a.next) hm
  exact ⟨last,hl,hkl.trans hk⟩

theorem stable_trans {s t u : State} (a : Stable s t) (b : Stable t u) : Stable s u :=
  ⟨b.config.trans a.config,b.verify.trans a.verify,b.registration.trans a.registration,
   b.entryKey.trans a.entryKey,ledger_trans a.ledger b.ledger⟩

theorem finish_stable {s t : State} (now : Nat) (h : Stable s t) : Stable s (finish s now t) :=
  ⟨h.config,h.verify,h.registration,h.entryKey,h.ledger⟩

theorem write_stable (s : Registry.State) (id : Nat) (b : Registry.Bond)
    (found : s.bonds id = some b) (value : Staking.Bond) :
    LedgerStable s (writeValue s id b value) := by
  refine ⟨Nat.le_refl _,rfl,rfl,fun _ _ h => h,?_⟩
  intro other old _ ho
  by_cases eq : other = id
  · subst other
    have hb : old = b := Option.some.inj (ho.symm.trans found)
    subst old
    exact ⟨⟨{ value with key := b.value.key },b.slot⟩,by simp [writeValue,Registry.updateBond],rfl⟩
  · exact ⟨old,by simp [writeValue,Registry.updateBond,eq,ho],rfl⟩

theorem edit_stable {s t : State} {id : Nat} {f : Staking.Bond → Option Staking.Bond}
    (ok : editValue s id f = some t) : Stable s t := by
  unfold editValue at ok
  split at ok
  next =>
    cases hb : s.ledger.bonds id <;> simp only [hb,Option.bind_none,Option.bind_some] at ok
    next => contradiction
    next b =>
      cases hf : f b.value <;> simp only [hf,Option.map_none,Option.map_some] at ok
      next => contradiction
      next value =>
        cases Option.some.inj ok
        exact ⟨rfl,rfl,rfl,rfl,write_stable _ _ _ hb _⟩
  next => simp at ok

theorem registration_stable {s t : Registry.State} {key caller amount now id : Nat}
    (ok : Registry.register s key caller amount now = some (t,id)) : LedgerStable s t := by
  unfold Registry.register at ok
  dsimp only at ok
  split at ok
  next guard =>
    obtain ⟨rfl,rfl⟩ := Prod.mk.inj (Option.some.inj ok)
    refine ⟨Nat.le_succ _,?_,?_,?_,?_⟩
    · cases hs : s.slots (Registry.admissionSlot s) <;> simp [hs,Registry.updateBond]
      split <;> rfl
    · cases hs : s.slots (Registry.admissionSlot s) <;> simp [hs,Registry.updateBond]
      split <;> rfl
    · intro k old hk
      have ne : k ≠ key := by intro eq; subst k; simp [guard.1] at hk
      simp [ne,hk]
    · intro old b bound found
      have ne : old ≠ s.nextId := by omega
      simp only [Registry.updateBond,ne,↓reduceIte]
      cases hs : s.slots (Registry.admissionSlot s)
      · exact ⟨b,by simp [hs,found],rfl⟩
      · rename_i displaced
        cases hd : s.bonds displaced
        · exact ⟨b,by simp [hs,hd,found],rfl⟩
        · rename_i d
          by_cases eq : old = displaced
          · subst old
            have hb : b = d := Option.some.inj (found.symm.trans hd)
            subst b
            exact ⟨⟨Staking.exclude d.value now,none⟩,by simp [hs,hd,Registry.updateBond],rfl⟩
          · exact ⟨b,by simp [hs,hd,Registry.updateBond,eq,found],rfl⟩
  next => simp at ok

theorem withdrawal_stable {s t : Registry.State} {id caller now delay payout : Nat}
    (ok : Registry.withdraw s id caller now delay = some (t,payout)) : LedgerStable s t := by
  unfold Registry.withdraw at ok
  split at ok
  next =>
    cases hb : s.bonds id <;> simp only [hb,Option.bind_none,Option.bind_some] at ok
    next => contradiction
    next b =>
      cases hc : b.value.confirmedAt <;> simp only [hc] at ok
      next => contradiction
      next atL1 =>
        split at ok
        next =>
          cases Option.some.inj ok
          refine ⟨Nat.le_refl _,rfl,rfl,fun _ _ h => h,?_⟩
          intro other old _ ho
          by_cases eq : other = id
          · subst other
            have h : old = b := Option.some.inj (ho.symm.trans hb)
            subst old
            exact ⟨Registry.withdrawn b,by simp [Registry.updateBond],rfl⟩
          · exact ⟨old,by simp [Registry.updateBond,eq,ho],rfl⟩
        next => simp at ok
  next => simp at ok

theorem excluded_stable (s : State) (xs : List (Nat × Hash)) (snapshot : Nat) :
    Stable s { s with ledger := excludedLedger s xs snapshot } := by
  refine ⟨rfl,rfl,rfl,rfl,⟨Nat.le_refl _,rfl,rfl,fun _ _ h => h,?_⟩⟩
  intro id b _ hb
  simp only [excludedLedger,hb,Option.map_some]
  split <;> exact ⟨_,rfl,rfl⟩

theorem recheck_stable (s : State) (snapshot : Nat) :
    Stable s { s with ledger := recheckedLedger s snapshot } := by
  refine ⟨rfl,rfl,rfl,rfl,⟨Nat.le_refl _,rfl,rfl,fun _ _ h => h,?_⟩⟩
  intro id b _ hb
  refine ⟨⟨Staking.rollbackBySnapshot snapshot b.value,b.slot⟩,by simp [recheckedLedger,hb],?_⟩
  simp only [Staking.rollbackBySnapshot]
  split
  · split <;> rfl
  · rfl

theorem execute_stable {s t : State} {v : InboxView} {now : Nat} {action : Action}
    (ok : execute s v now action = some t) : Stable s t := by
  unfold execute at ok
  split at ok
  next =>
    obtain ⟨u,hu,rfl⟩ := Option.map_eq_some_iff.mp ok
    apply finish_stable
    cases action with
    | register key caller amount pop =>
      simp only at hu
      split at hu
      next =>
        obtain ⟨⟨ledger,id⟩,h,rfl⟩ := Option.map_eq_some_iff.mp hu
        exact ⟨rfl,rfl,rfl,rfl,registration_stable h⟩
      next => simp at hu
    | withdraw id caller to =>
      obtain ⟨⟨ledger,payout⟩,h,rfl⟩ := Option.map_eq_some_iff.mp hu
      exact ⟨rfl,rfl,rfl,rfl,withdrawal_stable h⟩
    | exclude caller snapshot xs =>
      simp only at hu
      split at hu
      next => cases Option.some.inj hu; exact excluded_stable _ _ _
      next => simp at hu
    | recheck caller snapshot =>
      simp only at hu
      split at hu
      next => cases Option.some.inj hu; exact recheck_stable _ _
      next => simp at hu
    | forfeit id caller key incident deadline =>
      obtain ⟨r,h,rfl⟩ := Option.map_eq_some_iff.mp hu
      have hs := edit_stable h
      exact ⟨hs.config,hs.verify,hs.registration,hs.entryKey,hs.ledger⟩
    | requestExit _ _ | topUp _ _ _ | activateTopUp _ | confirm _ | slash _ _ _ _ _ =>
      exact edit_stable hu
  next => simp at ok

theorem step_stable {s t : World} (h : Step s t) : WorldStable s t := by
  cases h with
  | call action ok => exact ⟨execute_stable ok,rfl,Nat.le_refl _,id,Nat.le_refl _,Nat.le_refl _⟩
  | frame s v w now later hd hg hi hn ht => exact ⟨stable_refl _,hd,hg,hi,hn,ht⟩
  | rollback v w now hd hg hi ht ok => exact ⟨execute_stable ok,hd,hg,hi,Nat.le_refl _,ht⟩

theorem trace_stable {s t : World} (h : Trace s t) : WorldStable s t := by
  induction h with
  | refl => exact ⟨stable_refl _,rfl,Nat.le_refl _,id,Nat.le_refl _,Nat.le_refl _⟩
  | step _ change ih =>
    have hh := step_stable change
    exact ⟨stable_trans ih.registry hh.registry,hh.domain.trans ih.domain,
      Nat.le_trans ih.generation hh.generation,fun h => hh.initialized (ih.initialized h),
      Nat.le_trans ih.time hh.time,Nat.le_trans ih.timestamp hh.timestamp⟩

theorem evidence_monotone {s t : State} {v w : InboxView} {key : Hash}
    {a b : Staking.Vote} {sa sb : Hash} (fixed : t.verify = s.verify)
    (domain : w.domain = v.domain) (generation : v.generation ≤ w.generation)
    (h : Evidence s v key a b sa sb) : Evidence t w key a b sa sb := by
  refine ⟨by simpa [fixed] using h.1,by simpa [fixed] using h.2.1,?_⟩
  have hd := h.2.2
  simp only [Staking.doubleSign,decide_eq_true_eq] at hd ⊢
  exact ⟨hd.1.trans domain.symm,hd.2.1.trans domain.symm,hd.2.2.1,
    Nat.le_trans hd.2.2.2.1 generation,hd.2.2.2.2⟩

theorem slash_enabled {s : State} {v : InboxView} {now id : Nat} {b : Registry.Bond}
    (issued : id < s.ledger.nextId) (found : s.ledger.bonds id = some b)
    (initialized : v.initialized = true) (free : v.entered = false)
    (live : b.value.released = false) (positive : 0 < b.value.balance)
    (rate : s.config.slashBountyBps ≤ 10000)
    {a z : Staking.Vote} {sa sz : Hash}
    (auth : Evidence s v b.value.key a z sa sz) :
    ∃ t, execute s v now (.slash id a z sa sz) = some t := by
  simp only [execute,free,↓reduceIte,editValue,issued,found,Option.bind_some,
    bondEdit,initialized,live,positive,rate,auth,and_self,Option.map_some]
  exact ⟨_,rfl⟩

/-- Fixed authenticated evidence survives every closed lifecycle/context transition.
The conclusion is conditional only on remaining principal and lack of withdrawal;
slot possession, committee membership, forfeiture and current generation equality are irrelevant. -/
theorem evidence_stays_slashable {first later : World} (trace : Trace first later)
    {id : Nat} {original current : Registry.Bond}
    (issued : id < first.registry.ledger.nextId)
    (found : first.registry.ledger.bonds id = some original)
    (initialized : first.inbox.initialized = true)
    {a b : Staking.Vote} {sa sb : Hash}
    (auth : Evidence first.registry first.inbox original.value.key a b sa sb)
    (present : later.registry.ledger.bonds id = some current)
    (live : current.value.released = false) (positive : 0 < current.value.balance)
    (free : later.inbox.entered = false)
    (rate : first.registry.config.slashBountyBps ≤ 10000) :
    ∃ t, execute later.registry later.inbox later.now (.slash id a b sa sb) = some t := by
  have stable := trace_stable trace
  obtain ⟨retained,hr,hk⟩ := stable.registry.ledger.bonds id original issued found
  have same : retained = current := Option.some.inj (hr.symm.trans present)
  subst retained
  have evidence := evidence_monotone stable.registry.verify stable.domain stable.generation auth
  rw [← hk] at evidence
  exact slash_enabled (Nat.lt_of_lt_of_le issued stable.registry.ledger.next) present
    (stable.initialized initialized) free live positive
    (by simpa [stable.registry.config] using rate) evidence

/-- Success drains both principal components and preserves the permanent key and slot. -/
theorem slash_exact {s : State} {v : InboxView} {now id : Nat} {b : Registry.Bond}
    (issued : id < s.ledger.nextId) (found : s.ledger.bonds id = some b)
    (initialized : v.initialized = true) (free : v.entered = false)
    (live : b.value.released = false) (positive : 0 < b.value.balance)
    (rate : s.config.slashBountyBps ≤ 10000)
    {a z : Staking.Vote} {sa sz : Hash}
    (auth : Evidence s v b.value.key a z sa sz) :
    ∃ t c, execute s v now (.slash id a z sa sz) = some t ∧
      t.ledger.bonds id = some c ∧ c.value.key = b.value.key ∧
      c.value.stake = 0 ∧ c.value.pendingTopUp = 0 ∧ c.value.topUpReadyAtL1 = 0 ∧
      c.value.exitAt = min b.value.exitAt now ∧ c.slot = b.slot := by
  let wiped : Staking.Bond := { b.value with stake := 0, pendingTopUp := 0, topUpReadyAtL1 := 0, exitAt := min b.value.exitAt now }
  refine ⟨finish s now { s with ledger := writeValue s.ledger id b wiped },
    ⟨wiped,b.slot⟩,?_,?_,rfl,rfl,rfl,rfl,rfl,rfl⟩
  · simp only [execute,free,↓reduceIte,editValue,issued,found,Option.bind_some,
      bondEdit,initialized,live,positive,rate,auth,and_self,Option.map_some]
    simp only [wiped,live]
  · simp [finish,writeValue,Registry.updateBond,wiped]

/-- Lifetime key registration makes every later registration of that key fail. -/
theorem used_key_rejected {s : State} (v : InboxView) (now key caller amount pop id : Nat)
    (used : s.ledger.keyId key = some id) :
    execute s v now (.register key caller amount pop) = none := by
  simp [execute,Registry.register,used]

end Etna.Design.Current.RegistryMachine
