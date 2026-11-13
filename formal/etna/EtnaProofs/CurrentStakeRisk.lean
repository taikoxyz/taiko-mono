import EtnaModel.CurrentStakeRisk
import EtnaProofs.CurrentEconomics

namespace Etna.Design.Current.StakeRisk
open RegistryMachine
set_option maxRecDepth 30000
set_option maxHeartbeats 4000000

theorem NormalTrace.project {first later : RegistryMachine.World} (run : NormalTrace first later) :
    RegistryMachine.Trace first later := by
  induction run with
  | refl => exact .refl _
  | call _ action _ ok ih => exact .step ih (.call action ok)
  | frame _ hd hg hi ht htime hs ih => exact .step ih (.frame _ _ _ _ _ hd hg hi ht htime)

theorem NormalTrace.snapshot_mono {first later : RegistryMachine.World} (run : NormalTrace first later) :
    first.inbox.snapshot ≤ later.inbox.snapshot := by
  induction run with
  | refl => exact Nat.le_refl _
  | call _ _ _ _ ih => exact ih
  | frame _ _ _ _ _ _ hs ih => exact Nat.le_trans ih hs

theorem metadata_mono {s : RegistryMachine.State} {a b : Nat} (old : Metadata s a)
    (order : a ≤ b) : Metadata s b := by
  intro id bond found
  have prior := old id bond found
  exact ⟨prior.1,fun released => Nat.le_trans (prior.2 released) order⟩

private theorem exclude_metadata {snapshot cutoff : Nat} {b : Staking.Bond}
    (old : BondMetadata snapshot b) : BondMetadata snapshot (Staking.exclude b cutoff) :=
  ⟨old.1,fun h => Nat.le_trans (Nat.min_le_left _ _) (old.2 h)⟩

private theorem bondEdit_metadata {s : RegistryMachine.State} {v : InboxView} {now : Nat}
    {b value : Staking.Bond} {action : Action} (old : BondMetadata v.snapshot b)
    (ok : bondEdit s v now b action = some value) : BondMetadata v.snapshot value := by
  cases action with
  | requestExit id caller =>
    simp only [bondEdit,Staking.requestExit] at ok
    split at ok
    next allowed =>
      cases Option.some.inj ok
      refine ⟨old.1,?_⟩
      intro h
      have bound := old.2 h
      rw [allowed.2.2.1] at bound
      exact Nat.le_trans (Nat.le_of_lt allowed.2.2.2) bound
    next => cases ok
  | topUp id caller amount | activateTopUp id =>
    simp only [bondEdit] at ok
    split at ok
    next allowed =>
      cases Option.some.inj ok
      constructor
      · intro released; simp_all
      · exact old.2
    next => cases ok
  | confirm id =>
    simp only [bondEdit] at ok
    split at ok
    next allowed =>
      cases Option.some.inj ok
      exact ⟨old.1,fun _ => allowed.2.2.2⟩
    next => cases ok
  | slash id a b sa sb | forfeit id caller key incident deadline =>
    simp only [bondEdit] at ok
    split at ok
    next allowed =>
      cases Option.some.inj ok
      constructor
      · intro released; simp_all
      · intro h
        exact Nat.le_trans (Nat.min_le_left _ _) (old.2 h)
    next => cases ok
  | register _ _ _ _ | withdraw _ _ _ | exclude _ _ _ | recheck _ _ => cases ok

private theorem edit_metadata {s t : RegistryMachine.State} {v : InboxView} {now target : Nat}
    {action : Action} (old : Metadata s v.snapshot)
    (ok : editValue s target (fun b => bondEdit s v now b action) = some t) : Metadata t v.snapshot := by
  unfold editValue at ok
  split at ok
  · obtain ⟨previous,present,ok⟩ := Option.bind_eq_some_iff.mp ok
    obtain ⟨value,checked,rfl⟩ := Option.map_eq_some_iff.mp ok
    intro id bond found
    by_cases same : id = target
    · subst target
      simp only [writeValue,Registry.updateBond,ite_true] at found
      cases Option.some.inj found
      change BondMetadata v.snapshot value
      exact bondEdit_metadata (old id previous present) checked
    · simp only [writeValue,Registry.updateBond,same,ite_false] at found
      exact old id bond found
  · cases ok

