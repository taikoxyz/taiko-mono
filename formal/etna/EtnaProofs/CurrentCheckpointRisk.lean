import EtnaModel.CurrentCheckpointRisk
import EtnaProofs.CurrentStakeRisk
import EtnaProofs.CurrentCoherentCustody
import EtnaProofs.CurrentMetadata
import EtnaProofs.CurrentArchive
import EtnaProofs.CurrentCandidate

namespace Etna.Design.Current.CheckpointRisk
open Protocol
set_option maxRecDepth 30000
set_option maxHeartbeats 4000000

private structure Frame (env : Environment) (w t : World) : Prop where
  registry : t.registry.registry = w.registry.registry
  domain : t.inbox.domain = w.inbox.domain
  generation : w.inbox.generation ≤ t.inbox.generation
  initialized : w.initialized = true → t.initialized = true
  number : w.number ≤ t.number
  time : env.time w.number ≤ env.time t.number

private theorem frame_trace {env : Environment} {w t : World} (snapshot : w.inbox.snapshot ≤ t.inbox.snapshot) (frame : Frame env w t) :
    StakeRisk.NormalTrace (registryWorld env w) (registryWorld env t) := by
  unfold registryWorld
  rw [frame.registry]
  exact .frame (.refl _) frame.domain frame.generation frame.initialized frame.number frame.time snapshot

private theorem unchanged_trace {env : Environment} {w t : World}
    (same : registryWorld env t = registryWorld env w) :
    StakeRisk.NormalTrace (registryWorld env w) (registryWorld env t) := by
  rw [same]
  exact .refl _

theorem execute_registry_normal {env : Environment} {w t : World} {call : Call}
    (ordinary : OrdinaryCall call) (snapshot : w.inbox.snapshot ≤ t.inbox.snapshot)
    (ok : execute env w call = some t) :
    StakeRisk.NormalTrace (registryWorld env w) (registryWorld env t) := by
  cases call with
  | advance number =>
    simp only [Protocol.execute] at ok
    unfold Protocol.advance at ok
    split at ok
    next allowed =>
      cases Option.some.inj ok
      apply frame_trace snapshot
      exact ⟨rfl,rfl,Nat.le_refl _,id,Nat.le_of_lt allowed.1,allowed.2.2⟩
    next => cases ok
  | initializeInbox caller =>
    simp only [Protocol.execute] at ok
    unfold Protocol.initializeInbox at ok
    split at ok
    next allowed =>
      split at ok
      · split at ok
        · cases Option.some.inj ok
          apply frame_trace snapshot
          constructor <;> simp_all [writeStart]
        · cases ok
      · cases Option.some.inj ok
        apply frame_trace snapshot
        exact ⟨rfl,rfl,Nat.le_refl _,fun _ => rfl,Nat.le_refl _,Nat.le_refl _⟩
    next => cases ok
  | setOrigin caller height hash root =>
    simp only [Protocol.execute] at ok
    unfold Protocol.setOrigin at ok
    split at ok
    next allowed =>
      cases Option.some.inj ok
      apply frame_trace snapshot
      constructor <;> simp_all [writeStart]
    next => cases ok
  | correctStart caller height hash root =>
    simp only [Protocol.execute] at ok
    unfold Protocol.correctStart at ok
    obtain ⟨old,_,ok⟩ := Option.bind_eq_some_iff.mp ok
    split at ok
    · cases Option.some.inj ok
      apply frame_trace snapshot
      exact ⟨rfl,rfl,Nat.le_succ _,id,Nat.le_refl _,Nat.le_refl _⟩
    · cases ok
  | registry caller action =>
    simp only [Protocol.execute] at ok
    unfold Protocol.registryCall at ok
    split at ok
    · obtain ⟨⟨paid,receipts⟩,transaction,equal⟩ := Option.map_eq_some_iff.mp ok
      subst t
      have normal : StakeRisk.NormalAction w.number action := by
        cases action <;> simp_all [Protocol.publicRegistry,StakeRisk.NormalAction]
      exact .call (.refl _) action normal (RegistryPayments.tx_success_projects transaction)
    · cases ok
  | enqueue raw paid refund =>
    simp only [Protocol.execute] at ok
    unfold Protocol.enqueue at ok
    split at ok
    · obtain ⟨inbox,enqueued,equal⟩ := Option.map_eq_some_iff.mp ok
      subst t
      unfold Forced.enqueue at enqueued
      dsimp only at enqueued
      split at enqueued
      · cases Option.some.inj enqueued
        exact unchanged_trace rfl
      · cases enqueued
    · cases ok
  | sweep transfer =>
    simp only [Protocol.execute] at ok
    unfold Protocol.sweep at ok
    obtain ⟨inbox,swept,equal⟩ := Option.map_eq_some_iff.mp ok
    subst t
    unfold Forced.sweep at swept
    split at swept
    · cases Option.some.inj swept
      exact unchanged_trace rfl
    · cases swept
  | forcedETH amount =>
    cases Option.some.inj ok
    exact unchanged_trace rfl
  | scheduleRules caller rule time =>
    simp only [Protocol.execute] at ok
    unfold Protocol.scheduleRules at ok
    obtain ⟨schedule,_,equal⟩ := Option.map_eq_some_iff.mp ok
    subst t
    exact unchanged_trace rfl
  | scheduleStop caller time grid =>
    simp only [Protocol.execute] at ok
    unfold Protocol.scheduleStop at ok
    obtain ⟨schedule,_,equal⟩ := Option.map_eq_some_iff.mp ok
    subst t
    exact unchanged_trace rfl
  | recover request =>
    simp only [Protocol.execute] at ok
    unfold Protocol.recover at ok
    obtain ⟨start,_,ok⟩ := Option.bind_eq_some_iff.mp ok
    cases upgrade : request.upgrade <;> simp only [upgrade,Option.isSome_none,Option.isSome_some,Option.getD_none,Option.getD_some,Bool.false_eq_true,ite_true,ite_false] at ok
    all_goals
      split at ok
      · obtain ⟨schedule,_,ok⟩ := Option.bind_eq_some_iff.mp ok
        obtain ⟨registry,executed,equal⟩ := Option.map_eq_some_iff.mp ok
        subst t
        exact .frame (.call (.refl _) (.exclude w.registry.registry.config.inbox w.number request.exclusions) rfl executed)
          rfl (Nat.le_succ _) id (Nat.le_refl _) (Nat.le_refl _) snapshot
      · cases ok
  | invalidate caller nonce =>
    simp only [Protocol.execute] at ok
    unfold Protocol.invalidate at ok
    split at ok
    · cases Option.some.inj ok
      exact unchanged_trace rfl
    · cases ok
  | rollback caller trusted restored => exact False.elim ordinary
  | land landing =>
    simp only [Protocol.execute] at ok
    unfold Protocol.land at ok
    split at ok
    · cases Option.some.inj ok
      apply frame_trace snapshot
      exact ⟨rfl,rfl,Nat.le_refl _,id,Nat.le_refl _,Nat.le_refl _⟩
    · cases ok
  | unzenProve proposal header proof =>
    simp only [Protocol.execute] at ok
    unfold Protocol.unzenProve at ok
    split at ok
    · cases Option.some.inj ok
      exact unchanged_trace rfl
    · cases ok
  | image caller image register =>
    simp only [Protocol.execute] at ok
    split at ok
    · cases Option.some.inj ok
      exact unchanged_trace rfl
    · cases ok
  | verifier caller version =>
    simp only [Protocol.execute] at ok
    split at ok
    · cases Option.some.inj ok
      exact unchanged_trace rfl
    · cases ok
  | observe number =>
    simp only [Protocol.execute] at ok
    unfold Protocol.observe at ok
    obtain ⟨snapshot,_,equal⟩ := Option.map_eq_some_iff.mp ok
    subst t
    exact unchanged_trace rfl
  | importSnapshot candidate durable =>
    simp only [Protocol.execute] at ok
    unfold Protocol.nodeImport at ok
    cases target : w.node.target with
    | none => simp [target] at ok
    | some target =>
      simp only [target] at ok
      split at ok
      · obtain ⟨installed,_,equal⟩ := Option.map_eq_some_iff.mp ok
        subst t
        exact unchanged_trace rfl
      · cases ok
  | restart =>
    cases Option.some.inj ok
    exact unchanged_trace rfl
  | openSigner authoritative =>
    cases Option.some.inj ok
    exact unchanged_trace rfl
  | switchSigner persisted =>
    cases Option.some.inj ok
    exact unchanged_trace rfl
  | sign request signature persisted =>
    simp only [Protocol.execute] at ok
    obtain ⟨result,_,equal⟩ := Option.map_eq_some_iff.mp ok
    subst t
    exact unchanged_trace rfl

