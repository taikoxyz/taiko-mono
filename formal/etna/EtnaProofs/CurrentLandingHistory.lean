import EtnaModel.CurrentGovernance
import EtnaProofs.CurrentCustody
import EtnaProofs.CurrentCoherentCustody

/-! Retained landing events come from their actual accepted calls. Certification judges each
call's full statement, including its saved snapshot and SignalService root. -/
namespace Etna.Design.Current.Protocol.Governance

set_option maxRecDepth 30000
set_option maxHeartbeats 2000000

private theorem write_start_records (w : World) (height hash root block time generation : Nat) :
    ∀ cp ∈ (writeStart w height hash root block time generation).activeRecords,
      StartRecord (writeStart w height hash root block time generation) cp := by
  intro cp member
  have same : cp = ⟨height,hash,0,0,generation,height⟩ := by
    simpa [writeStart] using member
  subst cp
  exact ⟨⟨height,hash,root⟩,rfl,rfl,rfl,rfl,rfl⟩

private theorem execute_landing_effect {env : Environment} {w t : World} {call : Call}
    (ok : Protocol.execute env w call = some t) :
    (t.start = w.start ∧ t.activeRecords = w.activeRecords ∧
      t.activeLandings = w.activeLandings) ∨
    (t.activeLandings = [] ∧ ∀ cp ∈ t.activeRecords, StartRecord t cp) ∨
    (∃ a, land env w a = some t) ∨
    (∃ height, t.start = w.start ∧
      t.activeRecords = w.activeRecords.filter (fun cp => cp.height ≤ height) ∧
      t.activeLandings = w.activeLandings.filter
        (fun event => event.landing.input.lastHeight ≤ height)) := by
  cases call with
  | advance number =>
    change advance env w number = some t at ok
    unfold advance at ok
    split at ok
    next => cases Option.some.inj ok; exact Or.inl ⟨rfl,rfl,rfl⟩
    next => cases ok
  | initializeInbox caller =>
    change initializeInbox env w caller = some t at ok
    unfold initializeInbox at ok
    split at ok
    next =>
      split at ok
      next =>
        split at ok
        next =>
          cases Option.some.inj ok
          refine Or.inr (Or.inl ⟨rfl,?_⟩)
          intro cp member
          have same : cp = ⟨0,env.genesisHeader.elHash,0,0,0,0⟩ := by
            simpa only [writeStart,List.mem_singleton] using member
          subst cp
          exact ⟨⟨0,env.genesisHeader.elHash,env.genesisHeader.stateRoot⟩,
            rfl,rfl,rfl,rfl,rfl⟩
        next => cases ok
      next => cases Option.some.inj ok; exact Or.inl ⟨rfl,rfl,rfl⟩
    next => cases ok
  | setOrigin caller height hash root =>
    change setOrigin env w caller height hash root = some t at ok
    unfold setOrigin at ok
    split at ok
    next =>
      cases Option.some.inj ok
      exact Or.inr (Or.inl ⟨rfl,
        write_start_records w height hash root w.number (env.time w.number) 0⟩)
    next => cases ok
  | correctStart caller height hash root =>
    change correctStart env w caller height hash root = some t at ok
    unfold correctStart at ok
    obtain ⟨old,_,ok⟩ := Option.bind_eq_some_iff.mp ok
    split at ok
    next =>
      cases Option.some.inj ok
      exact Or.inr (Or.inl ⟨rfl,
        write_start_records w height hash root w.number (env.time w.number) (w.inbox.generation+1)⟩)
    next => cases ok
  | registry caller action =>
    change registryCall env w caller action = some t at ok
    unfold registryCall at ok
    split at ok
    next =>
      obtain ⟨result,_,rfl⟩ := Option.map_eq_some_iff.mp ok
      exact Or.inl ⟨rfl,rfl,rfl⟩
    next => cases ok
  | enqueue raw paid refund =>
    change enqueue env w raw paid refund = some t at ok
    unfold enqueue at ok
    split at ok
    next =>
      obtain ⟨inbox,inner,rfl⟩ := Option.map_eq_some_iff.mp ok
      unfold Forced.enqueue at inner
      dsimp only at inner
      split at inner
      next => cases Option.some.inj inner; exact Or.inl ⟨rfl,rfl,rfl⟩
      next => cases inner
    next => cases ok
  | sweep transfer =>
    change sweep w transfer = some t at ok
    obtain ⟨inbox,inner,rfl⟩ := Option.map_eq_some_iff.mp ok
    unfold Forced.sweep at inner
    split at inner
    next => cases Option.some.inj inner; exact Or.inl ⟨rfl,rfl,rfl⟩
    next => cases inner
  | forcedETH amount =>
    cases Option.some.inj ok
    exact Or.inl ⟨rfl,rfl,rfl⟩
  | scheduleRules caller rule time =>
    change scheduleRules env w caller rule time = some t at ok
    obtain ⟨schedule,_,rfl⟩ := Option.map_eq_some_iff.mp ok
    exact Or.inl ⟨rfl,rfl,rfl⟩
  | scheduleStop caller time =>
    change scheduleStop env w caller time = some t at ok
    obtain ⟨schedule,_,rfl⟩ := Option.map_eq_some_iff.mp ok
    exact Or.inl ⟨rfl,rfl,rfl⟩
  | recover request =>
    change recover env w request = some t at ok
    unfold recover at ok
    obtain ⟨start,_,ok⟩ := Option.bind_eq_some_iff.mp ok
    dsimp only at ok
    cases upgrade : request.upgrade <;>
      simp only [upgrade,Option.isSome_none,Option.isSome_some,Option.getD_none,
        Option.getD_some,Bool.false_eq_true,↓reduceIte] at ok
    all_goals
      split at ok
      next =>
        obtain ⟨schedule,_,ok⟩ := Option.bind_eq_some_iff.mp ok
        obtain ⟨registry,_,rfl⟩ := Option.map_eq_some_iff.mp ok
        exact Or.inl ⟨rfl,rfl,rfl⟩
      next => cases ok
  | invalidate caller nonce =>
    change invalidate env w caller nonce = some t at ok
    unfold invalidate at ok
    split at ok
    next => cases Option.some.inj ok; exact Or.inl ⟨rfl,rfl,rfl⟩
    next => cases ok
  | rollback caller trusted snapshot =>
    change rollback env w caller trusted snapshot = some t at ok
    unfold rollback at ok
    split at ok
    next =>
      obtain ⟨registry,_,rfl⟩ := Option.map_eq_some_iff.mp ok
      exact Or.inr (Or.inr (Or.inr ⟨trusted.height,rfl,rfl,rfl⟩))
    next => cases ok
  | land a => exact Or.inr (Or.inr (Or.inl ⟨a,ok⟩))
  | unzenProve proposal header proof =>
    change unzenProve env w proposal header proof = some t at ok
    unfold unzenProve at ok
    split at ok
    next => cases Option.some.inj ok; exact Or.inl ⟨rfl,rfl,rfl⟩
    next => cases ok
  | image caller image register | verifier caller version =>
    simp only [Protocol.execute] at ok
    split at ok
    next => cases Option.some.inj ok; exact Or.inl ⟨rfl,rfl,rfl⟩
    next => cases ok
  | observe number =>
    change observe env w number = some t at ok
    obtain ⟨s,_,rfl⟩ := Option.map_eq_some_iff.mp ok
    exact Or.inl ⟨rfl,rfl,rfl⟩
  | importSnapshot candidate durable =>
    change nodeImport env w candidate durable = some t at ok
    unfold nodeImport at ok
    split at ok
    next => cases ok
    next =>
      split at ok
      next =>
        obtain ⟨installed,_,rfl⟩ := Option.map_eq_some_iff.mp ok
        exact Or.inl ⟨rfl,rfl,rfl⟩
      next => cases ok
  | restart | openSigner _ | switchSigner _ =>
    cases Option.some.inj ok
    exact Or.inl ⟨rfl,rfl,rfl⟩
  | sign message signature persisted =>
    obtain ⟨result,_,rfl⟩ := Option.map_eq_some_iff.mp ok
    exact Or.inl ⟨rfl,rfl,rfl⟩

