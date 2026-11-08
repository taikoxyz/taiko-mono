import EtnaStatements
import EtnaProofs.CurrentRecoveryPath
import EtnaProofs.CurrentRecoverySegment

/-! H4 statement surface, pinned before the review-surface lock covers it: which calls
`RecoveryCall` admits (no rollback, only plain recoveries, every other call), the trace class
`RecoveryTrace`, the conclusion `RecoverableAt`, the claim `Recoverability`, and the field
names, types and order of `LiveAt` and `RecoveryPremises`. Then the L1 half of the path:
`Recovery.prepare`'s type and the names and types of its handoff record `Recovery.Prepared`. Then
the K-block segment: `Recovery.segment`'s type and the names and types of its input record
`Recovery.SegmentContext`. -/
namespace Etna.CurrentRecoveryRegression
open Etna.Design Etna.Design.Current Etna.Design.Current.Protocol Etna.Statements.Current

-- RecoveryCall: rollback and recoveries with exclusions, clears or an upgrade are out;
-- a plain recovery and the catch-all arm are in.
example (caller : Nat) (trusted : Checkpoint) (snapshot : Nat) :
    ¬ RecoveryCall (.rollback caller trusted snapshot) := id
example (r : RecoveryRequest) (x : Nat × Hash) :
    ¬ RecoveryCall (.recover { r with exclusions := [x] }) := fun h => nomatch h.1
example (r : RecoveryRequest) (i : Nat) :
    ¬ RecoveryCall (.recover { r with clear := [i] }) := fun h => nomatch h.2.1
example (r : RecoveryRequest) (p : Current.Protocol.Parameters) :
    ¬ RecoveryCall (.recover { r with upgrade := some p }) := fun h => nomatch h.2.2
example (r : RecoveryRequest) (h1 : r.exclusions = []) (h2 : r.clear = []) (h3 : r.upgrade = none) :
    RecoveryCall (.recover r) := ⟨h1,h2,h3⟩
example (a : Landing) : RecoveryCall (.land a) := trivial
example (n : Nat) : NoRollback (.advance n) := trivial

-- Pin the trace class and the conclusion.
example (env : Environment) : RecoveryTrace env = CallTrace env RecoveryCall := rfl
example (env : Environment) (w : World) :
    RecoverableAt env w = ∃ u a t, RecoveryTrace env w u ∧ land env u a = some t ∧
      (w.everLanded = true → w.inbox.checkpoint.height < t.inbox.checkpoint.height) := rfl
example : Recoverability = ∀ env registry, RecoveryPremises env registry → ∀ w,
    Trace env (empty env registry) w → w.initialized = true → LiveAt env w →
    RecoverableAt env w := rfl

-- Pin LiveAt's exact fields: types and order, then names.
example (env : Environment) (w : World)
    (a : ∀ start, w.start = some start →
      Start.onGrid start.height w.inbox.gridK w.inbox.checkpoint.height = true)
    (b : w.inbox.generation+2 < limit48) (c : w.inbox.recoveryNonce+1 < limit256)
    (d : w.schedule.next+1 < limit48) (e : w.inbox.checkpoint.height+w.inbox.gridK < limit48)
    (f : ∃ n keys, w.number < n ∧ n+4 < limit48 ∧ WindowBound env w ≤ env.time n ∧
      env.time n+8 < limit256 ∧ CommitteeLive env w n keys)
    (g : LiveRules env w) (h : UnzenLaneLive env w) :
    LiveAt env w := ⟨a,b,c,d,e,f,g,h⟩
example (env : Environment) (w : World)
    (a : ∀ start, w.start = some start →
      Start.onGrid start.height w.inbox.gridK w.inbox.checkpoint.height = true)
    (b : w.inbox.generation+2 < limit48) (c : w.inbox.recoveryNonce+1 < limit256)
    (d : w.schedule.next+1 < limit48) (e : w.inbox.checkpoint.height+w.inbox.gridK < limit48)
    (f : ∃ n keys, w.number < n ∧ n+4 < limit48 ∧ WindowBound env w ≤ env.time n ∧
      env.time n+8 < limit256 ∧ CommitteeLive env w n keys)
    (g : LiveRules env w) (h : UnzenLaneLive env w) : LiveAt env w :=
  { grid := a, generation := b, nonce := c, rules := d, height := e, window := f,
    ruleset := g, unzen := h }