private theorem registration_metadata {s t : Registry.State} {key caller amount now fresh snapshot : Nat}
    (old : ∀ id b, s.bonds id = some b → BondMetadata snapshot b.value)
    (ok : Registry.register s key caller amount now = some (t,fresh)) :
    ∀ id b, t.bonds id = some b → BondMetadata snapshot b.value := by
  unfold Registry.register at ok
  dsimp only at ok
  split at ok
  · obtain ⟨rfl,rfl⟩ := Prod.mk.inj (Option.some.inj ok)
    intro id bond found
    by_cases fresh : id = s.nextId
    · subst id
      simp only [Registry.updateBond,ite_true] at found
      cases Option.some.inj found
      simp [BondMetadata,Staking.Bond.balance]
    · simp only [Registry.updateBond,fresh,ite_false] at found
      cases slot : s.slots (Registry.admissionSlot s) with
      | none => exact old id bond (by simpa [slot] using found)
      | some displaced =>
        cases was : s.bonds displaced with
        | none => exact old id bond (by simpa [slot,was] using found)
        | some previous =>
          by_cases same : id = displaced
          · subst displaced
            simp only [slot,was,ite_true] at found
            cases Option.some.inj found
            exact exclude_metadata (old id previous was)
          · exact old id bond (by simpa [slot,was,Registry.updateBond,same] using found)
  · cases ok

private theorem withdrawal_metadata {s t : Registry.State} {target caller now delay payout snapshot : Nat}
    (old : ∀ id b, s.bonds id = some b → BondMetadata snapshot b.value)
    (ok : Registry.withdraw s target caller now delay = some (t,payout)) :
    ∀ id b, t.bonds id = some b → BondMetadata snapshot b.value := by
  unfold Registry.withdraw at ok
  split at ok
  · obtain ⟨previous,present,ok⟩ := Option.bind_eq_some_iff.mp ok
    cases record : previous.value.confirmedAt with
    | none => simp [record] at ok
    | some atL1 =>
      simp only [record] at ok
      split at ok
      · obtain ⟨rfl,rfl⟩ := Prod.mk.inj (Option.some.inj ok)
        intro id bond found
        by_cases same : id = target
        · subst target
          simp only [Registry.updateBond,ite_true] at found
          cases Option.some.inj found
          refine ⟨by simp [Registry.withdrawn,Staking.Bond.balance],?_⟩
          intro _
          exact (old id previous present).2 (Or.inr (by rw [record]; simp))
        · exact old id bond (by simpa [Registry.updateBond,same] using found)
      · cases ok
  · cases ok

