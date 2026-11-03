import EtnaModel.CurrentMetadata
import EtnaProofs.CurrentJournal
import EtnaProofs.CurrentProtocolFinality
import EtnaProofs.CurrentEconomics

namespace Etna.Design.Current.Protocol

private theorem execute_metadata {env : Environment} {w t : World} {call : Call}
    (ok : execute env w call = some t) :
    (t.start=w.start ∧ t.inbox.origin=w.inbox.origin) ∨ w.initialized=false ∨
      w.start=none ∨ w.inbox.generation<t.inbox.generation := by
  cases call with
  | advance n =>
    simp only [execute] at ok
    unfold advance at ok
    split at ok
    next allowed =>
      cases Option.some.inj ok
      exact Or.inl ⟨rfl,rfl⟩
    · cases ok
  | initializeInbox caller =>
    simp only [execute] at ok
    unfold initializeInbox at ok
    split at ok
    next guard => exact Or.inr (Or.inl guard.2.1)
    · cases ok
  | setOrigin caller h hash root =>
    simp only [execute] at ok
    unfold setOrigin at ok
    split at ok
    next guard => exact Or.inr (Or.inr (Or.inl guard.2.1))
    · cases ok
  | correctStart caller h hash root =>
    simp only [execute] at ok
    unfold correctStart at ok
    obtain ⟨old,_,ok⟩ := Option.bind_eq_some_iff.mp ok
    split at ok
    · cases Option.some.inj ok
      exact Or.inr (Or.inr (Or.inr (Nat.lt_succ_self _)))
    · cases ok
  | registry caller action =>
    simp only [execute] at ok
    unfold registryCall at ok
    split at ok
    · obtain ⟨result,_,rfl⟩ := Option.map_eq_some_iff.mp ok
      exact Or.inl ⟨rfl,rfl⟩
    · cases ok
  | enqueue raw paid refund =>
    simp only [execute] at ok
    unfold enqueue at ok
    split at ok
    · obtain ⟨inbox,enqueued,rfl⟩ := Option.map_eq_some_iff.mp ok
      unfold Forced.enqueue at enqueued
      dsimp only at enqueued
      split at enqueued
      · cases Option.some.inj enqueued; exact Or.inl ⟨rfl,rfl⟩
      · cases enqueued
    · cases ok
  | sweep transfer =>
    simp only [execute] at ok
    obtain ⟨inbox,swept,rfl⟩ := Option.map_eq_some_iff.mp ok
    unfold Forced.sweep at swept
    split at swept
    · cases Option.some.inj swept; exact Or.inl ⟨rfl,rfl⟩
    · cases swept
  | forcedETH amount => cases Option.some.inj ok; exact Or.inl ⟨rfl,rfl⟩
  | scheduleRules caller rule time | scheduleStop caller time grid =>
    simp only [execute] at ok
    obtain ⟨schedule,_,rfl⟩ := Option.map_eq_some_iff.mp ok
    exact Or.inl ⟨rfl,rfl⟩
  | recover request =>
    simp only [execute] at ok
    unfold recover at ok
    obtain ⟨start,_,ok⟩ := Option.bind_eq_some_iff.mp ok
    cases upgrade : request.upgrade <;> simp only [upgrade,Option.isSome_none,
      Option.isSome_some,Option.getD_none,Option.getD_some,Bool.false_eq_true,ite_true,ite_false] at ok
    all_goals
      split at ok
      · obtain ⟨schedule,_,ok⟩ := Option.bind_eq_some_iff.mp ok
        obtain ⟨registry,_,rfl⟩ := Option.map_eq_some_iff.mp ok
        exact Or.inr (Or.inr (Or.inr (Nat.lt_succ_self _)))
      · cases ok
  | invalidate caller nonce =>
    simp only [execute] at ok
    unfold invalidate at ok
    split at ok
    · cases Option.some.inj ok; exact Or.inl ⟨rfl,rfl⟩
    · cases ok
  | rollback caller trusted cutoff =>
    simp only [execute] at ok
    unfold rollback at ok
    split at ok
    · obtain ⟨registry,_,rfl⟩ := Option.map_eq_some_iff.mp ok
      exact Or.inl ⟨rfl,rfl⟩
    · cases ok
  | land landing =>
    simp only [execute] at ok
    unfold Protocol.land at ok
    split at ok
    · cases Option.some.inj ok; exact Or.inl ⟨rfl,rfl⟩
    · cases ok
  | unzenProve proposal header proof =>
    simp only [execute] at ok
    unfold unzenProve at ok
    split at ok
    · cases Option.some.inj ok; exact Or.inl ⟨rfl,rfl⟩
    · cases ok
  | image caller image register | verifier caller version =>
    simp only [execute] at ok
    split at ok
    · cases Option.some.inj ok; exact Or.inl ⟨rfl,rfl⟩
    · cases ok
  | observe number =>
    simp only [execute] at ok
    obtain ⟨s,_,rfl⟩ := Option.map_eq_some_iff.mp ok
    exact Or.inl ⟨rfl,rfl⟩
  | importSnapshot candidate durable =>
    simp only [execute] at ok
    unfold nodeImport at ok
    cases target : w.node.target with
    | none => simp [target] at ok
    | some target =>
      simp only [target] at ok
      split at ok
      · obtain ⟨installed,_,rfl⟩ := Option.map_eq_some_iff.mp ok
        exact Or.inl ⟨rfl,rfl⟩
      · cases ok
  | restart | openSigner _ | switchSigner _ =>
    cases Option.some.inj ok; exact Or.inl ⟨rfl,rfl⟩
  | sign request signature persisted =>
    simp only [execute] at ok
    obtain ⟨result,_,rfl⟩ := Option.map_eq_some_iff.mp ok
    exact Or.inl ⟨rfl,rfl⟩

