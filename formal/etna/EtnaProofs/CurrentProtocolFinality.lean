import EtnaModel.CurrentProtocolFinality
import EtnaProofs.CurrentRegistryPayments
import EtnaProofs.CurrentFinality

namespace Etna.Design.Current.ProtocolFinality
open Protocol

private theorem registry_trans {a b c : RegistryMachine.World}
    (first : RegistryMachine.Trace a b) (later : RegistryMachine.Trace b c) : RegistryMachine.Trace a c := by
  induction later with
  | refl => exact first
  | step _ change ih => exact .step ih change

private structure Frame (env : Environment) (w t : World) : Prop where
  registry : t.registry.registry = w.registry.registry
  domain : t.inbox.domain = w.inbox.domain
  generation : w.inbox.generation ≤ t.inbox.generation
  initialized : w.initialized = true → t.initialized = true
  number : w.number ≤ t.number
  time : env.time w.number ≤ env.time t.number

private theorem frame_trace {env : Environment} {w t : World} (frame : Frame env w t) :
    RegistryMachine.Trace (registryWorld env w) (registryWorld env t) := by
  unfold registryWorld
  rw [frame.registry]
  exact .step (.refl _) (.frame _ _ _ _ _ frame.domain frame.generation frame.initialized frame.number frame.time)

private theorem unchanged_trace {env : Environment} {w t : World}
    (same : registryWorld env t = registryWorld env w) :
    RegistryMachine.Trace (registryWorld env w) (registryWorld env t) := by
  rw [same]
  exact .refl _

/-- Each successful real call projects to closed principal actions and derived Inbox
frames. Registry public calls first pass the atomic payment wrapper; recovery and rollback
invoke their actual internal actions before advancing the corresponding Inbox view. -/
theorem execute_registry_trace {env : Environment} {w t : World} {call : Call}
    (ok : execute env w call = some t) :
    RegistryMachine.Trace (registryWorld env w) (registryWorld env t) := by
  cases call with
  | advance number =>
    simp only [Protocol.execute] at ok
    unfold Protocol.advance at ok
    split at ok
    next allowed =>
      cases Option.some.inj ok
      apply frame_trace
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
          apply frame_trace
          constructor <;> simp_all [writeStart]
        · cases ok
      · cases Option.some.inj ok
        apply frame_trace
        exact ⟨rfl,rfl,Nat.le_refl _,fun _ => rfl,Nat.le_refl _,Nat.le_refl _⟩
    next => cases ok
  | setOrigin caller height hash root =>
    simp only [Protocol.execute] at ok
    unfold Protocol.setOrigin at ok
    split at ok
    next allowed =>
      cases Option.some.inj ok
      apply frame_trace
      constructor <;> simp_all [writeStart]
    next => cases ok
  | correctStart caller height hash root =>
    simp only [Protocol.execute] at ok
    unfold Protocol.correctStart at ok
    obtain ⟨old,_,ok⟩ := Option.bind_eq_some_iff.mp ok
    split at ok
    · cases Option.some.inj ok
      apply frame_trace
      exact ⟨rfl,rfl,Nat.le_succ _,id,Nat.le_refl _,Nat.le_refl _⟩
    · cases ok
  | registry caller action =>
    simp only [Protocol.execute] at ok
    unfold Protocol.registryCall at ok
    split at ok
    · obtain ⟨⟨paid,receipts⟩,transaction,equal⟩ := Option.map_eq_some_iff.mp ok
      subst t
      exact .step (.refl _) (.call action (RegistryPayments.tx_success_projects transaction))
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
        exact .step (.step (.refl _) (.call _ executed))
          (.frame registry _ _ _ _ rfl (Nat.le_succ _) id (Nat.le_refl _) (Nat.le_refl _))
      · cases ok
  | invalidate caller nonce =>
    simp only [Protocol.execute] at ok
    unfold Protocol.invalidate at ok
    split at ok
    · cases Option.some.inj ok
      exact unchanged_trace rfl
    · cases ok
  | rollback caller trusted snapshot =>
    simp only [Protocol.execute] at ok
    unfold Protocol.rollback at ok
    split at ok
    · obtain ⟨registry,executed,equal⟩ := Option.map_eq_some_iff.mp ok
      subst t
      exact .step (.step (.refl _) (.call _ executed))
        (.frame registry _ _ _ _ rfl (Nat.le_refl _) id (Nat.le_refl _) (Nat.le_refl _))
    · cases ok
  | land landing =>
    simp only [Protocol.execute] at ok
    unfold Protocol.land at ok
    split at ok
    · cases Option.some.inj ok
      apply frame_trace
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