-- Pin RecoveryPremises: it extends FundPremises with exactly these five fields.
example (env : Environment) (registry : RegistryMachine.State) (f : FundPremises env registry)
    (a : ∀ m n, m < n → env.time m < env.time n) (b : CatalogueHash env)
    (c : ProofComplete env) (d : PayloadLive env) (e : UnzenStartUsable env) :
    RecoveryPremises env registry := ⟨f,a,b,c,d,e⟩
example (env : Environment) (registry : RegistryMachine.State) (f : FundPremises env registry)
    (a : ∀ m n, m < n → env.time m < env.time n) (b : CatalogueHash env)
    (c : ProofComplete env) (d : PayloadLive env) (e : UnzenStartUsable env) :
    RecoveryPremises env registry :=
  { toFundPremises := f, recoveryClock := a, recoveryCatalogueHash := b, proofComplete := c,
    payloadLive := d, unzenStart := e }

-- The L1 half of the path (`Recovery.prepare`) and its handoff record.
example : ∀ {env : Environment} {registry : RegistryMachine.State} {w : World},
    RecoveryPremises env registry → Trace env (empty env registry) w → w.initialized = true →
    LiveAt env w → ∃ u p R keys image, Recovery.Prepared env registry w u p R keys image :=
  @Etna.Design.Current.Protocol.Recovery.prepare

-- Pin `Prepared`'s exact fields (the landing proof reads them by name): types, then names.
example (env : Environment) (registry : RegistryMachine.State) (w u : World) (p : Header) (R : Nat)
    (keys : List Hash) (image : Hash)
    (path : RecoveryTrace env w u) (reachable : Trace env (empty env registry) u)
    (number : u.number = R+2 ∧ R+4 < limit48)
    (progress : w.everLanded = true → u.inbox.checkpoint.height = w.inbox.checkpoint.height)
    (recovered : 0 < u.inbox.generation ∧ u.inbox.origin.height = u.inbox.checkpoint.height ∧
      u.inbox.origin.l1Block = R)
    (closed : ∀ s ∈ u.history, R ≤ s.number → s.inbox = u.inbox ∧ s.schedule = u.schedule ∧
      s.queue = u.queue ∧ s.registryHistory = u.registry.registry.history ∧ s.start = u.start)
    (parent : Custody.HeaderOf u.inbox.checkpoint p ∧ HashBound env p)
    (parentTime : p.timestamp+u.inbox.gridK+1 ≤ env.time R ∧ env.time R+8 < limit256)
    (grid : ∃ start, u.start = some start ∧
      Start.onGrid start.height u.inbox.gridK u.inbox.checkpoint.height = true ∧
      u.inbox.checkpoint.height+u.inbox.gridK < limit48 ∧
      (env.core.unzenInbox ≠ 0 → p.height = start.height → env.startImplementation p.stateRoot = true))
    (fence : firstFence env u = true) (stop : u.schedule.stopTime = 0)
    (rules : ∀ t, RulesetLive env (Rules.select u.schedule t) ∧ Rules.select u.schedule t ∈ env.imageRules image)
    (proofs : image ∈ u.images ∧ ∀ w' image' d, ImageCertifies env w' image' d →
      ∃ proofs : List Proof, dualOK (proofs.map fun q => (q.backend,true)) = true ∧
        ∀ q ∈ proofs, q.image = image' ∧ env.verify u.verifier q.backend image' q.bytes d = true)
    (committee : CommitteeLive env u R keys) (initialized : u.initialized = true)
    (entered : u.inbox.entered = false)
    (params : (parametersOf u.inbox).valid = true ∧
      u.inbox.committeeConfig = env.configHash (Encoding.configWords u.inbox.domain.l2ChainId
        u.inbox.domain.registry u.inbox.configuration.unit u.inbox.configuration.minimum
        u.inbox.configuration.nMax u.inbox.configuration.unsettled))
    (queue : ∀ i e, (i,e) ∈ u.queue → ∃ raw : Blocks.Bytes, env.txHash raw = e.txHash ∧ raw.length ≤ 8192) :
    Recovery.Prepared env registry w u p R keys image :=
  { path := path, reachable := reachable, number := number, progress := progress, recovered := recovered,
    closed := closed, parent := parent, parentTime := parentTime, grid := grid, fence := fence, stop := stop,
    rules := rules, proofs := proofs, committee := committee, initialized := initialized, entered := entered,
    params := params, queue := queue }
example (env : Environment) (registry : RegistryMachine.State) (w u : World) (p : Header) (R : Nat)
    (keys : List Hash) (image : Hash) (x : Recovery.Prepared env registry w u p R keys image) :
    Recovery.Prepared env registry w u p R keys image :=
  ⟨x.path,x.reachable,x.number,x.progress,x.recovered,x.closed,x.parent,x.parentTime,x.grid,x.fence,x.stop,
    x.rules,x.proofs,x.committee,x.initialized,x.entered,x.params,x.queue⟩

