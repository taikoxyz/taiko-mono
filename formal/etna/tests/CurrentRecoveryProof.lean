import EtnaProofs.CurrentRecoveryPath
import EtnaProofs.CurrentRecoverySegment
import EtnaProofs.CurrentRecoveryLanding

/-! H4's proof interfaces: `Recovery.prepare`'s type and the names and types of its handoff
record `Recovery.Prepared` (the L1 half of the path), then `Recovery.segment`'s type and the names
and types of its input record `Recovery.SegmentContext` (the K-block segment), and H4's proof
`Recovery.recoverable` (certificate and landing). Kept apart from
tests/CurrentRecovery.lean so the H4 statement pins never depend on a proof build. -/
namespace Etna.CurrentRecoveryProofRegression
open Etna.Design Etna.Design.Current Etna.Design.Current.Protocol Etna.Statements.Current

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

-- H4 itself: the certificate and the landing close the path (`Recovery.recoverable`).
example : Recoverability := Etna.Design.Current.Protocol.Recovery.recoverable

-- H4 needs no grid condition. With ruleset nextRules + 1 live and implemented (`LiveRules`'
-- second case), `LiveAt` holds wherever c is, and `Recovery.recoverable` gives an accepted
-- landing. Under these premises only a rollback that no authorized history runs leaves c off the
-- grid; the rollback grid trap's environment meets no premise record, so this does not apply there.
example {env : Environment} {registry : RegistryMachine.State} {w : World}
    (premises : RecoveryPremises env registry) (trace : Trace env (empty env registry) w)
    (initialized : w.initialized = true) (generation : w.inbox.generation+2 < limit48)
    (nonce : w.inbox.recoveryNonce+1 < limit256) (rules : w.schedule.next+1 < limit48)
    (height : w.inbox.checkpoint.height+w.inbox.gridK < limit48)
    (window : ∃ n keys, w.number < n ∧ n+4 < limit48 ∧ WindowBound env w ≤ env.time n ∧
      env.time n+8 < limit256 ∧ CommitteeLive env w n keys)
    (fresh : RulesetLive env (w.schedule.next+1)) (image : Hash)
    (implemented : w.schedule.next+1 ∈ env.imageRules image) (unzen : UnzenLaneLive env w) :
    RecoverableAt env w :=
  Etna.Design.Current.Protocol.Recovery.recoverable env registry premises w trace initialized
    ⟨generation,nonce,rules,height,window,.inr ⟨fresh,image,implemented⟩,unzen⟩

end Etna.CurrentRecoveryProofRegression
