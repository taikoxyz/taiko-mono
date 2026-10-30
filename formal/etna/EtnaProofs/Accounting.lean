import EtnaModel.Accounting
import EtnaProofs.Staking
import EtnaProofs.RegistryHistory

namespace Etna.Design.Accounting

theorem bondEffect_project (r : RegistryHistory.State) (inbox : State) (now : Nat)
    (b : Staking.Bond) (action : RegistryHistory.Edit) :
    (bondEffect r inbox now b action).map Prod.fst = RegistryHistory.editBond r inbox now b action := by
  cases action <;> simp [bondEffect,RegistryHistory.editBond,Option.map_map,Function.comp_def]
  split <;> simp [Option.map_map,Function.comp_def]

theorem editEffect_project (s : RegistryHistory.State) (inbox : State) (id now : Nat)
    (action : RegistryHistory.Edit) :
    (editEffect s inbox id now action).map Prod.fst = RegistryHistory.edit s inbox id now action := by
  simp only [editEffect,RegistryHistory.edit]
  split
  · rw [← bondEffect_project]
    simp [Option.map_map,edited,Function.comp_def]
  · rfl

theorem editEffect_lift {s t : RegistryHistory.State} {inbox : State} {id now : Nat}
    {action : RegistryHistory.Edit} (ok : RegistryHistory.edit s inbox id now action = some t) :
    ∃ f, editEffect s inbox id now action = some (t,f) := by
  rw [← editEffect_project] at ok
  obtain ⟨⟨u,f⟩,effect,equal⟩ := Option.map_eq_some_iff.mp ok
  cases equal
  exact ⟨f,effect⟩

theorem attempt_failure {α : Type} (before : α) : attempt before none = (before,Flow.zero) := rfl

theorem failed_edit_zero {s : RegistryHistory.State} {inbox : State} {id now : Nat}
    {action : RegistryHistory.Edit} (failed : RegistryHistory.edit s inbox id now action = none) :
    attempt s (editEffect s inbox id now action) = (s,Flow.zero) := by
  have h : editEffect s inbox id now action = none := by
    rw [← editEffect_project] at failed
    exact Option.map_eq_none_iff.mp failed
  simp [h,attempt]

theorem failed_registration_zero {s : RegistryHistory.State} {key owner amount now : Nat}
    (failed : RegistryHistory.register s key owner amount now = none) :
    attempt s (registerEffect s key owner amount now) = (s,Flow.zero) := by
  simp [registerEffect,failed,attempt]

theorem bondEffect_balance {r : RegistryHistory.State} {inbox : State} {now : Nat}
    {b out : Staking.Bond} {action : RegistryHistory.Edit} {f : Flow}
    (ok : bondEffect r inbox now b action = some (out,f)) :
    out.balance+f.outgoing = b.balance+f.deposits := by
  cases action with
  | requestExit caller =>
    obtain ⟨x,h,equal⟩ := Option.map_eq_some_iff.mp ok
    cases equal
    unfold Staking.requestExit at h
    split at h
    · cases h; rfl
    · contradiction
  | confirm =>
    obtain ⟨x,h,equal⟩ := Option.map_eq_some_iff.mp ok
    cases equal
    unfold Staking.confirmExit at h
    split at h
    · cases record : b.confirmedAt <;> simp only [record] at h <;> cases h <;> rfl
    · contradiction
  | withdraw caller =>
    obtain ⟨⟨x,amount⟩,h,equal⟩ := Option.map_eq_some_iff.mp ok
    cases equal
    obtain ⟨amountEq,zero,_,_⟩ := Staking.withdrawal_clears_principal h
    simp [Flow.outgoing,zero,amountEq]
  | topUp caller amount =>
    obtain ⟨x,h,equal⟩ := Option.map_eq_some_iff.mp ok
    cases equal
    simpa [Flow.outgoing] using (Staking.top_up_accounting h).2.2.2.2.2.1
  | activateTopUp =>
    obtain ⟨x,h,equal⟩ := Option.map_eq_some_iff.mp ok
    cases equal
    simpa [Flow.outgoing,Flow.zero] using (Staking.activation_preserves_principal h).2.2.1
  | forfeit key incident validUntil timestamp owner externalOK =>
    obtain ⟨⟨x,penalty⟩,h,equal⟩ := Option.map_eq_some_iff.mp ok
    cases equal
    simpa [Flow.outgoing] using (Staking.forfeit_conserves_principal h).2.2.1
  | slash a v sigA sigB =>
    simp only [bondEffect] at ok
    split at ok
    · obtain ⟨⟨x,bounty,sink⟩,h,equal⟩ := Option.map_eq_some_iff.mp ok
      cases equal
      obtain ⟨total,zero,_,_⟩ := Staking.double_sign_entire_balance h
      simp [Flow.outgoing,zero,total]
    · contradiction
  | forceExit =>
    simp only [bondEffect] at ok
    split at ok
    · cases ok; rfl
    · contradiction
  | recheck snapshot =>
    cases ok
    simp only [Flow.outgoing,Flow.zero,Nat.add_zero]
    unfold Staking.rollbackBySnapshot
    cases b.confirmedAt <;> simp only
    split <;> rfl

