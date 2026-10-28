import EtnaModel.Deployment
import EtnaStatements.Premises
import EtnaProofs.ProtocolState
import EtnaProofs.Lifecycle

/-! Proofs about `EtnaModel.Deployment`. -/
namespace Etna.Design.Deployment

/-- Independent unfolded contracts: deleting a constraint (e.g. L ≥ 3 inside `configOK`), a
commitment check or a stored-field assignment from these definitions must fail here. They
constrain the modeled definitions, not their correspondence to every source rule. -/
theorem constraints_contract (s : State) (cfg : Config) :
    _root_.Etna.Design.Deployment.Constraints s cfg ↔
      (decide (1 ≤ s.gridK ∧ s.gridK ≤ 6 ∧ 3 ≤ s.epochLen ∧ s.epochLen+1 < _root_.Etna.Design.limit48 ∧
          s.gridK ≤ cfg.unsettled ∧ cfg.unsettled ≤ 65536 ∧ cfg.unsettled % s.gridK = 0) = true ∧
        0 < s.forcedDelay ∧ s.forcedDelay < _root_.Etna.Design.limit48 ∧ 1152 ≤ s.maxAnchorAge ∧
        s.maxAnchorAge < _root_.Etna.Design.limit48 ∧
        s.origins.head? = some (0,_root_.Etna.Design.Deployment.genesisOrigin s) ∧
        (_root_.Etna.Design.Deployment.genesisOrigin s).height = 0 ∧
        s.genesisCutoff < (_root_.Etna.Design.Deployment.genesisOrigin s).l1Block ∧
        (_root_.Etna.Design.Deployment.genesisOrigin s).l1Block < _root_.Etna.Design.limit48 ∧
        1 ≤ cfg.nMax ∧ cfg.nMax ≤ 4096 ∧ 867361738 ≤ cfg.unit ∧ cfg.unit ≤ cfg.minimum ∧
        s.gridK ≤ s.maxBatchBlocks ∧ 0 < s.forcedFee ∧ 0 < s.forcedThreshold ∧ s.protocolFeeRecipient ≠ 0) := Iff.rfl

theorem registry_constraints_contract (r : _root_.Etna.Design.RegistryHistory.State) :
    _root_.Etna.Design.Deployment.RegistryConstraints r ↔
      0 < r.activationDelay ∧ 0 < r.exitDelay ∧ r.slashBountyBps ≤ 10000 := Iff.rfl

theorem definitions_contract (s : State) (registry : RegistryHistory.State) (cfg : Config) (archive : List Nat) :
    _root_.Etna.Design.Deployment.words s cfg = _root_.Etna.Design.Encoding.configWords s.domain.l2ChainId
      s.domain.registry cfg.unit cfg.minimum cfg.nMax cfg.unsettled ∧
    _root_.Etna.Design.Deployment.parameters s cfg = ⟨s.genesisCutoff,s.epochLen,cfg.unit,cfg.minimum,cfg.nMax⟩ ∧
    _root_.Etna.Design.Deployment.genesis s registry cfg archive = _root_.Etna.Design.Consensus.selected
      (_root_.Etna.Design.HistoricalContext.derive s registry (_root_.Etna.Design.Deployment.parameters s cfg) archive)
      0 s.genesisCutoff ∧
    _root_.Etna.Design.Deployment.genesisOrigin s = ((s.origins.head?).map Prod.snd).getD ⟨0,0,0⟩ ∧
    (_root_.Etna.Design.Deployment.GenesisElected s registry cfg ↔
      _root_.Etna.Design.Committee.election cfg.unit cfg.minimum s.genesisCutoff cfg.nMax
        (_root_.Etna.Design.HistoricalContext.registryAt registry s.genesisCutoff) = some s.committeeZeroRecord.members) :=
  ⟨rfl,rfl,rfl,rfl,Iff.rfl⟩