theorem NormalRun.project {env : Environment} {first later : World} (run : NormalRun env first later) :
    Trace env first later := by
  induction run with
  | refl => exact .refl _
  | call _ call _ _ ih => exact .step ih (.call _ call)
  | node _ after valid ih => exact .step ih (.node after valid)

theorem RollbackFreeRun.project {env : Environment} {first later : World} (run : RollbackFreeRun env first later) :
    Trace env first later := by
  induction run with
  | refl => exact .refl _
  | call _ call _ ih => exact .step ih (.call _ call)
  | node _ after valid ih => exact .step ih (.node after valid)

theorem NormalRun.trans {env : Environment} {a b c : World}
    (ab : NormalRun env a b) (bc : NormalRun env b c) : NormalRun env a c := by
  induction bc with
  | refl => exact ab
  | call _ call ordinary snapshot ih => exact .call ih call ordinary snapshot
  | node _ after valid ih => exact .node ih after valid

private theorem normal_trans {a b c : RegistryMachine.World}
    (first : StakeRisk.NormalTrace a b) (last : StakeRisk.NormalTrace b c) : StakeRisk.NormalTrace a c := by
  induction last with
  | refl => exact first
  | call _ action normal ok ih => exact .call ih action normal ok
  | frame _ hd hg hi ht htime hs ih => exact .frame ih hd hg hi ht htime hs

theorem NormalRun.registry {env : Environment} {first later : World} (run : NormalRun env first later) :
    StakeRisk.NormalTrace (registryWorld env first) (registryWorld env later) := by
  induction run with
  | refl => exact .refl _
  | @call w prior call ordinary snapshot ih =>
    cases ok : execute env w call with
    | none => simpa only [Protocol.transact,ok,Option.getD_none] using ih
    | some t =>
      have order : w.inbox.snapshot ≤ t.inbox.snapshot := by simpa only [Protocol.transact,ok,Option.getD_some] using snapshot
      simpa only [Protocol.transact,ok,Option.getD_some] using normal_trans ih (execute_registry_normal ordinary order ok)
  | node _ after valid ih => exact ih

theorem execute_checkpoint_frame {env : Environment} {w t : World} {call : Call}
    (ordinary : OrdinaryCall call)
    (ok : execute env w call = some t) :
    Protocol.Custody.writesCheckpoint call = true ∨
      (t.inbox.checkpoint = w.inbox.checkpoint ∧ t.inbox.snapshot = w.inbox.snapshot ∧ t.start = w.start) := by
  cases call with
  | advance number =>
    simp only [Protocol.execute] at ok
    unfold Protocol.advance at ok
    split at ok
    next allowed =>
      cases Option.some.inj ok
      exact Or.inr ⟨rfl,rfl,rfl⟩
    next => cases ok
  | initializeInbox caller => exact Or.inl rfl
  | setOrigin caller height hash root => exact Or.inl rfl
  | correctStart caller height hash root => exact Or.inl rfl
  | registry caller action =>
    simp only [Protocol.execute] at ok
    unfold Protocol.registryCall at ok
    split at ok
    · obtain ⟨⟨paid,receipts⟩,transaction,equal⟩ := Option.map_eq_some_iff.mp ok
      subst t
      exact Or.inr ⟨rfl,rfl,rfl⟩
    · cases ok
  | enqueue raw paid refund =>
    simp only [Protocol.execute] at ok
    unfold Protocol.enqueue at ok
    split at ok
    · obtain ⟨inbox,enqueued,equal⟩ := Option.map_eq_some_iff.mp ok
      subst t
      unfold Forced.enqueue at enqueued
      dsimp only at enqueued
      split at enqueued
      · cases Option.some.inj enqueued
        exact Or.inr ⟨rfl,rfl,rfl⟩
      · cases enqueued
    · cases ok
  | sweep transfer =>
    simp only [Protocol.execute] at ok
    unfold Protocol.sweep at ok
    obtain ⟨inbox,swept,equal⟩ := Option.map_eq_some_iff.mp ok
    subst t
    unfold Forced.sweep at swept
    split at swept
    · cases Option.some.inj swept
      exact Or.inr ⟨rfl,rfl,rfl⟩
    · cases swept
  | forcedETH amount =>
    cases Option.some.inj ok
    exact Or.inr ⟨rfl,rfl,rfl⟩
  | scheduleRules caller rule time =>
    simp only [Protocol.execute] at ok
    unfold Protocol.scheduleRules at ok
    obtain ⟨schedule,_,equal⟩ := Option.map_eq_some_iff.mp ok
    subst t
    exact Or.inr ⟨rfl,rfl,rfl⟩
  | scheduleStop caller time grid =>
    simp only [Protocol.execute] at ok
    unfold Protocol.scheduleStop at ok
    obtain ⟨schedule,_,equal⟩ := Option.map_eq_some_iff.mp ok
    subst t
    exact Or.inr ⟨rfl,rfl,rfl⟩
  | recover request =>
    simp only [Protocol.execute] at ok
    unfold Protocol.recover at ok
    obtain ⟨start,_,ok⟩ := Option.bind_eq_some_iff.mp ok
    cases upgrade : request.upgrade <;> simp only [upgrade,Option.isSome_none,Option.isSome_some,Option.getD_none,Option.getD_some,Bool.false_eq_true,ite_true,ite_false] at ok
    all_goals
      split at ok
      · obtain ⟨schedule,_,ok⟩ := Option.bind_eq_some_iff.mp ok
        obtain ⟨registry,executed,equal⟩ := Option.map_eq_some_iff.mp ok
        subst t
        exact Or.inr ⟨rfl,rfl,rfl⟩
      · cases ok
  | invalidate caller nonce =>
    simp only [Protocol.execute] at ok
    unfold Protocol.invalidate at ok
    split at ok
    · cases Option.some.inj ok
      exact Or.inr ⟨rfl,rfl,rfl⟩
    · cases ok
  | rollback caller trusted restored => exact False.elim ordinary
  | land landing => exact Or.inl rfl
  | unzenProve proposal header proof =>
    simp only [Protocol.execute] at ok
    unfold Protocol.unzenProve at ok
    split at ok
    · cases Option.some.inj ok
      exact Or.inr ⟨rfl,rfl,rfl⟩
    · cases ok
  | image caller image register =>
    simp only [Protocol.execute] at ok
    split at ok
    · cases Option.some.inj ok
      exact Or.inr ⟨rfl,rfl,rfl⟩
    · cases ok
  | verifier caller version =>
    simp only [Protocol.execute] at ok
    split at ok
    · cases Option.some.inj ok
      exact Or.inr ⟨rfl,rfl,rfl⟩
    · cases ok
  | observe number =>
    simp only [Protocol.execute] at ok
    unfold Protocol.observe at ok
    obtain ⟨snapshot,_,equal⟩ := Option.map_eq_some_iff.mp ok
    subst t
    exact Or.inr ⟨rfl,rfl,rfl⟩
  | importSnapshot candidate durable =>
    simp only [Protocol.execute] at ok
    unfold Protocol.nodeImport at ok
    cases target : w.node.target with
    | none => simp [target] at ok
    | some target =>
      simp only [target] at ok
      split at ok
      · obtain ⟨installed,_,equal⟩ := Option.map_eq_some_iff.mp ok
        subst t
        exact Or.inr ⟨rfl,rfl,rfl⟩
      · cases ok
  | restart =>
    cases Option.some.inj ok
    exact Or.inr ⟨rfl,rfl,rfl⟩
  | openSigner authoritative =>
    cases Option.some.inj ok
    exact Or.inr ⟨rfl,rfl,rfl⟩
  | switchSigner persisted =>
    cases Option.some.inj ok
    exact Or.inr ⟨rfl,rfl,rfl⟩
  | sign request signature persisted =>
    simp only [Protocol.execute] at ok
    obtain ⟨result,_,equal⟩ := Option.map_eq_some_iff.mp ok
    subst t
    exact Or.inr ⟨rfl,rfl,rfl⟩