theorem execute_metadata {s t : RegistryMachine.State} {v : InboxView} {now : Nat} {action : Action}
    (old : Metadata s v.snapshot) (normal : NormalAction now action)
    (ok : execute s v now action = some t) : Metadata t v.snapshot := by
  unfold execute at ok
  split at ok
  · obtain ⟨u,checked,rfl⟩ := Option.map_eq_some_iff.mp ok
    change Metadata u v.snapshot
    cases action with
    | register key caller amount pop =>
      simp only at checked
      split at checked
      · obtain ⟨⟨ledger,id⟩,registered,rfl⟩ := Option.map_eq_some_iff.mp checked
        exact registration_metadata old registered
      · cases checked
    | withdraw id caller to =>
      obtain ⟨⟨ledger,payout⟩,withdrawn,rfl⟩ := Option.map_eq_some_iff.mp checked
      exact withdrawal_metadata old withdrawn
    | exclude caller cutoff xs =>
      simp only at checked
      split at checked
      · cases Option.some.inj checked
        intro id bond found
        simp only [excludedLedger] at found
        cases prior : s.ledger.bonds id with
        | none => simp [prior] at found
        | some previous =>
          have valid := old id previous prior
          simp only [prior,Option.map_some] at found
          split at found
          · cases Option.some.inj found; exact exclude_metadata valid
          · cases Option.some.inj found; exact valid
      · cases checked
    | recheck caller cutoff => exact False.elim normal
    | forfeit id caller key incident deadline =>
      obtain ⟨u,edited,rfl⟩ := Option.map_eq_some_iff.mp checked
      change Metadata u v.snapshot
      exact edit_metadata old edited
    | requestExit _ _ | topUp _ _ _ | activateTopUp _ | confirm _ | slash _ _ _ _ _ =>
      exact edit_metadata old checked
  · cases ok

theorem normal_metadata {first later : RegistryMachine.World} (run : NormalTrace first later)
    (genesis : Genesis first.registry) : Metadata later.registry later.inbox.snapshot := by
  induction run with
  | refl => intro id bond found; rw [genesis.2.1 id] at found; cases found
  | call _ action normal ok ih => exact execute_metadata ih normal ok
  | frame _ _ _ _ _ _ hs ih => exact metadata_mono ih hs

private theorem finish_head (before after : RegistryMachine.State) (now : Nat)
    (old : HeadCurrent before) : HeadCurrent (finish before now after) := by
  unfold finish
  split
  next same =>
    intro cp rest found
    change before.history = cp :: rest at found
    change cp.entries = entries after
    rw [old cp rest found]
    exact same.symm
  next =>
    intro cp rest found
    change RegistryHistory.recordSnapshot now (entries after) before.history = cp :: rest at found
    change cp.entries = entries after
    have head := RegistryHistory.record_head now (entries after) before.history
    rw [found] at head
    have same := Option.some.inj head
    exact congrArg RegistryHistory.Snapshot.entries same

theorem normal_head {first later : RegistryMachine.World} (run : NormalTrace first later)
    (genesis : Genesis first.registry) : HeadCurrent later.registry := by
  induction run with
  | refl => intro cp rest found; rw [genesis.2.2.2.2.1] at found; cases found
  | call _ action normal ok ih =>
    unfold execute at ok
    split at ok
    · obtain ⟨u,_,rfl⟩ := Option.map_eq_some_iff.mp ok
      exact finish_head _ _ _ ih
    · cases ok
  | frame _ _ _ _ _ _ _ ih => exact ih

private theorem bondEdit_retained {s : RegistryMachine.State} {v : InboxView} {now cutoff : Nat}
    {b value : Staking.Bond} {action : Action}
    (ok : bondEdit s v now b action = some value)
    (live : b.released = false) (unconfirmed : b.confirmedAt = none)
    (exit : cutoff < b.exitAt) (time : cutoff < now) (snapshot : v.snapshot ≤ cutoff) :
    value.released = false ∧ value.confirmedAt = none ∧ cutoff < value.exitAt := by
  cases action with
  | requestExit id caller =>
    simp only [bondEdit,Staking.requestExit] at ok
    split at ok
    · cases Option.some.inj ok
      exact ⟨live,unconfirmed,by change cutoff < max (now+s.config.exitDelay) (b.activeFrom+s.config.exitDelay); omega⟩
    · cases ok
  | topUp _ _ _ | activateTopUp _ =>
    simp only [bondEdit] at ok
    split at ok
    · cases Option.some.inj ok; exact ⟨live,unconfirmed,exit⟩
    · cases ok
  | confirm id =>
    simp only [bondEdit] at ok
    split at ok
    next allowed => have covered := allowed.2.2.2; omega
    next => cases ok
  | slash _ _ _ _ _ | forfeit _ _ _ _ _ =>
    simp only [bondEdit] at ok
    split at ok
    · cases Option.some.inj ok
      exact ⟨live,unconfirmed,by change cutoff < min b.exitAt now; omega⟩
    · cases ok
  | register _ _ _ _ | withdraw _ _ _ | exclude _ _ _ | recheck _ _ => cases ok

