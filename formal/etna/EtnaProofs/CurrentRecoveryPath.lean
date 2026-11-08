import EtnaModel.CurrentRecoveryInterface
import EtnaStatements.Current
import EtnaProofs.Current
import EtnaProofs.CurrentUnzen

/-! The L1 half of the recovery path (design 4.3, steps 1-4). From a reachable, initialized
state satisfying `LiveAt`, five steps of calls, numbered so below: (1) advance L1 to the window
block R; (2) on a switching network, write, correct or prove the start where needed; (3) register
an image and select the complete verifier version; (4) one plain recovery at R; (5) advance L1
to R+2. `Recovery.prepare` returns the reached state with the facts the landing proof needs
(`Recovery.Prepared`). The reachable-state facts it needs beyond the existing journals are
`Reach`, proved by induction over `Trace` from `empty`. -/
namespace Etna.Design.Current.Protocol.Recovery
open Etna.Statements.Current

/-! ### Reachable-state facts -/

/-- A listed configuration's maximum anchor age is at most the largest one (`maxAges`'s fold). -/
private theorem ages_member : ∀ {xs : List (Nat × Parameters)} {g : Nat} {p : Parameters},
    (g,p) ∈ xs → p.maxAnchorAge ≤ (xs.map fun x => x.2.maxAnchorAge).foldr max 0
  | [], _, _, mem => nomatch mem
  | x :: xs, g, p, mem => by
    simp only [List.map_cons,List.foldr_cons]
    rcases List.mem_cons.mp mem with rfl | rest
    · exact Nat.le_max_left _ _
    · exact Nat.le_trans (ages_member rest) (Nat.le_max_right _ _)

/-- A landed record's header: it matches the record, is hash-bound, and its timestamp is within
the largest anchor age of the time of an L1 block below the current one. -/
private def Timed (env : Environment) (w : World) (cp : Checkpoint) : Prop :=
  ∃ T, Custody.HeaderOf cp T ∧ HashBound env T ∧ ∃ m, m < w.number ∧ T.timestamp ≤ env.time m+maxAges w

/-- The record the start write saves (START-10-5b): the start's height and hash, zero Comet
hash, FI cursor and validator-state hash. -/
private def StartRecord (s : StartData) (cp : Checkpoint) : Prop :=
  cp.height = s.height ∧ cp.elHash = s.hash ∧ cp.cometHash = 0 ∧ cp.cursor = 0 ∧ cp.valStateHash = 0

/-- The committee configuration hash `install` writes for the stored configuration. -/
private def Committed (env : Environment) (s : Etna.Design.State) : Prop :=
  s.committeeConfig = env.configHash (Encoding.configWords s.domain.l2ChainId s.domain.registry
    s.configuration.unit s.configuration.minimum s.configuration.nMax s.configuration.unsettled)

/-- Facts of every reachable state that the path needs and the existing journals do not give. -/
private structure Reach (env : Environment) (w : World) : Prop where
  generation : w.start = none → w.inbox.generation = 0
  entered : w.inbox.entered = false
  proposals : w.unzen.nextProposal = env.unzenNextProposal
  retained : ∀ h, w.unzenHeader = some h → ∃ proof, env.unzenValid w.unzen.finalizedProposal h proof = true
  genesis : env.core.unzenInbox = 0 → w.initialized = true →
    w.start = some ⟨0,env.genesisHeader.elHash,env.genesisHeader.stateRoot⟩ ∧ env.genesisHeader.height = 0 ∧
      env.genesisHeader.cursor = 0 ∧ env.genesisHeader.cometHash = 0 ∧ env.genesisHeader.valStateHash = 0
  fresh : w.initialized = false → parametersOf w.inbox = env.parameters
  params : w.initialized = true → (∃ g, (g,parametersOf w.inbox) ∈ w.configurations) ∧
    ∀ x ∈ w.configurations, x.2.valid = true
  committed : Committed env w.inbox
  queue : ∀ i e, (i,e) ∈ w.queue → ∃ raw : Blocks.Bytes, env.txHash raw = e.txHash ∧ raw.length ≤ 8192
  fenced : w.everLanded = true → env.core.unzenInbox ≠ 0 → ∃ s h, w.start = some s ∧ w.unzenHeader = some h ∧
    w.unzen.nextProposal = w.unzen.finalizedProposal+1 ∧ w.unzen.finalizedHash = s.hash ∧
    w.unzen.checkpointExists = true ∧ w.unzen.checkpointHash = s.hash ∧ w.unzen.checkpointRoot = s.stateRoot ∧
    h.height = s.height ∧ h.elHash = s.hash ∧ h.stateRoot = s.stateRoot
  records : ∀ cp ∈ w.activeRecords, ∃ s, w.start = some s ∧
    (StartRecord s cp ∨ (s.height < cp.height ∧ Timed env w cp))

/-- The fields `Reach` reads, kept by a call (L1 may advance). -/
private structure Same (w t : World) : Prop where
  start : t.start = w.start
  initialized : t.initialized = w.initialized
  generation : t.inbox.generation = w.inbox.generation
  entered : t.inbox.entered = w.inbox.entered
  params : parametersOf t.inbox = parametersOf w.inbox
  committed : t.inbox.committeeConfig = w.inbox.committeeConfig ∧ t.inbox.domain = w.inbox.domain
  unzen : t.unzen = w.unzen
  header : t.unzenHeader = w.unzenHeader
  ever : t.everLanded = w.everLanded
  records : t.activeRecords = w.activeRecords
  number : w.number ≤ t.number
  configurations : t.configurations = w.configurations
  queue : t.queue = w.queue

private theorem timed_mono {env : Environment} {w t : World} {cp : Checkpoint} (timed : Timed env w cp)
    (number : w.number ≤ t.number) (ages : maxAges w ≤ maxAges t) : Timed env t cp := by
  obtain ⟨T,header,bound,m,below,time⟩ := timed
  exact ⟨T,header,bound,m,Nat.lt_of_lt_of_le below number,by omega⟩

private theorem reach_same {env : Environment} {w t : World} (held : Reach env w) (same : Same w t) :
    Reach env t := by
  obtain ⟨start,init,gen,ent,params,⟨cc,dom⟩,unzen,header,landed,records,number,configs,queue⟩ := same
  have conf : t.inbox.configuration = w.inbox.configuration := congrArg Parameters.committee params
  refine ⟨?_,?_,?_,?_,?_,?_,?_,?_,?_,?_,?_⟩
  · rw [start,gen]; exact held.generation
  · rw [ent]; exact held.entered
  · rw [unzen]; exact held.proposals
  · rw [header,unzen]; exact held.retained
  · rw [init,start]; exact held.genesis
  · rw [init,params]; exact held.fresh
  · rw [init,params,configs]; exact held.params
  · unfold Committed; rw [cc,dom,conf]; exact held.committed
  · rw [queue]; exact held.queue
  · rw [landed,start,header,unzen]; exact held.fenced
  · intro cp mem
    rw [records] at mem
    obtain ⟨s,st,record⟩ := held.records cp mem
    refine ⟨s,start.trans st,?_⟩
    rcases record with root | ⟨above,timed⟩
    · exact Or.inl root
    · exact Or.inr ⟨above,timed_mono timed number (by unfold maxAges; rw [configs]; exact Nat.le_refl _)⟩

/-- Calls that keep every field `Reach` reads. -/
private def Keeps : Call → Prop
  | .initializeInbox .. | .setOrigin .. | .correctStart .. | .enqueue .. | .recover .. | .rollback ..
  | .land .. | .unzenProve .. => False
  | _ => True