private theorem execute_origin_progress {env : Environment} {w t : World} {call : Call}
    (ordinary : OrdinaryCall call)
    (ok : execute env w call = some t) :
    (t.inbox.generation = w.inbox.generation ∧ t.inbox.origin = w.inbox.origin) ∨
      t.inbox.origin.l1Block = w.number := by
  cases call with
  | advance number =>
    simp only [Protocol.execute] at ok
    unfold Protocol.advance at ok
    split at ok
    next allowed =>
      cases Option.some.inj ok
      exact Or.inl ⟨rfl,rfl⟩
    next => cases ok
  | initializeInbox caller =>
    change initializeInbox env w caller = some t at ok
    unfold initializeInbox at ok
    split at ok
    · split at ok
      · split at ok
        · cases Option.some.inj ok; exact Or.inr rfl
        · cases ok
      · cases Option.some.inj ok; exact Or.inl ⟨rfl,rfl⟩
    · cases ok
  | setOrigin caller height hash root =>
    change setOrigin env w caller height hash root = some t at ok
    unfold setOrigin at ok
    split at ok
    · cases Option.some.inj ok; exact Or.inr rfl
    · cases ok
  | correctStart caller height hash root =>
    change correctStart env w caller height hash root = some t at ok
    unfold correctStart at ok
    obtain ⟨previous,_,ok⟩ := Option.bind_eq_some_iff.mp ok
    split at ok
    · cases Option.some.inj ok; exact Or.inr rfl
    · cases ok
  | registry caller action =>
    simp only [Protocol.execute] at ok
    unfold Protocol.registryCall at ok
    split at ok
    · obtain ⟨⟨paid,receipts⟩,transaction,equal⟩ := Option.map_eq_some_iff.mp ok
      subst t
      exact Or.inl ⟨rfl,rfl⟩
    · cases ok
  | enqueue raw paid refund =>
    simp only [Protocol.execute] at ok
    unfold Protocol.enqueue at ok
    split at ok
    · obtain ⟨inbox,enqueued,equal⟩ := Option.map_eq_some_iff.mp ok
      subst t
      unfold Forced.enqueue at enqueued
      dsimp only at enqueued
      split at enqueued
      · cases Option.some.inj enqueued
        exact Or.inl ⟨rfl,rfl⟩
      · cases enqueued
    · cases ok
  | sweep transfer =>
    simp only [Protocol.execute] at ok
    unfold Protocol.sweep at ok
    obtain ⟨inbox,swept,equal⟩ := Option.map_eq_some_iff.mp ok
    subst t
    unfold Forced.sweep at swept
    split at swept
    · cases Option.some.inj swept
      exact Or.inl ⟨rfl,rfl⟩
    · cases swept
  | forcedETH amount =>
    cases Option.some.inj ok
    exact Or.inl ⟨rfl,rfl⟩
  | scheduleRules caller rule time =>
    simp only [Protocol.execute] at ok
    unfold Protocol.scheduleRules at ok
    obtain ⟨schedule,_,equal⟩ := Option.map_eq_some_iff.mp ok
    subst t
    exact Or.inl ⟨rfl,rfl⟩
  | scheduleStop caller time grid =>
    simp only [Protocol.execute] at ok
    unfold Protocol.scheduleStop at ok
    obtain ⟨schedule,_,equal⟩ := Option.map_eq_some_iff.mp ok
    subst t
    exact Or.inl ⟨rfl,rfl⟩
  | recover request =>
    simp only [Protocol.execute] at ok
    unfold Protocol.recover at ok
    obtain ⟨start,_,ok⟩ := Option.bind_eq_some_iff.mp ok
    cases upgrade : request.upgrade <;> simp only [upgrade,Option.isSome_none,Option.isSome_some,Option.getD_none,Option.getD_some,Bool.false_eq_true,ite_true,ite_false] at ok
    all_goals
      split at ok
      · obtain ⟨schedule,_,ok⟩ := Option.bind_eq_some_iff.mp ok
        obtain ⟨registry,executed,equal⟩ := Option.map_eq_some_iff.mp ok
        subst t
        exact Or.inr rfl
      · cases ok
  | invalidate caller nonce =>
    simp only [Protocol.execute] at ok
    unfold Protocol.invalidate at ok
    split at ok
    · cases Option.some.inj ok
      exact Or.inl ⟨rfl,rfl⟩
    · cases ok
  | rollback caller trusted restored => exact False.elim ordinary
  | land landing =>
    change Protocol.land env w landing = some t at ok
    unfold Protocol.land at ok
    split at ok
    · cases Option.some.inj ok; exact Or.inl ⟨rfl,rfl⟩
    · cases ok
  | unzenProve proposal header proof =>
    simp only [Protocol.execute] at ok
    unfold Protocol.unzenProve at ok
    split at ok
    · cases Option.some.inj ok
      exact Or.inl ⟨rfl,rfl⟩
    · cases ok
  | image caller image register =>
    simp only [Protocol.execute] at ok
    split at ok
    · cases Option.some.inj ok
      exact Or.inl ⟨rfl,rfl⟩
    · cases ok
  | verifier caller version =>
    simp only [Protocol.execute] at ok
    split at ok
    · cases Option.some.inj ok
      exact Or.inl ⟨rfl,rfl⟩
    · cases ok
  | observe number =>
    simp only [Protocol.execute] at ok
    unfold Protocol.observe at ok
    obtain ⟨snapshot,_,equal⟩ := Option.map_eq_some_iff.mp ok
    subst t
    exact Or.inl ⟨rfl,rfl⟩
  | importSnapshot candidate durable =>
    simp only [Protocol.execute] at ok
    unfold Protocol.nodeImport at ok
    cases target : w.node.target with
    | none => simp [target] at ok
    | some target =>
      simp only [target] at ok
      split at ok
      · obtain ⟨installed,_,equal⟩ := Option.map_eq_some_iff.mp ok
        subst t
        exact Or.inl ⟨rfl,rfl⟩
      · cases ok
  | restart =>
    cases Option.some.inj ok
    exact Or.inl ⟨rfl,rfl⟩
  | openSigner authoritative =>
    cases Option.some.inj ok
    exact Or.inl ⟨rfl,rfl⟩
  | switchSigner persisted =>
    cases Option.some.inj ok
    exact Or.inl ⟨rfl,rfl⟩
  | sign request signature persisted =>
    simp only [Protocol.execute] at ok
    obtain ⟨result,_,equal⟩ := Option.map_eq_some_iff.mp ok
    subst t
    exact Or.inl ⟨rfl,rfl⟩

private theorem execute_initialized_change {env : Environment} {w t : World} {call : Call}
    (ok : execute env w call = some t) :
    t.initialized = w.initialized ∨ ∃ caller, call = .initializeInbox caller := by
  cases call with
  | advance number =>
    simp only [Protocol.execute] at ok
    unfold Protocol.advance at ok
    split at ok
    next allowed =>
      cases Option.some.inj ok
      exact Or.inl rfl
    next => cases ok
  | initializeInbox caller => exact Or.inr ⟨caller,rfl⟩
  | setOrigin caller height hash root =>
    change setOrigin env w caller height hash root = some t at ok
    unfold setOrigin at ok
    split at ok
    · cases Option.some.inj ok; exact Or.inl rfl
    · cases ok
  | correctStart caller height hash root =>
    change correctStart env w caller height hash root = some t at ok
    unfold correctStart at ok
    obtain ⟨previous,_,ok⟩ := Option.bind_eq_some_iff.mp ok
    split at ok
    · cases Option.some.inj ok; exact Or.inl rfl
    · cases ok
  | registry caller action =>
    simp only [Protocol.execute] at ok
    unfold Protocol.registryCall at ok
    split at ok
    · obtain ⟨⟨paid,receipts⟩,transaction,equal⟩ := Option.map_eq_some_iff.mp ok
      subst t
      exact Or.inl rfl
    · cases ok
  | enqueue raw paid refund =>
    simp only [Protocol.execute] at ok
    unfold Protocol.enqueue at ok
    split at ok
    · obtain ⟨inbox,enqueued,equal⟩ := Option.map_eq_some_iff.mp ok
      subst t
      unfold Forced.enqueue at enqueued
      dsimp only at enqueued
      split at enqueued
      · cases Option.some.inj enqueued
        exact Or.inl rfl
      · cases enqueued
    · cases ok
  | sweep transfer =>
    simp only [Protocol.execute] at ok
    unfold Protocol.sweep at ok
    obtain ⟨inbox,swept,equal⟩ := Option.map_eq_some_iff.mp ok
    subst t
    unfold Forced.sweep at swept
    split at swept
    · cases Option.some.inj swept
      exact Or.inl rfl
    · cases swept
  | forcedETH amount =>
    cases Option.some.inj ok
    exact Or.inl rfl
  | scheduleRules caller rule time =>
    simp only [Protocol.execute] at ok
    unfold Protocol.scheduleRules at ok
    obtain ⟨schedule,_,equal⟩ := Option.map_eq_some_iff.mp ok
    subst t
    exact Or.inl rfl
  | scheduleStop caller time grid =>
    simp only [Protocol.execute] at ok
    unfold Protocol.scheduleStop at ok
    obtain ⟨schedule,_,equal⟩ := Option.map_eq_some_iff.mp ok
    subst t
    exact Or.inl rfl
  | recover request =>
    simp only [Protocol.execute] at ok
    unfold Protocol.recover at ok
    obtain ⟨start,_,ok⟩ := Option.bind_eq_some_iff.mp ok
    cases upgrade : request.upgrade <;> simp only [upgrade,Option.isSome_none,Option.isSome_some,Option.getD_none,Option.getD_some,Bool.false_eq_true,ite_true,ite_false] at ok
    all_goals
      split at ok
      · obtain ⟨schedule,_,ok⟩ := Option.bind_eq_some_iff.mp ok
        obtain ⟨registry,executed,equal⟩ := Option.map_eq_some_iff.mp ok
        subst t
        exact Or.inl rfl
      · cases ok
  | invalidate caller nonce =>
    simp only [Protocol.execute] at ok
    unfold Protocol.invalidate at ok
    split at ok
    · cases Option.some.inj ok
      exact Or.inl rfl
    · cases ok
  | rollback caller trusted restored =>
    change rollback env w caller trusted restored = some t at ok
    unfold rollback at ok
    split at ok
    · obtain ⟨registry,_,rfl⟩ := Option.map_eq_some_iff.mp ok
      exact Or.inl rfl
    · cases ok
  | land landing =>
    change Protocol.land env w landing = some t at ok
    unfold Protocol.land at ok
    split at ok
    · cases Option.some.inj ok; exact Or.inl rfl
    · cases ok
  | unzenProve proposal header proof =>
    simp only [Protocol.execute] at ok
    unfold Protocol.unzenProve at ok
    split at ok
    · cases Option.some.inj ok
      exact Or.inl rfl
    · cases ok
  | image caller image register =>
    simp only [Protocol.execute] at ok
    split at ok
    · cases Option.some.inj ok
      exact Or.inl rfl
    · cases ok
  | verifier caller version =>
    simp only [Protocol.execute] at ok
    split at ok
    · cases Option.some.inj ok
      exact Or.inl rfl
    · cases ok
  | observe number =>
    simp only [Protocol.execute] at ok
    unfold Protocol.observe at ok
    obtain ⟨snapshot,_,equal⟩ := Option.map_eq_some_iff.mp ok
    subst t
    exact Or.inl rfl
  | importSnapshot candidate durable =>
    simp only [Protocol.execute] at ok
    unfold Protocol.nodeImport at ok
    cases target : w.node.target with
    | none => simp [target] at ok
    | some target =>
      simp only [target] at ok
      split at ok
      · obtain ⟨installed,_,equal⟩ := Option.map_eq_some_iff.mp ok
        subst t
        exact Or.inl rfl
      · cases ok
  | restart =>
    cases Option.some.inj ok
    exact Or.inl rfl
  | openSigner authoritative =>
    cases Option.some.inj ok
    exact Or.inl rfl
  | switchSigner persisted =>
    cases Option.some.inj ok
    exact Or.inl rfl
  | sign request signature persisted =>
    simp only [Protocol.execute] at ok
    obtain ⟨result,_,equal⟩ := Option.map_eq_some_iff.mp ok
    subst t
    exact Or.inl rfl