theorem step_started_metadata {env : Environment} {registry : RegistryMachine.State} {w t : World}
    (reach : Trace env (empty env registry) w) (change : Step env w t)
    (same : t.inbox.generation=w.inbox.generation) (started : w.start.isSome=true) :
    t.start=w.start ∧ t.inbox.origin=w.inbox.origin := by
  cases change with
  | node after validated => exact ⟨rfl,rfl⟩
  | call call =>
    cases result : execute env w call with
    | none => simp [Protocol.transact,result]
    | some after =>
      have same' : after.inbox.generation=w.inbox.generation := by
        simpa only [Protocol.transact,result,Option.getD_some] using same
      have shape := Journal.trace_frontier_shape reach
      rcases execute_metadata result with fixed | uninit | missing | increased
      · simpa only [Protocol.transact,result,Option.getD_some] using fixed
      · have absent := shape.uninitialized uninit
        simp [absent] at started
      · simp [missing] at started
      · omega

/-- Completed canonical snapshots retain their started generation's immutable origin,
including empty blocks and later calls in the same generation. -/
theorem closed_started_metadata {env : Environment} {registry : RegistryMachine.State} {w : World}
    (run : Trace env (empty env registry) w) : ClosedStartedMetadata w := by
  induction run with
  | refl => intro s member; simp [empty] at member
  | @step before after prior change ih =>
    have journal := Journal.trace_invariant prior
    have effect := Journal.step_effect change
    have gen := (ProtocolFinality.trace_fields (Trace.step (Trace.refl before) change)).2.1
    have old : ∀ s ∈ before.history, s.start.isSome=true → s.inbox.generation=after.inbox.generation →
        after.start=s.start ∧ after.inbox.origin=s.inbox.origin := by
      intro s member started same
      have bound := (journal.snapshots s member).2.2.1
      have sameOld : s.inbox.generation=before.inbox.generation := by omega
      have oldFields := ih s member started sameOld
      have oldStarted : before.start.isSome=true := by rw [oldFields.1]; exact started
      have nextFields := step_started_metadata prior change (by omega) oldStarted
      exact ⟨nextFields.1.trans oldFields.1,nextFields.2.trans oldFields.2⟩
    intro s member started same
    cases effect with
    | frame _ _ _ history _ => exact old s (history ▸ member) started same
    | admission _ _ _ _ history _ _ _ => exact old s (history ▸ member) started same
    | clearing _ _ _ _ history _ => exact old s (history ▸ member) started same
    | close _ _ _ generation history =>
      rw [history] at member
      rcases List.mem_append.mp member with previous | newly
      · exact old s previous started same
      · obtain ⟨n,_,rfl⟩ := List.mem_map.mp newly
        have beforeStarted : before.start.isSome=true := started
        exact step_started_metadata prior change generation beforeStarted