private theorem execute_same {env : Environment} {w t : World} {call : Call} (keeps : Keeps call)
    (ok : execute env w call = some t) : Same w t := by
  cases call with
  | advance number =>
    change advance env w number = some t at ok
    unfold advance at ok
    split at ok
    next guard =>
      cases Option.some.inj ok
      exact ⟨rfl,rfl,rfl,rfl,rfl,⟨rfl,rfl⟩,rfl,rfl,rfl,rfl,Nat.le_of_lt guard.1,rfl,rfl⟩
    next => simp at ok
  | registry caller action =>
    change registryCall env w caller action = some t at ok
    unfold registryCall at ok
    split at ok
    next =>
      obtain ⟨result,_,rfl⟩ := Option.map_eq_some_iff.mp ok
      exact ⟨rfl,rfl,rfl,rfl,rfl,⟨rfl,rfl⟩,rfl,rfl,rfl,rfl,Nat.le_refl _,rfl,rfl⟩
    next => simp at ok
  | sweep transfer =>
    change sweep w transfer = some t at ok
    obtain ⟨inbox,inner,rfl⟩ := Option.map_eq_some_iff.mp ok
    unfold Forced.sweep at inner
    split at inner
    next =>
      cases Option.some.inj inner
      exact ⟨rfl,rfl,rfl,rfl,rfl,⟨rfl,rfl⟩,rfl,rfl,rfl,rfl,Nat.le_refl _,rfl,rfl⟩
    next => simp at inner
  | forcedETH amount =>
    cases Option.some.inj ok
    exact ⟨rfl,rfl,rfl,rfl,rfl,⟨rfl,rfl⟩,rfl,rfl,rfl,rfl,Nat.le_refl _,rfl,rfl⟩
  | scheduleRules caller rule time =>
    change Protocol.scheduleRules env w caller rule time = some t at ok
    obtain ⟨schedule,_,rfl⟩ := Option.map_eq_some_iff.mp ok
    exact ⟨rfl,rfl,rfl,rfl,rfl,⟨rfl,rfl⟩,rfl,rfl,rfl,rfl,Nat.le_refl _,rfl,rfl⟩
  | scheduleStop caller time grid =>
    change Protocol.scheduleStop env w caller time grid = some t at ok
    obtain ⟨schedule,_,rfl⟩ := Option.map_eq_some_iff.mp ok
    exact ⟨rfl,rfl,rfl,rfl,rfl,⟨rfl,rfl⟩,rfl,rfl,rfl,rfl,Nat.le_refl _,rfl,rfl⟩
  | invalidate caller nonce =>
    change invalidate env w caller nonce = some t at ok
    unfold invalidate at ok
    split at ok
    next =>
      cases Option.some.inj ok
      exact ⟨rfl,rfl,rfl,rfl,rfl,⟨rfl,rfl⟩,rfl,rfl,rfl,rfl,Nat.le_refl _,rfl,rfl⟩
    next => simp at ok
  | image caller image register | verifier caller version =>
    simp only [execute] at ok
    split at ok
    next =>
      cases Option.some.inj ok
      exact ⟨rfl,rfl,rfl,rfl,rfl,⟨rfl,rfl⟩,rfl,rfl,rfl,rfl,Nat.le_refl _,rfl,rfl⟩
    next => simp at ok
  | observe number =>
    change observe env w number = some t at ok
    obtain ⟨s,_,rfl⟩ := Option.map_eq_some_iff.mp ok
    exact ⟨rfl,rfl,rfl,rfl,rfl,⟨rfl,rfl⟩,rfl,rfl,rfl,rfl,Nat.le_refl _,rfl,rfl⟩
  | importSnapshot candidate durable =>
    change nodeImport env w candidate durable = some t at ok
    unfold nodeImport at ok
    split at ok
    next => simp at ok
    next =>
      split at ok
      next =>
        obtain ⟨installed,_,rfl⟩ := Option.map_eq_some_iff.mp ok
        exact ⟨rfl,rfl,rfl,rfl,rfl,⟨rfl,rfl⟩,rfl,rfl,rfl,rfl,Nat.le_refl _,rfl,rfl⟩
      next => simp at ok
  | restart | openSigner _ | switchSigner _ =>
    cases Option.some.inj ok
    exact ⟨rfl,rfl,rfl,rfl,rfl,⟨rfl,rfl⟩,rfl,rfl,rfl,rfl,Nat.le_refl _,rfl,rfl⟩
  | sign message signature persisted =>
    obtain ⟨result,_,rfl⟩ := Option.map_eq_some_iff.mp ok
    exact ⟨rfl,rfl,rfl,rfl,rfl,⟨rfl,rfl⟩,rfl,rfl,rfl,rfl,Nat.le_refl _,rfl,rfl⟩
  | initializeInbox | setOrigin | correctStart | enqueue | recover | rollback | land | unzenProve =>
    exact (keeps : False).elim

private theorem parameters_install (s : Etna.Design.State) (p : Parameters) (configHash : List Encoding.Word → Hash) :
    parametersOf (install s p configHash) = p := by
  cases p; rfl

private theorem initialize_reach {env : Environment} {registry : RegistryMachine.State} {w t : World}
    {caller : Nat} (reach : Trace env (empty env registry) w) (held : Reach env w)
    (ok : initializeInbox env w caller = some t) : Reach env t := by
  unfold initializeInbox at ok
  split at ok
  next guard =>
    have fresh := held.fresh guard.2.1
    have shape := Journal.trace_frontier_shape reach
    have unstarted := shape.uninitialized guard.2.1
    have unlanded := shape.unstarted unstarted
    have params : ∀ x ∈ [(0,env.parameters)], x.2.valid = true := by
      intro x mem
      rw [List.mem_singleton.mp mem]
      exact guard.2.2.2.1
    split at ok
    next newNetwork =>
      split at ok
      next genesis =>
        cases Option.some.inj ok
        refine ⟨?_,held.entered,held.proposals,held.retained,fun _ _ => ⟨rfl,genesis⟩,?_,
          fun _ => ⟨⟨0,?_⟩,params⟩,held.committed,held.queue,fun _ switching => (switching newNetwork).elim,?_⟩
        · intro absent; cases absent
        · intro absent; cases absent
        · change (0,parametersOf w.inbox) ∈ [(0,env.parameters)]
          rw [fresh]
          exact List.mem_singleton_self _
        · intro cp mem
          rw [List.mem_singleton.mp mem]
          exact ⟨_,rfl,Or.inl ⟨rfl,rfl,rfl,rfl,rfl⟩⟩
      next => simp at ok
    next switching =>
      cases Option.some.inj ok
      refine ⟨fun _ => guard.2.2.1,held.entered,held.proposals,held.retained,fun newNetwork => (switching newNetwork).elim,
        ?_,fun _ => ⟨⟨0,?_⟩,params⟩,held.committed,held.queue,?_,?_⟩
      · intro absent; cases absent
      · change (0,parametersOf w.inbox) ∈ [(0,env.parameters)]
        rw [fresh]
        exact List.mem_singleton_self _
      · intro ever
        change w.everLanded = true at ever
        rw [unlanded] at ever
        cases ever
      · intro cp mem
        obtain ⟨s,st,_⟩ := held.records cp mem
        rw [unstarted] at st
        cases st
  next => simp at ok

/-- A start write (`setOrigin` or `correctStart`) before any landing. -/
private theorem write_start_reach {env : Environment} {w : World} {height hash root block timestamp generation : Nat}
    (held : Reach env w) (switching : env.core.unzenInbox ≠ 0) (unlanded : w.everLanded = false) :
    Reach env (writeStart w height hash root block timestamp generation) := by
  refine ⟨?_,held.entered,held.proposals,held.retained,fun newNetwork => (switching newNetwork).elim,held.fresh,
    held.params,held.committed,held.queue,?_,?_⟩
  · intro absent; cases absent
  · intro ever
    change w.everLanded = true at ever
    rw [unlanded] at ever
    cases ever
  · intro cp mem
    rw [List.mem_singleton.mp mem]
    exact ⟨_,rfl,Or.inl ⟨rfl,rfl,rfl,rfl,rfl⟩⟩