theorem bondEffect_released_zero {r : RegistryHistory.State} {inbox : State} {now : Nat}
    {b out : Staking.Bond} {action : RegistryHistory.Edit} {f : Flow}
    (zero : b.released = true → b.balance = 0)
    (ok : bondEffect r inbox now b action = some (out,f)) :
    out.released = true → out.balance = 0 := by
  have projected : RegistryHistory.editBond r inbox now b action = some out := by
    rw [← bondEffect_project,ok]; rfl
  cases action with
  | requestExit caller =>
    simp only [RegistryHistory.editBond] at projected
    unfold Staking.requestExit at projected
    split at projected
    · cases projected; exact zero
    · contradiction
  | confirm =>
    simp only [RegistryHistory.editBond] at projected
    unfold Staking.confirmExit at projected
    split at projected
    · cases record : b.confirmedAt <;> simp only [record] at projected <;> cases projected <;> exact zero
    · contradiction
  | withdraw caller =>
    obtain ⟨⟨x,amount⟩,h,equal⟩ := Option.map_eq_some_iff.mp projected
    cases equal
    intro _
    exact (Staking.withdrawal_clears_principal h).2.1
  | topUp caller amount =>
    simp only [RegistryHistory.editBond] at projected
    unfold Staking.topUp at projected
    split at projected
    · rename_i guard
      cases projected
      intro released
      have := guard.2.2.1
      simp_all
    · contradiction
  | activateTopUp =>
    simp only [RegistryHistory.editBond] at projected
    unfold Staking.activateTopUp at projected
    split at projected
    · rename_i guard
      cases projected
      intro released
      have := guard.2.1
      simp_all
    · contradiction
  | forfeit key incident validUntil timestamp owner externalOK =>
    obtain ⟨⟨x,penalty⟩,h,equal⟩ := Option.map_eq_some_iff.mp projected
    cases equal
    have checks := Staking.forfeit_execution_checks h
    unfold Staking.forfeit at h
    split at h
    · cases h
      intro released
      have live := checks.2.2.2.1
      simp_all
    · contradiction
  | slash a v sigA sigB =>
    simp only [RegistryHistory.editBond] at projected
    split at projected
    · obtain ⟨⟨x,bounty,sink⟩,h,equal⟩ := Option.map_eq_some_iff.mp projected
      cases equal
      intro _
      exact (Staking.double_sign_entire_balance h).2.1
    · contradiction
  | forceExit =>
    simp only [RegistryHistory.editBond] at projected
    split at projected
    · cases projected; exact zero
    · contradiction
  | recheck snapshot =>
    cases projected
    unfold Staking.rollbackBySnapshot
    cases b.confirmedAt with
    | none => exact zero
    | some _ =>
      by_cases h : snapshot < b.exitAt <;> simpa [h,Staking.Bond.balance] using zero

theorem sumBalances_congr {f g : Nat → Nat} {n : Nat}
    (same : ∀ i, i < n → f i = g i) : sumBalances f n = sumBalances g n := by
  induction n with
  | zero => rfl
  | succ n ih =>
    simp only [sumBalances,ih (fun i range => same i (by omega)),same n (by omega)]