/-- PARAM-11-11 is a deployment assumption. Execution only transports the
immutable withdrawal delay; initializeInbox does not check an external evidence policy. -/
theorem evidence_window_of_deployment {env : Environment} {registry : RegistryMachine.State} {w : World}
    (deployment : env.evidenceWindow ≤ registry.config.withdrawalDelay)
    (run : Trace env (empty env registry) w) :
    env.evidenceWindow ≤ w.registry.registry.config.withdrawalDelay := by
  have fixed : w.registry.registry.config = registry.config :=
    (ProtocolFinality.trace_fields run).2.2.2.2.2.1
  rw [fixed]
  exact deployment

theorem NormalRun.generation_origin_floor {env : Environment} {first later : World}
    (run : NormalRun env first later) (generation : first.inbox.generation < later.inbox.generation) :
    first.number ≤ later.inbox.origin.l1Block := by
  induction run with
  | refl => omega
  | @call before prior call ordinary snapshot ih =>
    cases ok : execute env before call with
    | none =>
      simp only [Protocol.transact,ok,Option.getD_none] at generation ⊢
      exact ih generation
    | some after =>
      simp only [Protocol.transact,ok,Option.getD_some] at generation ⊢
      rcases execute_origin_progress ordinary ok with fixed | fresh
      · rw [fixed.1] at generation
        rw [fixed.2]
        exact ih generation
      · rw [fresh]
        exact (ProtocolFinality.trace_fields prior.project).2.2.2.1
  | node prior after valid ih => exact ih generation

/-- The current checkpoint/snapshot writer is retained with its actual later trace. -/
theorem NormalRun.source {env : Environment} {registry : RegistryMachine.State} {w : World}
    (run : NormalRun env (empty env registry) w) (started : w.start.isSome = true) :
    CurrentSource env (empty env registry) w := by
  induction run with
  | refl => simp [empty] at started
  | @call before prior call ordinary snapshot ih =>
    cases ok : execute env before call with
    | none =>
      simp only [Protocol.transact,ok,Option.getD_none] at started ⊢
      exact ih started
    | some after =>
      simp only [Protocol.transact,ok,Option.getD_some] at started ⊢
      rcases execute_checkpoint_frame ordinary ok with writer | fields
      · have complete : NormalRun env (empty env registry) after := by
          simpa only [Protocol.transact,ok,Option.getD_some] using NormalRun.call prior call ordinary snapshot
        exact ⟨before,call,after,prior,ok,writer,complete,started,.refl _,rfl,rfl⟩
      · have was : before.start.isSome = true := by simpa only [fields.2.2] using started
        obtain ⟨source,writer,endOfWrite,reach,accepted,writes,complete,sourceStarted,later,checkpoint,saved⟩ := ih was
        have change : NormalRun env before after := by
          simpa only [Protocol.transact,ok,Option.getD_some] using
            (show NormalRun env before (Protocol.transact env before call) from .call (.refl before) call ordinary snapshot)
        exact ⟨source,writer,endOfWrite,reach,accepted,writes,complete,sourceStarted,later.trans change,
          checkpoint.trans fields.1.symm,saved.trans fields.2.1.symm⟩
  | node prior after valid ih =>
    obtain ⟨source,writer,endOfWrite,reach,accepted,writes,complete,sourceStarted,later,checkpoint,saved⟩ := ih started
    exact ⟨source,writer,endOfWrite,reach,accepted,writes,complete,sourceStarted,.node later after valid,checkpoint,saved⟩

private theorem required_within_height (cfg : Finality.Config) (height : Nat) :
    Finality.requiredPrefix cfg height ≤ height-cfg.originHeight := by
  have before := Finality.decision_lookback_before cfg height
  unfold Finality.requiredPrefix
  split
  · omega
  · omega

private theorem landing_time {env : Environment} {registry : RegistryMachine.State} {w t : World} {a : Landing}
    (genesis : RegistryMachine.Genesis registry)
    (sound : VerifierSound env (empty env registry)) (reach : Trace env (empty env registry) w)
    (accepted : Protocol.land env w a = some t) : t.inbox.snapshot ≤ t.number := by
  obtain ⟨archive,parent,blocks,ready,valid,binding,hashParent,hashes,implementation,auth⟩ :=
    Protocol.Custody.certified_landing genesis sound reach accepted
  have input := congrArg (fun d : StatementData => d.input.activeCommitteeSnapshot) binding
  change a.input.activeCommitteeSnapshot =
    (Consensus.activeAt (Finality.derive (config w) w.registry.registry archive)
      (Blocks.terminal parent blocks).height).cutoff at input
  have bounded := Archive.active_cutoff_bounded auth ready
  rw [← input] at bounded
  have early := (Protocol.land_success accepted).1.reference
  rw [(Protocol.land_success accepted).2]
  exact Nat.le_trans bounded (Nat.le_of_lt early)

private theorem execute_snapshot_timed {env : Environment} {registry : RegistryMachine.State} {w t : World} {call : Call}
    (genesis : RegistryMachine.Genesis registry)
    (sound : VerifierSound env (empty env registry)) (reach : Trace env (empty env registry) w)
    (old : w.inbox.snapshot ≤ w.number) (ordinary : OrdinaryCall call)
    (ok : execute env w call = some t) : t.inbox.snapshot ≤ t.number := by
  cases call
  case initializeInbox caller =>
    change initializeInbox env w caller = some t at ok
    unfold initializeInbox at ok
    split at ok
    next allowed =>
      have cutoff := allowed.2.2.2.2.2.1
      split at ok
      · split at ok
        · cases Option.some.inj ok; exact Nat.le_of_lt cutoff
        · cases ok
      · cases Option.some.inj ok; exact Nat.le_of_lt cutoff
    next => cases ok
  case setOrigin caller height hash root =>
    change setOrigin env w caller height hash root = some t at ok
    unfold setOrigin at ok
    split at ok
    · cases Option.some.inj ok; exact old
    · cases ok
  case correctStart caller height hash root =>
    change correctStart env w caller height hash root = some t at ok
    unfold correctStart at ok
    obtain ⟨previous,_,ok⟩ := Option.bind_eq_some_iff.mp ok
    split at ok
    · cases Option.some.inj ok; exact old
    · cases ok
  case land landing => exact landing_time genesis sound reach ok
  case rollback caller trusted snapshot => exact False.elim ordinary
  all_goals
    rcases execute_checkpoint_frame ordinary ok with impossible | fields
    · cases impossible
    · have later := (RegistryMachine.trace_stable (ProtocolFinality.execute_registry_trace ok)).time
      change w.number ≤ t.number at later
      rw [fields.2.1]
      exact Nat.le_trans old later

