import EtnaModel.CurrentRegistry
import EtnaProofs.Staking
import EtnaProofs.RegistryHistory

namespace Etna.Design.Current.RegistryMachine
set_option maxRecDepth 30000

/-- Closing an L1 block makes all earlier election checkpoints immutable, including
when another transaction replaces the checkpoint of the still open block. -/
theorem record_closed_history (now cutoff : Nat) (es : List Committee.Entry)
    (history : List RegistryHistory.Snapshot) (closed : cutoff < now) :
    (RegistryHistory.recordSnapshot now es history).filter (fun cp => decide (cp.block ≤ cutoff)) =
      history.filter (fun cp => decide (cp.block ≤ cutoff)) := by
  cases history with
  | nil => simp [RegistryHistory.recordSnapshot, Nat.not_le_of_gt closed]
  | cons head rest =>
    by_cases same : head.block = now
    · simp [RegistryHistory.recordSnapshot,same, Nat.not_le_of_gt closed]
    · simp [RegistryHistory.recordSnapshot,same, Nat.not_le_of_gt closed]

theorem finish_closed_history (before after : State) (now cutoff : Nat)
    (closed : cutoff < now) :
    (finish before now after).history.filter (fun cp => decide (cp.block ≤ cutoff)) =
      before.history.filter (fun cp => decide (cp.block ≤ cutoff)) := by
  unfold finish
  dsimp only
  split
  · rfl
  · exact record_closed_history now cutoff _ _ closed

theorem record_history_time (s : State) (now : Nat) (es : List Committee.Entry)
    (old : HistoryTime s now) :
    RegistryHistory.Ordered (RegistryHistory.recordSnapshot now es s.history) ∧
      ∀ cp ∈ RegistryHistory.recordSnapshot now es s.history, cp.block ≤ now := by
  constructor
  · apply RegistryHistory.record_preserves_order _ _ _ old.1
    cases history : s.history with
    | nil =>
      simp only [List.head?_nil,Option.getD_none]
      exact Nat.zero_le now
    | cons head rest =>
      have bound := old.2 head (by simp [history])
      simpa [history] using bound
  · intro cp member
    cases history : s.history with
    | nil => simp [history,RegistryHistory.recordSnapshot] at member; cases member; exact Nat.le_refl _
    | cons head rest =>
      by_cases same : head.block = now
      · simp only [history,RegistryHistory.recordSnapshot,same,ite_true,List.mem_cons] at member
        rcases member with rfl | past
        · exact Nat.le_refl _
        · exact old.2 cp (by simp [history,past])
      · simp only [history,RegistryHistory.recordSnapshot,same,ite_false,List.mem_cons] at member
        rcases member with rfl | past
        · exact Nat.le_refl _
        · exact old.2 cp (by simpa [history] using past)

theorem execute_history_time {s t : State} {v : InboxView} {now : Nat} {a : Action}
    (old : HistoryTime s now) (ok : execute s v now a = some t) : HistoryTime t now := by
  unfold execute at ok
  split at ok
  · obtain ⟨u,_,rfl⟩ := Option.map_eq_some_iff.mp ok
    change RegistryHistory.Ordered (if entries u = entries s then s.history else
      RegistryHistory.recordSnapshot now (entries u) s.history) ∧ _
    by_cases same : entries u = entries s
    · simpa only [same,ite_true,finish,HistoryTime] using old
    · simpa only [same,ite_false,finish] using record_history_time s now (entries u) old
  · cases ok

theorem execute_closed_history {s t : State} {v : InboxView} {now cutoff : Nat}
    {action : Action} (ok : execute s v now action = some t) (closed : cutoff < now) :
    t.history.filter (fun cp => decide (cp.block ≤ cutoff)) =
      s.history.filter (fun cp => decide (cp.block ≤ cutoff)) := by
  unfold execute at ok
  split at ok
  · obtain ⟨u,_,rfl⟩ := Option.map_eq_some_iff.mp ok
    exact finish_closed_history s u now cutoff closed
  · cases ok

/-- Successful slashing authenticates the issued bond's own permanent key. -/
theorem slash_evidence {s t : State} {v : InboxView} {now id : Nat}
    {a b : Staking.Vote} {sa sb : Hash}
    (ok : execute s v now (.slash id a b sa sb) = some t) :
    ∃ bond, id < s.ledger.nextId ∧ s.ledger.bonds id = some bond ∧
      Evidence s v bond.value.key a b sa sb := by
  simp only [execute] at ok
  split at ok
  · obtain ⟨u,edited,_⟩ := Option.map_eq_some_iff.mp ok
    simp only [editValue] at edited
    split at edited
    next issued =>
      obtain ⟨bond,found,edited⟩ := Option.bind_eq_some_iff.mp edited
      obtain ⟨value,checked,_⟩ := Option.map_eq_some_iff.mp edited
      simp only [bondEdit] at checked
      split at checked
      next allowed => exact ⟨bond,issued,found,allowed.2.2.2.2⟩
      next => cases checked
    next => cases edited
  · cases ok