private theorem edit_retained {s t : RegistryMachine.State} {v : InboxView} {now cutoff id target : Nat}
    {action : Action} {key : Hash} (old : Retained s cutoff id key)
    (time : cutoff < now) (snapshot : v.snapshot ≤ cutoff)
    (ok : editValue s target (fun b => bondEdit s v now b action) = some t) : Retained t cutoff id key := by
  obtain ⟨bond,issued,found,key,live,clock,exit⟩ := old
  unfold editValue at ok
  split at ok
  · obtain ⟨previous,present,ok⟩ := Option.bind_eq_some_iff.mp ok
    obtain ⟨value,checked,rfl⟩ := Option.map_eq_some_iff.mp ok
    by_cases same : id = target
    · subst target
      have equal : previous = bond := Option.some.inj (present.symm.trans found)
      subst previous
      have kept := bondEdit_retained checked live clock exit time snapshot
      refine ⟨⟨{value with key := bond.value.key},bond.slot⟩,issued,?_,key,kept⟩
      simp [writeValue,Registry.updateBond]
    · exact ⟨bond,issued,by simp [writeValue,Registry.updateBond,same,found],key,live,clock,exit⟩
  · cases ok

private theorem registration_retained {s t : Registry.State} {key caller amount now fresh id cutoff : Nat}
    (ok : Registry.register s key caller amount now = some (t,fresh))
    {bond : Registry.Bond} (issued : id < s.nextId) (found : s.bonds id = some bond)
    (live : bond.value.released = false) (clock : bond.value.confirmedAt = none)
    (exit : cutoff < bond.value.exitAt) (time : cutoff < now) :
    ∃ retained, id < t.nextId ∧ t.bonds id = some retained ∧ retained.value.key = bond.value.key ∧
      retained.value.released = false ∧ retained.value.confirmedAt = none ∧ cutoff < retained.value.exitAt := by
  unfold Registry.register at ok
  dsimp only at ok
  split at ok
  · obtain ⟨rfl,rfl⟩ := Prod.mk.inj (Option.some.inj ok)
    have different : id ≠ s.nextId := by omega
    simp only [Registry.updateBond,different,ite_false]
    cases slot : s.slots (Registry.admissionSlot s) with
    | none => exact ⟨bond,by omega,by simp [found],rfl,live,clock,exit⟩
    | some old =>
      cases prior : s.bonds old with
      | none => exact ⟨bond,by omega,by simp [prior,found],rfl,live,clock,exit⟩
      | some previous =>
        by_cases same : id = old
        · subst old
          have equal : previous = bond := Option.some.inj (prior.symm.trans found)
          subst previous
          exact ⟨⟨Staking.exclude bond.value now,none⟩,by omega,
            by simp [prior],rfl,live,clock,by simpa [Staking.exclude] using (show cutoff < min bond.value.exitAt now by omega)⟩
        · exact ⟨bond,by omega,by simp [prior,same,found],rfl,live,clock,exit⟩
  · cases ok

private theorem withdrawal_retained {s t : Registry.State} {target caller now delay payout id : Nat}
    (ok : Registry.withdraw s target caller now delay = some (t,payout))
    {bond : Registry.Bond} (issued : id < s.nextId) (found : s.bonds id = some bond)
    (clock : bond.value.confirmedAt = none) : id < t.nextId ∧ t.bonds id = some bond := by
  unfold Registry.withdraw at ok
  split at ok
  · obtain ⟨previous,present,ok⟩ := Option.bind_eq_some_iff.mp ok
    have different : id ≠ target := by
      intro same
      subst target
      have equal : previous = bond := Option.some.inj (present.symm.trans found)
      subst previous
      simp [clock] at ok
    cases record : previous.value.confirmedAt with
    | none => simp [record] at ok
    | some atL1 =>
      simp only [record] at ok
      split at ok
      · obtain ⟨rfl,rfl⟩ := Prod.mk.inj (Option.some.inj ok)
        exact ⟨issued,by simp [Registry.updateBond,different,found]⟩
      · cases ok
  · cases ok