/-- Every actual normal snapshot is a past/current L1 block, derived from accepted
guest ancestry and initializer bounds rather than supplied as snapshot provenance. -/
theorem NormalRun.snapshot_timed {env : Environment} {registry : RegistryMachine.State} {w : World}
    (genesis : RegistryMachine.Genesis registry)
    (run : NormalRun env (empty env registry) w) (sound : VerifierSound env (empty env registry)) :
    w.inbox.snapshot ≤ w.number := by
  induction run with
  | refl => exact Nat.le_refl _
  | @call before prior call ordinary snapshot ih =>
    cases ok : execute env before call with
    | none => simpa only [Protocol.transact,ok,Option.getD_none] using ih
    | some after =>
      simpa only [Protocol.transact,ok,Option.getD_some] using execute_snapshot_timed genesis sound prior.project ih ordinary ok
  | node prior after valid ih => exact ih

private theorem execute_unlanded_snapshot {env : Environment} {w t : World} {call : Call}
    (old : w.inbox.snapshot ≤ env.parameters.genesisCutoff) (ordinary : OrdinaryCall call)
    (ok : execute env w call = some t) (unlanded : t.everLanded = false) :
    t.inbox.snapshot ≤ env.parameters.genesisCutoff := by
  cases call
  case initializeInbox caller =>
    change initializeInbox env w caller = some t at ok
    unfold initializeInbox at ok
    split at ok
    · split at ok
      · split at ok
        · cases Option.some.inj ok; exact Nat.le_refl _
        · cases ok
      · cases Option.some.inj ok; exact Nat.le_refl _
    · cases ok
  case setOrigin caller height hash root =>
    change setOrigin env w caller height hash root = some t at ok
    unfold setOrigin at ok
    split at ok
    · cases Option.some.inj ok; exact old
    · cases ok
  case correctStart caller height hash root =>
    change correctStart env w caller height hash root = some t at ok
    unfold correctStart at ok
    obtain ⟨previous,_,ok⟩ := Option.bind_eq_some_iff.mp ok
    split at ok
    · cases Option.some.inj ok; exact old
    · cases ok
  case land landing =>
    rw [(Protocol.land_success ok).2] at unlanded
    cases unlanded
  case rollback caller trusted snapshot => exact False.elim ordinary
  all_goals
    rcases execute_checkpoint_frame ordinary ok with impossible | fields
    · cases impossible
    · rw [fields.2.1]; exact old

/-- Before any landing in generation zero, initialization is the only possible
snapshot advance. No initialized/balance/confirmation premise is required. -/
theorem NormalRun.zero_unlanded_snapshot {env : Environment} {registry : RegistryMachine.State} {w : World}
    (run : NormalRun env (empty env registry) w)
    (generation : w.inbox.generation = 0) (unlanded : w.everLanded = false) :
    w.inbox.snapshot ≤ env.parameters.genesisCutoff := by
  induction run with
  | refl => exact Nat.zero_le _
  | @call before prior call ordinary snapshot ih =>
    cases ok : execute env before call with
    | none =>
      simp only [Protocol.transact,ok,Option.getD_none] at generation unlanded ⊢
      exact ih generation unlanded
    | some after =>
      simp only [Protocol.transact,ok,Option.getD_some] at generation unlanded ⊢
      have change : Trace env before after := by
        simpa only [Protocol.transact,ok,Option.getD_some] using
          (show Trace env before (Protocol.transact env before call) from .step (.refl before) (.call before call))
      have beforeGeneration : before.inbox.generation = 0 := by
        have order := (ProtocolFinality.trace_fields change).2.1
        omega
      have beforeUnlanded : before.everLanded = false := by
        cases ever : before.everLanded with
        | false => rfl
        | true =>
          have impossible := (Protocol.Custody.trace_start_frozen prior.project ever change).2
          rw [unlanded] at impossible
          cases impossible
      exact execute_unlanded_snapshot (ih beforeGeneration beforeUnlanded) ordinary ok unlanded
  | node prior after valid ih => exact ih generation unlanded

/-- The raw latest-checkpoint hash fence fixes every earlier physical anchor, so a
same-generation landing writer's real snapshot is below the candidate's cutoff.
No cutoff inequality, committee equality or economic status is an input. -/
theorem landing_snapshot_bound {env : Environment} {registry : RegistryMachine.State}
    {before after w : World} {a : Landing} {h : Nat}
    (genesis : RegistryMachine.Genesis registry)
    (primitive : Protocol.Custody.Primitives env)
    (sound : VerifierSound env (empty env registry))
    (reach : Trace env (empty env registry) before)
    (accepted : Protocol.land env before a = some after) (later : Trace env after w)
    (generation : w.inbox.generation = before.inbox.generation)
    (checkpoint : after.inbox.checkpoint = w.inbox.checkpoint)
    (snapshot : after.inbox.snapshot = w.inbox.snapshot)
    (candidate : Candidate env w h) :
    w.inbox.snapshot ≤ Finality.cutoff (config w) candidate.headers h := by
  have check := (Protocol.land_success accepted).1
  have afterEq := (Protocol.land_success accepted).2
  have landingRun : Trace env before after := by
    have call : execute env before (.land a) = some after := accepted
    simpa only [Protocol.transact,call,Option.getD_some] using
      (show Trace env before (Protocol.transact env before (.land a)) from .step (.refl _) (.call before (.land a)))
  have sameConfig := trace_same_generation_config reach (Economics.trace_trans landingRun later) check.started generation
  obtain ⟨archive,parent,blocks,ready,valid,binding,hashParent,hashes,implementation,auth⟩ :=
    Protocol.Custody.certified_landing genesis sound reach accepted
  have height : (Blocks.terminal parent blocks).height = w.inbox.checkpoint.height := by
    have input := congrArg (fun d : StatementData => d.input.lastHeight) binding
    change a.input.lastHeight = (Blocks.terminal parent blocks).height at input
    have actual := congrArg Checkpoint.height checkpoint
    rw [afterEq] at actual
    exact input.symm.trans actual
  have hash : (Blocks.terminal parent blocks).elHash = w.inbox.checkpoint.elHash := by
    have input := congrArg (fun d : StatementData => d.input.lastBlockHash) binding
    change a.input.lastBlockHash = (Blocks.terminal parent blocks).elHash at input
    have actual := congrArg Checkpoint.elHash checkpoint
    rw [afterEq] at actual
    exact input.symm.trans actual
  have recorded : w.inbox.snapshot = Finality.cutoff (config w) archive w.inbox.checkpoint.height := by
    have input := congrArg (fun d : StatementData => d.input.activeCommitteeSnapshot) binding
    change a.input.activeCommitteeSnapshot =
      (Consensus.activeAt (Finality.derive (config before) before.registry.registry archive)
        (Blocks.terminal parent blocks).height).cutoff at input
    rw [Finality.active_cutoff,height,← sameConfig] at input
    rw [afterEq] at snapshot
    exact snapshot.symm.trans input
  obtain ⟨root,prior,rootHeight,rootCut,rootBound,shape,parentEq,linked,bound,_⟩ := auth
  have fullTerminal : Archive.terminal root archive = Blocks.terminal parent blocks := by
    rw [shape,Archive.terminal_append,parentEq,Archive.terminal_block_headers]
  have rootSame : root.height = candidate.root.height := by
    change root.height = (config before).originHeight at rootHeight
    rw [← sameConfig] at rootHeight
    exact rootHeight.trans candidate.rootHeight.symm
  have prefixLinked := ((Archive.linked_append env.headerParent candidate.root candidate.beforeCheckpoint candidate.afterCheckpoint).mp candidate.linked).1
  have sourceLength := Archive.linked_terminal_height linked
  have candidateLength := Archive.linked_terminal_height prefixLinked
  have lengths : archive.length = candidate.beforeCheckpoint.length := by
    rw [fullTerminal,height,rootSame] at sourceLength
    rw [candidate.checkpointHeight] at candidateLength
    omega
  have sourceBound : ∀ header ∈ root :: archive, env.headerHash header = header.elHash := by
    intro header member
    rcases List.mem_cons.mp member with same | past
    · subst header; exact rootBound
    · exact bound header past
  have candidateBound : ∀ header ∈ candidate.root :: candidate.beforeCheckpoint,
      env.headerHash header = header.elHash := by
    intro header member
    rcases List.mem_cons.mp member with same | past
    · subst header; exact candidate.hashes _ List.mem_cons_self
    · exact candidate.hashes _ (List.mem_cons_of_mem _ (List.mem_append_left _ past))
  have anchors := Archive.cutoff_agrees_at_ancestor (cfg := config w)
    (fun x y hx hy same => congrArg BlockValidity.Anchor.number (primitive.separation x y hx hy same).2.2.2)
    linked prefixLinked sourceBound candidateBound lengths
    (by rw [fullTerminal,hash,candidate.checkpointHash]) w.inbox.checkpoint.height
  have covered : Finality.requiredPrefix (config w) w.inbox.checkpoint.height ≤ candidate.beforeCheckpoint.length := by
    have numeric := required_within_height (config w) w.inbox.checkpoint.height
    rw [candidate.checkpointHeight,candidate.rootHeight] at candidateLength
    omega
  have prefixCut := Finality.cutoff_prefix (config w) candidate.beforeCheckpoint candidate.afterCheckpoint
    w.inbox.checkpoint.height covered
  have terminalLength := Archive.linked_terminal_height candidate.linked
  have order : w.inbox.checkpoint.height ≤ h := by
    rw [candidate.terminalHeight,List.length_append] at terminalLength
    rw [candidate.checkpointHeight] at candidateLength
    omega
  rw [recorded,anchors,← prefixCut]
  exact Archive.cutoff_monotone order candidate.ready