private theorem start_record_transport {w t : World} {cp : Checkpoint}
    (same : t.start = w.start) (start : StartRecord w cp) : StartRecord t cp := by
  simpa only [StartRecord,same] using start

private theorem trace_landing_sources {env : Environment} {registry : RegistryMachine.State}
    {w : World} (trace : Trace env (empty env registry) w) :
    (∀ event ∈ w.activeLandings, ∃ before after,
      Trace env (empty env registry) before ∧ land env before event.landing = some after ∧
      event.inbox = before.inbox ∧ event.history = before.history) ∧
    (∀ cp ∈ w.activeRecords, StartRecord w cp ∨
      ∃ event ∈ w.activeLandings, event.checkpoint = cp) := by
  induction trace with
  | refl => simp [empty]
  | @step previous current prior change ih =>
    cases change with
    | node after verified => exact ih
    | call call =>
      cases ok : Protocol.execute env previous call with
      | none => simpa only [Protocol.transact,ok,Option.getD_none] using ih
      | some t =>
        change (∀ event ∈ (Protocol.transact env previous call).activeLandings, _) ∧ _
        simp only [Protocol.transact,ok,Option.getD_some]
        rcases execute_landing_effect ok with frame | start | landing | rollback
        · obtain ⟨same,records,events⟩ := frame
          refine ⟨?_,?_⟩
          · simpa only [events] using ih.1
          · intro cp member
            rcases ih.2 cp (records ▸ member) with root | ⟨event,member,matching⟩
            · exact Or.inl (start_record_transport same root)
            · exact Or.inr ⟨event,events ▸ member,matching⟩
        · refine ⟨?_,fun cp member => Or.inl (start.2 cp member)⟩
          intro event member
          rw [start.1] at member
          cases member
        · obtain ⟨a,accepted⟩ := landing
          obtain ⟨_,rfl⟩ := land_success accepted
          refine ⟨?_,?_⟩
          · intro event member
            rcases List.mem_cons.mp member with fresh | old
            · subst event
              exact ⟨previous,landed previous a,prior,accepted,rfl,rfl⟩
            · exact ih.1 event old
          · intro cp member
            rcases List.mem_cons.mp member with fresh | old
            · exact Or.inr ⟨⟨previous.inbox,previous.history,a⟩,
                List.mem_cons_self,fresh.symm⟩
            · rcases ih.2 cp old with root | ⟨event,member,matching⟩
              · exact Or.inl root
              · exact Or.inr ⟨event,List.mem_cons_of_mem _ member,matching⟩
        · obtain ⟨height,same,records,events⟩ := rollback
          refine ⟨?_,?_⟩
          · intro event member
            rw [events] at member
            exact ih.1 event (List.mem_filter.mp member).1
          · intro cp member
            rw [records] at member
            obtain ⟨old,bounded⟩ := List.mem_filter.mp member
            rcases ih.2 cp old with root | ⟨event,member,matching⟩
            · exact Or.inl (start_record_transport same root)
            · refine Or.inr ⟨event,?_,matching⟩
              rw [events]
              apply List.mem_filter.mpr
              refine ⟨member,?_⟩
              have high := congrArg Checkpoint.height matching
              have high' : event.landing.input.lastHeight = cp.height := high
              simpa only [high'] using bounded

private theorem landing_source_certified {env : Environment} {initial before : World}
    {event : LandingRecord} (inbox : event.inbox = before.inbox)
    (history : event.history = before.history)
    (certificate : Certifies env before (statement env before event.landing)) :
    event.Certified env initial := by
  have same : statement env (event.source initial) event.landing =
      statement env before event.landing := by
    simp only [statement,LandingRecord.source,referenceHash,referencePrefix,inbox,history]
  unfold LandingRecord.Certified
  rw [same]
  obtain ⟨archive,parent,blocks,certificate⟩ := certificate
  refine ⟨archive,parent,blocks,?_⟩
  simpa only [BatchCertificate,certificateWorld,referencePrefix,LandingRecord.source,history]
    using certificate

/-- Every retained record has actual certified landing provenance, or is the current start.
The actual statement includes the saved selection snapshot and the emitted SignalService root. -/
theorem trace_trusted_records {env : Environment} {registry : RegistryMachine.State} {w : World}
    (genesis : RegistryMachine.Genesis registry) (primitives : Custody.Primitives env)
    (soundness : VerifierSound env (empty env registry))
    (trace : Trace env (empty env registry) w) :
    ∀ cp ∈ w.activeRecords, TrustedRecord env (empty env registry) w cp := by
  obtain ⟨sources,coverage⟩ := trace_landing_sources trace
  have certified : ∀ event ∈ w.activeLandings, event.Certified env (empty env registry) := by
    intro event member
    obtain ⟨before,after,reachable,accepted,inbox,history⟩ := sources event member
    obtain ⟨proof,_,archive,parent,blocks,certificate,_⟩ :=
      Journal.accepted_image_certificate soundness reachable accepted
    exact landing_source_certified inbox history ⟨archive,parent,blocks,certificate⟩
  intro cp member
  refine ⟨(Custody.trace_invariant genesis primitives soundness trace).records cp member,?_,
    fun event retained _ => certified event retained⟩
  rcases coverage cp member with start | ⟨event,retained,matching⟩
  · exact Or.inl start
  · exact Or.inr ⟨event,retained,matching,certified event retained⟩

end Etna.Design.Current.Protocol.Governance