theorem sumBalances_update (f : Nat → Nat) (n id value : Nat) (bound : id < n) :
    sumBalances (fun i => if i = id then value else f i) n+f id = sumBalances f n+value := by
  induction n with
  | zero => omega
  | succ n ih =>
    by_cases same : n = id
    · subst id
      have eq : sumBalances (fun i => if i = n then value else f i) n = sumBalances f n :=
        sumBalances_congr (fun i range => by simp [show i ≠ n by omega])
      simp [sumBalances,eq]
      omega
    · have h := ih (by omega)
      simp only [sumBalances,ite_eq_right same]
      omega

theorem editEffect_success {s t : RegistryHistory.State} {inbox : State} {id now : Nat}
    {action : RegistryHistory.Edit} {f : Flow}
    (ok : editEffect s inbox id now action = some (t,f)) :
    id < s.nextId ∧ ∃ b, bondEffect s inbox now (s.slots id) action = some (b,f) ∧
      t = edited s id now action b := by
  unfold editEffect at ok
  split at ok
  · rename_i guard
    obtain ⟨⟨b,g⟩,h,equal⟩ := Option.map_eq_some_iff.mp ok
    cases equal
    exact ⟨guard.1,b,h,rfl⟩
  · contradiction

theorem editEffect_conserves {s t : RegistryHistory.State} {inbox : State} {id now : Nat}
    {action : RegistryHistory.Edit} {f : Flow}
    (ok : editEffect s inbox id now action = some (t,f)) :
    held t+f.outgoing = held s+f.deposits := by
  obtain ⟨bound,b,localStep,rfl⟩ := editEffect_success ok
  have localBalance := bondEffect_balance localStep
  have globalBalance := sumBalances_update (fun i => (s.slots i).balance) s.nextId id b.balance bound
  change sumBalances (fun i => (if i = id then b else s.slots i).balance) s.nextId+f.outgoing = _
  have eq : (fun i => (if i = id then b else s.slots i).balance) =
      (fun i => if i = id then b.balance else (s.slots i).balance) := by
    funext i; split <;> rfl
  rw [eq]
  unfold held
  omega

theorem editEffect_preserves_released_zero {s t : RegistryHistory.State} {inbox : State}
    {id now : Nat} {action : RegistryHistory.Edit} {f : Flow}
    (zero : ReleasedZero s) (ok : editEffect s inbox id now action = some (t,f)) : ReleasedZero t := by
  obtain ⟨_,b,localStep,rfl⟩ := editEffect_success ok
  intro i released
  by_cases same : i = id
  · subst i
    have localReleased : b.released = true := by
      simpa [edited,RegistryHistory.finish,RegistryHistory.writeSlot] using released
    simpa [edited,RegistryHistory.finish,RegistryHistory.writeSlot] using
      bondEffect_released_zero (zero id) localStep localReleased
  · simpa [edited,RegistryHistory.finish,RegistryHistory.writeSlot,same] using
      zero i (by simpa [edited,RegistryHistory.finish,RegistryHistory.writeSlot,same] using released)

theorem register_preserves_released_zero {s t : RegistryHistory.State} {key owner amount now : Nat}
    (zero : ReleasedZero s) (ok : RegistryHistory.register s key owner amount now = some t) :
    ReleasedZero t := by
  unfold RegistryHistory.register at ok
  split at ok
  · cases ok
    intro i released
    by_cases same : i = (RegistryHistory.allocation s).1
    · simp only [RegistryHistory.allocation] at same
      simp [RegistryHistory.finish,RegistryHistory.writeSlot,same] at released
    · simp only [RegistryHistory.allocation] at same
      simpa [RegistryHistory.finish,RegistryHistory.writeSlot,RegistryHistory.allocation,same] using
        zero i (by simpa [RegistryHistory.finish,RegistryHistory.writeSlot,RegistryHistory.allocation,same] using released)
  · contradiction