theorem build_contract (w : ProtocolState.World) (cfg : Config) (archive : List Nat) (template : BlockValidity.Rules) :
    _root_.Etna.Design.Deployment.build w cfg archive template =
      if _root_.Etna.Design.Deployment.Constraints w.inbox cfg ∧ cfg = w.inbox.configuration ∧
          w.inbox.committeeConfig = w.adapters.configHash (_root_.Etna.Design.Deployment.words w.inbox cfg) ∧
          _root_.Etna.Design.Deployment.genesis w.inbox w.registry cfg archive = w.inbox.committeeZeroRecord ∧
          _root_.Etna.Design.Deployment.GenesisElected w.inbox w.registry cfg ∧
          w.inbox.committeeZero = w.adapters.recordHash w.inbox.committeeZeroRecord ∧
          _root_.Etna.Design.Deployment.RegistryConstraints w.registry then
        (_root_.Etna.Design.HistoricalContext.build w.inbox w.registry
          (_root_.Etna.Design.Deployment.parameters w.inbox cfg) archive).map fun c =>
          { template with
            consensus := c,gridK := w.inbox.gridK,committeeConfig := w.inbox.committeeConfig,
            maxAnchorAge := w.inbox.maxAnchorAge,forcedDelay := w.inbox.forcedDelay,unsettled := cfg.unsettled,
            configHash := w.adapters.configHash,committeeHash := w.adapters.recordHash }
      else none := rfl

theorem build_success {w : ProtocolState.World} {cfg : Config} {archive : List Nat} {template r : BlockValidity.Rules}
    (ok : build w cfg archive template = some r) :
    Constraints w.inbox cfg ∧ cfg = w.inbox.configuration ∧
    w.inbox.committeeConfig = w.adapters.configHash (words w.inbox cfg) ∧
    genesis w.inbox w.registry cfg archive = w.inbox.committeeZeroRecord ∧ GenesisElected w.inbox w.registry cfg ∧
    w.inbox.committeeZero = w.adapters.recordHash w.inbox.committeeZeroRecord ∧ RegistryConstraints w.registry ∧
    ∃ c, HistoricalContext.build w.inbox w.registry (parameters w.inbox cfg) archive = some c ∧
      r = { template with
        consensus := c,gridK := w.inbox.gridK,committeeConfig := w.inbox.committeeConfig,
        maxAnchorAge := w.inbox.maxAnchorAge,forcedDelay := w.inbox.forcedDelay,unsettled := cfg.unsettled,
        configHash := w.adapters.configHash,committeeHash := w.adapters.recordHash } := by
  unfold build at ok
  split at ok
  · rename_i guard
    cases found : HistoricalContext.build w.inbox w.registry (parameters w.inbox cfg) archive with
    | none => simp [found] at ok
    | some c =>
      simp only [found,Option.map_some,Option.some.injEq] at ok
      exact ⟨guard.1,guard.2.1,guard.2.2.1,guard.2.2.2.1,guard.2.2.2.2.1,guard.2.2.2.2.2.1,guard.2.2.2.2.2.2,c,rfl,ok.symm⟩
  · contradiction

/-- Every deployment-bound Rules field comes from the initialized World: stored L, genesis,
K, slot-282 immutables and commitments, the authenticated config opening and the World's
fixed adapters, with committee 0 recomputed to its authenticated opening. -/
theorem build_binds_parameters {w : ProtocolState.World} {cfg : Config} {archive : List Nat}
    {template r : BlockValidity.Rules} (ok : build w cfg archive template = some r) :
    cfg = w.inbox.configuration ∧ r.consensus.domain = w.inbox.domain ∧ r.consensus.epochLen = w.inbox.epochLen ∧
    r.consensus.genesisCutoff = w.inbox.genesisCutoff ∧
    r.consensus.unit = cfg.unit ∧ r.consensus.minimum = cfg.minimum ∧ r.consensus.nMax = cfg.nMax ∧
    r.unsettled = cfg.unsettled ∧ r.gridK = w.inbox.gridK ∧ r.committeeConfig = w.inbox.committeeConfig ∧
    r.maxAnchorAge = w.inbox.maxAnchorAge ∧ r.forcedDelay = w.inbox.forcedDelay ∧
    r.configHash = w.adapters.configHash ∧ r.committeeHash = w.adapters.recordHash ∧
    w.inbox.committeeConfig = w.adapters.configHash (words w.inbox cfg) ∧
    genesis w.inbox w.registry cfg archive = w.inbox.committeeZeroRecord ∧
    w.inbox.committeeZero = w.adapters.recordHash w.inbox.committeeZeroRecord := by
  obtain ⟨_,fixed,opened,zero,_,stored,_,c,built,rfl⟩ := build_success ok
  rw [(HistoricalContext.build_success built).2]
  exact ⟨fixed,rfl,rfl,rfl,rfl,rfl,rfl,rfl,rfl,rfl,rfl,rfl,rfl,rfl,opened,zero,stored⟩