/-- A successful withdrawal has waited the complete configured evidence duration from
the recorded confirmation, irrespective of the earlier eligibility exit block. -/
theorem withdrawal_window {s t : Registry.State} {id caller now delay payout window : Nat}
    (ok : Registry.withdraw s id caller now delay = some (t,payout)) (bound : window ≤ delay) :
    ∃ bond atL1, id < s.nextId ∧ s.bonds id = some bond ∧
      bond.value.confirmedAt = some atL1 ∧ atL1+window ≤ now := by
  unfold Registry.withdraw at ok
  split at ok
  next issued =>
    obtain ⟨bond,found,ok⟩ := Option.bind_eq_some_iff.mp ok
    cases clock : bond.value.confirmedAt with
    | none => simp [clock] at ok
    | some atL1 =>
      simp only [clock] at ok
      split at ok
      next allowed => exact ⟨bond,atL1,issued,found,clock,by omega⟩
      next => cases ok
  next => cases ok

/-- STAKE-4.1-26 blocks the confirmation transaction while the actual landed
selection snapshot is below a selected identity's effective exit. This is the raw
call-level fence; a historical entry alone does not establish the present bond's
exit or the preceding snapshot trajectory. -/
theorem confirm_blocked_above_snapshot {s : State} {v : InboxView}
    {now cutoff id : Nat} {bond : Registry.Bond}
    (found : s.ledger.bonds id = some bond)
    (selected : cutoff < bond.value.exitAt) (settlement : v.snapshot ≤ cutoff) :
    execute s v now (.confirm id) = none := by
  have blocked : ¬ bond.value.exitAt ≤ v.snapshot := by omega
  simp only [execute]
  split
  · unfold editValue
    split
    · simp [found,bondEdit,blocked]
    · rfl
  · rfl
set_option linter.unusedSimpArgs false
set_option maxRecDepth 20000

theorem sumBalances_congr {a b : Nat → Option Registry.Bond} {n : Nat}
    (same : ∀ id, id < n → ((a id).map (fun b : Registry.Bond => b.value.balance)).getD 0 =
      ((b id).map (fun b : Registry.Bond => b.value.balance)).getD 0) : sumBalances a n = sumBalances b n := by
  induction n with
  | zero => rfl
  | succ n ih =>
    rw [sumBalances,sumBalances,ih (fun id bound => same id (by omega)),same n (by omega)]

theorem sumBalances_update (bonds : Nat → Option Registry.Bond) (n id : Nat)
    (value old : Registry.Bond) (found : bonds id = some old) (issued : id < n) :
    sumBalances (fun i => if i = id then some value else bonds i) n + old.value.balance =
      sumBalances bonds n + value.value.balance := by
  induction n with
  | zero => omega
  | succ n ih =>
    by_cases last : id = n
    · subst id
      have prior : sumBalances (fun i => if i = n then some value else bonds i) n = sumBalances bonds n :=
        sumBalances_congr (fun i bound => by simp [Nat.ne_of_lt bound])
      simp [sumBalances,prior,found,Nat.add_comm,Nat.add_left_comm,Nat.add_assoc]
    · have before : id < n := by omega
      simp only [sumBalances,Ne.symm last,ite_false]
      have prior := ih before
      omega

theorem reserve_member {s : Registry.State} {id : Nat} {bond : Registry.Bond}
    (issued : id < s.nextId) (found : s.bonds id = some bond) : bond.value.balance ≤ reserve s := by
  have bound : ∀ n, id < n → bond.value.balance ≤ sumBalances s.bonds n := by
    intro n
    induction n with
    | zero => omega
    | succ n ih =>
      intro h
      by_cases same : id = n
      · subst id; simp [sumBalances,found]
      · have prior := ih (by omega)
        simp only [sumBalances]
        omega
  exact bound _ issued

theorem update_reserve (s : Registry.State) (id : Nat) (value old : Registry.Bond)
    (found : s.bonds id = some old) (issued : id < s.nextId) :
    reserve (Registry.updateBond s id value) + old.value.balance = reserve s + value.value.balance :=
  sumBalances_update s.bonds s.nextId id value old found issued