theorem register_conserves {s t : RegistryHistory.State} {key owner amount now : Nat}
    (zero : ReleasedZero s) (ok : RegistryHistory.register s key owner amount now = some t) :
    held t = held s+amount := by
  unfold RegistryHistory.register at ok
  split at ok
  · rename_i allowed
    rcases allowed with ⟨_,_,_,_,_,_,_,bound,_,released⟩
    have priorZero := zero (RegistryHistory.allocation s).1 released
    cases ok
    change sumBalances (fun i => (if i = (RegistryHistory.allocation s).1 then
      (⟨key,owner,amount,now+s.activationDelay,Staking.noExit,false,none,0,0⟩ : Staking.Bond)
      else s.slots i).balance) (RegistryHistory.allocation s).2.2 = held s+amount
    have balances : (fun i => (if i = (RegistryHistory.allocation s).1 then
      (⟨key,owner,amount,now+s.activationDelay,Staking.noExit,false,none,0,0⟩ : Staking.Bond)
      else s.slots i).balance) =
      (fun i => if i = (RegistryHistory.allocation s).1 then amount else (s.slots i).balance) := by
      funext i; split <;> rfl
    rw [balances]
    cases free : s.free with
    | nil =>
      simp only [RegistryHistory.allocation,free] at bound priorZero ⊢
      have same : sumBalances (fun i => if i = s.nextId then amount else (s.slots i).balance) s.nextId = held s :=
        sumBalances_congr (fun i range => by simp [show i ≠ s.nextId by omega])
      simp [sumBalances,same]
    | cons id rest =>
      simp only [RegistryHistory.allocation,free] at bound priorZero ⊢
      have total := sumBalances_update (fun i => (s.slots i).balance) s.nextId id amount bound
      simpa [priorZero,held] using total
  · contradiction

theorem rollback_bond_principal (b : Staking.Bond) (snapshot : Nat) :
    (Staking.rollbackBySnapshot snapshot b).balance = b.balance ∧
    (Staking.rollbackBySnapshot snapshot b).released = b.released := by
  unfold Staking.rollbackBySnapshot
  cases b.confirmedAt with
  | none => exact ⟨rfl,rfl⟩
  | some _ => by_cases h : snapshot < b.exitAt <;> simp [h,Staking.Bond.balance]

theorem recheck_conserves (s : RegistryHistory.State) (snapshot : Nat) :
    held (RegistryHistory.recheckAll s snapshot) = held s :=
  sumBalances_congr (fun i _ => (rollback_bond_principal (s.slots i) snapshot).1)

theorem recheck_preserves_released_zero (s : RegistryHistory.State) (snapshot : Nat)
    (zero : ReleasedZero s) : ReleasedZero (RegistryHistory.recheckAll s snapshot) := by
  intro id released
  have facts := rollback_bond_principal (s.slots id) snapshot
  rw [show ((RegistryHistory.recheckAll s snapshot).slots id).balance = (s.slots id).balance from facts.1]
  exact zero id (facts.2 ▸ released)

theorem exclusions_conserve (s : RegistryHistory.State) (xs : List Recovery.Exclusion) (now : Nat) :
    held (RegistryHistory.forceExclusions s xs now) = held s := by
  apply sumBalances_congr
  intro i _
  change (if Recovery.exclusionApplies xs i (s.slots i).key then Staking.exclude (s.slots i) now else s.slots i).balance = _
  split <;> rfl

theorem exclusions_preserve_released_zero (s : RegistryHistory.State) (xs : List Recovery.Exclusion)
    (now : Nat) (zero : ReleasedZero s) : ReleasedZero (RegistryHistory.forceExclusions s xs now) := by
  intro id released
  by_cases applies : Recovery.exclusionApplies xs id (s.slots id).key
  · simpa [RegistryHistory.forceExclusions,RegistryHistory.finish,applies,Staking.exclude,Staking.Bond.balance] using
      zero id (by simpa [RegistryHistory.forceExclusions,RegistryHistory.finish,applies,Staking.exclude,Staking.Bond.balance] using released)
  · simpa [RegistryHistory.forceExclusions,RegistryHistory.finish,applies] using
      zero id (by simpa [RegistryHistory.forceExclusions,RegistryHistory.finish,applies] using released)

theorem empty_released_zero : ReleasedZero RegistryHistory.empty := by
  intro id _; rfl

theorem registry_step_preserves_released_zero {s t : RegistryHistory.State}
    (zero : ReleasedZero s) (change : RegistryHistory.Step s t) : ReleasedZero t := by
  cases change with
  | registration ok => exact register_preserves_released_zero zero ok
  | modification ok =>
    obtain ⟨f,effect⟩ := editEffect_lift ok
    exact editEffect_preserves_released_zero zero effect
  | rollback snapshot => exact recheck_preserves_released_zero _ snapshot zero