/-- An election over no entries fails (the result must be nonempty), so an elected committee
0 implies a registry checkpoint at or before genesisCutoff. -/
private theorem elected_checkpointed {s : State} {registry : RegistryHistory.State} {cfg : Config}
    (elected : GenesisElected s registry cfg) :
    (RegistryHistory.latestSnapshot registry.history s.genesisCutoff).isSome = true := by
  cases found : RegistryHistory.latestSnapshot registry.history s.genesisCutoff with
  | some _ => rfl
  | none =>
    have empty : HistoricalContext.registryAt registry s.genesisCutoff = [] := by
      simp [HistoricalContext.registryAt,found]
    unfold GenesisElected at elected
    rw [empty] at elected
    simp [Committee.election,Committee.chosen] at elected

/-- A successful construction exposes the §10 initialization constraints, the §11 Inbox and
registry immutable bounds, that committee 0 is the valid genesis-cutoff election and that
genesisCutoff is no earlier than the first registry checkpoint (L541). -/
theorem build_initialization_constraints {w : ProtocolState.World} {cfg : Config} {archive : List Nat}
    {template r : BlockValidity.Rules} (ok : build w cfg archive template = some r) :
    1 ≤ w.inbox.gridK ∧ w.inbox.gridK ≤ 6 ∧ 3 ≤ w.inbox.epochLen ∧ w.inbox.epochLen+1 < limit48 ∧
    w.inbox.gridK ≤ cfg.unsettled ∧ cfg.unsettled ≤ 65536 ∧ cfg.unsettled % w.inbox.gridK = 0 ∧
    0 < w.inbox.forcedDelay ∧ w.inbox.forcedDelay < limit48 ∧
    1152 ≤ w.inbox.maxAnchorAge ∧ w.inbox.maxAnchorAge < limit48 ∧
    w.inbox.origins.head? = some (0,genesisOrigin w.inbox) ∧ (genesisOrigin w.inbox).height = 0 ∧
    w.inbox.genesisCutoff < (genesisOrigin w.inbox).l1Block ∧ (genesisOrigin w.inbox).l1Block < limit48 ∧
    1 ≤ cfg.nMax ∧ cfg.nMax ≤ 4096 ∧ Committee.minUnit ≤ cfg.unit ∧ cfg.unit ≤ cfg.minimum ∧
    w.inbox.gridK ≤ w.inbox.maxBatchBlocks ∧ 0 < w.inbox.forcedFee ∧ 0 < w.inbox.forcedThreshold ∧
    w.inbox.protocolFeeRecipient ≠ 0 ∧
    0 < w.registry.activationDelay ∧ 0 < w.registry.exitDelay ∧ w.registry.slashBountyBps ≤ 10000 ∧
    Committee.election cfg.unit cfg.minimum w.inbox.genesisCutoff cfg.nMax
      (HistoricalContext.registryAt w.registry w.inbox.genesisCutoff) = some w.inbox.committeeZeroRecord.members ∧
    (RegistryHistory.latestSnapshot w.registry.history w.inbox.genesisCutoff).isSome = true := by
  obtain ⟨⟨grid,delay,delayBound,age,ageBound,head,height,past,l1,n1,n2,unit,minimum,batch,fee,threshold,recipient⟩,
    _,_,_,elected,_,⟨activation,exit,bounty⟩,_⟩ := build_success ok
  have k := of_decide_eq_true grid
  exact ⟨k.1,k.2.1,k.2.2.1,k.2.2.2.1,k.2.2.2.2.1,k.2.2.2.2.2.1,k.2.2.2.2.2.2,delay,delayBound,age,ageBound,
    head,height,past,l1,n1,n2,unit,minimum,batch,fee,threshold,recipient,activation,exit,bounty,elected,
    elected_checkpointed elected⟩