private theorem cutoff_initial_floor (cfg : Finality.Config) (archive : List Header) (h : Nat)
    (genesis : cfg.genesisCutoff ≤ cfg.originBlock) :
    Finality.initialCutoff cfg ≤ Finality.cutoff cfg archive h := by
  unfold Finality.cutoff
  split
  · have initial : Finality.initialCutoff cfg ≤ cfg.originBlock := by
      unfold Finality.initialCutoff
      split
      · exact genesis
      · exact Nat.le_refl _
    exact Nat.le_trans initial (Nat.le_max_right _ _)
  · exact Nat.le_refl _

private theorem candidate_genesis_floor {env : Environment} {registry : RegistryMachine.State} {w : World} {h : Nat}
    (run : NormalRun env (empty env registry) w) (candidate : Candidate env w h)
    (generation : w.inbox.generation = 0) :
    env.parameters.genesisCutoff ≤ Finality.cutoff (config w) candidate.headers h := by
  have parameters := Economics.generation_zero_parameters run.project generation
  have cutoff := congrArg Parameters.genesisCutoff parameters
  change w.inbox.genesisCutoff = env.parameters.genesisCutoff at cutoff
  have floor := cutoff_initial_floor (config w) candidate.headers h candidate.ready.2.1
  simpa only [Finality.initialCutoff,config,generation,ite_true,cutoff] using floor

private theorem candidate_origin_floor {env : Environment} {w : World} {h : Nat}
    (candidate : Candidate env w h) (generation : w.inbox.generation ≠ 0) :
    w.inbox.origin.l1Block ≤ Finality.cutoff (config w) candidate.headers h := by
  have floor := cutoff_initial_floor (config w) candidate.headers h candidate.ready.2.1
  simpa only [Finality.initialCutoff,config,generation,ite_false] using floor

/-- Every candidate decision cutoff belongs to its actual closed L1 reference. -/
theorem Candidate.cutoff_closed {env : Environment} {w : World} {h : Nat}
    (candidate : Candidate env w h) : Finality.cutoff (config w) candidate.headers h < w.number := by
  have bounded : Finality.cutoff (config w) candidate.headers h ≤ candidate.reference := by
    unfold Finality.cutoff
    split
    · exact Nat.max_le.mpr ⟨Archive.anchor_bounded candidate.originBeforeReference candidate.anchorBounds _,candidate.originBeforeReference⟩
    · unfold Finality.initialCutoff
      split
      · exact Nat.le_trans candidate.ready.2.1 candidate.originBeforeReference
      · exact candidate.originBeforeReference
  exact Nat.lt_of_le_of_lt bounded candidate.closedReference

/-- A normal node candidate above the real checkpoint uses a selection cutoff no
earlier than the actual stored activeCommitteeSnapshot. The proof follows the
checkpoint's real writer through initialization, start correction, landings and
generation changes. Its only candidate fence is raw physical checkpoint hash equality. -/
theorem candidate_snapshot_bound {env : Environment} {registry : RegistryMachine.State} {w : World} {h : Nat}
    (genesis : RegistryMachine.Genesis registry)
    (run : NormalRun env (empty env registry) w) (started : w.start.isSome = true)
    (primitive : Protocol.Custody.Primitives env) (sound : VerifierSound env (empty env registry))
    (candidate : Candidate env w h) :
    w.inbox.snapshot ≤ Finality.cutoff (config w) candidate.headers h := by
  obtain ⟨before,call,after,priorRun,accepted,writes,complete,sourceStarted,later,checkpoint,snapshot⟩ := run.source started
  have generationOrder := (ProtocolFinality.trace_fields later.project).2.1
  by_cases sameGeneration : w.inbox.generation = after.inbox.generation
  · cases call
    case land landing =>
      have gen : after.inbox.generation = before.inbox.generation := by
        rw [(Protocol.land_success accepted).2]
        rfl
      exact landing_snapshot_bound genesis primitive sound priorRun.project accepted later.project
        (sameGeneration.trans gen) checkpoint snapshot candidate
    case initializeInbox caller =>
      change initializeInbox env before caller = some after at accepted
      unfold initializeInbox at accepted
      split at accepted
      next allowed =>
        split at accepted
        · split at accepted
          · cases Option.some.inj accepted
            have zero : w.inbox.generation = 0 := sameGeneration
            have actual : w.inbox.snapshot = env.parameters.genesisCutoff := snapshot.symm
            rw [actual]
            exact candidate_genesis_floor run candidate zero
          · cases accepted
        · cases Option.some.inj accepted
          have absent := (Journal.trace_frontier_shape priorRun.project).uninitialized allowed.2.1
          change before.start.isSome = true at sourceStarted
          rw [absent] at sourceStarted
          cases sourceStarted
      next => cases accepted
    case setOrigin caller height hash root =>
      change setOrigin env before caller height hash root = some after at accepted
      unfold setOrigin at accepted
      split at accepted
      next allowed =>
        cases Option.some.inj accepted
        have zero : w.inbox.generation = 0 := sameGeneration
        have wasZero : before.inbox.generation = 0 := allowed.2.2.1
        have unlanded := (Journal.trace_frontier_shape priorRun.project).unstarted allowed.2.1
        have old := priorRun.zero_unlanded_snapshot wasZero unlanded
        have actual : w.inbox.snapshot = before.inbox.snapshot := snapshot.symm
        rw [actual]
        exact Nat.le_trans old (candidate_genesis_floor run candidate zero)
      next => cases accepted
    case correctStart caller height hash root =>
      change correctStart env before caller height hash root = some after at accepted
      unfold correctStart at accepted
      obtain ⟨previous,_,accepted⟩ := Option.bind_eq_some_iff.mp accepted
      split at accepted
      · cases Option.some.inj accepted
        have origin := (trace_started_metadata complete.project later.project sourceStarted sameGeneration).2
        have old := priorRun.snapshot_timed genesis sound
        have positive : w.inbox.generation ≠ 0 := by
          change w.inbox.generation = before.inbox.generation+1 at sameGeneration
          omega
        have actual : w.inbox.snapshot = before.inbox.snapshot := snapshot.symm
        rw [actual]
        have floor := candidate_origin_floor candidate positive
        rw [origin] at floor
        exact Nat.le_trans old floor
      · cases accepted
    all_goals cases writes
  · have increased : after.inbox.generation < w.inbox.generation := by omega
    have origin := later.generation_origin_floor increased
    have old := complete.snapshot_timed genesis sound
    have positive : w.inbox.generation ≠ 0 := by omega
    rw [← snapshot]
    exact Nat.le_trans old (Nat.le_trans origin (candidate_origin_floor candidate positive))

