import EtnaModel.CurrentEconomics
import EtnaProofs.CurrentProtocolFinality

namespace Etna.Design.Current.Economics
open Protocol
set_option maxRecDepth 30000
set_option maxHeartbeats 4000000

theorem protocol_closed_history {env : Environment} {first later : World}
    (run : Trace env first later) {cutoff : Nat} (closed : cutoff < first.number) :
    later.registry.registry.history.filter (fun cp => decide (cp.block ≤ cutoff)) =
      first.registry.registry.history.filter (fun cp => decide (cp.block ≤ cutoff)) :=
  RegistryMachine.trace_closed_history (ProtocolFinality.registry_trace run) closed

/-- Empty raw genesis storage plus actual registry calls eliminates phantom historical
committee identities, including entries later displaced, punished or withdrawn. -/
theorem history_issued {env : Environment} {registry : RegistryMachine.State} {w : World}
    (genesis : RegistryMachine.Genesis registry) (run : Trace env (empty env registry) w) :
    RegistryMachine.SlotsIssued w.registry.registry.ledger ∧ RegistryMachine.HistoryIssued w.registry.registry :=
  RegistryMachine.trace_history_issued (ProtocolFinality.registry_trace run) genesis

theorem registry_history_time {env : Environment} {registry : RegistryMachine.State} {w : World}
    (genesis : RegistryMachine.Genesis registry) (run : Trace env (empty env registry) w) :
    RegistryHistory.Ordered w.registry.registry.history ∧
      ∀ cp ∈ w.registry.registry.history, cp.block ≤ w.number := by
  apply RegistryMachine.trace_history_time (ProtocolFinality.registry_trace run)
  have noHistory := genesis.2.2.2.2.1
  constructor
  · change RegistryHistory.Ordered registry.history
    simp [noHistory,RegistryHistory.Ordered]
  · intro cp member
    change cp ∈ registry.history at member
    rw [noHistory] at member
    cases member

/-- The reverse signature refinement authenticates both actual signed votes in every
successful public slash. A permissive verifier cannot satisfy this primitive contract. -/
theorem no_false_slash {env : Environment} {registry : RegistryMachine.State} {w next : World}
    (run : Trace env (empty env registry) w)
    (sound : Finality.SignatureSound registry env.signature) {caller id : Nat}
    {a b : Staking.Vote} {sa sb : Hash}
    (ok : registryCall env w caller (.slash id a b sa sb) = some next) :
    ∃ bond, id < w.registry.registry.ledger.nextId ∧
      w.registry.registry.ledger.bonds id = some bond ∧
      env.signature (Finality.signedVote bond.value.key a) ∧
      env.signature (Finality.signedVote bond.value.key b) ∧
      Staking.doubleSign w.inbox.domain w.inbox.generation a b = true := by
  simp only [registryCall,publicRegistry,ite_true] at ok
  obtain ⟨⟨paid,receipts⟩,transaction,_⟩ := Option.map_eq_some_iff.mp ok
  obtain ⟨bond,issued,found,evidence⟩ :=
    RegistryMachine.slash_evidence (RegistryPayments.tx_success_projects transaction)
  have fixed := (ProtocolFinality.trace_fields run).2.2.2.2.2.2
  refine ⟨bond,issued,found,?_,?_,evidence.2.2⟩
  · exact sound _ _ _ (by simpa only [fixed,empty] using evidence.1)
  · exact sound _ _ _ (by simpa only [fixed,empty] using evidence.2.1)

theorem derived_member_issued {cfg : Finality.Config} {registry : RegistryMachine.State}
    {archive : List Blocks.Header} {h : Nat} {entry : Committee.Entry}
    (history : RegistryMachine.HistoryIssued registry) (unit : 0 < cfg.unit)
    (member : entry ∈ (Consensus.activeAt (Finality.derive cfg registry archive) h).members) :
    ∃ id bond, id < registry.ledger.nextId ∧ registry.ledger.bonds id = some bond ∧
      bond.value.key = entry.key := by
  let c := Finality.derive cfg registry archive
  let cut := (Consensus.activeAt c h).cutoff
  have chosen : (Consensus.activeAt c h).members =
      Committee.chosen cfg.unit cfg.minimum cut cfg.nMax (Finality.registryAt registry cut) := by
    unfold cut Consensus.activeAt
    dsimp only
    split <;> rfl
  change entry ∈ (Consensus.activeAt c h).members at member
  rw [chosen] at member
  have elected := Committee.chosen_eligible cfg.unit cfg.minimum cut cfg.nMax _ entry member
  have positive : entry.stake ≠ 0 := by
    have high := Nat.le_max_right cfg.minimum cfg.unit
    omega
  have raw := elected.1
  unfold Finality.registryAt at raw
  cases found : RegistryHistory.latestSnapshot registry.history cut with
  | none => simp [found] at raw
  | some cp =>
    simp only [found,Option.map_some,Option.getD_some] at raw
    exact history cp (List.mem_of_find?_eq_some found) entry raw positive