theorem released_zero_from_empty {s : RegistryHistory.State} (run : RegistryHistory.Trace RegistryHistory.empty s) :
    ReleasedZero s := by
  induction run with
  | refl => exact empty_released_zero
  | step prior change ih => exact registry_step_preserves_released_zero ih change

theorem empty_slot_good : SlotGood RegistryHistory.empty :=
  ⟨empty_released_zero,fun _ _ => rfl⟩

theorem register_preserves_unallocated_zero {s t : RegistryHistory.State} {key owner amount now : Nat}
    (zero : UnallocatedZero s) (ok : RegistryHistory.register s key owner amount now = some t) :
    UnallocatedZero t := by
  have monotone : s.nextId ≤ (RegistryHistory.allocation s).2.2 := by
    cases free : s.free <;> simp [RegistryHistory.allocation,free]
  unfold RegistryHistory.register at ok
  split at ok
  · rename_i allowed
    rcases allowed with ⟨_,_,_,_,_,_,_,bound,_,_⟩
    cases ok
    intro i outside
    change (RegistryHistory.allocation s).2.2 ≤ i at outside
    change (RegistryHistory.allocation s).1 < (RegistryHistory.allocation s).2.2 at bound
    have same : i ≠ (RegistryHistory.allocation s).1 := by omega
    change (if i = (RegistryHistory.allocation s).1 then
      (⟨key,owner,amount,now+s.activationDelay,Staking.noExit,false,none,0,0⟩ : Staking.Bond)
      else s.slots i).balance = 0
    rw [ite_eq_right same]
    exact zero i (by omega)
  · contradiction

theorem editEffect_preserves_unallocated_zero {s t : RegistryHistory.State} {inbox : State}
    {id now : Nat} {action : RegistryHistory.Edit} {f : Flow}
    (zero : UnallocatedZero s) (ok : editEffect s inbox id now action = some (t,f)) : UnallocatedZero t := by
  obtain ⟨bound,b,_,rfl⟩ := editEffect_success ok
  intro i outside
  change s.nextId ≤ i at outside
  have same : i ≠ id := by omega
  change (if i = id then b else s.slots i).balance = 0
  rw [ite_eq_right same]
  exact zero i outside

theorem recheck_preserves_unallocated_zero (s : RegistryHistory.State) (snapshot : Nat)
    (zero : UnallocatedZero s) : UnallocatedZero (RegistryHistory.recheckAll s snapshot) := by
  intro id outside
  exact (rollback_bond_principal (s.slots id) snapshot).1.trans (zero id outside)

theorem exclusions_preserve_unallocated_zero (s : RegistryHistory.State) (xs : List Recovery.Exclusion)
    (now : Nat) (zero : UnallocatedZero s) : UnallocatedZero (RegistryHistory.forceExclusions s xs now) := by
  intro id outside
  change s.nextId ≤ id at outside
  change (if Recovery.exclusionApplies xs id (s.slots id).key then
    Staking.exclude (s.slots id) now else s.slots id).balance = 0
  split <;> exact zero id outside

theorem registry_step_preserves_slot_good {s t : RegistryHistory.State}
    (good : SlotGood s) (change : RegistryHistory.Step s t) : SlotGood t := by
  refine ⟨registry_step_preserves_released_zero good.1 change,?_⟩
  cases change with
  | registration ok => exact register_preserves_unallocated_zero good.2 ok
  | modification ok =>
    obtain ⟨f,effect⟩ := editEffect_lift ok
    exact editEffect_preserves_unallocated_zero good.2 effect
  | rollback snapshot => exact recheck_preserves_unallocated_zero _ snapshot good.2

theorem slot_good_from_empty {s : RegistryHistory.State} (run : RegistryHistory.Trace RegistryHistory.empty s) :
    SlotGood s := by
  induction run with
  | refl => exact empty_slot_good
  | step prior change ih => exact registry_step_preserves_slot_good ih change