theorem execute_retained {s t : RegistryMachine.State} {v : InboxView} {now cutoff id : Nat} {key : Hash}
    {action : Action} (old : Retained s cutoff id key) (time : cutoff < now)
    (snapshot : v.snapshot ≤ cutoff) (normal : NormalAction now action)
    (ok : execute s v now action = some t) : Retained t cutoff id key := by
  unfold execute at ok
  split at ok
  · obtain ⟨u,checked,rfl⟩ := Option.map_eq_some_iff.mp ok
    change Retained u cutoff id key
    cases action with
    | register newKey caller amount pop =>
      simp only at checked
      split at checked
      · obtain ⟨⟨ledger,fresh⟩,registered,rfl⟩ := Option.map_eq_some_iff.mp checked
        obtain ⟨bond,issued,found,key,live,clock,exit⟩ := old
        obtain ⟨kept,ki,kf,kk,kl,kc,ke⟩ := registration_retained registered issued found live clock exit time
        exact ⟨kept,ki,kf,kk.trans key,kl,kc,ke⟩
      · cases checked
    | withdraw target caller to =>
      obtain ⟨⟨ledger,payout⟩,withdrawn,rfl⟩ := Option.map_eq_some_iff.mp checked
      obtain ⟨bond,issued,found,key,live,clock,exit⟩ := old
      have kept := withdrawal_retained withdrawn issued found clock
      exact ⟨bond,kept.1,kept.2,key,live,clock,exit⟩
    | exclude caller selection xs =>
      simp only at checked
      split at checked
      · cases Option.some.inj checked
        obtain ⟨bond,issued,found,key,live,clock,exit⟩ := old
        have same : selection = now := normal
        subst selection
        refine ⟨(if xs.any (fun x => x.1 == id) then
          ⟨Staking.exclude bond.value now,bond.slot⟩ else bond),issued,?_,?_,?_,?_,?_⟩
        · simp only [excludedLedger,found,Option.map_some]
        · split <;> exact key
        · split <;> exact live
        · split <;> exact clock
        · split
          · change cutoff < min bond.value.exitAt now; omega
          · exact exit
      · cases checked
    | recheck caller selection => exact False.elim normal
    | forfeit target caller entry incident deadline =>
      obtain ⟨u,edited,rfl⟩ := Option.map_eq_some_iff.mp checked
      change Retained u cutoff id key
      exact edit_retained old time snapshot edited
    | requestExit _ _ | topUp _ _ _ | activateTopUp _ | confirm _ | slash _ _ _ _ _ =>
      exact edit_retained old time snapshot checked
  · cases ok