theorem transact_registry_trace (env : Environment) (w : World) (call : Call) :
    RegistryMachine.Trace (registryWorld env w) (registryWorld env (Protocol.transact env w call)) := by
  cases outcome : execute env w call with
  | none => simp only [Protocol.transact,outcome,Option.getD_none]; exact .refl _
  | some t => simp only [Protocol.transact,outcome,Option.getD_some]; exact execute_registry_trace outcome

theorem step_registry_trace {env : Environment} {w t : World} (change : Step env w t) :
    RegistryMachine.Trace (registryWorld env w) (registryWorld env t) := by
  cases change with
  | call call => exact transact_registry_trace env _ call
  | node => exact unchanged_trace rfl

/-- Actual protocol traces induce the closed permanent-registry trace. The only changed
L1 clock is guarded by advance; no caller-supplied frame or time monotonicity is assumed. -/
theorem registry_trace {env : Environment} {first later : World} (run : Trace env first later) :
    RegistryMachine.Trace (registryWorld env first) (registryWorld env later) := by
  induction run with
  | refl => exact .refl _
  | step _ change ih => exact registry_trans ih (step_registry_trace change)

/-- Domain, initialization, generation, both clocks and immutable registry adapters are
consequences of the actual protocol trace, including payment failures and node events. -/
theorem trace_fields {env : Environment} {first later : World} (run : Trace env first later) :
    later.inbox.domain = first.inbox.domain ∧ first.inbox.generation ≤ later.inbox.generation ∧
    (first.initialized = true → later.initialized = true) ∧ first.number ≤ later.number ∧
    env.time first.number ≤ env.time later.number ∧
    later.registry.registry.config = first.registry.registry.config ∧
    later.registry.registry.verify = first.registry.registry.verify := by
  have stable := RegistryMachine.trace_stable (registry_trace run)
  exact ⟨stable.domain,stable.generation,stable.initialized,stable.time,stable.timestamp,
    stable.registry.config,stable.registry.verify⟩

theorem signature_refinement_trace {env : Environment} {first later : World} (run : Trace env first later)
    (refinement : Finality.SignatureRefinement first.registry.registry env.signature) :
    Finality.SignatureRefinement later.registry.registry env.signature := by
  intro vote signed
  obtain ⟨signature,verified⟩ := refinement vote signed
  refine ⟨signature,?_⟩
  rw [(trace_fields run).2.2.2.2.2.2]
  exact verified

private theorem standard_environment_eq (token : RegistryPayments.PaymentEnvironment)
    (standard : token.transfer = RegistryPayments.standardTransfer token.registryAddress) :
    token = RegistryPayments.standardEnvironment token.registryAddress token.slashSink := by
  cases token
  dsimp only at standard
  cases standard
  rfl

/-- The actual outer slash transaction commits its principal edit and both fixed-rate
payments atomically. Available standard-token funding is the only external condition;
principal authorization is derived from persistent authenticated evidence. -/
theorem paid_evidence_future_liability {env : Environment} {first : World} {key : Hash}
    {a b : Staking.Vote} {sa sb : Hash}
    (standard : StandardToken env) (initialized : first.initialized = true)
    (rate : first.registry.registry.config.slashBountyBps < 10000)
    (auth : RegistryMachine.Evidence first.registry.registry (registryView env first) key a b sa sb) :
    PaidFutureLiability env first key a b sa sb := by
  intro later run id current caller issued found sameKey live positive free funded
  have stable := RegistryMachine.trace_stable (registry_trace run)
  have evidence := RegistryMachine.evidence_monotone stable.registry.verify stable.domain stable.generation auth
  rw [← sameKey] at evidence
  have laterRate : later.registry.registry.config.slashBountyBps < 10000 := by
    rw [(trace_fields run).2.2.2.2.2.1]
    exact rate
  obtain ⟨principal,executed⟩ := RegistryMachine.slash_enabled (now := later.number) issued found (stable.initialized initialized)
    free live positive laterRate evidence
  obtain ⟨token,transfers⟩ := RegistryPayments.standard_slash_transfers_available
    env.token.registryAddress env.token.slashSink caller current.value.balance
    later.registry.registry.config.slashBountyBps later.registry.token (Nat.le_of_lt laterRate) funded
  rw [← standard_environment_eq env.token standard] at transfers
  have intents := RegistryPayments.slash_payments_exact env.token later.registry.registry caller id a b sa sb current found
  rw [← intents] at transfers
  have transaction := RegistryPayments.principal_and_transfers_commit executed rfl transfers
  simp only [registryWorld] at transaction
  refine ⟨{ later with registry := ⟨principal,token⟩, receipts := later.receipts ++
      RegistryPayments.paymentIntents env.token later.registry.registry caller (.slash id a b sa sb) },?_,?_⟩
  · simp only [registryCall,publicRegistry,ite_true,transaction,Option.map_some]
  · change later.receipts ++ RegistryPayments.paymentIntents env.token later.registry.registry caller (.slash id a b sa sb) = _
    rw [intents]
    rfl