private theorem set_origin_reach {env : Environment} {registry : RegistryMachine.State} {w t : World}
    {caller height hash root : Nat} (reach : Trace env (empty env registry) w) (held : Reach env w)
    (ok : setOrigin env w caller height hash root = some t) : Reach env t := by
  unfold setOrigin at ok
  split at ok
  next guard =>
    cases Option.some.inj ok
    exact write_start_reach held guard.2.2.2.2.1 ((Journal.trace_frontier_shape reach).unstarted guard.2.1)
  next => simp at ok

private theorem correct_reach {env : Environment} {w t : World} {caller height hash root : Nat}
    (held : Reach env w) (ok : correctStart env w caller height hash root = some t) : Reach env t := by
  unfold correctStart at ok
  obtain ⟨old,_,ok⟩ := Option.bind_eq_some_iff.mp ok
  split at ok
  next guard =>
    cases Option.some.inj ok
    exact write_start_reach held guard.2.1 guard.2.2.1
  next => simp at ok

private theorem enqueue_reach {env : Environment} {w t : World} {raw : Blocks.Bytes} {paid : Nat} {refund : Bool}
    (held : Reach env w) (ok : enqueue env w raw paid refund = some t) : Reach env t := by
  unfold enqueue at ok
  split at ok
  next =>
    obtain ⟨inbox,inner,rfl⟩ := Option.map_eq_some_iff.mp ok
    unfold Forced.enqueue at inner
    dsimp only at inner
    split at inner
    next guard =>
      cases Option.some.inj inner
      refine ⟨held.generation,held.entered,held.proposals,held.retained,held.genesis,held.fresh,held.params,
        held.committed,?_,held.fenced,held.records⟩
      intro i e mem
      rcases List.mem_append.mp mem with old | new
      · exact held.queue i e old
      · rw [List.mem_singleton] at new
        cases new
        exact ⟨raw,rfl,guard.2.2.1⟩
    next => simp at inner
  next => simp at ok

/-- The state a successful recovery writes, for either parameter source. -/
private theorem recovered_reach {env : Environment} {w : World} {start : StartData} {inbox : Etna.Design.State}
    {parameters : Parameters} {registry : RegistryMachine.State} {schedule : Rules.Schedule} {clear : List Nat}
    (held : Reach env w) (started : w.start = some start) (initialized : w.initialized = true)
    (entered : inbox.entered = w.inbox.entered) (params : parametersOf inbox = parameters)
    (valid : parameters.valid = true) (committed : Committed env inbox) :
    Reach env { w with
      inbox :=
        { inbox with
          generation := w.inbox.generation+1, recoveryNonce := w.inbox.recoveryNonce+1,
          origin := ⟨w.inbox.checkpoint.height,w.number,env.time w.number⟩,
          origins := w.inbox.origins ++ [(w.inbox.generation+1,⟨w.inbox.checkpoint.height,w.number,env.time w.number⟩)] },
      registry := { w.registry with registry := registry }, schedule := schedule,
      queue := w.queue.map (fun (i,e) => (i,if i ∈ clear then Forced.clear (emptyHash env) e else e)),
      configurations := (w.inbox.generation+1,parameters) :: w.configurations } := by
  have before := held.params initialized
  refine ⟨?_,entered.trans held.entered,held.proposals,held.retained,held.genesis,?_,?_,committed,?_,held.fenced,?_⟩
  · intro absent
    change w.start = none at absent
    rw [started] at absent
    cases absent
  · intro absent
    change w.initialized = false at absent
    rw [initialized] at absent
    cases absent
  · intro _
    refine ⟨⟨w.inbox.generation+1,?_⟩,?_⟩
    · change (w.inbox.generation+1,parametersOf inbox) ∈ (w.inbox.generation+1,parameters) :: w.configurations
      rw [params]
      exact List.mem_cons_self
    · intro x mem
      rcases List.mem_cons.mp mem with rfl | old
      · exact valid
      · exact before.2 x old
  · intro i e mem
    obtain ⟨⟨j,entry⟩,member,same⟩ := List.mem_map.mp mem
    by_cases blanked : j ∈ clear
    · simp only [blanked,↓reduceIte,Prod.mk.injEq] at same
      obtain ⟨-,rfl⟩ := same
      exact ⟨[],rfl,Nat.zero_le _⟩
    · simp only [blanked,↓reduceIte,Prod.mk.injEq] at same
      obtain ⟨rfl,rfl⟩ := same
      exact held.queue _ _ member
  · intro cp mem
    obtain ⟨s,st,record⟩ := held.records cp mem
    refine ⟨s,st,?_⟩
    rcases record with root | ⟨above,timed⟩
    · exact Or.inl root
    · refine Or.inr ⟨above,timed_mono timed (Nat.le_refl _) ?_⟩
      simp only [maxAges,List.map_cons,List.foldr_cons]
      exact Nat.le_max_right _ _

private theorem recover_reach {env : Environment} {w t : World} {request : RecoveryRequest}
    (held : Reach env w) (ok : recover env w request = some t) : Reach env t := by
  unfold recover at ok
  obtain ⟨start,started,ok⟩ := Option.bind_eq_some_iff.mp ok
  dsimp only at ok
  cases upgrade : request.upgrade with
  | none =>
    simp only [upgrade,Option.isSome_none,Option.getD_none,Bool.false_eq_true,↓reduceIte] at ok
    split at ok
    next guard =>
      obtain ⟨schedule,_,ok⟩ := Option.bind_eq_some_iff.mp ok
      obtain ⟨registry,_,rfl⟩ := Option.map_eq_some_iff.mp ok
      have before := held.params guard.2.1
      obtain ⟨g,mem⟩ := before.1
      exact recovered_reach held started guard.2.1 rfl rfl (before.2 _ mem) held.committed
    next => simp at ok
  | some parameters =>
    simp only [upgrade,Option.isSome_some,Option.getD_some,↓reduceIte] at ok
    split at ok
    next guard =>
      obtain ⟨schedule,_,ok⟩ := Option.bind_eq_some_iff.mp ok
      obtain ⟨registry,_,rfl⟩ := Option.map_eq_some_iff.mp ok
      have upgraded := guard.2.2.2.2.2.2.2.2.2.2.2.2.2.2 trivial
      exact recovered_reach held started guard.2.1 rfl (parameters_install _ _ _) upgraded.1 rfl
    next => simp at ok

private theorem rollback_reach {env : Environment} {w t : World} {caller snapshot : Nat} {trusted : Checkpoint}
    (held : Reach env w) (ok : rollback env w caller trusted snapshot = some t) : Reach env t := by
  unfold rollback at ok
  split at ok
  next =>
    obtain ⟨registry,_,rfl⟩ := Option.map_eq_some_iff.mp ok
    refine ⟨held.generation,held.entered,held.proposals,held.retained,held.genesis,held.fresh,held.params,
      held.committed,held.queue,held.fenced,?_⟩
    intro cp mem
    exact held.records cp (List.mem_filter.mp mem).1
  next => simp at ok

/-- The last header of a valid chain is its parent or the header of a valid block. -/
private theorem chain_terminal {r : Blocks.Policy} :
    ∀ {q : Header} {bs : List Block}, Blocks.Chain r q bs →
      Blocks.terminal q bs = q ∨ ∃ parent b, Blocks.Valid r parent b ∧ b.header = Blocks.terminal q bs
  | _, [], _ => Or.inl rfl
  | q, b :: rest, chain => by
    rcases chain_terminal chain.2 with same | ⟨parent,last,valid,eq⟩
    · exact Or.inr ⟨q,b,chain.1,same.symm⟩
    · exact Or.inr ⟨parent,last,valid,eq⟩