private theorem current_selected {s : RegistryMachine.State} {v : InboxView} {now cutoff : Nat}
    (metadata : Metadata s v.snapshot) (head : HeadCurrent s)
    (historyTime : HistoryTime s now) (slots : SlotsIssued s.ledger)
    (early : now ≤ cutoff) (snapshot : v.snapshot ≤ cutoff)
    {entry : Committee.Entry} (member : entry ∈ Finality.registryAt s cutoff)
    (positive : entry.stake ≠ 0) (eligible : cutoff < entry.exitAt) :
    ∃ id, Retained s cutoff id entry.key := by
  have current : entry ∈ entries s := by
    cases history : s.history with
    | nil => simp [Finality.registryAt,RegistryHistory.latestSnapshot,history] at member
    | cons cp rest =>
      have due := Nat.le_trans (historyTime.2 cp (by simp [history])) early
      have same := head cp rest history
      simpa [Finality.registryAt,RegistryHistory.latestSnapshot,history,due,same] using member
  obtain ⟨id,bond,issued,found,equal,principal⟩ := entries_principal slots current positive
  have validMetadata := metadata id bond found
  have exit : cutoff < bond.value.exitAt := by simpa [← equal,Staking.toEntry] using eligible
  have live : bond.value.released = false := by
    cases released : bond.value.released with
    | false => rfl
    | true =>
      have zero := validMetadata.1 released
      rw [zero] at principal
      omega
  have unconfirmed : bond.value.confirmedAt = none := by
    by_cases confirmed : bond.value.confirmedAt = none
    · exact confirmed
    · have covered := validMetadata.2 (Or.inr confirmed)
      omega
  exact ⟨id,bond,issued,found,congrArg Committee.Entry.key equal,live,unconfirmed,exit⟩

/-- In normal execution, every eligible historical selection at or above the actual
landed snapshot retains its lifetime bond, unreleased and unconfirmed. This derives
both statuses from raw Genesis and the real lifecycle; punishment may already have
reduced the balance to zero, so no original-quantity promise is made. -/
theorem selected_unconfirmed {first later : RegistryMachine.World} (run : NormalTrace first later)
    (genesis : Genesis first.registry) {cutoff : Nat} (snapshot : later.inbox.snapshot ≤ cutoff)
    {entry : Committee.Entry} (member : entry ∈ Finality.registryAt later.registry cutoff)
    (positive : entry.stake ≠ 0) (eligible : cutoff < entry.exitAt) :
    ∃ id, Retained later.registry cutoff id entry.key := by
  induction run with
  | refl =>
    simp [Finality.registryAt,RegistryHistory.latestSnapshot,genesis.2.2.2.2.1] at member
  | @call s t v now prior action normal ok ih =>
    by_cases early : now ≤ cutoff
    · let full := NormalTrace.call prior action normal ok
      have issued := trace_history_issued full.project genesis
      have timed : HistoryTime t now := trace_history_time full.project (by
        constructor
        · simp [genesis.2.2.2.2.1,RegistryHistory.Ordered]
        · intro cp mem; rw [genesis.2.2.2.2.1] at mem; cases mem)
      exact current_selected (normal_metadata full genesis) (normal_head full genesis)
        timed issued.1 early snapshot member positive eligible
    · have closed : cutoff < now := by omega
      have raw := Finality.registry_from_raw_prefix (execute_closed_history ok closed)
      rw [raw] at member
      obtain ⟨id,retained⟩ := ih snapshot member
      exact ⟨id,execute_retained retained closed snapshot normal ok⟩
  | frame prior hd hg hi ht htime hs ih =>
    exact ih (Nat.le_trans hs snapshot) member

/-- The committee wrapper consumes the cutoff bound obtained from an authenticated
current-generation ancestry and the actual checkpoint's governing selection snapshot.
Historical committee lists, live/released flags and confirmation flags are not premises. -/
theorem committee_unconfirmed {first later : RegistryMachine.World} (run : NormalTrace first later)
    (genesis : Genesis first.registry) {cfg : Finality.Config} {archive : List Blocks.Header} {h : Nat}
    (unit : 0 < cfg.unit)
    (snapshot : later.inbox.snapshot ≤ Finality.cutoff cfg archive h)
    {entry : Committee.Entry}
    (member : entry ∈ (Consensus.activeAt (Finality.derive cfg later.registry archive) h).members) :
    ∃ id, Retained later.registry (Finality.cutoff cfg archive h) id entry.key := by
  let c := Finality.derive cfg later.registry archive
  let cut := (Consensus.activeAt c h).cutoff
  have chosen : (Consensus.activeAt c h).members =
      Committee.chosen cfg.unit cfg.minimum cut cfg.nMax (Finality.registryAt later.registry cut) := by
    unfold cut Consensus.activeAt
    dsimp only
    split <;> rfl
  change entry ∈ (Consensus.activeAt c h).members at member
  rw [chosen] at member
  have elected := Committee.chosen_eligible cfg.unit cfg.minimum cut cfg.nMax _ entry member
  have positive : entry.stake ≠ 0 := by
    have high := Nat.le_max_right cfg.minimum cfg.unit
    omega
  have cutoffEq : cut = Finality.cutoff cfg archive h := Finality.active_cutoff cfg later.registry archive h
  rw [cutoffEq] at elected
  exact selected_unconfirmed run genesis snapshot elected.1 positive elected.2.2.1