/-- The accepted guest's full physical archive passes the same raw latest-checkpoint
hash check as a node candidate. The cutoff equality is extracted from statement bytes. -/
theorem candidate_of_accepted_landing {env : Environment} {registry : RegistryMachine.State}
    {w t : World} {a : Landing} (genesis : RegistryMachine.Genesis registry)
    (sound : VerifierSound env (empty env registry))
    (reach : Trace env (empty env registry) w) (accepted : Protocol.land env w a = some t) :
    ∃ candidate : Candidate env w a.input.lastHeight,
      Finality.cutoff (config w) candidate.headers a.input.lastHeight = a.input.activeCommitteeSnapshot := by
  have check := (Protocol.land_success accepted).1
  have cert := Protocol.Custody.certified_landing genesis sound reach accepted
  obtain ⟨archive,parent,blocks,certificate⟩ := cert
  have frontier := Journal.trace_frontier_shape reach
  have record := frontier.records _ (frontier.member check.started)
  obtain ⟨root,as,bs,rootHeight,shape,linked,hashes,checkpointHeight,checkpointHash⟩ :=
    Protocol.accepted_certificate_checkpoint_split accepted certificate record
  obtain ⟨ready,valid,binding,hashParent,blockHashes,implementation,auth⟩ := certificate
  have height := congrArg (fun d : StatementData => d.input.lastHeight) binding
  change a.input.lastHeight = (Blocks.terminal parent blocks).height at height
  have input := congrArg (fun d : StatementData => d.input.activeCommitteeSnapshot) binding
  change a.input.activeCommitteeSnapshot =
    (Consensus.activeAt (Finality.derive (config w) w.registry.registry archive)
      (Blocks.terminal parent blocks).height).cutoff at input
  rw [Finality.active_cutoff,← height] at input
  obtain ⟨authRoot,prior,authHeight,_,authBound,authShape,authParent,authLinked,authHashes,_,origin,anchors⟩ := auth
  have authTerminal : Archive.terminal authRoot archive = Blocks.terminal parent blocks := by
    rw [authShape,Archive.terminal_append,authParent,Archive.terminal_block_headers]
  have sourceLength := Archive.linked_terminal_height authLinked
  have targetLength := Archive.linked_terminal_height linked
  have terminalHeight : (Archive.terminal root (as ++ bs)).height = a.input.lastHeight := by
    rw [authTerminal,authHeight,← height] at sourceLength
    rw [← shape]
    rw [targetLength,rootHeight]
    exact sourceLength.symm
  let candidate : Candidate env w a.input.lastHeight := {
    root := root, beforeCheckpoint := as, afterCheckpoint := bs,
    rootHeight := rootHeight,
    linked := by rw [← shape]; exact linked,
    hashes := by rw [← shape]; exact hashes,
    checkpointHeight := checkpointHeight, checkpointHash := checkpointHash,
    terminalHeight := terminalHeight,
    ready := by rw [← shape,height]; exact ready,
    reference := a.input.l1ReferenceBlockNumber,
    closedReference := check.reference,
    originBeforeReference := origin,
    anchorBounds := by rw [← shape]; exact anchors }
  refine ⟨candidate,?_⟩
  change Finality.cutoff (config w) (as ++ bs) a.input.lastHeight = _
  rw [← shape]
  exact input.symm

private theorem ordinary_snapshot_order {env : Environment} {registry : RegistryMachine.State} {w t : World} {call : Call}
    (genesis : RegistryMachine.Genesis registry)
    (run : NormalRun env (empty env registry) w) (primitive : Protocol.Custody.Primitives env)
    (sound : VerifierSound env (empty env registry)) (ordinary : OrdinaryCall call)
    (ok : execute env w call = some t) : w.inbox.snapshot ≤ t.inbox.snapshot := by
  cases call
  case initializeInbox caller =>
    change initializeInbox env w caller = some t at ok
    unfold initializeInbox at ok
    split at ok
    next allowed =>
      have absent := (Journal.trace_frontier_shape run.project).uninitialized allowed.2.1
      have unlanded := (Journal.trace_frontier_shape run.project).unstarted absent
      have old := run.zero_unlanded_snapshot allowed.2.2.1 unlanded
      split at ok
      · split at ok
        · cases Option.some.inj ok; exact old
        · cases ok
      · cases Option.some.inj ok; exact old
    next => cases ok
  case setOrigin caller height hash root =>
    change setOrigin env w caller height hash root = some t at ok
    unfold setOrigin at ok
    split at ok
    · cases Option.some.inj ok; exact Nat.le_refl _
    · cases ok
  case correctStart caller height hash root =>
    change correctStart env w caller height hash root = some t at ok
    unfold correctStart at ok
    obtain ⟨previous,_,ok⟩ := Option.bind_eq_some_iff.mp ok
    split at ok
    · cases Option.some.inj ok; exact Nat.le_refl _
    · cases ok
  case land landing =>
    obtain ⟨candidate,cutoff⟩ := candidate_of_accepted_landing genesis sound run.project ok
    have bound := candidate_snapshot_bound genesis run (Protocol.land_success ok).1.started primitive sound candidate
    rw [cutoff] at bound
    rw [(Protocol.land_success ok).2]
    exact bound
  case rollback caller trusted restored => exact False.elim ordinary
  all_goals
    rcases execute_checkpoint_frame ordinary ok with impossible | fields
    · cases impossible
    · rw [fields.2.1]; exact Nat.le_refl _

/-- STAKE-4.1-29 is derived for every ordinary accepted call, using the actual
checkpoint hash fence authenticated by L1's accepted frontier cut. -/
theorem RollbackFreeRun.normal {env : Environment} {registry : RegistryMachine.State} {w : World}
    (genesis : RegistryMachine.Genesis registry)
    (run : RollbackFreeRun env (empty env registry) w) (primitive : Protocol.Custody.Primitives env)
    (sound : VerifierSound env (empty env registry)) : NormalRun env (empty env registry) w := by
  induction run with
  | refl => exact .refl _
  | @call before prior call ordinary ih =>
    apply NormalRun.call ih call ordinary
    cases ok : execute env before call with
    | none => simp only [Protocol.transact,ok,Option.getD_none]; exact Nat.le_refl _
    | some after =>
      simpa only [Protocol.transact,ok,Option.getD_some] using ordinary_snapshot_order genesis ih primitive sound ordinary ok
  | node prior after valid ih => exact .node ih after valid