theorem future_trace_preserves_slot_good {first s : RegistryHistory.State} {cutoff : Nat}
    (good : SlotGood first) (run : RegistryHistory.FutureTrace cutoff first s) : SlotGood s := by
  induction run with
  | refl => exact good
  | registration prior past ok ih =>
    exact ⟨register_preserves_released_zero ih.1 ok,register_preserves_unallocated_zero ih.2 ok⟩
  | modification prior past ok ih =>
    obtain ⟨f,effect⟩ := editEffect_lift ok
    exact ⟨editEffect_preserves_released_zero ih.1 effect,editEffect_preserves_unallocated_zero ih.2 effect⟩
  | recovery xs now prior past ih =>
    exact ⟨exclusions_preserve_released_zero _ xs now ih.1,exclusions_preserve_unallocated_zero _ xs now ih.2⟩
  | rollback snapshot prior ih =>
    exact ⟨recheck_preserves_released_zero _ snapshot ih.1,recheck_preserves_unallocated_zero _ snapshot ih.2⟩

theorem step_project {w t : ProtocolState.World} {f : Flow} (change : Step w t f) :
    w = t ∨ ProtocolState.Step w t := by
  cases change with
  | rejectedCall _ => exact Or.inl rfl
  | landing time ok => exact Or.inr (.landing time ok)
  | registration time ok => exact Or.inr (.registration time ok)
  | modification time callable ok =>
    have projected := congrArg (Option.map Prod.fst) ok
    rw [editEffect_project] at projected
    exact Or.inr (.modification time callable projected)
  | enqueue time blockRange timestampRange ok => exact Or.inr (.enqueue time blockRange timestampRange ok)
  | sweep time ok => exact Or.inr (.sweep time ok)
  | recovery time ok => exact Or.inr (.recovery time ok)
  | invalidation time ok => exact Or.inr (.invalidation time ok)
  | rollback trusted snapshot now time retained authorized => exact Or.inr (.rollback trusted snapshot now time retained authorized)

theorem step_lift {w t : ProtocolState.World} (change : ProtocolState.Step w t) : ∃ f, Step w t f := by
  cases change with
  | landing time ok => exact ⟨_,.landing time ok⟩
  | registration time ok => exact ⟨_,.registration time ok⟩
  | modification time callable ok =>
    obtain ⟨f,effect⟩ := editEffect_lift ok
    exact ⟨f,.modification time callable effect⟩
  | enqueue time blockRange timestampRange ok => exact ⟨_,.enqueue time blockRange timestampRange ok⟩
  | sweep time ok => exact ⟨_,.sweep time ok⟩
  | recovery time ok => exact ⟨_,.recovery time ok⟩
  | invalidation time ok => exact ⟨_,.invalidation time ok⟩
  | rollback trusted snapshot now time retained authorized => exact ⟨_,.rollback trusted snapshot now time retained authorized⟩

theorem trace_project {first last : ProtocolState.World} {f : Flow} (run : Trace first last f) :
    ProtocolState.Trace first last := by
  induction run with
  | refl => exact .refl _
  | step prior change ih =>
    rcases step_project change with same | projected
    · cases same; exact ih
    · exact .step ih projected

theorem trace_lift {first last : ProtocolState.World} (run : ProtocolState.Trace first last) :
    ∃ f, Trace first last f := by
  induction run with
  | refl => exact ⟨_,.refl _⟩
  | step prior change ih =>
    obtain ⟨f,observed⟩ := ih
    obtain ⟨g,observedStep⟩ := step_lift change
    exact ⟨_,.step observed observedStep⟩

theorem step_preserves_released_zero {w t : ProtocolState.World} {f : Flow}
    (zero : ReleasedZero w.registry) (change : Step w t f) : ReleasedZero t.registry := by
  cases change with
  | rejectedCall _ => exact zero
  | registration _ ok => exact register_preserves_released_zero zero ok
  | modification _ _ ok => exact editEffect_preserves_released_zero zero ok
  | recovery _ _ => exact exclusions_preserve_released_zero _ _ _ zero
  | rollback _ _ _ _ _ _ => exact recheck_preserves_released_zero _ _ zero
  | landing _ _ | enqueue _ _ _ _ | sweep _ _ | invalidation _ _ => exact zero

theorem step_preserves_slot_good {w t : ProtocolState.World} {f : Flow}
    (good : SlotGood w.registry) (change : Step w t f) : SlotGood t.registry := by
  refine ⟨step_preserves_released_zero good.1 change,?_⟩
  cases change with
  | rejectedCall _ => exact good.2
  | registration _ ok => exact register_preserves_unallocated_zero good.2 ok
  | modification _ _ ok => exact editEffect_preserves_unallocated_zero good.2 ok
  | recovery _ _ => exact exclusions_preserve_unallocated_zero _ _ _ good.2
  | rollback _ _ _ _ _ _ => exact recheck_preserves_unallocated_zero _ _ good.2
  | landing _ _ | enqueue _ _ _ _ | sweep _ _ | invalidation _ _ => exact good.2