theorem trace_started_metadata {env : Environment} {registry : RegistryMachine.State} {first later : World}
    (reach : Trace env (empty env registry) first) (run : Trace env first later)
    (started : first.start.isSome=true) (same : later.inbox.generation=first.inbox.generation) :
    later.start=first.start ∧ later.inbox.origin=first.inbox.origin := by
  induction run with
  | refl => exact ⟨rfl,rfl⟩
  | @step before after prior change ih =>
    have initialBound := (ProtocolFinality.trace_fields prior).2.1
    have nextBound := (ProtocolFinality.trace_fields (Trace.step (Trace.refl before) change)).2.1
    have beforeSame : before.inbox.generation=first.inbox.generation := by omega
    have old := ih beforeSame
    have oldStarted : before.start.isSome=true := by rw [old.1]; exact started
    have next := step_started_metadata (Economics.trace_trans reach prior) change (by omega) oldStarted
    exact ⟨next.1.trans old.1,next.2.trans old.2⟩

/-- Actual execution within one started generation preserves all derived configuration
data. Temporal agreement need not assume equality of already-derived contexts. -/
theorem trace_same_generation_config {env : Environment} {registry : RegistryMachine.State} {first later : World}
    (reach : Trace env (empty env registry) first) (run : Trace env first later)
    (started : first.start.isSome=true) (same : later.inbox.generation=first.inbox.generation) :
    config later=config first := by
  have parameters := Economics.trace_same_generation_parameters run same
  have epoch := congrArg Parameters.epochLen parameters
  have cutoff := congrArg Parameters.genesisCutoff parameters
  have committee := congrArg Parameters.committee parameters
  dsimp only [parametersOf] at epoch cutoff committee
  have origin := (trace_started_metadata reach run started same).2
  have domain := (ProtocolFinality.trace_fields run).1
  unfold config
  rw [domain,same,origin,epoch,cutoff,committee]

/-- A closed reference snapshot fixes every deployment parameter while its generation
remains active, including positive recovery generations. -/
theorem closed_generation_parameters {env : Environment} {registry : RegistryMachine.State} {w : World}
    (run : Trace env (empty env registry) w) : ClosedGenerationParameters w := by
  induction run with
  | refl => intro s member; simp [empty] at member
  | @step before after prior change ih =>
    have journal := Journal.trace_invariant prior
    have gen := (ProtocolFinality.trace_fields (Trace.step (Trace.refl before) change)).2.1
    have old : ∀ s ∈ before.history, s.inbox.generation=after.inbox.generation →
        parametersOf after.inbox=parametersOf s.inbox := by
      intro s member same
      have bound := (journal.snapshots s member).2.2.1
      have sameOld : s.inbox.generation=before.inbox.generation := by omega
      have next := Economics.trace_same_generation_parameters
        (Trace.step (Trace.refl before) change) (by omega)
      exact next.trans (ih s member sameOld)
    intro s member same
    cases effect : Journal.step_effect change with
    | frame _ _ _ history _ => exact old s (history ▸ member) same
    | admission _ _ _ _ history _ _ _ => exact old s (history ▸ member) same
    | clearing _ _ _ _ history _ => exact old s (history ▸ member) same
    | close _ _ _ generation history =>
      rw [history] at member
      rcases List.mem_append.mp member with previous | newly
      · exact old s previous same
      · obtain ⟨n,_,rfl⟩ := List.mem_map.mp newly
        exact Economics.trace_same_generation_parameters
          (Trace.step (Trace.refl before) change) generation

end Etna.Design.Current.Protocol