/-- One successful ordinary call keeps every retained signal. Once something has landed it
also keeps every retained record and never lowers the checkpoint: only `land` writes one,
above the old checkpoint, and the calls that rewrite the start are refused after a landing. -/
theorem execute_retains {env : Environment} {initial w t : World} {call : Call}
    (shape : Journal.FrontierShape w) (held : Protocol.Custody.Coherent env initial w)
    (ordinary : OrdinaryCall call) (ok : execute env w call = some t) :
    (∀ s ∈ w.inbox.signals, s ∈ t.inbox.signals) ∧
      (w.everLanded = true → w.inbox.checkpoint.height ≤ t.inbox.checkpoint.height ∧
        ∀ cp ∈ w.activeRecords, cp ∈ t.activeRecords) := by
  have keep : t.inbox.signals = w.inbox.signals → t.inbox.checkpoint = w.inbox.checkpoint →
      t.activeRecords = w.activeRecords → (∀ s ∈ w.inbox.signals, s ∈ t.inbox.signals) ∧
      (w.everLanded = true → w.inbox.checkpoint.height ≤ t.inbox.checkpoint.height ∧
        ∀ cp ∈ w.activeRecords, cp ∈ t.activeRecords) := by
    intro signals checkpoint records
    rw [signals,checkpoint,records]
    exact ⟨fun _ m => m,fun _ => ⟨Nat.le_refl _,fun _ m => m⟩⟩
  cases call with
  | advance number =>
    change Protocol.advance env w number = some t at ok
    unfold Protocol.advance at ok
    split at ok
    next => cases Option.some.inj ok; exact keep rfl rfl rfl
    next => simp at ok
  | initializeInbox caller =>
    change Protocol.initializeInbox env w caller = some t at ok
    unfold Protocol.initializeInbox at ok
    split at ok
    next guard =>
      have unstarted := shape.uninitialized guard.2.1
      have none := Protocol.Custody.unstarted_no_signals held unstarted
      have unlanded := shape.unstarted unstarted
      exact ⟨by simp [none],fun ever => by simp [ever] at unlanded⟩
    next => simp at ok
  | setOrigin caller height hash root =>
    change Protocol.setOrigin env w caller height hash root = some t at ok
    unfold Protocol.setOrigin at ok
    split at ok
    next guard =>
      cases Option.some.inj ok
      have unlanded := shape.unstarted guard.2.1
      exact ⟨fun _ m => m,fun ever => by simp [ever] at unlanded⟩
    next => simp at ok
  | correctStart caller height hash root =>
    change Protocol.correctStart env w caller height hash root = some t at ok
    unfold Protocol.correctStart at ok
    obtain ⟨old,_,ok⟩ := Option.bind_eq_some_iff.mp ok
    split at ok
    next guard =>
      cases Option.some.inj ok
      exact ⟨fun _ m => m,fun ever => by simp [ever] at guard⟩
    next => simp at ok
  | registry caller action =>
    change Protocol.registryCall env w caller action = some t at ok
    unfold Protocol.registryCall at ok
    split at ok
    next =>
      obtain ⟨result,_,rfl⟩ := Option.map_eq_some_iff.mp ok
      exact keep rfl rfl rfl
    next => simp at ok
  | enqueue raw paid refund =>
    change Protocol.enqueue env w raw paid refund = some t at ok
    unfold Protocol.enqueue at ok
    split at ok
    next =>
      obtain ⟨inbox,inner,rfl⟩ := Option.map_eq_some_iff.mp ok
      unfold Forced.enqueue at inner
      dsimp only at inner
      split at inner
      next => cases Option.some.inj inner; exact keep rfl rfl rfl
      next => simp at inner
    next => simp at ok
  | sweep transfer =>
    change Protocol.sweep w transfer = some t at ok
    obtain ⟨inbox,inner,rfl⟩ := Option.map_eq_some_iff.mp ok
    unfold Forced.sweep at inner
    split at inner
    next => cases Option.some.inj inner; exact keep rfl rfl rfl
    next => simp at inner
  | forcedETH amount =>
    cases Option.some.inj ok
    exact keep rfl rfl rfl
  | scheduleRules caller rule time =>
    change Protocol.scheduleRules env w caller rule time = some t at ok
    obtain ⟨schedule,_,rfl⟩ := Option.map_eq_some_iff.mp ok
    exact keep rfl rfl rfl
  | scheduleStop caller time grid =>
    change Protocol.scheduleStop env w caller time grid = some t at ok
    obtain ⟨schedule,_,rfl⟩ := Option.map_eq_some_iff.mp ok
    exact keep rfl rfl rfl
  | recover request =>
    change Protocol.recover env w request = some t at ok
    unfold Protocol.recover at ok
    obtain ⟨start,_,ok⟩ := Option.bind_eq_some_iff.mp ok
    dsimp only at ok
    cases upgrade : request.upgrade <;> simp only [upgrade,Option.isSome_none,Option.isSome_some,
      Option.getD_none,Option.getD_some,Bool.false_eq_true,↓reduceIte] at ok
    all_goals
      split at ok
      next =>
        obtain ⟨schedule,_,ok⟩ := Option.bind_eq_some_iff.mp ok
        obtain ⟨registry,_,rfl⟩ := Option.map_eq_some_iff.mp ok
        exact keep rfl rfl rfl
      next => simp at ok
  | invalidate caller nonce =>
    change Protocol.invalidate env w caller nonce = some t at ok
    unfold Protocol.invalidate at ok
    split at ok
    next => cases Option.some.inj ok; exact keep rfl rfl rfl
    next => simp at ok
  | rollback caller trusted restored => exact False.elim ordinary
  | land a =>
    obtain ⟨check,rfl⟩ := Protocol.land_success ok
    exact ⟨fun _ m => List.mem_append_left _ m,
      fun _ => ⟨Nat.le_of_lt check.progress,fun _ m => List.mem_cons_of_mem _ m⟩⟩
  | unzenProve proposal header proof =>
    change Protocol.unzenProve env w proposal header proof = some t at ok
    unfold Protocol.unzenProve at ok
    split at ok
    next => cases Option.some.inj ok; exact keep rfl rfl rfl
    next => simp at ok
  | image caller image register | verifier caller version =>
    simp only [Protocol.execute] at ok
    split at ok
    next => cases Option.some.inj ok; exact keep rfl rfl rfl
    next => simp at ok
  | observe number =>
    change Protocol.observe env w number = some t at ok
    obtain ⟨s,_,rfl⟩ := Option.map_eq_some_iff.mp ok
    exact keep rfl rfl rfl
  | importSnapshot candidate durable =>
    change Protocol.nodeImport env w candidate durable = some t at ok
    unfold Protocol.nodeImport at ok
    split at ok
    next => simp at ok
    next =>
      split at ok
      next =>
        obtain ⟨installed,_,rfl⟩ := Option.map_eq_some_iff.mp ok
        exact keep rfl rfl rfl
      next => simp at ok
  | restart | openSigner _ | switchSigner _ =>
    cases Option.some.inj ok
    exact keep rfl rfl rfl
  | sign message signature persisted =>
    obtain ⟨result,_,rfl⟩ := Option.map_eq_some_iff.mp ok
    exact keep rfl rfl rfl

/-- SPEC section 1, finality of checkpoints: a later run without a rollback keeps every
retained signal and, once something has landed, every retained record and a checkpoint at
least as high. -/
theorem RollbackFreeRun.retains {env : Environment} {registry : RegistryMachine.State}
    {w later : World} (genesis : RegistryMachine.Genesis registry)
    (primitive : Protocol.Custody.Primitives env) (sound : VerifierSound env (empty env registry))
    (reach : Trace env (empty env registry) w) (run : RollbackFreeRun env w later) :
    (∀ s ∈ w.inbox.signals, s ∈ later.inbox.signals) ∧
      (w.everLanded = true → w.inbox.checkpoint.height ≤ later.inbox.checkpoint.height ∧
        ∀ cp ∈ w.activeRecords, cp ∈ later.activeRecords) := by
  induction run with
  | refl => exact ⟨fun _ m => m,fun _ => ⟨Nat.le_refl _,fun _ m => m⟩⟩
  | @call before prior call ordinary ih =>
    cases ok : execute env before call with
    | none => simpa only [Protocol.transact,ok,Option.getD_none] using ih
    | some after =>
      have current := Protocol.Custody.trace_append reach prior.project
      have step := execute_retains (Journal.trace_frontier_shape current)
        (Protocol.Custody.trace_coherent genesis primitive sound current) ordinary ok
      simp only [Protocol.transact,ok,Option.getD_some]
      refine ⟨fun s m => step.1 s (ih.1 s m),fun ever => ?_⟩
      obtain ⟨height,records⟩ := ih.2 ever
      obtain ⟨height',records'⟩ :=
        step.2 (Protocol.Custody.trace_start_frozen reach ever prior.project).2
      exact ⟨Nat.le_trans height height',fun cp m => records' cp (records cp m)⟩
  | node prior after valid ih => exact ih

/-- The complete normal-execution accountability result consumes the node's raw
candidate ancestry/checkpoint hash check and derives the retention cutoff itself. -/
theorem economically_at_risk_of_candidate {env : Environment} {registry : RegistryMachine.State}
    {w : World} {h : Nat} (run : RollbackFreeRun env (empty env registry) w)
    (started : w.start.isSome = true) (primitive : Protocol.Custody.Primitives env)
    (sound : VerifierSound env (empty env registry)) (candidate : Candidate env w h)
    (genesis : RegistryMachine.Genesis registry) (standard : ProtocolFinality.StandardToken env)
    (self : env.initialToken.allowances env.token.registryAddress env.token.registryAddress = 0)
    (rate : registry.config.slashBountyBps < 10000)
    (refinement : Finality.SignatureRefinement registry env.signature)
    (deployment : env.evidenceWindow ≤ registry.config.withdrawalDelay) (initialized : w.initialized = true)
    {common moreA moreB : List Header} {referenceA referenceB round a b : Nat}
    {votesA votesB : List Consensus.Vote}
    (shape : candidate.headers = common ++ moreA)
    (covered : Finality.requiredPrefix (config w) h ≤ common.length)
    (validA : Consensus.CommitValid (policy env w (common ++ moreA) referenceA).consensus env.signature h round a votesA)
    (validB : Consensus.CommitValid (policy env w (common ++ moreB) referenceB).consensus env.signature h round b votesB)
    (conflict : a ≠ b) :
    StakeRisk.AccountableAtRisk env w (policy env w (common ++ moreA) referenceA).consensus h votesA votesB := by
  have normal := run.normal genesis primitive sound
  have window := evidence_window_of_deployment deployment run.project
  have bound := candidate_snapshot_bound genesis normal started primitive sound candidate
  rw [shape] at bound
  exact StakeRisk.economically_at_risk genesis standard self rate run.project normal.registry
    refinement initialized window bound covered validA validB conflict

/-- Every member of a valid candidate committee is retained, independent of which
members form a particular equivocation overlap or which consensus round is used. -/
theorem committee_retained_of_candidate {env : Environment} {registry : RegistryMachine.State}
    {w : World} {h : Nat} (genesis : RegistryMachine.Genesis registry)
    (run : RollbackFreeRun env (empty env registry) w) (started : w.start.isSome = true)
    (primitive : Protocol.Custody.Primitives env) (sound : VerifierSound env (empty env registry))
    (candidate : Candidate env w h)
    (elected : Consensus.ElectionValid (policy env w candidate.headers candidate.reference).consensus
      (Consensus.activeAt (policy env w candidate.headers candidate.reference).consensus h)) :
    ∀ entry ∈ (Consensus.activeAt (policy env w candidate.headers candidate.reference).consensus h).members,
      ∃ id, StakeRisk.Retained w.registry.registry
        (Finality.cutoff (config w) candidate.headers h) id entry.key := by
  have unit : 0 < w.inbox.configuration.unit := by
    unfold Consensus.ElectionValid Committee.election at elected
    dsimp only at elected
    split at elected
    next allowed => exact allowed.1
    next => cases elected
  have normal := run.normal genesis primitive sound
  have bound := candidate_snapshot_bound genesis normal started primitive sound candidate
  intro entry member
  exact StakeRisk.committee_unconfirmed normal.registry genesis unit bound member

end Etna.Design.Current.CheckpointRisk