/-- Two successful constructions from one World agree on every deployment-bound Rules field,
for any archives and templates: hashes, K, U, slot-282 values and the consensus schedule
are fixed; only the anchor archive lookup and template-supplied external relations vary. -/
theorem constructed_rules_fixed {w : ProtocolState.World} {a b : Config} {aa ab : List Nat}
    {ta tb ra rb : BlockValidity.Rules} (okA : build w a aa ta = some ra) (okB : build w b ab tb = some rb) :
    ra.configHash = rb.configHash ∧ ra.committeeHash = rb.committeeHash ∧ ra.committeeConfig = rb.committeeConfig ∧
    ra.gridK = rb.gridK ∧ ra.maxAnchorAge = rb.maxAnchorAge ∧ ra.forcedDelay = rb.forcedDelay ∧
    ra.unsettled = rb.unsettled ∧ ra.consensus.domain = rb.consensus.domain ∧
    ra.consensus.generation = rb.consensus.generation ∧ ra.consensus.originHeight = rb.consensus.originHeight ∧
    ra.consensus.originBlock = rb.consensus.originBlock ∧ ra.consensus.genesisCutoff = rb.consensus.genesisCutoff ∧
    ra.consensus.epochLen = rb.consensus.epochLen ∧ ra.consensus.unit = rb.consensus.unit ∧
    ra.consensus.minimum = rb.consensus.minimum ∧ ra.consensus.nMax = rb.consensus.nMax ∧
    ra.consensus.registry = rb.consensus.registry := by
  obtain ⟨_,fa,_,_,_,_,_,ca,builtA,rfl⟩ := build_success okA
  obtain ⟨_,fb,_,_,_,_,_,cb,builtB,rfl⟩ := build_success okB
  subst fa fb
  rw [(HistoricalContext.build_success builtA).2,(HistoricalContext.build_success builtB).2]
  exact ⟨rfl,rfl,rfl,rfl,rfl,rfl,rfl,rfl,rfl,rfl,rfl,rfl,rfl,rfl,rfl,rfl,rfl⟩

/-- Even a constant hash adapter cannot substitute parameters for the fixed decoded
configuration in the authenticated state: constructions on one State, with any registry,
archive, adapters or template, use one config. Cryptographic opening validation is external. -/
theorem constructed_configuration_unique {wa wb : ProtocolState.World} {a b : Config} {aa ab : List Nat}
    {ta tb outA outB : BlockValidity.Rules} (same : wa.inbox = wb.inbox)
    (okA : build wa a aa ta = some outA) (okB : build wb b ab tb = some outB) : a = b := by
  rw [(build_success okA).2.1,(build_success okB).2.1,same]

/-- Committee 0 is bound by the State: constructions on one State, with any registry history,
archive, adapters (including a constant record hash) or template, recompute the same genesis
committee, namely the authenticated committee-0 opening. -/
theorem constructed_committee_zero_unique {wa wb : ProtocolState.World} {a b : Config} {aa ab : List Nat}
    {ta tb outA outB : BlockValidity.Rules} (same : wa.inbox = wb.inbox)
    (okA : build wa a aa ta = some outA) (okB : build wb b ab tb = some outB) :
    genesis wa.inbox wa.registry a aa = genesis wb.inbox wb.registry b ab ∧
    genesis wa.inbox wa.registry a aa = wa.inbox.committeeZeroRecord := by
  have za := (build_success okA).2.2.2.1
  have zb := (build_success okB).2.2.2.1
  exact ⟨by rw [za,zb,same],za⟩

/-- The §10 constraints, once satisfied by the initialized state, hold in every reachable
state: their fields are immutable and generation 0's origin stays first in the archive. -/
theorem trace_preserves_constraints {w t : ProtocolState.World} (trace : ProtocolState.Trace w t) {cfg : Config}
    (initialized : Constraints w.inbox cfg) : Constraints t.inbox cfg := by
  obtain ⟨_,_,grid,epoch,cutoff,_,_,_,age,delay,batch,fee,threshold,recipient,_⟩ :=
    ProtocolState.trace_preserves_immutables trace
  obtain ⟨extra,origins⟩ := ProtocolState.trace_keeps_origin_archive trace
  have head : t.inbox.origins.head? = w.inbox.origins.head? := by
    rw [origins,List.head?_append,initialized.2.2.2.2.2.1]
    rfl
  have same : genesisOrigin t.inbox = genesisOrigin w.inbox := by simp only [genesisOrigin,head]
  unfold Constraints at *
  rw [same,head,grid,epoch,cutoff,age,delay,batch,fee,threshold,recipient]
  exact initialized

/-- The registry's deployment bounds hold in every reachable state: the delays and bounty
are registry immutables no landing, registry, FI, recovery or rollback step writes. -/
theorem trace_preserves_registry_constraints {w t : ProtocolState.World} (trace : ProtocolState.Trace w t)
    (initialized : RegistryConstraints w.registry) : RegistryConstraints t.registry := by
  obtain ⟨_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,_,bounty,_,activation,exit,_⟩ := ProtocolState.trace_preserves_immutables trace
  unfold RegistryConstraints at *
  rw [bounty,activation,exit]
  exact initialized