theorem registration_reserve {s t : Registry.State} {key caller amount now id : Nat}
    (ok : Registry.register s key caller amount now = some (t,id)) : reserve t = reserve s+amount := by
  unfold Registry.register at ok
  dsimp only at ok
  split at ok
  · obtain ⟨rfl,rfl⟩ := Prod.mk.inj (Option.some.inj ok)
    unfold reserve
    simp only [sumBalances]
    have unchanged : ∀ i, i < s.nextId →
        (((match s.slots (Registry.admissionSlot s) with
          | none => s
          | some old => match s.bonds old with
            | none => s
            | some bond => Registry.updateBond s old ⟨Staking.exclude bond.value now,none⟩).bonds i).map
              (fun b : Registry.Bond => b.value.balance)).getD 0 =
          ((s.bonds i).map (fun b : Registry.Bond => b.value.balance)).getD 0 := by
      intro i _
      cases slot : s.slots (Registry.admissionSlot s) with
      | none => simp [slot]
      | some old =>
        cases found : s.bonds old with
        | none => simp [slot,found]
        | some bond =>
          by_cases same : i = old
          · subst i; simp [slot,found,Registry.updateBond,Staking.exclude,Staking.Bond.balance]
          · simp [slot,found,Registry.updateBond,same]
    simp only [Registry.updateBond,ite_true,Option.map_some,Option.getD_some,
      Staking.Bond.balance,Nat.add_zero]
    apply congrArg (fun x => x+amount)
    apply sumBalances_congr
    intro i bound
    simp only [Nat.ne_of_lt bound,ite_false]
    exact unchanged i bound
  · cases ok

theorem bondEdit_balance {s : State} {v : InboxView} {now : Nat} {b value : Staking.Bond}
    {a : Action} (ok : bondEdit s v now b a = some value) :
    value.balance+outgoingBond s b a = b.balance+incoming a := by
  cases a with
  | requestExit id caller =>
    simp only [bondEdit,Staking.requestExit] at ok
    split at ok
    · cases Option.some.inj ok; rfl
    · cases ok
  | topUp id caller amount =>
    simp only [bondEdit] at ok
    split at ok
    next allowed =>
      cases Option.some.inj ok
      simp only [Staking.Bond.balance,outgoingBond,incoming,Nat.add_zero]
      have pending := allowed.2.2.2.2.2.2.1
      omega
    next => cases ok
  | activateTopUp id =>
    simp only [bondEdit] at ok
    split at ok
    · cases Option.some.inj ok; simp [outgoingBond,incoming,Staking.Bond.balance]
    · cases ok
  | confirm id =>
    simp only [bondEdit] at ok
    split at ok
    · cases Option.some.inj ok; rfl
    · cases ok
  | slash id a z sa sz =>
    simp only [bondEdit] at ok
    split at ok
    · cases Option.some.inj ok; simp [outgoingBond,incoming,Staking.Bond.balance]
    · cases ok
  | forfeit id caller key incident deadline =>
    simp only [bondEdit] at ok
    split at ok
    next allowed =>
      cases Option.some.inj ok
      have bounded := Staking.forfeit_penalty_bounded b.balance s.config.forfeitBps allowed.2.2.2.2.2.2.2.2
      simp only [Staking.Bond.balance,outgoingBond,incoming,Nat.add_zero] at *
      omega
    next => cases ok
  | register _ _ _ _ | withdraw _ _ _ | exclude _ _ _ | recheck _ _ => cases ok

theorem edit_reserve {s t : State} {v : InboxView} {now id : Nat} {a : Action}
    (ok : editValue s id (fun b => bondEdit s v now b a) = some t)
    (out : ∀ b, s.ledger.bonds id = some b → outgoing s a = outgoingBond s b.value a) :
    reserve t.ledger+outgoing s a = reserve s.ledger+incoming a := by
  unfold editValue at ok
  split at ok
  next issued =>
    obtain ⟨bond,found,ok⟩ := Option.bind_eq_some_iff.mp ok
    obtain ⟨value,checked,rfl⟩ := Option.map_eq_some_iff.mp ok
    have change := update_reserve s.ledger id ⟨{value with key := bond.value.key},bond.slot⟩ bond found issued
    have principal := bondEdit_balance checked
    change reserve (Registry.updateBond s.ledger id _) + outgoing s a = _
    rw [out bond found]
    change reserve (Registry.updateBond s.ledger id _) + bond.value.balance = reserve s.ledger+value.balance at change
    omega
  next => cases ok

theorem withdrawal_reserve {s t : Registry.State} {id caller now delay payout : Nat}
    (ok : Registry.withdraw s id caller now delay = some (t,payout)) :
    reserve t+payout = reserve s := by
  unfold Registry.withdraw at ok
  split at ok
  next issued =>
    obtain ⟨bond,found,ok⟩ := Option.bind_eq_some_iff.mp ok
    cases clock : bond.value.confirmedAt with
    | none => simp [clock] at ok
    | some atL1 =>
      simp only [clock] at ok
      split at ok
      · obtain ⟨rfl,rfl⟩ := Prod.mk.inj (Option.some.inj ok)
        have change := update_reserve s id (Registry.withdrawn bond) bond found issued
        simpa only [reserve,Registry.withdrawn,Staking.Bond.balance,Nat.add_zero] using change
      · cases ok
  next => cases ok