theorem step_conserves {w t : ProtocolState.World} {f : Flow}
    (zero : ReleasedZero w.registry) (change : Step w t f) :
    held t.registry+f.outgoing = held w.registry+f.deposits := by
  cases change with
  | rejectedCall _ => rfl
  | registration _ ok => exact register_conserves zero ok
  | modification _ _ ok => exact editEffect_conserves ok
  | recovery _ _ => exact exclusions_conserve _ _ _
  | rollback _ _ _ _ _ _ => exact recheck_conserves _ _
  | landing _ _ | enqueue _ _ _ _ | sweep _ _ | invalidation _ _ => rfl

theorem trace_preserves_released_zero {first last : ProtocolState.World} {f : Flow}
    (zero : ReleasedZero first.registry) (run : Trace first last f) : ReleasedZero last.registry := by
  induction run with
  | refl => exact zero
  | step prior change ih => exact step_preserves_released_zero ih change

theorem trace_preserves_slot_good {first last : ProtocolState.World} {f : Flow}
    (good : SlotGood first.registry) (run : Trace first last f) : SlotGood last.registry := by
  induction run with
  | refl => exact good
  | step prior change ih => exact step_preserves_slot_good ih change

/-- Whole-trajectory logical principal conservation. Initial endowment is exactly the
initial allocated effective-plus-pending principal. Neither custody nor a conservation
equation is assumed: receipts are derived from inputs and actual operation returns. -/
theorem trajectory_conservation {first last : ProtocolState.World} {f : Flow}
    (zero : ReleasedZero first.registry) (run : Trace first last f) :
    held first.registry+f.deposits =
      held last.registry+f.withdrawals+f.bounty+f.sink := by
  induction run with
  | refl => simp [Flow.zero]
  | step prior change ih =>
    have localBalance := step_conserves (trace_preserves_released_zero zero prior) change
    simp only [Flow.add,Flow.outgoing] at localBalance ⊢
    omega

/-- Every original machine trace has an accounting refinement satisfying conservation. -/
theorem protocol_trajectory_conservation {first last : ProtocolState.World}
    (zero : ReleasedZero first.registry) (run : ProtocolState.Trace first last) :
    ∃ f, Trace first last f ∧ held first.registry+f.deposits =
      held last.registry+f.withdrawals+f.bounty+f.sink := by
  obtain ⟨f,observed⟩ := trace_lift run
  exact ⟨f,observed,trajectory_conservation zero observed⟩

theorem protocol_trace_preserves_slot_good {first last : ProtocolState.World}
    (good : SlotGood first.registry) (run : ProtocolState.Trace first last) : SlotGood last.registry := by
  obtain ⟨f,observed⟩ := trace_lift run
  exact trace_preserves_slot_good good observed

theorem protocol_slot_good_from_empty {first last : ProtocolState.World}
    (initial : first.registry = RegistryHistory.empty) (run : ProtocolState.Trace first last) :
    SlotGood last.registry := by
  apply protocol_trace_preserves_slot_good (run := run)
  rw [initial]
  exact empty_slot_good

/-- With an empty initial registry, no separate principal endowment or slot invariant
is assumed: deposits alone cover final liabilities and all cumulative payouts. -/
theorem protocol_conservation_from_empty {first last : ProtocolState.World}
    (initial : first.registry = RegistryHistory.empty) (run : ProtocolState.Trace first last) :
    ∃ f, Trace first last f ∧ SlotGood last.registry ∧
      f.deposits = held last.registry+f.withdrawals+f.bounty+f.sink := by
  have zero : ReleasedZero first.registry := by rw [initial]; exact empty_released_zero
  obtain ⟨f,observed,conserved⟩ := protocol_trajectory_conservation zero run
  refine ⟨f,observed,protocol_slot_good_from_empty initial run,?_⟩
  simpa [initial,held,RegistryHistory.empty,sumBalances] using conserved

end Etna.Design.Accounting