/-- Explicit idealized preimage separation, not a theorem about real keccak. Vacuous: no
adapter meets `separates`, because `natWord` keeps only the low 256 bits
(`opening_separation_unsatisfiable`). `representable_opening_unique` is the uint256
restatement. -/
theorem opening_unique (s : State) (a b : Config) (hash : List Encoding.Word → Hash)
    (separates : ∀ x y, hash (words s x) = hash (words s y) → x = y)
    (openedA : s.committeeConfig = hash (words s a)) (openedB : s.committeeConfig = hash (words s b)) : a = b :=
  separates a b (openedA.symm.trans openedB)

/-- Separation of every config is impossible: the configs with vp_unit 0 and 2^256 have the same
7-word preimage, since a uint256 word keeps only the low 256 bits. So `opening_unique`'s
`separates` premise never holds. -/
theorem opening_separation_unsatisfiable (s : State) (hash : List Encoding.Word → Hash) :
    ¬ ∀ x y, hash (words s x) = hash (words s y) → x = y := by
  intro separates
  have wrap : Encoding.natWord 0 = Encoding.natWord limit256 := by decide +kernel
  have same := separates ⟨0,0,0,0⟩ ⟨limit256,0,0,0⟩ (by simp only [words,Encoding.configWords,wrap])
  exact absurd (congrArg CommitteeConfig.unit same) (by decide)