theorem withdrawal_payout {s t : Registry.State} {id caller now delay payout : Nat}
    (ok : Registry.withdraw s id caller now delay = some (t,payout)) :
    ((s.bonds id).map (fun b => b.value.balance)).getD 0 = payout := by
  unfold Registry.withdraw at ok
  split at ok
  · obtain ⟨bond,found,ok⟩ := Option.bind_eq_some_iff.mp ok
    cases clock : bond.value.confirmedAt with
    | none => simp [clock] at ok
    | some atL1 =>
      simp only [clock] at ok
      split at ok
      · obtain ⟨_,rfl⟩ := Prod.mk.inj (Option.some.inj ok)
        simp [found]
      · cases ok
  · cases ok

theorem excluded_reserve (s : State) (xs : List (Nat × Hash)) (cutoff : Nat) :
    reserve (excludedLedger s xs cutoff) = reserve s.ledger := by
  apply sumBalances_congr
  intro id _
  simp only [excludedLedger]
  cases found : s.ledger.bonds id with
  | none => rfl
  | some bond =>
    simp only [Option.map_some,Option.getD_some]
    split <;> rfl

theorem rechecked_reserve (s : State) (cutoff : Nat) :
    reserve (recheckedLedger s cutoff) = reserve s.ledger := by
  apply sumBalances_congr
  intro id _
  simp only [recheckedLedger]
  cases found : s.ledger.bonds id with
  | none => rfl
  | some bond =>
    simp only [Option.map_some,Option.getD_some,Staking.rollbackBySnapshot]
    split
    · split <;> rfl
    · rfl

/-- Every principal reduction is exactly a withdrawal or specified punishment amount;
displacement, recovery and rollback cannot silently consume deposited principal. -/
theorem execute_reserve {s t : State} {v : InboxView} {now : Nat} {action : Action}
    (ok : execute s v now action = some t) :
    reserve t.ledger+outgoing s action = reserve s.ledger+incoming action := by
  unfold execute at ok
  split at ok
  · obtain ⟨u,checked,rfl⟩ := Option.map_eq_some_iff.mp ok
    change reserve u.ledger+outgoing s action = _
    cases action with
    | register key caller amount pop =>
      simp only at checked
      split at checked
      · obtain ⟨⟨ledger,id⟩,registered,rfl⟩ := Option.map_eq_some_iff.mp checked
        simpa only [outgoing,incoming,Nat.add_zero] using registration_reserve registered
      · cases checked
    | withdraw id caller recipient =>
      obtain ⟨⟨ledger,payout⟩,withdrawn,rfl⟩ := Option.map_eq_some_iff.mp checked
      have change := withdrawal_reserve withdrawn
      have payment := withdrawal_payout withdrawn
      simpa only [outgoing,outgoingBond,incoming,Nat.add_zero,payment] using change
    | exclude caller cutoff xs =>
      simp only at checked
      split at checked
      · cases Option.some.inj checked
        simpa only [outgoing,incoming,Nat.add_zero] using excluded_reserve s xs cutoff
      · cases checked
    | recheck caller cutoff =>
      simp only at checked
      split at checked
      · cases Option.some.inj checked
        simpa only [outgoing,incoming,Nat.add_zero] using rechecked_reserve s cutoff
      · cases checked
    | forfeit id caller key incident deadline =>
      obtain ⟨u,edited,rfl⟩ := Option.map_eq_some_iff.mp checked
      have change := edit_reserve edited (fun b found => by simp [outgoing,found])
      exact change
    | requestExit _ _ | topUp _ _ _ | activateTopUp _ | confirm _ =>
      exact edit_reserve checked (fun _ _ => rfl)
    | slash id a b sa sb =>
      exact edit_reserve checked (fun b found => by simp [outgoing,found])
  · cases ok

theorem bondEdit_clock {s : State} {v : InboxView} {now since : Nat} {b value : Staking.Bond}
    {a : Action} (ok : bondEdit s v now b a = some value) (live : b.released = false)
    (clock : ∀ atL1, b.confirmedAt = some atL1 → since ≤ atL1) (time : since ≤ now) :
    value.released = false ∧ ∀ atL1, value.confirmedAt = some atL1 → since ≤ atL1 := by
  cases a with
  | requestExit id caller =>
    simp only [bondEdit,Staking.requestExit] at ok
    split at ok
    · cases Option.some.inj ok; exact ⟨live,clock⟩
    · cases ok
  | topUp _ _ _ | activateTopUp _ | slash _ _ _ _ _ | forfeit _ _ _ _ _ =>
    simp only [bondEdit] at ok
    split at ok
    · cases Option.some.inj ok; exact ⟨live,clock⟩
    · cases ok
  | confirm id =>
    simp only [bondEdit] at ok
    split at ok
    · cases Option.some.inj ok
      refine ⟨live,?_⟩
      cases record : b.confirmedAt with
      | none => simpa only [record,Option.getD_none,Option.some.injEq] using fun atL1 (same : now = atL1) => same ▸ time
      | some old =>
        intro atL1 same
        have oldBound := clock old record
        simp only [record,Option.getD_some,Option.some.injEq] at same
        omega
    · cases ok
  | register _ _ _ _ | withdraw _ _ _ | exclude _ _ _ | recheck _ _ => cases ok