/-- Same-round normal execution strengthens historical funded liability to actual
current-window stake retention. Snapshot order is supplied by the authenticated
candidate/checkpoint ancestry; all bond statuses are derived from the lifecycle. -/
theorem economically_at_risk {env : Protocol.Environment} {registry : RegistryMachine.State}
    {w : Protocol.World} (genesis : Genesis registry) (standard : ProtocolFinality.StandardToken env)
    (self : env.initialToken.allowances env.token.registryAddress env.token.registryAddress = 0)
    (rate : registry.config.slashBountyBps < 10000)
    (run : Protocol.Trace env (Protocol.empty env registry) w)
    (normal : NormalTrace (Protocol.registryWorld env (Protocol.empty env registry)) (Protocol.registryWorld env w))
    (refinement : Finality.SignatureRefinement registry env.signature) (initialized : w.initialized = true)
    (window : env.evidenceWindow ≤ w.registry.registry.config.withdrawalDelay)
    {common moreA moreB : List Blocks.Header} {referenceA referenceB h round a b : Nat}
    {votesA votesB : List Consensus.Vote}
    (snapshot : w.inbox.snapshot ≤ Finality.cutoff (Protocol.config w) (common ++ moreA) h)
    (covered : Finality.requiredPrefix (Protocol.config w) h ≤ common.length)
    (validA : Consensus.CommitValid (Protocol.policy env w (common ++ moreA) referenceA).consensus env.signature h round a votesA)
    (validB : Consensus.CommitValid (Protocol.policy env w (common ++ moreB) referenceB).consensus env.signature h round b votesB)
    (conflict : a ≠ b) :
    AccountableAtRisk env w (Protocol.policy env w (common ++ moreA) referenceA).consensus h votesA votesB := by
  have liability := Economics.economically_accountable genesis standard self rate run refinement initialized
    covered validA validB conflict
  have unit : 0 < w.inbox.configuration.unit := by
    have elected := validA.2.1
    unfold Consensus.ElectionValid Committee.election at elected
    dsimp only at elected
    split at elected
    next allowed => exact allowed.1
    next => cases elected
  refine ⟨liability.1,?_⟩
  intro entry member
  obtain ⟨id,bond,issued,found,key,live,unconfirmed,_⟩ :=
    committee_unconfirmed normal genesis unit snapshot (List.mem_filter.mp member).1
  obtain ⟨_,_,_,_,_,va,inA,vb,inB,keyA,keyB,sa,sb,evidence,_⟩ := liability.2 entry member
  refine ⟨id,bond,issued,found,key,live,unconfirmed,va,inA,vb,inB,keyA,keyB,sa,sb,evidence,?_⟩
  have bondEvidence : RegistryMachine.Evidence w.registry.registry (Protocol.registryView env w) bond.value.key
      (Accountability.evidence va) (Accountability.evidence vb) sa sb := by simpa only [key] using evidence
  simpa only [key] using Economics.retained_window_liability genesis standard self rate run initialized
    issued found live unconfirmed window bondEvidence

end Etna.Design.Current.StakeRisk