/-- Representable configs (four uint256 fields, as Appendix A's 7-word preimage carries them)
have distinct preimages: `natWord` is injective below 2^256. So an adapter that is injective on
word lists separates them, and the premise of `representable_opening_unique` can hold. -/
theorem representable_words_injective (s : State) {a b : Config} (representableA : Statements.Representable a)
    (representableB : Statements.Representable b) (same : words s a = words s b) : a = b := by
  obtain ⟨ua,ma,na,sa⟩ := a
  obtain ⟨ub,mb,nb,sb⟩ := b
  simp only [words,Encoding.configWords,List.cons.injEq] at same
  obtain ⟨_,_,_,unit,minimum,nMax,unsettled,_⟩ := same
  obtain ⟨unitA,minimumA,nMaxA,unsettledA⟩ := representableA
  obtain ⟨unitB,minimumB,nMaxB,unsettledB⟩ := representableB
  rw [Encoding.natWord_injective ua ub unitA unitB unit,Encoding.natWord_injective ma mb minimumA minimumB minimum,
    Encoding.natWord_injective na nb nMaxA nMaxB nMax,Encoding.natWord_injective sa sb unsettledA unsettledB unsettled]

/-- Idealized preimage separation over uint256 configs, not a theorem about real keccak: if the
adapter separates the preimages of representable configs, a stored commitment has at most one
representable opening. `Statements.Premises.hashSeparation` assumes the consequence for the
deployment's commitment directly. -/
theorem representable_opening_unique (s : State) (a b : Config) (hash : List Encoding.Word → Hash)
    (separates : ∀ x y, Statements.Representable x → Statements.Representable y →
      hash (words s x) = hash (words s y) → x = y)
    (representableA : Statements.Representable a) (representableB : Statements.Representable b)
    (openedA : s.committeeConfig = hash (words s a)) (openedB : s.committeeConfig = hash (words s b)) : a = b :=
  separates a b representableA representableB (openedA.symm.trans openedB)

theorem accepted_deployed_snapshot {w : ProtocolState.World} {t : State} {i : LandInput}
    {leaves : List Leaf} {e : LandingEnv} {cfg : Config} {archive : List Nat} {template r : BlockValidity.Rules}
    {p : BlockValidity.Header} {bs : List BlockValidity.Block} {blobs : List Hash}
    (accepted : land w.inbox i leaves e = some t)
    (built : build w cfg archive template = some r)
    (valid : Settlement.BatchValid r p bs blobs)
    (binding : e.certificate = Settlement.statement r p bs blobs)
    (covered : (BlockValidity.terminal p bs).height < archive.length) :
    t.snapshot = HistoricalContext.cutoff w.inbox (parameters w.inbox cfg) archive (BlockValidity.terminal p bs).height ∧
    cfg = w.inbox.configuration ∧ r.consensus.epochLen = w.inbox.epochLen ∧ r.consensus.genesisCutoff = w.inbox.genesisCutoff ∧
    w.inbox.committeeConfig = w.adapters.configHash (words w.inbox cfg) ∧
    genesis w.inbox w.registry cfg archive = w.inbox.committeeZeroRecord ∧
    w.inbox.committeeZero = w.adapters.recordHash w.inbox.committeeZeroRecord := by
  obtain ⟨_,fixed,opened,zero,_,stored,_,c,history,result⟩ := build_success built
  have ctx : HistoricalContext.build w.inbox w.registry (parameters w.inbox cfg) archive = some r.consensus := by
    simpa only [result] using history
  have snapshot := ProtocolState.accepted_snapshot_from_history accepted valid binding ctx covered
  have fields := build_binds_parameters built
  exact ⟨snapshot.1,fixed,fields.2.2.1,fields.2.2.2.1,opened,zero,stored⟩

theorem genesis_contract (w : _root_.Etna.Design.ProtocolState.World) (hash root : _root_.Etna.Design.Hash) :
    _root_.Etna.Design.Deployment.Genesis w hash root ↔
      w.inbox.generation = 0 ∧ w.inbox.checkpoint = ⟨0,hash,0,0,0,0⟩ ∧ w.inbox.records = [w.inbox.checkpoint] ∧
      w.inbox.signals = [⟨0,hash,root⟩] ∧ w.inbox.head = 0 ∧ w.inbox.tail = 0 ∧ w.queue = [] ∧
      w.inbox.snapshot = w.inbox.genesisCutoff ∧ w.inbox.origins = [(0,w.inbox.origin)] ∧
      w.inbox.origin.l1Block ≤ w.l1Block ∧ w.inbox.entered = _root_.Bool.false ∧
      _root_.Etna.Design.FeeConserved w.inbox ∧
      _root_.Etna.Design.ProtocolState.RegistryValid w.registry w.l1Block ∧
      w.schedule = _root_.Etna.Design.Committee.recoverySchedule w.inbox.committeeZeroRecord ∧
      _root_.Etna.Design.Deployment.Constraints w.inbox w.inbox.configuration ∧
      _root_.Etna.Design.Deployment.RegistryConstraints w.registry ∧
      w.inbox.committeeConfig = w.adapters.configHash (_root_.Etna.Design.Deployment.words w.inbox w.inbox.configuration) ∧
      w.inbox.committeeZero = w.adapters.recordHash w.inbox.committeeZeroRecord ∧
      w.inbox.committeeZeroRecord.targetEpoch = 0 ∧ w.inbox.committeeZeroRecord.cutoff = w.inbox.genesisCutoff ∧
      _root_.Etna.Design.Deployment.GenesisElected w.inbox w.registry w.inbox.configuration ∧
      (_root_.Etna.Design.RegistryHistory.latestSnapshot w.registry.history w.inbox.genesisCutoff).isSome =
        _root_.Bool.true := Iff.rfl

/-- An initialized World satisfies the combined structural invariant: block 0 is the retained
grid record at c with cursor = head, the queue indices are empty, fees conserve and the
registry is valid. -/
theorem genesis_core {w : ProtocolState.World} {hash root : Hash} (init : Genesis w hash root) :
    ProtocolState.Core w := by
  obtain ⟨_,checkpoint,records,_,head,tail,queue,_,_,_,_,fees,registry,_⟩ := init
  have record : recordAt w.inbox w.inbox.checkpoint.height = some w.inbox.checkpoint := by
    simp [recordAt,records]
  refine ⟨⟨⟨record,?_,⟨?_,?_⟩,?_,?_⟩,fees,?_,?_⟩,registry,?_⟩
  · rw [checkpoint,head]
  · rw [checkpoint]; exact Nat.zero_mod _
  · intro r member
    rw [records,List.mem_singleton] at member
    rw [member,checkpoint]
    exact Nat.zero_mod _
  · simp [records]
  · intro r member
    rw [records,List.mem_singleton] at member
    rw [member]
    exact Nat.le_refl _
  · rw [head,tail]
    exact Nat.le_refl 0
  · intro r member
    rw [records,List.mem_singleton] at member
    rw [member,checkpoint,tail]
    exact Nat.le_refl 0
  · rw [queue,tail]
    rfl

/-- §10 step 5 sanity: the initialized World admits the deployment construction. For the
stored configuration, any template and any sorted archive covering block 0, `build` succeeds,
so its whole guard holds: the §10/§11 constraints, both openings, committee 0 equal to the
genesis-cutoff election with target epoch 0, and `HistoricalContext.Ready` (generation 0's
origin, a registry checkpoint at or before genesisCutoff, a nonempty election, L ≥ 3 and
genesisCutoff ≤ L1_0). -/
theorem genesis_builds {w : ProtocolState.World} {hash root : Hash} (init : Genesis w hash root)
    (archive : List Nat) (template : BlockValidity.Rules) (covered : 0 < archive.length)
    (sorted : archive.Pairwise (· ≤ ·)) : ∃ r, build w w.inbox.configuration archive template = some r := by
  obtain ⟨generation,checkpoint,_,_,_,_,_,_,origins,_,_,_,registry,_,constraints,bounds,opened,stored,
    target,cutoff,elected,checkpointed⟩ := init
  have origin : genesisOrigin w.inbox = w.inbox.origin := by simp [genesisOrigin,origins]
  have k := of_decide_eq_true constraints.1
  have past := constraints.2.2.2.2.2.2.2.1
  rw [origin] at past
  have members := Committee.election_chosen elected
  have zero : genesis w.inbox w.registry w.inbox.configuration archive = w.inbox.committeeZeroRecord := by
    show (⟨0,w.inbox.genesisCutoff,Committee.chosen w.inbox.configuration.unit w.inbox.configuration.minimum
      w.inbox.genesisCutoff w.inbox.configuration.nMax (HistoricalContext.registryAt w.registry w.inbox.genesisCutoff)⟩ :
        Committee.Record) =
      ⟨w.inbox.committeeZeroRecord.targetEpoch,w.inbox.committeeZeroRecord.cutoff,w.inbox.committeeZeroRecord.members⟩
    rw [target,cutoff,members]
  have ready : HistoricalContext.Ready w.inbox w.registry (parameters w.inbox w.inbox.configuration) archive := by
    refine ⟨?_,?_,sorted,registry.history,?_,?_,k.2.2.1,Nat.le_of_lt past⟩
    · simp [HistoricalContext.fixedOrigin,origins,generation]
    · rw [checkpoint]
      exact covered
    · simp only [generation,↓reduceIte]
      exact checkpointed
    · simp only [generation,↓reduceIte]
      show (Committee.election w.inbox.configuration.unit w.inbox.configuration.minimum w.inbox.genesisCutoff
        w.inbox.configuration.nMax (HistoricalContext.registryAt w.registry w.inbox.genesisCutoff)).isSome = true
      rw [elected]
      rfl
  unfold build
  split
  · unfold HistoricalContext.build
    rw [ite_eq_left ready]
    exact ⟨_,rfl⟩
  · rename_i unguarded
    exact absurd ⟨constraints,rfl,opened,zero,elected,stored,bounds⟩ unguarded

/-- From an initialized World every reachable state keeps the structural invariant, the §10
Inbox and registry constraints of the stored configuration, the Inbox initialization the
registry reads, and committee 0's registry snapshot at genesisCutoff (which is in the past). -/
theorem genesis_trace_invariants {w t : ProtocolState.World} {hash root : Hash} (init : Genesis w hash root)
    (trace : ProtocolState.Trace w t) :
    ProtocolState.Core t ∧ Constraints t.inbox t.inbox.configuration ∧ RegistryConstraints t.registry ∧
    Staking.inboxInitialized t.inbox = true ∧
    RegistryHistory.latestSnapshot t.registry.history t.inbox.genesisCutoff =
      RegistryHistory.latestSnapshot w.registry.history w.inbox.genesisCutoff := by
  have parts := init
  obtain ⟨_,_,_,_,_,_,_,_,origins,clock,_,_,_,_,constraints,bounds,_⟩ := parts
  have fixed := ProtocolState.trace_preserves_immutables trace
  have cutoff : w.inbox.genesisCutoff < w.l1Block := by
    have past := constraints.2.2.2.2.2.2.2.1
    have origin : genesisOrigin w.inbox = w.inbox.origin := by simp [genesisOrigin,origins]
    rw [origin] at past
    omega
  have initialized : Staking.inboxInitialized w.inbox = true := by
    simp [Staking.inboxInitialized,origins]
  refine ⟨ProtocolState.trace_preserves_core (genesis_core init) trace,?_,
    trace_preserves_registry_constraints trace bounds,
    Lifecycle.trace_keeps_inbox_initialized trace initialized,?_⟩
  · rw [fixed.2.2.2.2.2.2.1]
    exact trace_preserves_constraints trace constraints
  · rw [fixed.2.2.2.2.1]
    exact ProtocolState.trace_preserves_old_snapshot trace _ cutoff

/-- Slot 284 starts at genesisCutoff, which is the generation-0 floor of any context built on
the initialized World, so it fits that context (`Settlement.SnapshotFits`). -/
theorem genesis_snapshot_fits {w : ProtocolState.World} {hash root : Hash} {cfg : Config} {archive : List Nat}
    {template r : BlockValidity.Rules} (init : Genesis w hash root) (built : build w cfg archive template = some r) :
    Settlement.floor r.consensus = w.inbox.genesisCutoff ∧ Settlement.SnapshotFits r.consensus w.inbox := by
  obtain ⟨_,_,_,_,_,_,_,c,context,rfl⟩ := build_success built
  have floor : Settlement.floor c = w.inbox.genesisCutoff := by
    rw [(HistoricalContext.build_success context).2]
    simp [Settlement.floor,HistoricalContext.derive,parameters,init.1]
  exact ⟨floor,Or.inr (by rw [floor,init.2.2.2.2.2.2.2.1]; exact Nat.le_refl _)⟩

/-- From an initialized World, every certified landing sequence under the built generation-0
context keeps slot 284 at or above genesisCutoff and fitting the context. -/
theorem genesis_snapshot_monotone {w : ProtocolState.World} {hash root : Hash} {cfg : Config} {archive : List Nat}
    {template r : BlockValidity.Rules} {finish : State} (init : Genesis w hash root)
    (built : build w cfg archive template = some r) (trace : Settlement.CertifiedTrace r.consensus w.inbox finish) :
    w.inbox.genesisCutoff ≤ finish.snapshot ∧ Settlement.SnapshotFits r.consensus finish := by
  have start := genesis_snapshot_fits init built
  obtain ⟨_,_,_,_,_,_,_,c,context,rfl⟩ := build_success built
  have info := HistoricalContext.build_success context
  have genesis : c.genesisCutoff ≤ c.originBlock := by
    rw [info.2]
    exact info.1.2.2.2.2.2.2.2
  have anchors : ∀ x y, x ≤ y → c.anchorAt x ≤ c.anchorAt y := by
    intro x y order
    rw [info.2]
    exact HistoricalContext.derived_anchors_monotone _ _ _ _ order
  have result := Settlement.certified_trace_snapshot_monotone genesis anchors start.2 trace
  rw [← init.2.2.2.2.2.2.2.1]
  exact result

/-- Initialization stores genesisCutoff < L1_0 ≤ the World clock in slot 284. -/
theorem genesis_snapshot_below {w : ProtocolState.World} {hash root : Hash} (init : Genesis w hash root) :
    w.inbox.snapshot < w.l1Block := by
  have past := init.2.2.2.2.2.2.2.2.2.2.2.2.2.2.1.2.2.2.2.2.2.2.1
  have origin : genesisOrigin w.inbox = w.inbox.origin := by
    simp [genesisOrigin,init.2.2.2.2.2.2.2.2.1]
  rw [origin] at past
  rw [init.2.2.2.2.2.2.2.1]
  have := init.2.2.2.2.2.2.2.2.2.1
  omega

/-- Slot 284 across any recovery reached from an initialized World along a sound trace: the
`below` premise of `ProtocolState.snapshot_monotone_across_recovery` is derived, not assumed. -/
theorem genesis_snapshot_monotone_across_recovery {first w t : ProtocolState.World} {hash root : Hash}
    {a : Recovery.Request} {r : Origin} {owner externalOK : Bool} {registry : RegistryHistory.State}
    {params : HistoricalContext.Parameters} {archive : List Nat} {c : Consensus.Context} {finish : State}
    (init : Genesis first hash root) (trace : ProtocolState.SoundTrace first w) (time : w.l1Block ≤ r.l1Block)
    (ok : ProtocolState.recover w a r owner externalOK = some t)
    (built : HistoricalContext.build t.inbox registry params archive = some c)
    (certified : Settlement.CertifiedTrace c t.inbox finish) :
    w.inbox.snapshot < r.l1Block ∧ w.inbox.snapshot ≤ finish.snapshot ∧ Settlement.SnapshotFits c finish := by
  have below : w.inbox.snapshot < r.l1Block :=
    Nat.lt_of_lt_of_le (ProtocolState.sound_trace_snapshot_below trace (genesis_snapshot_below init)) time
  exact ⟨below,ProtocolState.snapshot_monotone_across_recovery ok below built certified⟩

end Etna.Design.Deployment