-- The K-block segment after recovery (`Recovery.segment`) over the closed certificate world.
-- Pin `SegmentContext`'s exact fields (the landing proof builds it field by field): types, then names.
example (env : Environment) (x : World) (p : Header) (R : Nat) (keys : List Hash) (image : Hash)
    (origin : x.inbox.origin.height = p.height ∧ x.inbox.origin.l1Block = R ∧ 0 < x.inbox.generation)
    (parent : Custody.HeaderOf x.inbox.checkpoint p ∧ HashBound env p ∧ p.cursor = x.inbox.head)
    (closed : ∃ s ∈ x.history, s.number = R ∧ s.inbox = x.inbox ∧ s.schedule = x.schedule ∧
      s.queue = x.queue ∧ s.registryHistory = x.registry.registry.history ∧ s.start = x.start)
    (numbers : x.history.map Snapshot.number = List.range (R+2))
    (timed : ∀ s ∈ x.history, s.timestamp = env.time s.number)
    (time : p.timestamp+x.inbox.gridK+1 ≤ env.time R ∧ env.time R+8 < limit256 ∧ R+2 < limit48)
    (params : (parametersOf x.inbox).valid = true ∧ x.inbox.committeeConfig = env.configHash
      (Encoding.configWords x.inbox.domain.l2ChainId x.inbox.domain.registry x.inbox.configuration.unit
        x.inbox.configuration.minimum x.inbox.configuration.nMax x.inbox.configuration.unsettled))
    (grid : ∃ start, x.start = some start ∧ Start.onGrid start.height x.inbox.gridK p.height = true ∧
      p.height+x.inbox.gridK < limit48)
    (stop : x.schedule.stopTime = 0) (fits : Rules.fits x.schedule)
    (rules : ∀ t, RulesetLive env (Rules.select x.schedule t) ∧ Rules.select x.schedule t ∈ env.imageRules image)
    (committee : CommitteeLive env x R keys)
    (queue : x.inbox.head ≤ x.inbox.tail ∧ (∀ i, x.inbox.head ≤ i → i < x.inbox.tail → ∃ e, (i,e) ∈ x.queue) ∧
      ∀ i e, (i,e) ∈ x.queue → ∃ raw : Blocks.Bytes, env.txHash raw = e.txHash ∧ raw.length ≤ 8192) :
    Recovery.SegmentContext env x p R keys image :=
  { origin := origin, parent := parent, closed := closed, numbers := numbers, timed := timed, time := time,
    params := params, grid := grid, stop := stop, fits := fits, rules := rules, committee := committee,
    queue := queue }
example (env : Environment) (x : World) (p : Header) (R : Nat) (keys : List Hash) (image : Hash)
    (c : Recovery.SegmentContext env x p R keys image) : Recovery.SegmentContext env x p R keys image :=
  ⟨c.origin,c.parent,c.closed,c.numbers,c.timed,c.time,c.params,c.grid,c.stop,c.fits,c.rules,c.committee,c.queue⟩

-- `Recovery.segment`'s type.
example : ∀ {env : Environment} {x : World} {p : Header} {R : Nat} {keys : List Hash} {image : Hash},
    (∀ id d, env.catalogue id = some d → d.bytes.hashBytes = env.txHash) →
    Recovery.SegmentContext env x p R keys image →
    ∃ bs : List Block, bs.length = x.inbox.gridK ∧
      Blocks.Chain (policy env x (bs.map Blocks.Block.header) (R+1)) p bs ∧
      (Blocks.terminal p bs).height = p.height+x.inbox.gridK ∧
      x.inbox.head ≤ (Blocks.terminal p bs).cursor ∧ (Blocks.terminal p bs).cursor ≤ x.inbox.tail ∧
      (Blocks.terminal p bs).cursor-x.inbox.head ≤ x.inbox.gridK ∧
      Archive.Linked env.headerParent p (bs.map Blocks.Block.header) ∧
      ∀ b ∈ bs, HashBound env b.header ∧ env.headerParent b.header.elHash = b.body.parentHash ∧
        b.body.blockBytes ≤ 124000 ∧ b.header.anchor.number = R ∧
        Blocks.selectedRules b ∈ env.imageRules image :=
  @Etna.Design.Current.Protocol.Recovery.segment

end Etna.CurrentRecoveryRegression