/-- A valid block's timestamp is within the maximum anchor age of its anchor, an actual
completed L1 block below the current one. -/
private theorem valid_time {env : Environment} {w : World} {archive : List Header} {reference : Nat}
    {q : Header} {b : Block} (inv : Journal.Invariant env w)
    (valid : Blocks.Valid (policy env w archive reference) q b) :
    ∃ m, m < w.number ∧ b.header.timestamp ≤ env.time m+w.inbox.maxAnchorAge := by
  obtain ⟨s,_,member,anchored⟩ := Journal.authenticated_snapshot valid.anchor.authenticated
  have age := valid.anchor.age
  have stamp : b.header.anchor.timestamp = s.timestamp := by rw [← anchored]; rfl
  obtain ⟨time,below,_⟩ := inv.snapshots s member
  change b.header.timestamp-b.header.anchor.timestamp ≤ w.inbox.maxAnchorAge at age
  exact ⟨s.number,below,by omega⟩

private theorem land_reach {env : Environment} {registry : RegistryMachine.State} {w t : World} {a : Landing}
    (premises : FundPremises env registry) (reach : Trace env (empty env registry) w) (held : Reach env w)
    (ok : land env w a = some t) : Reach env t := by
  obtain ⟨check,rfl⟩ := land_success ok
  obtain ⟨s,started⟩ := Option.isSome_iff_exists.mp check.started
  have frontier := Journal.trace_frontier_record reach check.started
  have certificate := Custody.certified_landing premises.currentRegistryGenesis premises.currentVerifierSound reach ok
  obtain ⟨segment⟩ := accepted_suffix_from_certificate ok certificate frontier.2.1
  refine ⟨held.generation,held.entered,held.proposals,held.retained,held.genesis,held.fresh,held.params,
    held.committed,held.queue,?_,?_⟩
  · intro _ switching
    cases ever : w.everLanded with
    | true => exact held.fenced ever switching
    | false =>
      rcases Custody.trace_switching_fence premises.currentRegistryGenesis switching premises.currentPrimitives
          premises.currentUnzenExtension premises.currentVerifierSound reach with ⟨_,_,records⟩ | ⟨landed,_⟩
      · rcases records with none | ⟨_,pending⟩
        · have member := frontier.1
          rw [none] at member
          cases member
        · obtain ⟨fence,legacy,retained,_,starts⟩ := Custody.pending_parent_fence premises.currentPrimitives reach ok
            (Custody.trace_invariant premises.currentRegistryGenesis premises.currentPrimitives
              premises.currentVerifierSound reach) segment frontier.2.2 frontier.2.1 pending certificate
          obtain ⟨start,written,_,_,closed,finalized,present,hash,root,height,elHash,stateRoot,_⟩ := fence
          exact ⟨start,legacy,written,retained,closed,finalized,present,hash,root,starts.1.symm.trans height,
            starts.2.1.symm.trans elHash,starts.2.2.1.symm.trans stateRoot⟩
      · rw [ever] at landed
        cases landed
  · intro cp mem
    rcases List.mem_cons.mp mem with rfl | old
    · refine ⟨s,started,Or.inr ⟨?_,?_⟩⟩
      · have grid := check.frontierGrid
        rw [started] at grid
        simp only [Option.map_some,Option.getD_some,Start.onGrid,decide_eq_true_eq] at grid
        have progress := check.progress
        change s.height < a.input.lastHeight
        omega
      · refine ⟨Blocks.terminal segment.parent segment.blocks,⟨segment.terminalHeight,segment.terminalCut⟩,
          Custody.suffix_terminal_bound segment,?_⟩
        rcases chain_terminal segment.valid with same | ⟨q,b,valid,eq⟩
        · have height := segment.terminalHeight
          rw [same,segment.parentHeight] at height
          have progress := check.progress
          omega
        · obtain ⟨m,below,time⟩ := valid_time (Journal.trace_invariant reach) valid
          obtain ⟨g,member⟩ := (held.params check.initialized).1
          have age : w.inbox.maxAnchorAge ≤ maxAges w := ages_member member
          refine ⟨m,below,?_⟩
          rw [← eq]
          change b.header.timestamp ≤ env.time m+maxAges w
          omega
    · exact held.records cp old

private theorem unzen_reach {env : Environment} {w t : World} {proposal : Nat} {h : Header} {proof : Hash}
    (held : Reach env w) (ok : unzenProve env w proposal h proof = some t) : Reach env t := by
  unfold unzenProve at ok
  split at ok
  next guard =>
    cases Option.some.inj ok
    refine ⟨held.generation,held.entered,held.proposals,?_,held.genesis,held.fresh,held.params,held.committed,
      held.queue,?_,held.records⟩
    · intro header retained
      cases Option.some.inj retained
      exact ⟨proof,guard.2.1⟩
    · intro ever switching
      obtain ⟨_,_,_,_,closed,_⟩ := held.fenced ever switching
      have below := guard.2.2.1
      have above := guard.2.2.2.1
      omega
  next => simp at ok

private theorem execute_reach {env : Environment} {registry : RegistryMachine.State} {w t : World} {call : Call}
    (premises : FundPremises env registry) (reach : Trace env (empty env registry) w)
    (held : Reach env w) (ok : execute env w call = some t) : Reach env t := by
  cases call with
  | initializeInbox caller => exact initialize_reach reach held ok
  | setOrigin caller height hash root => exact set_origin_reach reach held ok
  | correctStart caller height hash root => exact correct_reach held ok
  | enqueue raw paid refund => exact enqueue_reach held ok
  | recover request => exact recover_reach held ok
  | rollback caller trusted snapshot => exact rollback_reach held ok
  | land a => exact land_reach premises reach held ok
  | unzenProve proposal header proof => exact unzen_reach held ok
  | _ => exact reach_same held (execute_same (by exact trivial) ok)

private theorem empty_reach (env : Environment) (registry : RegistryMachine.State) :
    Reach env (empty env registry) := by
  refine ⟨fun _ => rfl,rfl,rfl,?_,?_,fun _ => parameters_install _ _ _,?_,rfl,?_,?_,?_⟩
  · intro h retained; cases retained
  · intro _ initialized; cases initialized
  · intro initialized; cases initialized
  · intro i e mem; cases mem
  · intro ever; cases ever
  · intro cp mem; cases mem

/-- Every reachable state satisfies `Reach`. -/
private theorem trace_reach {env : Environment} {registry : RegistryMachine.State} {w : World}
    (premises : FundPremises env registry) (trace : Trace env (empty env registry) w) : Reach env w := by
  induction trace with
  | refl => exact empty_reach env registry
  | @step previous current prior change ih =>
    cases change with
    | call call =>
      cases ok : execute env previous call with
      | none => simpa only [transact,ok,Option.getD_none] using ih
      | some result => simpa only [transact,ok,Option.getD_some] using execute_reach premises prior ih ok
    | node after validated =>
      exact reach_same ih ⟨rfl,rfl,rfl,rfl,rfl,⟨rfl,rfl⟩,rfl,rfl,rfl,rfl,Nat.le_refl _,rfl,rfl⟩

/-! ### Path steps -/

/-- A `CallTrace` is a `Trace`. -/
private theorem CallTrace.toTrace {env : Environment} {allowed : Call → Prop} {w u : World}
    (path : CallTrace env allowed w u) : Trace env w u := by
  induction path with
  | refl => exact .refl _
  | call _ call _ ih => exact .step ih (.call _ call)

private theorem CallTrace.append {env : Environment} {allowed : Call → Prop} {a b c : World}
    (first : CallTrace env allowed a b) (second : CallTrace env allowed b c) : CallTrace env allowed a c := by
  induction second with
  | refl => exact first
  | call _ call ok ih => exact .call ih call ok

/-- One accepted path call extends the path to its result. -/
private theorem extend {env : Environment} {w v t : World} {call : Call}
    (path : RecoveryTrace env w v) (ok : execute env v call = some t) (allowed : RecoveryCall call) :
    RecoveryTrace env w t := by
  have step := CallTrace.call path call allowed
  rwa [transact,ok,Option.getD_some] at step