theorem edit_clock {s t : State} {v : InboxView} {now since id target : Nat} {a : Action}
    (old : EvidenceClock s id since) (time : since ≤ now)
    (ok : editValue s target (fun b => bondEdit s v now b a) = some t) : EvidenceClock t id since := by
  obtain ⟨bond,issued,found,live,clock⟩ := old
  unfold editValue at ok
  split at ok
  · obtain ⟨previous,present,ok⟩ := Option.bind_eq_some_iff.mp ok
    obtain ⟨value,checked,rfl⟩ := Option.map_eq_some_iff.mp ok
    by_cases same : id = target
    · subst target
      have equal : previous = bond := Option.some.inj (present.symm.trans found)
      subst previous
      have kept := bondEdit_clock checked live clock time
      refine ⟨⟨{value with key := bond.value.key},bond.slot⟩,issued,?_,kept.1,kept.2⟩
      simp [writeValue,Registry.updateBond]
    · exact ⟨bond,issued,by simp [writeValue,Registry.updateBond,same,found],live,clock⟩
  · cases ok

theorem registration_clock {s t : Registry.State} {key caller amount now fresh id since : Nat}
    (ok : Registry.register s key caller amount now = some (t,fresh))
    {bond : Registry.Bond} (issued : id < s.nextId) (found : s.bonds id = some bond)
    (live : bond.value.released = false)
    (clock : ∀ atL1, bond.value.confirmedAt = some atL1 → since ≤ atL1) :
    ∃ retained, id < t.nextId ∧ t.bonds id = some retained ∧ retained.value.released = false ∧
      ∀ atL1, retained.value.confirmedAt = some atL1 → since ≤ atL1 := by
  unfold Registry.register at ok
  dsimp only at ok
  split at ok
  · obtain ⟨rfl,rfl⟩ := Prod.mk.inj (Option.some.inj ok)
    have different : id ≠ s.nextId := by omega
    simp only [Registry.updateBond,different,ite_false]
    cases slot : s.slots (Registry.admissionSlot s) with
    | none => exact ⟨bond,by omega,by simp [slot,found],live,clock⟩
    | some old =>
      cases prior : s.bonds old with
      | none => exact ⟨bond,by omega,by simp [slot,prior,found],live,clock⟩
      | some previous =>
        by_cases same : id = old
        · subst old
          have equal : previous = bond := Option.some.inj (prior.symm.trans found)
          subst previous
          exact ⟨⟨Staking.exclude bond.value now,none⟩,by omega,by simp [slot,prior,Registry.updateBond],live,clock⟩
        · exact ⟨bond,by omega,by simp [slot,prior,Registry.updateBond,same,found],live,clock⟩
  · cases ok

theorem withdrawal_clock {s t : Registry.State} {target caller now delay payout id since : Nat}
    (ok : Registry.withdraw s target caller now delay = some (t,payout))
    {bond : Registry.Bond} (issued : id < s.nextId) (found : s.bonds id = some bond)
    (live : bond.value.released = false)
    (clock : ∀ atL1, bond.value.confirmedAt = some atL1 → since ≤ atL1)
    (early : now < since+delay) :
    ∃ retained, id < t.nextId ∧ t.bonds id = some retained ∧ retained.value.released = false ∧
      ∀ atL1, retained.value.confirmedAt = some atL1 → since ≤ atL1 := by
  have different : id ≠ target := by
    intro same
    subst target
    obtain ⟨previous,atL1,_,present,record,mature⟩ := withdrawal_window ok (Nat.le_refl delay)
    have equal : previous = bond := Option.some.inj (present.symm.trans found)
    subst previous
    have bound := clock atL1 record
    omega
  unfold Registry.withdraw at ok
  split at ok
  · obtain ⟨previous,_,ok⟩ := Option.bind_eq_some_iff.mp ok
    cases record : previous.value.confirmedAt with
    | none => simp [record] at ok
    | some atL1 =>
      simp only [record] at ok
      split at ok
      · obtain ⟨rfl,rfl⟩ := Prod.mk.inj (Option.some.inj ok)
        exact ⟨bond,issued,by simp [Registry.updateBond,different,found],live,clock⟩
      · cases ok
  · cases ok