/-- Current accountable safety uses this reachable World's actual configuration and
historical slot snapshots, plus signature refinement preserved from the initial registry.
The conclusion covers actual future outer slash transactions and exact payment receipts. -/
theorem protocol_same_round_accountability {env : Environment} {initial w : World}
    (run : Trace env initial w) (standard : StandardToken env)
    (refinement : Finality.SignatureRefinement initial.registry.registry env.signature)
    (initialized : w.initialized = true)
    (rate : initial.registry.registry.config.slashBountyBps < 10000)
    {common moreA moreB : List Header} {referenceA referenceB h round a b : Nat}
    {votesA votesB : List Consensus.Vote}
    (covered : Finality.requiredPrefix (config w) h ≤ common.length)
    (validA : Consensus.CommitValid (policy env w (common ++ moreA) referenceA).consensus env.signature h round a votesA)
    (validB : Consensus.CommitValid (policy env w (common ++ moreB) referenceB).consensus env.signature h round b votesB)
    (conflict : a ≠ b) :
    PaidAccountable env w (policy env w (common ++ moreA) referenceA).consensus h votesA votesB := by
  have currentRate : w.registry.registry.config.slashBountyBps < 10000 := by
    rw [(trace_fields run).2.2.2.2.2.1]
    exact rate
  have liability := Finality.shared_prefix_accountability (cfg := config w)
    (registryA := w.registry.registry) (registryB := w.registry.registry)
    (common := common) (moreA := moreA) (moreB := moreB) (first := registryWorld env w)
    covered rfl validA validB conflict (signature_refinement_trace run refinement)
    rfl (Nat.le_refl _) initialized currentRate
  refine ⟨liability.1,?_⟩
  intro entry member
  obtain ⟨va,inA,vb,inB,keyA,keyB,sa,sb,evidence,_⟩ := liability.2 entry member
  exact ⟨va,inA,vb,inB,keyA,keyB,sa,sb,evidence,
    paid_evidence_future_liability standard initialized currentRate evidence⟩

/-- Global cross-round H2 for actual current World policies. Each complete chain derives
its own context from its own full header array; the common actual registry/configuration
is read directly from the current World, never supplied as a context-equality premise. -/
theorem protocol_full_chain_agreement {env : Environment} {w : World} {engine : Finality.Engine}
    {origin : Header} {as bs : List Block} {referenceA referenceB : Nat}
    (originHeight : origin.height = w.inbox.origin.height)
    (validA : Blocks.Chain (policy env w (as.map Blocks.Block.header) referenceA) origin as)
    (validB : Blocks.Chain (policy env w (bs.map Blocks.Block.header) referenceB) origin bs)
    (binding : Finality.CometHeaderBinding (policy env w (as.map Blocks.Block.header) referenceA)
      (policy env w (bs.map Blocks.Block.header) referenceB))
    (honesty : Finality.ChainHonesty engine (config w)
      (policy env w (as.map Blocks.Block.header) referenceA) origin as)
    (attrA : Finality.ChainAttribution engine (config w) origin as)
    (attrB : Finality.ChainAttribution engine (config w) origin bs) :
    Finality.HeaderAgreement (as.map Blocks.Block.header) (bs.map Blocks.Block.header) :=
  Finality.full_chain_agreement (cfg := config w) (registry := w.registry.registry)
    originHeight rfl rfl validA validB binding honesty attrA attrB

/-- Complete current H2 bridge over actual reachable protocol states. None of its primitive
premises asserts committee equality, chain agreement, evidence validity or slashability. -/
theorem current_h2 {env : Environment} {initial w : World} {engine : Finality.Engine}
    (run : Trace env initial w) (standard : StandardToken env)
    (refinement : Finality.SignatureRefinement initial.registry.registry env.signature)
    (initialized : w.initialized = true)
    (rate : initial.registry.registry.config.slashBountyBps < 10000)
    (codec : CodecSound env w) (honesty : HonestExecutions engine env w)
    (attribution : VoteAttribution engine env w) : H2 env w := by
  constructor
  · intro common moreA moreB refA refB h round a b votesA votesB covered validA validB conflict
    exact protocol_same_round_accountability run standard refinement initialized rate covered validA validB conflict
  · intro origin as bs refA refB originHeight validA validB
    exact protocol_full_chain_agreement originHeight validA validB (codec _ _ _ _)
      (honesty origin as refA originHeight validA)
      (attribution origin as refA originHeight validA) (attribution origin bs refB originHeight validB)

end Etna.Design.Current.ProtocolFinality