/-- `x` after L1 advances to block `number`. -/
private def closedAt (env : Environment) (x : World) (number : Nat) : World :=
  { x with number := number, history := x.history ++ (List.range' x.number (number-x.number)).map (snapshot env x) }

private theorem advance_ok {env : Environment} {x : World} {number : Nat}
    (clock : ∀ m n, m < n → env.time m < env.time n) (later : x.number < number) (fits : number < limit48) :
    execute env x (.advance number) = some (closedAt env x number) := by
  show advance env x number = some (closedAt env x number)
  unfold advance
  rw [ite_eq_left ⟨later,fits,Nat.le_of_lt (clock _ _ later)⟩]
  rfl

/-- What the path keeps until the recovery: the facts `LiveAt` states about `w` stay true. -/
private structure Kept (w v : World) : Prop where
  gridK : v.inbox.gridK = w.inbox.gridK
  nonce : v.inbox.recoveryNonce = w.inbox.recoveryNonce
  configuration : v.inbox.configuration = w.inbox.configuration
  schedule : v.schedule = w.schedule
  registry : v.registry = w.registry
  initialized : v.initialized = w.initialized

private theorem kept_trans {u v w : World} (first : Kept u v) (second : Kept v w) : Kept u w :=
  ⟨second.gridK.trans first.gridK,second.nonce.trans first.nonce,
    second.configuration.trans first.configuration,second.schedule.trans first.schedule,
    second.registry.trans first.registry,second.initialized.trans first.initialized⟩

/-- The state `v` at block `n` after steps 1-2, with the start settled and its batch parent `p`. -/
private structure Started (env : Environment) (w v : World) (p : Header) (n : Nat) : Prop where
  path : RecoveryTrace env w v
  number : v.number = n
  kept : Kept w v
  generation : v.inbox.generation+1 < limit48
  progress : w.everLanded = true → v.inbox.checkpoint.height = w.inbox.checkpoint.height
  start : ∃ s, v.start = some s ∧ Start.onGrid s.height v.inbox.gridK v.inbox.checkpoint.height = true ∧
    v.inbox.checkpoint.height+v.inbox.gridK < limit48 ∧
    (env.core.unzenInbox ≠ 0 → p.height = s.height → env.startImplementation p.stateRoot = true)
  fence : firstFence env v = true
  parent : Custody.HeaderOf v.inbox.checkpoint p ∧ HashBound env p
  time : p.timestamp+w.inbox.gridK+1 ≤ env.time n

/-- `LiveAt.window`'s block is late enough for a parent below any of its three bounds. -/
private theorem window_time {env : Environment} {w : World} {n t : Nat} (bound : WindowBound env w ≤ env.time n)
    (below : t ≤ env.time w.number+maxAges w ∨ t ≤ env.core.forkTime ∨ t ≤ env.genesisHeader.timestamp) :
    t+w.inbox.gridK+1 ≤ env.time n := by
  unfold WindowBound at bound
  have a := Nat.le_max_left (env.time w.number+maxAges w) (max env.core.forkTime env.genesisHeader.timestamp)
  have b := Nat.le_max_right (env.time w.number+maxAges w) (max env.core.forkTime env.genesisHeader.timestamp)
  have c := Nat.le_max_left env.core.forkTime env.genesisHeader.timestamp
  have d := Nat.le_max_right env.core.forkTime env.genesisHeader.timestamp
  omega

private theorem valid_grid {p : Parameters} (valid : p.valid = true) : 0 < p.gridK ∧ p.gridK ≤ 6 := by
  simp only [Parameters.valid,Committee.configOK,Bool.and_eq_true,decide_eq_true_eq] at valid
  omega

/-- A lane header with Etna's initial Comet, FI and validator-state fields (`Custody.StartsAt`). -/
private def zeroed (h : Header) : Header := { h with cometHash := 0, cursor := 0, valStateHash := 0 }

private theorem zeroed_starts (h : Header) : Custody.StartsAt (zeroed h) h :=
  ⟨rfl,rfl,rfl,rfl,rfl,rfl,rfl,rfl⟩

private theorem zeroed_header {cp : Checkpoint} {h : Header} {s : StartData} (record : StartRecord s cp)
    (height : h.height = s.height) (hash : h.elHash = s.hash) : Custody.HeaderOf cp (zeroed h) := by
  obtain ⟨ch,ce,cc,cu,cv⟩ := record
  refine ⟨height.trans ch.symm,?_⟩
  simp only [zeroed,BlockValidity.Header.cut,hash,ce,cc,cu,cv]

/-- With the start fixed (a new network, or a landed switching network) the parent is the
genesis header, the zeroed final lane header, or the header `Reach.records` keeps. -/
private theorem fixed_parent {env : Environment} {registry : RegistryMachine.State} {w : World}
    (premises : RecoveryPremises env registry) (trace : Trace env (empty env registry) w)
    (initialized : w.initialized = true) (held : Reach env w)
    (fixed : env.core.unzenInbox = 0 ∨ w.everLanded = true) :
    ∃ s p, w.start = some s ∧ Custody.HeaderOf w.inbox.checkpoint p ∧ HashBound env p ∧
      (p.timestamp ≤ env.time w.number+maxAges w ∨ p.timestamp ≤ env.core.forkTime ∨
        p.timestamp ≤ env.genesisHeader.timestamp) ∧
      (env.core.unzenInbox ≠ 0 → p.height = s.height → env.startImplementation p.stateRoot = true) ∧
      firstFence env w = true := by
  have written : ∃ s, w.start = some s := by
    by_cases newNetwork : env.core.unzenInbox = 0
    · exact ⟨_,(held.genesis newNetwork initialized).1⟩
    · obtain ⟨s,_,st,_⟩ := held.fenced (fixed.resolve_left newNetwork) newNetwork
      exact ⟨s,st⟩
  obtain ⟨s,started⟩ := written
  have member := (Journal.trace_frontier_record trace (by simp [started])).1
  obtain ⟨s',st',record⟩ := held.records _ member
  have same : s' = s := Option.some.inj (st'.symm.trans started)
  rw [same] at record
  rcases record with root | ⟨above,T,header,bound,m,below,time⟩
  · by_cases newNetwork : env.core.unzenInbox = 0
    · obtain ⟨st,height,cursor,comet,val⟩ := held.genesis newNetwork initialized
      rw [started] at st
      cases st
      obtain ⟨ch,ce,cc,cu,cv⟩ := root
      refine ⟨_,env.genesisHeader,started,⟨height.trans ch.symm,?_⟩,premises.currentPrimitives.genesis,
        Or.inr (Or.inr (Nat.le_refl _)),fun switching => (switching newNetwork).elim,?_⟩
      · simp only [BlockValidity.Header.cut,ce,cc,cu,cv,comet,cursor,val]
      · simp [firstFence,started,Start.firstLanding,newNetwork]
    · obtain ⟨s'',h,st,retained,closed,finalized,present,hash,stateRoot,hh,he,hr⟩ :=
        held.fenced (fixed.resolve_left newNetwork) newNetwork
      rw [started] at st
      cases st
      obtain ⟨proof,valid⟩ := held.retained h retained
      have final : w.unzen.finalizedProposal = env.unzenNextProposal-1 := by
        have := held.proposals
        omega
      rw [final] at valid
      obtain ⟨_,_,_,_,implementation,bound⟩ := premises.unzenStart newNetwork h proof valid
      have early := (premises.currentPrimitives.unzen _ _ _ valid).2.2
      refine ⟨_,zeroed h,started,zeroed_header root hh he,bound _ (zeroed_starts h),
        Or.inr (Or.inl (Nat.le_of_lt early)),fun _ _ => implementation,?_⟩
      simp [firstFence,started,Start.firstLanding,closed,finalized,present,hash,stateRoot]
  · refine ⟨s,T,started,header,bound,Or.inl ?_,?_,?_⟩
    · have := premises.recoveryClock m w.number below
      omega
    · intro _ height
      have := header.1
      omega
    · have off : w.inbox.checkpoint.height ≠ s.height := Nat.ne_of_gt above
      simp [firstFence,started,Start.firstLanding,off]

private theorem fixed_started {env : Environment} {registry : RegistryMachine.State} {w : World} {n : Nat}
    (premises : RecoveryPremises env registry) (trace : Trace env (empty env registry) w)
    (initialized : w.initialized = true) (live : LiveAt env w) (held : Reach env w)
    (fixed : env.core.unzenInbox = 0 ∨ w.everLanded = true)
    (later : w.number < n) (fits : n+4 < limit48) (bound : WindowBound env w ≤ env.time n) :
    ∃ v p, Started env w v p n := by
  obtain ⟨s,p,started,header,hashBound,below,implementation,fence⟩ :=
    fixed_parent premises trace initialized held fixed
  have generation := live.generation
  exact ⟨closedAt env w n,p,extend (.refl w) (advance_ok premises.recoveryClock later (by omega)) trivial,rfl,
    ⟨rfl,rfl,rfl,rfl,rfl,rfl⟩,by show w.inbox.generation+1 < limit48; omega,fun _ => rfl,
    ⟨s,started,live.grid s started,live.height,implementation⟩,fence,⟨header,hashBound⟩,window_time bound below⟩

/-- The final lane header: the retained one when the lane is finalized, else the one whose
proof `UnzenLaneLive` supplies. Either is a valid proof of the final proposal. -/
private theorem lane_header {env : Environment} {registry : RegistryMachine.State} {w : World}
    (premises : FundPremises env registry) (trace : Trace env (empty env registry) w) (held : Reach env w)
    (switching : env.core.unzenInbox ≠ 0) (live : UnzenLaneLive env w) :
    ∃ h proof, env.unzenValid (env.unzenNextProposal-1) h proof = true ∧
      ((w.unzen.checkpointExists = true ∧ w.unzen.nextProposal = w.unzen.finalizedProposal+1 ∧
          w.unzen.finalizedHash = h.elHash ∧ w.unzen.checkpointHash = h.elHash ∧ w.unzen.checkpointRoot = h.stateRoot) ∨
        (w.unzen.finalizedProposal < w.unzen.nextProposal-1 ∧
          env.unzenParent w.unzen.finalizedProposal (w.unzen.nextProposal-1) h proof = w.unzen.finalizedHash ∧
          env.unzenValid (w.unzen.nextProposal-1) h proof = true)) := by
  rcases live switching with ⟨present,closed⟩ | ⟨h,proof,valid,below,parent⟩
  · obtain ⟨h,retained,_,_,finalized,hash,root,_⟩ := (Custody.trace_invariant premises.currentRegistryGenesis
      premises.currentPrimitives premises.currentVerifierSound trace).unzen present
    obtain ⟨proof,valid⟩ := held.retained h retained
    have final : w.unzen.finalizedProposal = env.unzenNextProposal-1 := by
      have := held.proposals
      omega
    rw [final] at valid
    exact ⟨h,proof,valid,Or.inl ⟨present,closed,finalized,hash,root⟩⟩
  · have final := valid
    rw [held.proposals] at final
    exact ⟨h,proof,final,Or.inr ⟨below,parent,valid⟩⟩

/-- Step 2's start write: `setOrigin` when no start is written, `correctStart` when the written
start differs from the lane header, nothing when it equals it. -/
private theorem write_lane_start {env : Environment} {x : World} {h : Header}
    (switching : env.core.unzenInbox ≠ 0) (initialized : x.initialized = true)
    (unlanded : x.everLanded = false) (fresh : x.start = none → x.inbox.generation = 0)
    (waiting : ∀ s, x.start = some s → StartRecord s x.inbox.checkpoint ∧ x.inbox.signals = [])
    (fork : env.core.forkTime ≤ env.time x.number) (generation : x.inbox.generation+2 < limit48)
    (usable : 0 < h.height ∧ h.height < limit48 ∧ h.elHash ≠ 0 ∧ h.stateRoot ≠ 0) :
    ∃ y, RecoveryTrace env x y ∧ y.start = some ⟨h.height,h.elHash,h.stateRoot⟩ ∧
      StartRecord ⟨h.height,h.elHash,h.stateRoot⟩ y.inbox.checkpoint ∧ y.inbox.generation+1 < limit48 ∧
      y.number = x.number ∧ y.unzen = x.unzen ∧ Kept x y := by
  obtain ⟨positive,high,hash,root⟩ := usable
  cases started : x.start with
  | none =>
    refine ⟨writeStart x h.height h.elHash h.stateRoot x.number (env.time x.number) 0,
      extend (.refl x) (call := .setOrigin env.core.originWriter h.height h.elHash h.stateRoot) ?_ trivial,
      rfl,⟨rfl,rfl,rfl,rfl,rfl⟩,?_,rfl,rfl,⟨rfl,rfl,rfl,rfl,rfl,rfl⟩⟩
    · show setOrigin env x env.core.originWriter h.height h.elHash h.stateRoot = some _
      unfold setOrigin
      rw [ite_eq_left ⟨initialized,started,fresh started,rfl,switching,fork,positive,high,hash,root⟩]
    · show 0+1 < limit48
      omega
  | some s =>
    by_cases same : s = ⟨h.height,h.elHash,h.stateRoot⟩
    · subst same
      exact ⟨x,.refl x,started,(waiting _ started).1,by omega,rfl,rfl,⟨rfl,rfl,rfl,rfl,rfl,rfl⟩⟩
    · refine ⟨writeStart x h.height h.elHash h.stateRoot x.number (env.time x.number) (x.inbox.generation+1),
        extend (.refl x) (call := .correctStart env.core.owner h.height h.elHash h.stateRoot) ?_ trivial,
        rfl,⟨rfl,rfl,rfl,rfl,rfl⟩,?_,rfl,rfl,⟨rfl,rfl,rfl,rfl,rfl,rfl⟩⟩
      · show correctStart env x env.core.owner h.height h.elHash h.stateRoot = some _
        obtain ⟨record,signals⟩ := waiting s started
        unfold correctStart
        rw [started,Option.bind_some,ite_eq_left ⟨rfl,switching,unlanded,record.1,signals,positive,high,hash,root,
          by omega⟩]
      · show x.inbox.generation+1+1 < limit48
        omega

/-- Step 2's lane proof: `unzenProve` of the final proposal unless the lane is finalized; then
the first-landing fence holds at the start. -/
private theorem close_lane {env : Environment} {y : World} {h : Header} {proof : Hash}
    (switching : env.core.unzenInbox ≠ 0) (started : y.start = some ⟨h.height,h.elHash,h.stateRoot⟩)
    (lane : (y.unzen.checkpointExists = true ∧ y.unzen.nextProposal = y.unzen.finalizedProposal+1 ∧
        y.unzen.finalizedHash = h.elHash ∧ y.unzen.checkpointHash = h.elHash ∧ y.unzen.checkpointRoot = h.stateRoot) ∨
      (y.unzen.finalizedProposal < y.unzen.nextProposal-1 ∧
        env.unzenParent y.unzen.finalizedProposal (y.unzen.nextProposal-1) h proof = y.unzen.finalizedHash ∧
        env.unzenValid (y.unzen.nextProposal-1) h proof = true)) :
    ∃ v, RecoveryTrace env y v ∧ firstFence env v = true ∧ v.start = y.start ∧ v.inbox = y.inbox ∧
      v.number = y.number ∧ Kept y v := by
  rcases lane with ⟨present,closed,finalized,hash,root⟩ | ⟨below,parent,valid⟩
  · refine ⟨y,.refl y,?_,rfl,rfl,rfl,⟨rfl,rfl,rfl,rfl,rfl,rfl⟩⟩
    simp [firstFence,started,Start.firstLanding,closed,finalized,present,hash,root]
  · refine ⟨{ y with
          unzen := ⟨y.unzen.nextProposal,y.unzen.nextProposal-1,h.elHash,true,h.elHash,h.stateRoot⟩,
          unzenHeader := some h,legacySignals := y.legacySignals ++ [⟨h.height,h.elHash,h.stateRoot⟩] },
      extend (.refl y) (call := .unzenProve (y.unzen.nextProposal-1) h proof) ?_ trivial,?_,rfl,rfl,rfl,
      ⟨rfl,rfl,rfl,rfl,rfl,rfl⟩⟩
    · show unzenProve env y (y.unzen.nextProposal-1) h proof = some _
      unfold unzenProve
      rw [ite_eq_left ⟨switching,valid,below,by omega,parent,Or.inr (by simp [started])⟩]
    · simp [firstFence,started,Start.firstLanding]
      omega

private theorem unlanded_started {env : Environment} {registry : RegistryMachine.State} {w : World} {n : Nat}
    (premises : RecoveryPremises env registry) (trace : Trace env (empty env registry) w)
    (initialized : w.initialized = true) (live : LiveAt env w) (held : Reach env w)
    (switching : env.core.unzenInbox ≠ 0) (unlanded : w.everLanded = false)
    (later : w.number < n) (fits : n+4 < limit48) (bound : WindowBound env w ≤ env.time n) :
    ∃ v p, Started env w v p n := by
  have waiting : ∀ s, w.start = some s → StartRecord s w.inbox.checkpoint ∧ w.inbox.signals = [] := by
    intro s started
    rcases Custody.trace_switching_fence premises.currentRegistryGenesis switching premises.currentPrimitives
        premises.currentUnzenExtension premises.currentVerifierSound trace with ⟨_,signals,records⟩ | ⟨ever,_⟩
    · have member := (Journal.trace_frontier_record trace (by simp [started])).1
      rcases records with none | ⟨_,_,s',written,height,hash,comet,cursor,val⟩
      · rw [none] at member
        cases member
      · have same : s' = s := Option.some.inj (written.symm.trans started)
        subst same
        exact ⟨⟨height,hash,comet,cursor,val⟩,signals⟩
    · rw [unlanded] at ever
      cases ever
  obtain ⟨h,proof,valid,lane⟩ := lane_header premises.toFundPremises trace held switching live.unzen
  obtain ⟨positive,high,nonzeroHash,nonzeroRoot,implementation,startsBound⟩ :=
    premises.unzenStart switching h proof valid
  have early := (premises.currentPrimitives.unzen _ _ _ valid).2.2
  have fork : env.core.forkTime ≤ env.time n := by
    unfold WindowBound at bound
    have := Nat.le_max_left env.core.forkTime env.genesisHeader.timestamp
    have := Nat.le_max_right (env.time w.number+maxAges w) (max env.core.forkTime env.genesisHeader.timestamp)
    omega
  have generation := live.generation
  obtain ⟨y,toY,ystart,yrecord,ygen,ynumber,yunzen,ykept⟩ := write_lane_start (x := closedAt env w n) (h := h)
    switching initialized unlanded held.generation waiting fork (by show w.inbox.generation+2 < limit48; omega)
    ⟨positive,by omega,nonzeroHash,nonzeroRoot⟩
  obtain ⟨v,toV,fence,vstart,vinbox,vnumber,vkept⟩ := close_lane (proof := proof) switching ystart
    (by rw [yunzen]; exact lane)
  obtain ⟨g,member⟩ := (held.params initialized).1
  obtain ⟨gridPositive,gridSmall⟩ := valid_grid ((held.params initialized).2 _ member)
  have kept : Kept w v :=
    kept_trans (show Kept w (closedAt env w n) from ⟨rfl,rfl,rfl,rfl,rfl,rfl⟩) (kept_trans ykept vkept)
  have height : v.inbox.checkpoint.height = h.height := by
    rw [vinbox]
    exact yrecord.1
  have positiveK : 0 < w.inbox.gridK := gridPositive
  have smallK : w.inbox.gridK ≤ 6 := gridSmall
  refine ⟨v,zeroed h,?_,vnumber.trans ynumber,kept,?_,fun ever => ?_,
    ⟨_,vstart.trans ystart,?_,?_,fun _ _ => implementation⟩,fence,⟨?_,startsBound _ (zeroed_starts h)⟩,
    window_time bound (Or.inr (Or.inl (Nat.le_of_lt early)))⟩
  · exact CallTrace.append (extend (.refl w) (advance_ok premises.recoveryClock later (by omega)) trivial)
      (CallTrace.append toY toV)
  · rw [vinbox]
    exact ygen
  · rw [unlanded] at ever
    cases ever
  · rw [height,kept.gridK]
    simp only [Start.onGrid,Nat.sub_self,Nat.zero_mod,Nat.le_refl,and_true,decide_eq_true_eq]
    exact positiveK
  · rw [height,kept.gridK]
    omega
  · rw [vinbox]
    exact zeroed_header yrecord rfl rfl

/-- The rules argument of step 4 and the image of step 3: keep the schedule (`rules = 0`) when
its rulesets are live, otherwise install ruleset next+1; the image implements every ruleset the
resulting schedule selects. -/
private theorem recovery_rules {env : Environment} {w : World} (live : LiveAt env w) :
    ∃ rules image schedule, Rules.recover w.schedule rules = some schedule ∧
      ∀ t, RulesetLive env (Rules.select schedule t) ∧ Rules.select schedule t ∈ env.imageRules image := by
  rcases live.ruleset with ⟨active,next,image,inActive,inNext⟩ | ⟨fresh,image,inFresh⟩
  · refine ⟨0,image,{ w.schedule with stopTime := 0, stopGrid := 0 },rfl,fun t => ?_⟩
    unfold Rules.select
    split
    · exact ⟨next,inNext⟩
    · exact ⟨active,inActive⟩
  · refine ⟨w.schedule.next+1,image,⟨w.schedule.next+1,w.schedule.next+1,0,0,0⟩,?_,fun t => ?_⟩
    · unfold Rules.recover
      rw [ite_eq_right (Nat.succ_ne_zero _),ite_eq_left ⟨rfl,live.rules⟩]
    · unfold Rules.select
      split <;> exact ⟨fresh,inFresh⟩

/-- `image` registered and the complete verifier version selected (step 3). -/
private def configured (v : World) (image version : Nat) : World :=
  { v with images := image :: v.images, verifier := version }

private theorem configure {env : Environment} {w v : World} (path : RecoveryTrace env w v) (image version : Nat) :
    RecoveryTrace env w (configured v image version) := by
  have registered : execute env v (.image env.core.owner image true) = some { v with images := image :: v.images } := by
    simp [execute]
  exact extend (extend path registered trivial) (call := .verifier env.core.owner version)
    (by simp [execute,configured]) trivial

/-- An exclusion call with no exclusions leaves the registry exactly as it is. -/
private theorem exclude_none (s : RegistryMachine.State) (v : RegistryMachine.InboxView) (now : Nat)
    (free : v.entered = false) (initialized : v.initialized = true) :
    RegistryMachine.execute s v now (.exclude s.config.inbox now []) = some s := by
  have ledger : RegistryMachine.excludedLedger s [] now = s.ledger := by
    unfold RegistryMachine.excludedLedger
    have bonds : (fun id => (s.ledger.bonds id).map fun b =>
        if ([] : List (Nat × Hash)).any (fun x => x.1 == id) then
          (⟨Staking.exclude b.value now,b.slot⟩ : Registry.Bond) else b) = s.ledger.bonds := by
      funext id
      cases s.ledger.bonds id <;> rfl
    rw [bonds]
  simp [RegistryMachine.execute,free,initialized,RegistryMachine.exclusionsValid,ledger,RegistryMachine.finish]

/-- The plain recovery of step 4 at the current state's generation, checkpoint and nonce. -/
private def plainRequest (env : Environment) (w : World) (rules : Nat) : RecoveryRequest :=
  { caller := env.core.owner, expectedGeneration := w.inbox.generation,
    expectedCheckpoint := w.inbox.checkpoint.height, expectedNonce := w.inbox.recoveryNonce,
    validUntil := env.time w.number, exclusions := [], clear := [], rules := rules }

/-- The state the plain recovery writes. -/
private def recovered (env : Environment) (w : World) (schedule : Rules.Schedule) : World :=
  { w with
    inbox :=
      { w.inbox with
        generation := w.inbox.generation+1, recoveryNonce := w.inbox.recoveryNonce+1,
        origin := ⟨w.inbox.checkpoint.height,w.number,env.time w.number⟩,
        origins := w.inbox.origins ++ [(w.inbox.generation+1,⟨w.inbox.checkpoint.height,w.number,env.time w.number⟩)] },
    schedule := schedule, configurations := (w.inbox.generation+1,parametersOf w.inbox) :: w.configurations }

private theorem recover_ok {env : Environment} {w : World} {start : StartData} {rules : Nat}
    {schedule : Rules.Schedule} (started : w.start = some start) (initialized : w.initialized = true)
    (entered : w.inbox.entered = false) (nonce : w.inbox.recoveryNonce+1 < limit256)
    (stamp : env.time w.number < limit256) (generation : w.inbox.generation+1 < limit48)
    (grid : Start.onGrid start.height w.inbox.gridK w.inbox.checkpoint.height = true)
    (scheduled : Rules.recover w.schedule rules = some schedule) :
    execute env w (.recover (plainRequest env w rules)) = some (recovered env w schedule) := by
  show recover env w (plainRequest env w rules) = some (recovered env w schedule)
  unfold recover
  rw [started,Option.bind_some]
  simp only [show (plainRequest env w rules).upgrade = none from rfl,Option.isSome_none,Option.getD_none,
    Bool.false_eq_true,↓reduceIte]
  split
  next =>
    simp only [plainRequest,scheduled,Option.bind_some,
      exclude_none w.registry.registry (registryView env w) w.number entered initialized,Option.map_some,
      List.not_mem_nil,↓reduceIte]
    rw [show (fun x : Nat × Forced.Entry => (x.fst,x.snd)) = id from rfl,List.map_id,← started]
    rfl
  next refused =>
    exact (refused ⟨rfl,initialized,entered,rfl,rfl,rfl,nonce,Nat.le_refl _,stamp,generation,grid,List.Pairwise.nil,
      List.Pairwise.nil,fun _ absent => absurd absent List.not_mem_nil,by intro absent; cases absent⟩).elim

private theorem committee_transfer {env : Environment} {w x : World} {cutoff : Nat} {keys : List Hash}
    (configuration : x.inbox.configuration = w.inbox.configuration) (registry : x.registry = w.registry)
    (live : CommitteeLive env w cutoff keys) : CommitteeLive env x cutoff keys := by
  unfold CommitteeLive at live ⊢
  rw [configuration,registry]
  exact live

/-- Steps 3-5 from a settled start: image, verifier, the plain recovery at block `n`, and
L1 advanced to `n+2`. -/
private theorem finish {env : Environment} {registry : RegistryMachine.State} {w v : World} {p : Header}
    {n : Nat} {keys : List Hash} (premises : RecoveryPremises env registry)
    (trace : Trace env (empty env registry) w) (initialized : w.initialized = true) (live : LiveAt env w)
    (fits : n+4 < limit48) (stamp : env.time n+8 < limit256) (committee : CommitteeLive env w n keys)
    (started : Started env w v p n) : ∃ u image, Prepared env registry w u p n keys image := by
  obtain ⟨path,number,kept,generation,progress,⟨s,written,grid,height,implementation⟩,fence,parent,time⟩ :=
    started
  have heldV := trace_reach premises.toFundPremises (Custody.trace_append trace (CallTrace.toTrace path))
  obtain ⟨version,complete⟩ := premises.proofComplete
  obtain ⟨rules,image,schedule,scheduled,selected⟩ := recovery_rules live
  have recovery : execute env (configured v image version)
      (.recover (plainRequest env (configured v image version) rules)) =
      some (recovered env (configured v image version) schedule) := by
    refine recover_ok (start := s) written (kept.initialized.trans initialized) heldV.entered ?_ ?_ generation grid ?_
    · show v.inbox.recoveryNonce+1 < limit256
      rw [kept.nonce]
      exact live.nonce
    · show env.time v.number < limit256
      rw [number]
      omega
    · show Rules.recover v.schedule rules = some schedule
      rw [kept.schedule]
      exact scheduled
  have toR := extend (configure path image version) recovery ⟨rfl,rfl,rfl⟩
  have toU := extend toR (advance_ok (number := n+2) premises.recoveryClock
    (by show v.number < n+2; omega) (by omega)) trivial
  have reachR := Custody.trace_append trace (CallTrace.toTrace toR)
  have reachU := Custody.trace_append trace (CallTrace.toTrace toU)
  have heldU := trace_reach premises.toFundPremises reachU
  have ready : (closedAt env (recovered env (configured v image version) schedule) (n+2)).initialized = true :=
    kept.initialized.trans initialized
  obtain ⟨⟨g,member⟩,valid⟩ := heldU.params ready
  refine ⟨_,image,toU,reachU,⟨rfl,fits⟩,progress,⟨Nat.succ_pos _,rfl,number⟩,?_,parent,⟨?_,stamp⟩,
    ⟨s,written,grid,height,implementation⟩,fence,(Rules.recover_clears_stop scheduled).1,selected,
    ⟨List.mem_cons_self,complete⟩,committee_transfer kept.configuration kept.registry committee,ready,
    heldU.entered,⟨valid _ member,heldU.committed⟩,heldU.queue⟩
  · intro snap mem above
    rcases List.mem_append.mp mem with old | fresh
    · obtain ⟨_,below,_⟩ := (Journal.trace_invariant reachR).snapshots snap old
      change snap.number < v.number at below
      omega
    · obtain ⟨m,_,rfl⟩ := List.mem_map.mp fresh
      exact ⟨rfl,rfl,rfl,rfl,rfl⟩
  · show p.timestamp+v.inbox.gridK+1 ≤ env.time n
    rw [kept.gridK]
    exact time

/-! ### The L1 half -/

/-- From every reachable, initialized state satisfying `LiveAt`, the plain-recovery path of
design 4.3 (no rollback, no exclusions, no blanking, no upgrade) reaches a state with a settled
start, a fresh recovered generation whose origin is the current checkpoint at the window block
R, the snapshots at R and R+1 closed, a live committee and ruleset, a registered image and a
complete verifier, and a hash-bound parent header early enough for K blocks anchored at R. -/
theorem prepare {env : Environment} {registry : RegistryMachine.State} {w : World}
    (premises : Etna.Statements.Current.RecoveryPremises env registry)
    (trace : Trace env (empty env registry) w) (initialized : w.initialized = true)
    (live : Etna.Statements.Current.LiveAt env w) :
    ∃ u p R keys image, Prepared env registry w u p R keys image := by
  obtain ⟨n,keys,later,fits,bound,stamp,committee⟩ := live.window
  have held := trace_reach premises.toFundPremises trace
  have started : ∃ v p, Started env w v p n := by
    by_cases newNetwork : env.core.unzenInbox = 0
    · exact fixed_started premises trace initialized live held (Or.inl newNetwork) later fits bound
    · cases ever : w.everLanded with
      | true => exact fixed_started premises trace initialized live held (Or.inr ever) later fits bound
      | false => exact unlanded_started premises trace initialized live held newNetwork ever later fits bound
  obtain ⟨v,p,started⟩ := started
  obtain ⟨u,image,prepared⟩ := finish premises trace initialized live fits stamp committee started
  exact ⟨u,p,n,keys,image,prepared⟩

end Etna.Design.Current.Protocol.Recovery