theorem execute_clock {s t : State} {v : InboxView} {now since id : Nat} {a : Action}
    (old : EvidenceClock s id since) (time : since ≤ now) (early : now < since+s.config.withdrawalDelay)
    (ok : execute s v now a = some t) : EvidenceClock t id since := by
  unfold execute at ok
  split at ok
  · obtain ⟨u,checked,rfl⟩ := Option.map_eq_some_iff.mp ok
    change EvidenceClock u id since
    cases a with
    | register key caller amount pop =>
      simp only at checked
      split at checked
      · obtain ⟨⟨ledger,fresh⟩,registered,rfl⟩ := Option.map_eq_some_iff.mp checked
        obtain ⟨bond,issued,found,live,clock⟩ := old
        exact registration_clock registered issued found live clock
      · cases checked
    | withdraw target caller recipient =>
      obtain ⟨⟨ledger,payout⟩,withdrawn,rfl⟩ := Option.map_eq_some_iff.mp checked
      obtain ⟨bond,issued,found,live,clock⟩ := old
      exact withdrawal_clock withdrawn issued found live clock early
    | exclude caller cutoff xs =>
      simp only at checked
      split at checked
      · cases Option.some.inj checked
        obtain ⟨bond,issued,found,live,clock⟩ := old
        refine ⟨(if xs.any (fun x => x.1 == id) then
          ⟨Staking.exclude bond.value cutoff,bond.slot⟩ else bond),issued,?_,?_,?_⟩
        · simp only [excludedLedger,found,Option.map_some]
        · split <;> exact live
        · split <;> exact clock
      · cases checked
    | recheck caller cutoff =>
      simp only at checked
      split at checked
      · cases Option.some.inj checked
        obtain ⟨bond,issued,found,live,clock⟩ := old
        refine ⟨⟨Staking.rollbackBySnapshot cutoff bond.value,bond.slot⟩,issued,?_,?_,?_⟩
        · simp [recheckedLedger,found]
        · unfold Staking.rollbackBySnapshot; split
          · split <;> exact live
          · exact live
        · unfold Staking.rollbackBySnapshot; split
          · split
            · intro atL1 impossible; cases impossible
            · exact clock
          · exact clock
      · cases checked
    | forfeit target caller key incident deadline =>
      obtain ⟨u,edited,rfl⟩ := Option.map_eq_some_iff.mp checked
      have kept := edit_clock old time edited
      exact kept
    | requestExit _ _ | topUp _ _ _ | activateTopUp _ | confirm _ | slash _ _ _ _ _ =>
      exact edit_clock old time checked
  · cases ok

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

theorem trace_closed_history {first later : World} (run : Trace first later)
    {cutoff : Nat} (closed : cutoff < first.now) :
    later.registry.history.filter (fun cp => decide (cp.block ≤ cutoff)) =
      first.registry.history.filter (fun cp => decide (cp.block ≤ cutoff)) := by
  induction run with
  | refl => rfl
  | @step s t prior change ih =>
    have before : cutoff < s.now := Nat.lt_of_lt_of_le closed (trace_stable prior).time
    have one : t.registry.history.filter (fun cp => decide (cp.block ≤ cutoff)) =
        s.registry.history.filter (fun cp => decide (cp.block ≤ cutoff)) := by
      cases change with
      | call action ok => exact execute_closed_history ok before
      | frame => rfl
      | rollback _ _ _ _ _ _ _ ok => exact execute_closed_history ok before
    exact one.trans ih

/-- The evidence window starts no earlier than a real confirmation. All closed registry
steps, including slashing, forfeiture, displacement and rollback, retain an initially
unconfirmed bond until the complete delay after the initial observation has elapsed. -/
theorem trace_evidence_clock {first later : World} (run : Trace first later)
    {id since : Nat} (old : EvidenceClock first.registry id since) (time : since ≤ first.now)
    (early : later.now < since+first.registry.config.withdrawalDelay) : EvidenceClock later.registry id since := by
  induction run with
  | refl => exact old
  | @step s t prior change ih =>
    have frame := step_stable change
    have monotone := frame.time
    have priorBound : s.now < since+first.registry.config.withdrawalDelay := by omega
    have before := ih priorBound
    have stable := trace_stable prior
    have currentTime : since ≤ s.now := Nat.le_trans time stable.time
    have currentBound : s.now < since+s.registry.config.withdrawalDelay := by rw [stable.registry.config]; exact priorBound
    cases change with
    | call action ok => exact execute_clock before currentTime currentBound ok
    | frame => exact before
    | rollback _ _ _ _ _ _ _ ok => exact execute_clock before currentTime currentBound ok

theorem trace_history_time {first later : World} (run : Trace first later) (old : HistoryTime first.registry first.now) :
    HistoryTime later.registry later.now := by
  induction run with
  | refl => exact old
  | step _ change ih =>
    cases change with
    | call a ok => exact execute_history_time ih ok
    | frame s v w now later hd hg hi hn ht =>
      exact ⟨ih.1,fun cp member => Nat.le_trans (ih.2 cp member) hn⟩
    | rollback _ _ _ _ _ _ _ ok => exact execute_history_time ih ok

theorem registration_slots_issued {s t : Registry.State} {key caller amount now id : Nat}
    (old : SlotsIssued s) (ok : Registry.register s key caller amount now = some (t,id)) :
    SlotsIssued t := by
  unfold Registry.register at ok
  dsimp only at ok
  split at ok
  · obtain ⟨rfl,rfl⟩ := Prod.mk.inj (Option.some.inj ok)
    intro slot other found
    dsimp only at found ⊢
    split at found
    · cases Option.some.inj found; omega
    · have bound := old slot other found
      omega
  · cases ok