/-- Actual transaction history gives every selected committee identity a permanent issued
bond. Initial fabricated historical election power cannot satisfy raw Genesis. -/
theorem committee_issued {env : Environment} {registry : RegistryMachine.State} {w : World}
    (genesis : RegistryMachine.Genesis registry) (run : Trace env (empty env registry) w)
    (unit : 0 < w.inbox.configuration.unit) {archive : List Header} {reference h : Nat}
    {entry : Committee.Entry}
    (member : entry ∈ (Consensus.activeAt (policy env w archive reference).consensus h).members) :
    ∃ id bond, id < w.registry.registry.ledger.nextId ∧
      w.registry.registry.ledger.bonds id = some bond ∧ bond.value.key = entry.key :=
  derived_member_issued (history_issued genesis run).2 unit member

private theorem execute_history_cases {env : Environment} {w t : World} {call : Call}
    (ok : execute env w call = some t) :
    (t.history = w.history ∧ t.number = w.number) ∨
      ∃ n, w.number < n ∧ t.number = n ∧ t.registry.registry = w.registry.registry ∧
        t.history = w.history ++ (List.range' w.number (n-w.number)).map (snapshot env w) := by
  cases call with
  | advance n =>
    simp only [execute] at ok
    unfold advance at ok
    split at ok
    next allowed =>
      cases Option.some.inj ok
      exact Or.inr ⟨n,allowed.1,rfl,rfl,rfl⟩
    · cases ok
  | initializeInbox caller =>
    simp only [execute] at ok
    unfold initializeInbox at ok
    split at ok
    · split at ok
      · split at ok
        · cases Option.some.inj ok; exact Or.inl ⟨rfl,rfl⟩
        · cases ok
      · cases Option.some.inj ok; exact Or.inl ⟨rfl,rfl⟩
    · cases ok
  | setOrigin caller h hash root =>
    simp only [execute] at ok
    unfold setOrigin at ok
    split at ok
    · cases Option.some.inj ok; exact Or.inl ⟨rfl,rfl⟩
    · cases ok
  | correctStart caller h hash root =>
    simp only [execute] at ok
    unfold correctStart at ok
    obtain ⟨old,_,ok⟩ := Option.bind_eq_some_iff.mp ok
    split at ok
    · cases Option.some.inj ok; exact Or.inl ⟨rfl,rfl⟩
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
    · obtain ⟨inbox,_,rfl⟩ := Option.map_eq_some_iff.mp ok
      exact Or.inl ⟨rfl,rfl⟩
    · cases ok
  | sweep transfer =>
    simp only [execute] at ok
    obtain ⟨inbox,_,rfl⟩ := Option.map_eq_some_iff.mp ok
    exact Or.inl ⟨rfl,rfl⟩
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
        exact Or.inl ⟨rfl,rfl⟩
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

theorem execute_closed_registry_history {env : Environment} {w t : World} {call : Call}
    (old : ClosedRegistryHistory w) (ok : execute env w call = some t) : ClosedRegistryHistory t := by
  intro s member
  have reg := ProtocolFinality.execute_registry_trace ok
  have stable := RegistryMachine.trace_stable reg
  rcases execute_history_cases ok with ⟨same,number⟩ | ⟨n,advanced,number,registry,history⟩
  · rw [same] at member
    have prior := old s member
    exact ⟨by simpa [number] using prior.1,
      (RegistryMachine.trace_closed_history reg prior.1).trans prior.2⟩
  · rw [history,List.mem_append] at member
    rcases member with prior | fresh
    · have was := old s prior
      exact ⟨by omega,by simpa only [registry] using was.2⟩
    · obtain ⟨k,range,rfl⟩ := List.mem_map.mp fresh
      have bound := List.mem_range'.mp range
      exact ⟨by simp only [snapshot]; omega,by simp only [registry,snapshot]⟩

theorem closed_registry_history {env : Environment} {registry : RegistryMachine.State} {w : World}
    (run : Trace env (empty env registry) w) : ClosedRegistryHistory w := by
  induction run with
  | refl => intro s member; cases member
  | @step before after prior change ih =>
    cases change with
    | call call =>
      cases result : execute env before call with
      | none => simpa only [Protocol.transact,result,Option.getD_none] using ih
      | some after =>
        simpa only [Protocol.transact,result,Option.getD_some] using execute_closed_registry_history ih result
    | node after validated => exact ih

private theorem execute_parameters {env : Environment} {w t : World} {call : Call}
    (ok : execute env w call = some t) :
    parametersOf t.inbox = parametersOf w.inbox ∨ w.inbox.generation < t.inbox.generation := by
  cases call with
  | advance n =>
    simp only [execute] at ok
    unfold advance at ok
    split at ok
    next allowed =>
      cases Option.some.inj ok
      exact Or.inl rfl
    · cases ok
  | initializeInbox caller =>
    simp only [execute] at ok
    unfold initializeInbox at ok
    split at ok
    · split at ok
      · split at ok
        · cases Option.some.inj ok; exact Or.inl rfl
        · cases ok
      · cases Option.some.inj ok; exact Or.inl rfl
    · cases ok
  | setOrigin caller h hash root =>
    simp only [execute] at ok
    unfold setOrigin at ok
    split at ok
    · cases Option.some.inj ok; exact Or.inl rfl
    · cases ok
  | correctStart caller h hash root =>
    simp only [execute] at ok
    unfold correctStart at ok
    obtain ⟨old,_,ok⟩ := Option.bind_eq_some_iff.mp ok
    split at ok
    · cases Option.some.inj ok; exact Or.inl rfl
    · cases ok
  | registry caller action =>
    simp only [execute] at ok
    unfold registryCall at ok
    split at ok
    · obtain ⟨result,_,rfl⟩ := Option.map_eq_some_iff.mp ok
      exact Or.inl rfl
    · cases ok
  | enqueue raw paid refund =>
    simp only [execute] at ok
    unfold enqueue at ok
    split at ok
    · obtain ⟨inbox,enqueued,rfl⟩ := Option.map_eq_some_iff.mp ok
      unfold Forced.enqueue at enqueued
      dsimp only at enqueued
      split at enqueued
      · cases Option.some.inj enqueued; exact Or.inl rfl
      · cases enqueued
    · cases ok
  | sweep transfer =>
    simp only [execute] at ok
    obtain ⟨inbox,swept,rfl⟩ := Option.map_eq_some_iff.mp ok
    unfold Forced.sweep at swept
    split at swept
    · cases Option.some.inj swept; exact Or.inl rfl
    · cases swept
  | forcedETH amount => cases Option.some.inj ok; exact Or.inl rfl
  | scheduleRules caller rule time | scheduleStop caller time grid =>
    simp only [execute] at ok
    obtain ⟨schedule,_,rfl⟩ := Option.map_eq_some_iff.mp ok
    exact Or.inl rfl
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
        exact Or.inr (Nat.lt_succ_self _)
      · cases ok
  | invalidate caller nonce =>
    simp only [execute] at ok
    unfold invalidate at ok
    split at ok
    · cases Option.some.inj ok; exact Or.inl rfl
    · cases ok
  | rollback caller trusted cutoff =>
    simp only [execute] at ok
    unfold rollback at ok
    split at ok
    · obtain ⟨registry,_,rfl⟩ := Option.map_eq_some_iff.mp ok
      exact Or.inl rfl
    · cases ok
  | land landing =>
    simp only [execute] at ok
    unfold Protocol.land at ok
    split at ok
    · cases Option.some.inj ok; exact Or.inl rfl
    · cases ok
  | unzenProve proposal header proof =>
    simp only [execute] at ok
    unfold unzenProve at ok
    split at ok
    · cases Option.some.inj ok; exact Or.inl rfl
    · cases ok
  | image caller image register | verifier caller version =>
    simp only [execute] at ok
    split at ok
    · cases Option.some.inj ok; exact Or.inl rfl
    · cases ok
  | observe number =>
    simp only [execute] at ok
    obtain ⟨s,_,rfl⟩ := Option.map_eq_some_iff.mp ok
    exact Or.inl rfl
  | importSnapshot candidate durable =>
    simp only [execute] at ok
    unfold nodeImport at ok
    cases target : w.node.target with
    | none => simp [target] at ok
    | some target =>
      simp only [target] at ok
      split at ok
      · obtain ⟨installed,_,rfl⟩ := Option.map_eq_some_iff.mp ok
        exact Or.inl rfl
      · cases ok
  | restart | openSigner _ | switchSigner _ =>
    cases Option.some.inj ok; exact Or.inl rfl
  | sign request signature persisted =>
    simp only [execute] at ok
    obtain ⟨result,_,rfl⟩ := Option.map_eq_some_iff.mp ok
    exact Or.inl rfl

/-- A recovery or structural upgrade always opens a positive generation; generation
zero therefore retains exactly the parameters actually installed at deployment. -/
theorem generation_zero_parameters {env : Environment} {registry : RegistryMachine.State} {w : World}
    (run : Trace env (empty env registry) w) (zero : w.inbox.generation = 0) :
    parametersOf w.inbox = env.parameters := by
  induction run with
  | refl => rfl
  | @step before after prior change ih =>
    have oldZero : before.inbox.generation = 0 := by
      have bound := (ProtocolFinality.trace_fields (Trace.step (Trace.refl before) change)).2.1
      omega
    have old := ih oldZero
    cases change with
    | call call =>
      cases result : execute env before call with
      | none => simpa only [Protocol.transact,result,Option.getD_none] using old
      | some after =>
        have actualZero : after.inbox.generation = 0 := by
          simpa only [Protocol.transact,result,Option.getD_some] using zero
        rcases execute_parameters result with same | positive
        · simpa only [Protocol.transact,result,Option.getD_some] using same.trans old
        · omega
    | node after validated => exact old

/-- Parameter writes occur only when opening a strictly later generation. Equality of
the observed generation therefore derives equality of installed raw parameter data. -/
theorem trace_same_generation_parameters {env : Environment} {first later : World}
    (run : Trace env first later) (generation : later.inbox.generation = first.inbox.generation) :
    parametersOf later.inbox = parametersOf first.inbox := by
  induction run with
  | refl => rfl
  | @step before after prior change ih =>
    have beforeBound := (ProtocolFinality.trace_fields prior).2.1
    have afterBound := (ProtocolFinality.trace_fields (Trace.step (Trace.refl before) change)).2.1
    have beforeSame : before.inbox.generation = first.inbox.generation := by omega
    have old := ih beforeSame
    cases change with
    | call call =>
      cases result : execute env before call with
      | none => simpa only [Protocol.transact,result,Option.getD_none] using old
      | some after =>
        have same : after.inbox.generation = before.inbox.generation := by
          simp only [Protocol.transact,result,Option.getD_some] at generation
          omega
        rcases execute_parameters result with kept | increased
        · simpa only [Protocol.transact,result,Option.getD_some] using kept.trans old
        · omega
    | node after validated => exact old

theorem execute_backed {env : Environment} {w t : World} {call : Call}
    (standard : ProtocolFinality.StandardToken env) (backed : RegistryPayments.Backed env.token w.registry)
    (rate : w.registry.registry.config.slashBountyBps ≤ 10000)
    (ok : execute env w call = some t) : RegistryPayments.Backed env.token t.registry := by
  cases call with
  | advance n =>
    simp only [execute] at ok
    unfold advance at ok
    split at ok
    next allowed =>
      cases Option.some.inj ok
      exact backed
    · cases ok
  | initializeInbox caller =>
    simp only [execute] at ok
    unfold initializeInbox at ok
    split at ok
    · split at ok
      · split at ok
        · cases Option.some.inj ok; exact backed
        · cases ok
      · cases Option.some.inj ok; exact backed
    · cases ok
  | setOrigin caller h hash root =>
    simp only [execute] at ok
    unfold setOrigin at ok
    split at ok
    · cases Option.some.inj ok; exact backed
    · cases ok
  | correctStart caller h hash root =>
    simp only [execute] at ok
    unfold correctStart at ok
    obtain ⟨old,_,ok⟩ := Option.bind_eq_some_iff.mp ok
    split at ok
    · cases Option.some.inj ok; exact backed
    · cases ok
  | registry caller action =>
    simp only [execute] at ok
    unfold registryCall at ok
    split at ok
    · obtain ⟨⟨paid,receipts⟩,transaction,rfl⟩ := Option.map_eq_some_iff.mp ok
      exact RegistryPayments.transaction_backed standard backed rate transaction
    · cases ok
  | enqueue raw paid refund =>
    simp only [execute] at ok
    unfold enqueue at ok
    split at ok
    · obtain ⟨inbox,enqueued,rfl⟩ := Option.map_eq_some_iff.mp ok
      unfold Forced.enqueue at enqueued
      dsimp only at enqueued
      split at enqueued
      · cases Option.some.inj enqueued; exact backed
      · cases enqueued
    · cases ok
  | sweep transfer =>
    simp only [execute] at ok
    obtain ⟨inbox,swept,rfl⟩ := Option.map_eq_some_iff.mp ok
    unfold Forced.sweep at swept
    split at swept
    · cases Option.some.inj swept; exact backed
    · cases swept
  | forcedETH amount => cases Option.some.inj ok; exact backed
  | scheduleRules caller rule time | scheduleStop caller time grid =>
    simp only [execute] at ok
    obtain ⟨schedule,_,rfl⟩ := Option.map_eq_some_iff.mp ok
    exact backed
  | recover request =>
    simp only [execute] at ok
    unfold recover at ok
    obtain ⟨start,_,ok⟩ := Option.bind_eq_some_iff.mp ok
    cases upgrade : request.upgrade <;> simp only [upgrade,Option.isSome_none,
      Option.isSome_some,Option.getD_none,Option.getD_some,Bool.false_eq_true,ite_true,ite_false] at ok
    all_goals
      split at ok
      · obtain ⟨schedule,_,ok⟩ := Option.bind_eq_some_iff.mp ok
        obtain ⟨registry,executed,rfl⟩ := Option.map_eq_some_iff.mp ok
        have change := RegistryMachine.execute_reserve executed
        have same : RegistryMachine.reserve registry.ledger = RegistryMachine.reserve w.registry.registry.ledger := by
          simpa only [RegistryMachine.outgoing,RegistryMachine.incoming,Nat.add_zero] using change
        exact ⟨same ▸ backed.1,backed.2⟩
      · cases ok
  | invalidate caller nonce =>
    simp only [execute] at ok
    unfold invalidate at ok
    split at ok
    · cases Option.some.inj ok; exact backed
    · cases ok
  | rollback caller trusted cutoff =>
    simp only [execute] at ok
    unfold rollback at ok
    split at ok
    · obtain ⟨registry,executed,rfl⟩ := Option.map_eq_some_iff.mp ok
      have change := RegistryMachine.execute_reserve executed
      have same : RegistryMachine.reserve registry.ledger = RegistryMachine.reserve w.registry.registry.ledger := by
        simpa only [RegistryMachine.outgoing,RegistryMachine.incoming,Nat.add_zero] using change
      exact ⟨same ▸ backed.1,backed.2⟩
    · cases ok
  | land landing =>
    simp only [execute] at ok
    unfold Protocol.land at ok
    split at ok
    · cases Option.some.inj ok; exact backed
    · cases ok
  | unzenProve proposal header proof =>
    simp only [execute] at ok
    unfold unzenProve at ok
    split at ok
    · cases Option.some.inj ok; exact backed
    · cases ok
  | image caller image register | verifier caller version =>
    simp only [execute] at ok
    split at ok
    · cases Option.some.inj ok; exact backed
    · cases ok
  | observe number =>
    simp only [execute] at ok
    obtain ⟨s,_,rfl⟩ := Option.map_eq_some_iff.mp ok
    exact backed
  | importSnapshot candidate durable =>
    simp only [execute] at ok
    unfold nodeImport at ok
    cases target : w.node.target with
    | none => simp [target] at ok
    | some target =>
      simp only [target] at ok
      split at ok
      · obtain ⟨installed,_,rfl⟩ := Option.map_eq_some_iff.mp ok
        exact backed
      · cases ok
  | restart | openSigner _ | switchSigner _ =>
    cases Option.some.inj ok; exact backed
  | sign request signature persisted =>
    simp only [execute] at ok
    obtain ⟨result,_,rfl⟩ := Option.map_eq_some_iff.mp ok
    exact backed


/-- The complete protocol preserves escrow backing from raw empty genesis and real
standard-token balances. It assumes no condition about balances at future slash time. -/
theorem funds_backed {env : Environment} {registry : RegistryMachine.State} {w : World}
    (genesis : RegistryMachine.Genesis registry) (standard : ProtocolFinality.StandardToken env)
    (self : env.initialToken.allowances env.token.registryAddress env.token.registryAddress = 0)
    (rate : registry.config.slashBountyBps ≤ 10000)
    (run : Trace env (empty env registry) w) : RegistryPayments.Backed env.token w.registry := by
  induction run with
  | refl =>
    constructor
    · change RegistryMachine.sumBalances registry.ledger.bonds registry.ledger.nextId ≤ _
      rw [genesis.1]
      exact Nat.zero_le _
    · exact self
  | @step before after prior change ih =>
    have currentRate : before.registry.registry.config.slashBountyBps ≤ 10000 := by
      rw [(ProtocolFinality.trace_fields prior).2.2.2.2.2.1]
      exact rate
    cases change with
    | call call =>
      cases result : execute env before call with
      | none => simpa only [Protocol.transact,result,Option.getD_none] using ih
      | some after =>
        simpa only [Protocol.transact,result,Option.getD_some] using execute_backed standard ih currentRate result
    | node after validated => exact ih

theorem trace_trans {env : Environment} {a b c : World} (ab : Trace env a b) (bc : Trace env b c) : Trace env a c := by
  induction bc with
  | refl => exact ab
  | step _ change ih => exact Trace.step ih change

/-- An initially unconfirmed real bond remains unwithdrawn throughout the entire
deployment evidence window. A halt before confirmation cannot consume the window. -/
theorem evidence_window_retained {env : Environment} {first later : World}
    (run : Trace env first later) {id window : Nat} {bond : Registry.Bond}
    (issued : id < first.registry.registry.ledger.nextId)
    (found : first.registry.registry.ledger.bonds id = some bond)
    (live : bond.value.released = false) (unconfirmed : bond.value.confirmedAt = none)
    (windowBound : window ≤ first.registry.registry.config.withdrawalDelay)
    (early : later.number < first.number+window) :
    RegistryMachine.EvidenceClock later.registry.registry id first.number := by
  have clock : RegistryMachine.EvidenceClock first.registry.registry id first.number := by
    refine ⟨bond,issued,found,live,?_⟩
    intro atL1 impossible
    rw [unconfirmed] at impossible
    cases impossible
  exact RegistryMachine.trace_evidence_clock (ProtocolFinality.registry_trace run) clock (Nat.le_refl _)
    (by dsimp only [registryWorld]; omega)

/-- Replaying the same generation and raw common header prefix at a later closed L1
view derives the same committee. Open same-block records are excluded by `closed`. -/
theorem temporal_committee_agreement {env : Environment} {first later : World}
    (run : Trace env first later) {common moreA moreB : List Header} {h : Nat}
    (generationConfig : config later = config first)
    (covered : Finality.requiredPrefix (config first) h ≤ common.length)
    (closed : Finality.cutoff (config first) common h < first.number) :
    Consensus.activeAt (Finality.derive (config first) first.registry.registry (common ++ moreA)) h =
      Consensus.activeAt (Finality.derive (config later) later.registry.registry (common ++ moreB)) h := by
  rw [generationConfig]
  exact Finality.active_committee_prefix covered (protocol_closed_history run closed).symm

/-- Cross-round agreement also transports across real L1 execution, after a common
closed decision cutoff fixes the authority. The data equality fixes one generation's
deployment/origin fields; registry-history equality is derived from the actual trace. -/
theorem temporal_commit_agreement {env : Environment} {first later : World}
    (run : Trace env first later) {common moreA moreB : List Header}
    {referenceA referenceB h ra rb a b : Nat} {votesA votesB : List Consensus.Vote}
    (generationConfig : config later = config first)
    (covered : Finality.requiredPrefix (config first) h ≤ common.length)
    (closed : Finality.cutoff (config first) common h < first.number)
    {honest : Hash → Bool} {mode : Bool} {execution : Locking.Execution}
    (rules : Locking.HonestRules first.inbox.configuration.unit
      (Consensus.activeAt (policy env first (common ++ moreA) referenceA).consensus h).members honest mode execution)
    (minority : Locking.Minority first.inbox.configuration.unit
      (Consensus.activeAt (policy env first (common ++ moreA) referenceA).consensus h).members honest)
    (attrA : Locking.CommitAttribution execution ra a votesA)
    (attrB : Locking.CommitAttribution execution rb b votesB)
    (validA : Consensus.CommitValid (policy env first (common ++ moreA) referenceA).consensus env.signature h ra a votesA)
    (validB : Consensus.CommitValid (policy env later (common ++ moreB) referenceB).consensus env.signature h rb b votesB) : a = b := by
  change Consensus.CommitValid (Finality.derive (config later) later.registry.registry (common ++ moreB)) _ _ _ _ _ at validB
  rw [generationConfig] at validB
  exact Finality.shared_prefix_agreement covered (protocol_closed_history run closed).symm rules minority attrA attrB validA validB

theorem funded_future_liability {env : Environment} {registry : RegistryMachine.State} {w : World}
    (genesis : RegistryMachine.Genesis registry) (standard : ProtocolFinality.StandardToken env)
    (self : env.initialToken.allowances env.token.registryAddress env.token.registryAddress = 0)
    (rate : registry.config.slashBountyBps ≤ 10000) (run : Trace env (empty env registry) w)
    (initialized : w.initialized = true) {key : Hash} {a b : Staking.Vote} {sa sb : Hash}
    (auth : RegistryMachine.Evidence w.registry.registry (registryView env w) key a b sa sb) :
    FundedFutureLiability env w key a b sa sb := by
  intro later future id bond caller issued found sameKey live positive free
  have funded := (funds_backed genesis standard self rate (trace_trans run future)).1
  have enough := Nat.le_trans (RegistryMachine.reserve_member issued found) funded
  have currentRate : w.registry.registry.config.slashBountyBps ≤ 10000 := by
    rw [(ProtocolFinality.trace_fields run).2.2.2.2.2.1]
    exact rate
  exact ProtocolFinality.paid_evidence_future_liability standard initialized currentRate auth
    later future id bond caller issued found sameKey live positive free enough

theorem economically_accountable {env : Environment} {registry : RegistryMachine.State} {w : World}
    (genesis : RegistryMachine.Genesis registry) (standard : ProtocolFinality.StandardToken env)
    (self : env.initialToken.allowances env.token.registryAddress env.token.registryAddress = 0)
    (rate : registry.config.slashBountyBps ≤ 10000) (run : Trace env (empty env registry) w)
    (refinement : Finality.SignatureRefinement registry env.signature) (initialized : w.initialized = true)
    {common moreA moreB : List Header} {referenceA referenceB h round a b : Nat}
    {votesA votesB : List Consensus.Vote}
    (covered : Finality.requiredPrefix (config w) h ≤ common.length)
    (validA : Consensus.CommitValid (policy env w (common ++ moreA) referenceA).consensus env.signature h round a votesA)
    (validB : Consensus.CommitValid (policy env w (common ++ moreB) referenceB).consensus env.signature h round b votesB)
    (conflict : a ≠ b) :
    EconomicallyAccountable env w (policy env w (common ++ moreA) referenceA).consensus h votesA votesB := by
  have liability := ProtocolFinality.protocol_same_round_accountability run standard refinement initialized rate
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
  obtain ⟨id,bond,issued,found,key⟩ := committee_issued genesis run unit (List.mem_filter.mp member).1
  obtain ⟨va,inA,vb,inB,keyA,keyB,sa,sb,evidence,_⟩ := liability.2 entry member
  exact ⟨id,bond,issued,found,key,va,inA,vb,inB,keyA,keyB,sa,sb,evidence,
    funded_future_liability genesis standard self rate run initialized evidence⟩

theorem economic_safety {env : Environment} {registry : RegistryMachine.State} {w : World}
    (genesis : RegistryMachine.Genesis registry) (standard : ProtocolFinality.StandardToken env)
    (self : env.initialToken.allowances env.token.registryAddress env.token.registryAddress = 0)
    (rate : registry.config.slashBountyBps ≤ 10000) (run : Trace env (empty env registry) w)
    (sound : Finality.SignatureSound registry env.signature) : Safety env w := by
  refine ⟨funds_backed genesis standard self rate run,?_,?_,closed_registry_history run⟩
  · intro caller id a b sa sb next accepted
    exact no_false_slash run sound accepted
  · intro later future id window bond issued found live unconfirmed bounded early
    exact evidence_window_retained future issued found live unconfirmed bounded early

private theorem execute_registry_origin {env : Environment} {w t : World} {call : Call}
    (ok : execute env w call = some t) {cp : RegistryHistory.Snapshot}
    (member : cp ∈ t.registry.registry.history) :
    cp ∈ w.registry.registry.history ∨ (cp.block = t.number ∧ cp.entries = RegistryMachine.entries t.registry.registry) := by
  cases call with
  | advance n =>
    simp only [execute] at ok
    unfold advance at ok
    split at ok
    next allowed =>
      cases Option.some.inj ok
      exact Or.inl member
    · cases ok
  | initializeInbox caller =>
    simp only [execute] at ok
    unfold initializeInbox at ok
    split at ok
    · split at ok
      · split at ok
        · cases Option.some.inj ok; exact Or.inl member
        · cases ok
      · cases Option.some.inj ok; exact Or.inl member
    · cases ok
  | setOrigin caller h hash root =>
    simp only [execute] at ok
    unfold setOrigin at ok
    split at ok
    · cases Option.some.inj ok; exact Or.inl member
    · cases ok
  | correctStart caller h hash root =>
    simp only [execute] at ok
    unfold correctStart at ok
    obtain ⟨old,_,ok⟩ := Option.bind_eq_some_iff.mp ok
    split at ok
    · cases Option.some.inj ok; exact Or.inl member
    · cases ok
  | registry caller action =>
    simp only [execute] at ok
    unfold registryCall at ok
    split at ok
    · obtain ⟨⟨paid,receipts⟩,transaction,rfl⟩ := Option.map_eq_some_iff.mp ok
      exact RegistryMachine.execute_history_origin_exact (RegistryPayments.tx_success_projects transaction) member
    · cases ok
  | enqueue raw paid refund =>
    simp only [execute] at ok
    unfold enqueue at ok
    split at ok
    · obtain ⟨inbox,enqueued,rfl⟩ := Option.map_eq_some_iff.mp ok
      unfold Forced.enqueue at enqueued
      dsimp only at enqueued
      split at enqueued
      · cases Option.some.inj enqueued; exact Or.inl member
      · cases enqueued
    · cases ok
  | sweep transfer =>
    simp only [execute] at ok
    obtain ⟨inbox,swept,rfl⟩ := Option.map_eq_some_iff.mp ok
    unfold Forced.sweep at swept
    split at swept
    · cases Option.some.inj swept; exact Or.inl member
    · cases swept
  | forcedETH amount => cases Option.some.inj ok; exact Or.inl member
  | scheduleRules caller rule time | scheduleStop caller time grid =>
    simp only [execute] at ok
    obtain ⟨schedule,_,rfl⟩ := Option.map_eq_some_iff.mp ok
    exact Or.inl member
  | recover request =>
    simp only [execute] at ok
    unfold recover at ok
    obtain ⟨start,_,ok⟩ := Option.bind_eq_some_iff.mp ok
    cases upgrade : request.upgrade <;> simp only [upgrade,Option.isSome_none,
      Option.isSome_some,Option.getD_none,Option.getD_some,Bool.false_eq_true,ite_true,ite_false] at ok
    all_goals
      split at ok
      · obtain ⟨schedule,_,ok⟩ := Option.bind_eq_some_iff.mp ok
        obtain ⟨registry,executed,rfl⟩ := Option.map_eq_some_iff.mp ok
        exact RegistryMachine.execute_history_origin_exact executed member
      · cases ok
  | invalidate caller nonce =>
    simp only [execute] at ok
    unfold invalidate at ok
    split at ok
    · cases Option.some.inj ok; exact Or.inl member
    · cases ok
  | rollback caller trusted cutoff =>
    simp only [execute] at ok
    unfold rollback at ok
    split at ok
    · obtain ⟨registry,executed,rfl⟩ := Option.map_eq_some_iff.mp ok
      exact RegistryMachine.execute_history_origin_exact executed member
    · cases ok
  | land landing =>
    simp only [execute] at ok
    unfold Protocol.land at ok
    split at ok
    · cases Option.some.inj ok; exact Or.inl member
    · cases ok
  | unzenProve proposal header proof =>
    simp only [execute] at ok
    unfold unzenProve at ok
    split at ok
    · cases Option.some.inj ok; exact Or.inl member
    · cases ok
  | image caller image register | verifier caller version =>
    simp only [execute] at ok
    split at ok
    · cases Option.some.inj ok; exact Or.inl member
    · cases ok
  | observe number =>
    simp only [execute] at ok
    obtain ⟨s,_,rfl⟩ := Option.map_eq_some_iff.mp ok
    exact Or.inl member
  | importSnapshot candidate durable =>
    simp only [execute] at ok
    unfold nodeImport at ok
    cases target : w.node.target with
    | none => simp [target] at ok
    | some target =>
      simp only [target] at ok
      split at ok
      · obtain ⟨installed,_,rfl⟩ := Option.map_eq_some_iff.mp ok
        exact Or.inl member
      · cases ok
  | restart | openSigner _ | switchSigner _ =>
    cases Option.some.inj ok; exact Or.inl member
  | sign request signature persisted =>
    simp only [execute] at ok
    obtain ⟨result,_,rfl⟩ := Option.map_eq_some_iff.mp ok
    exact Or.inl member



/-- Every retained election checkpoint has a concrete originating protocol execution
state. Genesis contributes no caller-supplied registry history. -/
theorem historical_origin {env : Environment} {registry : RegistryMachine.State} {w : World}
    (genesis : RegistryMachine.Genesis registry) (run : Trace env (empty env registry) w) :
    HistoricalOrigin env (empty env registry) w := by
  induction run with
  | refl =>
    intro cp member
    change cp ∈ registry.history at member
    rw [genesis.2.2.2.2.1] at member
    cases member
  | @step before after prior change ih =>
    intro cp member
    have origin : cp ∈ before.registry.registry.history ∨ (cp.block = after.number ∧ cp.entries = RegistryMachine.entries after.registry.registry) := by
      cases change with
      | call call =>
        cases result : execute env before call with
        | none =>
          left
          simpa only [Protocol.transact,result,Option.getD_none] using member
        | some after =>
          have fresh := execute_registry_origin (cp := cp) result
          simp only [Protocol.transact,result,Option.getD_some] at member ⊢
          exact fresh member
      | node after valid => exact Or.inl member
    rcases origin with old | fresh
    · obtain ⟨past,earlier,later,atBlock,same⟩ := ih cp old
      exact ⟨past,earlier,Trace.step later change,atBlock,same⟩
    · exact ⟨after,Trace.step prior change,Trace.refl after,fresh.1.symm,fresh.2⟩

/-- Historical voting quantities were held by real issued bonds in an actual preceding
protocol state whose entire reserve was funded. The trace to the present is explicit. -/
theorem historical_stake_funded {env : Environment} {registry : RegistryMachine.State} {w : World}
    (genesis : RegistryMachine.Genesis registry) (standard : ProtocolFinality.StandardToken env)
    (self : env.initialToken.allowances env.token.registryAddress env.token.registryAddress = 0)
    (rate : registry.config.slashBountyBps ≤ 10000) (run : Trace env (empty env registry) w) :
    HistoricalStakeFunded env w := by
  intro cp member entry selected positive
  obtain ⟨past,earlier,later,atBlock,origin⟩ := historical_origin genesis run cp member
  rw [origin] at selected
  obtain ⟨id,bond,issued,found,entryEq,principal⟩ :=
    RegistryMachine.entries_principal (history_issued genesis earlier).1 selected positive
  have funded := funds_backed genesis standard self rate earlier
  have money := Nat.le_trans (RegistryMachine.reserve_member issued found) funded.1
  exact ⟨past,id,bond,later,atBlock,issued,found,entryEq,funded,Nat.le_trans principal money⟩

end Etna.Design.Current.Economics
