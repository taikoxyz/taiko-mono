import EtnaProofs.CurrentMetadata

namespace Etna.Design.Current.Protocol
set_option maxRecDepth 30000
set_option maxHeartbeats 1000000

/-- A completed snapshot was actually produced by an earlier reachable protocol state.
Later registry, frontier and node changes remain in the retained suffix trace. -/
theorem closed_snapshot_provenance {env : Environment} {registry : RegistryMachine.State} {w : World}
    (run : Trace env (empty env registry) w) :
    ∀ s ∈ w.history, ∃ before, Trace env (empty env registry) before ∧ Trace env before w ∧
      s.inbox = before.inbox ∧ s.start = before.start := by
  induction run with
  | refl => intro s member; cases member
  | @step before after prior change ih =>
    have old : ∀ s ∈ before.history, ∃ earlier,
        Trace env (empty env registry) earlier ∧ Trace env earlier after ∧
        s.inbox = earlier.inbox ∧ s.start = earlier.start := by
      intro s member
      obtain ⟨earlier,reach,later,inbox,start⟩ := ih s member
      exact ⟨earlier,reach,.step later change,inbox,start⟩
    intro s member
    cases effect : Journal.step_effect change with
    | frame _ _ _ history _ => exact old s (history ▸ member)
    | admission _ _ _ _ history _ _ _ => exact old s (history ▸ member)
    | clearing _ _ _ _ history _ => exact old s (history ▸ member)
    | close _ _ _ _ history =>
      rw [history] at member
      rcases List.mem_append.mp member with previous | newly
      · exact old s previous
      · obtain ⟨number,_,rfl⟩ := List.mem_map.mp newly
        exact ⟨before,prior,.step (.refl before) change,rfl,rfl⟩

private theorem execute_unstarted_records {env : Environment} {w t : World} {call : Call}
    (prior : w.start = none → w.inbox.records = []) (ok : execute env w call = some t) :
    t.start = none → t.inbox.records = [] := by
  cases call with
  | advance number =>
    simp only [execute] at ok
    unfold advance at ok
    split at ok
    · cases Option.some.inj ok; exact prior
    · cases ok
  | initializeInbox caller =>
    simp only [execute] at ok
    unfold initializeInbox at ok
    split at ok
    · split at ok
      · split at ok
        · cases Option.some.inj ok; simp [writeStart]
        · cases ok
      · cases Option.some.inj ok; exact prior
    · cases ok
  | setOrigin caller height hash root =>
    simp only [execute] at ok
    unfold setOrigin at ok
    split at ok
    · cases Option.some.inj ok; simp [writeStart]
    · cases ok
  | correctStart caller height hash root =>
    simp only [execute] at ok
    unfold correctStart at ok
    obtain ⟨old,_,ok⟩ := Option.bind_eq_some_iff.mp ok
    split at ok
    · cases Option.some.inj ok; simp [writeStart]
    · cases ok
  | registry caller action =>
    simp only [execute] at ok
    unfold registryCall at ok
    split at ok
    · obtain ⟨result,_,rfl⟩ := Option.map_eq_some_iff.mp ok; exact prior
    · cases ok
  | enqueue raw paid refund =>
    simp only [execute] at ok
    unfold enqueue at ok
    split at ok
    · obtain ⟨inbox,enqueued,rfl⟩ := Option.map_eq_some_iff.mp ok
      unfold Forced.enqueue at enqueued
      dsimp only at enqueued
      split at enqueued
      · cases Option.some.inj enqueued; exact prior
      · cases enqueued
    · cases ok
  | sweep transfer =>
    simp only [execute] at ok
    obtain ⟨inbox,swept,rfl⟩ := Option.map_eq_some_iff.mp ok
    unfold Forced.sweep at swept
    split at swept
    · cases Option.some.inj swept; exact prior
    · cases swept
  | forcedETH amount => cases Option.some.inj ok; exact prior
  | scheduleRules caller rule time | scheduleStop caller time grid =>
    simp only [execute] at ok
    obtain ⟨schedule,_,rfl⟩ := Option.map_eq_some_iff.mp ok; exact prior
  | recover request =>
    simp only [execute] at ok
    unfold recover at ok
    obtain ⟨start,present,ok⟩ := Option.bind_eq_some_iff.mp ok
    cases upgrade : request.upgrade <;> simp only [upgrade,Option.isSome_none,
      Option.isSome_some,Option.getD_none,Option.getD_some,Bool.false_eq_true,ite_true,ite_false] at ok
    all_goals
      split at ok
      · obtain ⟨schedule,_,ok⟩ := Option.bind_eq_some_iff.mp ok
        obtain ⟨registry,_,rfl⟩ := Option.map_eq_some_iff.mp ok
        intro absent
        rw [absent] at present
        cases present
      · cases ok
  | invalidate caller nonce =>
    simp only [execute] at ok
    unfold invalidate at ok
    split at ok
    · cases Option.some.inj ok; exact prior
    · cases ok
  | rollback caller trusted cutoff =>
    simp only [execute] at ok
    unfold rollback at ok
    split at ok
    · obtain ⟨registry,_,rfl⟩ := Option.map_eq_some_iff.mp ok
      intro absent
      simp [prior absent]
    · cases ok
  | land landing =>
    simp only [execute] at ok
    obtain ⟨checks,rfl⟩ := land_success ok
    intro absent
    have started := checks.started
    have absent' : w.start = none := absent
    simp [absent'] at started
  | unzenProve proposal header proof =>
    simp only [execute] at ok
    unfold unzenProve at ok
    split at ok
    · cases Option.some.inj ok; exact prior
    · cases ok
  | image caller image register | verifier caller version =>
    simp only [execute] at ok
    split at ok
    · cases Option.some.inj ok; exact prior
    · cases ok
  | observe number =>
    simp only [execute] at ok
    obtain ⟨s,_,rfl⟩ := Option.map_eq_some_iff.mp ok; exact prior
  | importSnapshot candidate durable =>
    simp only [execute] at ok
    unfold nodeImport at ok
    cases target : w.node.target with
    | none => simp [target] at ok
    | some target =>
      simp only [target] at ok
      split at ok
      · obtain ⟨installed,_,rfl⟩ := Option.map_eq_some_iff.mp ok; exact prior
      · cases ok
  | restart | openSigner _ | switchSigner _ => cases Option.some.inj ok; exact prior
  | sign request signature persisted =>
    simp only [execute] at ok
    obtain ⟨result,_,rfl⟩ := Option.map_eq_some_iff.mp ok; exact prior

/-- No retained landing or generation-origin record predates establishing the start. -/
theorem trace_unstarted_records {env : Environment} {registry : RegistryMachine.State} {w : World}
    (run : Trace env (empty env registry) w) : w.start = none → w.inbox.records = [] := by
  induction run with
  | refl => intro _; rfl
  | @step before after prior change ih =>
    cases change with
    | call call =>
      cases result : execute env before call with
      | none => simpa only [transact,result,Option.getD_none] using ih
      | some after => simpa only [transact,result,Option.getD_some] using execute_unstarted_records ih result
    | node after validated => exact ih

end Etna.Design.Current.Protocol