theorem withdrawal_slots_issued {s t : Registry.State} {id caller now delay payout : Nat}
    (old : SlotsIssued s) (ok : Registry.withdraw s id caller now delay = some (t,payout)) :
    SlotsIssued t := by
  unfold Registry.withdraw at ok
  split at ok
  · obtain ⟨bond,_,ok⟩ := Option.bind_eq_some_iff.mp ok
    cases clock : bond.value.confirmedAt with
    | none => simp [clock] at ok
    | some atL1 =>
      simp only [clock] at ok
      split at ok
      · obtain ⟨rfl,rfl⟩ := Prod.mk.inj (Option.some.inj ok)
        intro slot other found
        dsimp only at found ⊢
        split at found
        · cases found
        · exact old slot other found
      · cases ok
  · cases ok

theorem edit_slots_issued {s t : State} {id : Nat} {f : Staking.Bond → Option Staking.Bond}
    (old : SlotsIssued s.ledger) (ok : editValue s id f = some t) : SlotsIssued t.ledger := by
  unfold editValue at ok
  split at ok
  · obtain ⟨bond,_,ok⟩ := Option.bind_eq_some_iff.mp ok
    obtain ⟨value,_,rfl⟩ := Option.map_eq_some_iff.mp ok
    exact old
  · cases ok

theorem execute_slots_issued {s t : State} {v : InboxView} {now : Nat} {action : Action}
    (old : SlotsIssued s.ledger) (ok : execute s v now action = some t) : SlotsIssued t.ledger := by
  unfold execute at ok
  split at ok
  · obtain ⟨u,checked,rfl⟩ := Option.map_eq_some_iff.mp ok
    change SlotsIssued u.ledger
    cases action with
    | register key caller amount pop =>
      simp only at checked
      split at checked
      · obtain ⟨⟨ledger,id⟩,registered,rfl⟩ := Option.map_eq_some_iff.mp checked
        exact registration_slots_issued old registered
      · cases checked
    | withdraw id caller recipient =>
      obtain ⟨⟨ledger,payout⟩,withdrawn,rfl⟩ := Option.map_eq_some_iff.mp checked
      exact withdrawal_slots_issued old withdrawn
    | exclude caller cutoff xs | recheck caller cutoff =>
      simp only at checked
      split at checked
      · cases Option.some.inj checked; exact old
      · cases checked
    | forfeit id caller key incident deadline =>
      obtain ⟨u,edited,rfl⟩ := Option.map_eq_some_iff.mp checked
      have kept := edit_slots_issued old edited
      exact kept
    | requestExit _ _ | topUp _ _ _ | activateTopUp _ | confirm _ | slash _ _ _ _ _ =>
      exact edit_slots_issued old checked
  · cases ok

theorem entries_issued {s : State} (slots : SlotsIssued s.ledger) {entry : Committee.Entry}
    (member : entry ∈ entries s) (nonzero : entry.stake ≠ 0) :
    ∃ id bond, id < s.ledger.nextId ∧ s.ledger.bonds id = some bond ∧ bond.value.key = entry.key := by
  obtain ⟨slot,_,entryEq⟩ := List.mem_map.mp member
  cases hs : s.ledger.slots slot with
  | none => simp [hs] at entryEq; cases entryEq; exact False.elim (nonzero rfl)
  | some id =>
    cases hb : s.ledger.bonds id with
    | none => simp [hs,hb] at entryEq; cases entryEq; exact False.elim (nonzero rfl)
    | some bond =>
      simp only [hs,hb] at entryEq
      exact ⟨id,bond,slots slot id hs,hb,congrArg Committee.Entry.key entryEq⟩

theorem entries_principal {s : State} (slots : SlotsIssued s.ledger) {entry : Committee.Entry}
    (member : entry ∈ entries s) (positive : entry.stake ≠ 0) :
    ∃ id bond, id < s.ledger.nextId ∧ s.ledger.bonds id = some bond ∧
      Staking.toEntry bond.value = entry ∧ entry.stake ≤ bond.value.balance := by
  obtain ⟨slot,_,entryEq⟩ := List.mem_map.mp member
  cases hs : s.ledger.slots slot with
  | none => simp [hs] at entryEq; cases entryEq; exact False.elim (positive rfl)
  | some id =>
    cases hb : s.ledger.bonds id with
    | none => simp [hs,hb] at entryEq; cases entryEq; exact False.elim (positive rfl)
    | some bond =>
      simp only [hs,hb] at entryEq
      refine ⟨id,bond,slots slot id hs,hb,entryEq,?_⟩
      rw [← entryEq]
      exact Nat.le_add_right _ _

theorem execute_history_origin_exact {s t : State} {v : InboxView} {now : Nat} {action : Action}
    (ok : execute s v now action = some t) {cp : RegistryHistory.Snapshot} (member : cp ∈ t.history) :
    cp ∈ s.history ∨ (cp.block = now ∧ cp.entries = entries t) := by
  unfold execute at ok
  split at ok
  · obtain ⟨u,_,rfl⟩ := Option.map_eq_some_iff.mp ok
    change cp ∈ (if entries u = entries s then s.history else
      RegistryHistory.recordSnapshot now (entries u) s.history) at member
    change cp ∈ s.history ∨ (cp.block = now ∧ cp.entries = entries u)
    split at member
    · exact Or.inl member
    · cases history : s.history with
      | nil =>
        simp only [history,RegistryHistory.recordSnapshot,List.mem_singleton] at member
        cases member; exact Or.inr ⟨rfl,rfl⟩
      | cons head rest =>
        by_cases same : head.block = now
        · simp only [history,RegistryHistory.recordSnapshot,same,ite_true,List.mem_cons] at member
          rcases member with rfl | past
          · exact Or.inr ⟨rfl,rfl⟩
          · exact Or.inl (by simp [history,past])
        · simp only [history,RegistryHistory.recordSnapshot,same,ite_false,List.mem_cons] at member
          rcases member with rfl | past
          · exact Or.inr ⟨rfl,rfl⟩
          · exact Or.inl (by simpa [history] using past)
  · cases ok

theorem execute_history_origin {s t : State} {v : InboxView} {now : Nat} {action : Action}
    (ok : execute s v now action = some t) {cp : RegistryHistory.Snapshot} (member : cp ∈ t.history) :
    cp ∈ s.history ∨ cp.entries = entries t := by
  rcases execute_history_origin_exact ok member with old | fresh
  · exact Or.inl old
  · exact Or.inr fresh.2

theorem execute_history_issued {s t : State} {v : InboxView} {now : Nat} {action : Action}
    (slots : SlotsIssued s.ledger) (old : HistoryIssued s) (ok : execute s v now action = some t) :
    HistoryIssued t := by
  intro cp cpMem entry entryMem nonzero
  rcases execute_history_origin ok cpMem with past | fresh
  · obtain ⟨id,bond,issued,found,key⟩ := old cp past entry entryMem nonzero
    have stable := execute_stable ok
    obtain ⟨retained,present,same⟩ := stable.ledger.bonds id bond issued found
    exact ⟨id,retained,Nat.lt_of_lt_of_le issued stable.ledger.next,present,same.trans key⟩
  · rw [fresh] at entryMem
    exact entries_issued (execute_slots_issued slots ok) entryMem nonzero

theorem trace_history_issued {first later : World} (run : Trace first later) (genesis : Genesis first.registry) :
    SlotsIssued later.registry.ledger ∧ HistoryIssued later.registry := by
  induction run with
  | refl =>
    constructor
    · intro slot id found; rw [genesis.2.2.1 slot] at found; cases found
    · intro cp member; rw [genesis.2.2.2.2.1] at member; cases member
  | step _ change ih =>
    cases change with
    | call action ok => exact ⟨execute_slots_issued ih.1 ok,execute_history_issued ih.1 ih.2 ok⟩
    | frame => exact ih
    | rollback _ _ _ _ _ _ _ ok => exact ⟨execute_slots_issued ih.1 ok,execute_history_issued ih.1 ih.2 ok⟩

/-- Existing permanent registries need authenticated seed invariants, not a fabricated
empty deployment. A retarget preserving ledger/history can carry these facts forward. -/
theorem trace_history_issued_from_seed {first later : World} (run : Trace first later)
    (slots : SlotsIssued first.registry.ledger) (history : HistoryIssued first.registry) :
    SlotsIssued later.registry.ledger ∧ HistoryIssued later.registry := by
  induction run with
  | refl => exact ⟨slots,history⟩
  | step _ change ih =>
    cases change with
    | call action ok => exact ⟨execute_slots_issued ih.1 ok,execute_history_issued ih.1 ih.2 ok⟩
    | frame => exact ih
    | rollback _ _ _ _ _ _ _ ok => exact ⟨execute_slots_issued ih.1 ok,execute_history_issued ih.1 ih.2 ok⟩

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
    (rate : s.config.slashBountyBps < 10000)
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
    (rate : first.registry.config.slashBountyBps < 10000) :
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
    (rate : s.config.slashBountyBps < 10000)
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

/-- STAKE-4.1-13a: every bond edit (exit request, top-up, activation, confirmation, slash and
forfeit) taking an unissued id reverts, whatever default storage holds at that id. -/
theorem unissued_edit_rejected (s : State) (id : Nat) (f : Staking.Bond → Option Staking.Bond)
    (unissued : s.ledger.nextId ≤ id) : editValue s id f = none := by
  simp [editValue,Nat.not_lt.mpr unissued]

end Etna.Design.Current.RegistryMachine
