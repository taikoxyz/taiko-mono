import EtnaModel.CurrentRecovery
import EtnaModel.CurrentCustody

/-! Proof interfaces of the recoverability proof (H4). Each structure is a `Prop` record that
one proof step produces and the next consumes; none is part of the claim. They live in the
model because `EtnaProofs` holds only theorems and private helpers. -/
namespace Etna.Design.Current.Protocol.Recovery

/-- What the L1 half of the recovery path (`Recovery.prepare`) hands to the landing proof. From
`w`, the recovery path `path` reached `u`: L1 advanced to block `R`, the start was written,
corrected or proven where needed, `image` and the verifier version were set, one recovery ran at
`R` (plain on the grid, otherwise structural with K = 1), and L1 advanced to `R+2`, so the
snapshots at `R` and `R+1` are closed. K, the committee configuration and the parameters are
`u`'s, after the recovery.

`p` is the batch parent: a hash-bound header of the current checkpoint whose timestamp leaves
K+1 seconds of L1 time before `R`. `keys` are the online keys of the committee elected at `R`.
`proofs` restates the content of `ProofComplete` (a statement-layer definition, which the model
cannot import) for `u`'s verifier version. The last four fields are reachable-state facts the
landing proof needs about `u`. -/
structure Prepared (env : Environment) (registry : RegistryMachine.State) (w u : World)
    (p : Header) (R : Nat) (keys : List Hash) (image : Hash) : Prop where
  path : RecoveryTrace env w u
  reachable : Trace env (empty env registry) u
  number : u.number = R+2 ∧ R+4 < limit48
  progress : w.everLanded = true → u.inbox.checkpoint.height = w.inbox.checkpoint.height
  recovered : 0 < u.inbox.generation ∧ u.inbox.origin.height = u.inbox.checkpoint.height ∧
    u.inbox.origin.l1Block = R
  closed : ∀ s ∈ u.history, R ≤ s.number → s.inbox = u.inbox ∧ s.schedule = u.schedule ∧
    s.queue = u.queue ∧ s.registryHistory = u.registry.registry.history ∧ s.start = u.start
  parent : Custody.HeaderOf u.inbox.checkpoint p ∧ HashBound env p
  parentTime : p.timestamp+u.inbox.gridK+1 ≤ env.time R ∧ env.time R+8 < limit256
  grid : ∃ start, u.start = some start ∧
    Start.onGrid start.height u.inbox.gridK u.inbox.checkpoint.height = true ∧
    u.inbox.checkpoint.height+u.inbox.gridK < limit48 ∧
    (env.core.unzenInbox ≠ 0 → p.height = start.height → env.startImplementation p.stateRoot = true)
  fence : firstFence env u = true
  stop : u.schedule.stopTime = 0
  rules : ∀ t, RulesetLive env (Rules.select u.schedule t) ∧ Rules.select u.schedule t ∈ env.imageRules image
  proofs : image ∈ u.images ∧ ∀ w' image' d, ImageCertifies env w' image' d →
    ∃ proofs : List Proof, dualOK (proofs.map fun q => (q.backend,true)) = true ∧
      ∀ q ∈ proofs, q.image = image' ∧ env.verify u.verifier q.backend image' q.bytes d = true
  committee : CommitteeLive env u R keys
  /-- `land` reads both flags (`LandingChecks.initialized`, `LandingChecks.entered`). -/
  initialized : u.initialized = true
  entered : u.inbox.entered = false
  /-- The generation's parameters are valid and its committee configuration hash is the one
  `install` wrote for them (`Blocks.Valid.config`, `.configuration`, `LandingChecks.batchSize`). -/
  params : (parametersOf u.inbox).valid = true ∧
    u.inbox.committeeConfig = env.configHash (Encoding.configWords u.inbox.domain.l2ChainId
      u.inbox.domain.registry u.inbox.configuration.unit u.inbox.configuration.minimum
      u.inbox.configuration.nMax u.inbox.configuration.unsettled)
  /-- Every queued entry has bytes that hash to it (a blanked entry's are `[]`), so a block
  producer can include or skip it. -/
  queue : ∀ i e, (i,e) ∈ u.queue → ∃ raw : Blocks.Bytes, env.txHash raw = e.txHash ∧ raw.length ≤ 8192

/-- What the segment proof (`Recovery.segment`) needs about the closed certificate world `x`
(the landing proof's `certificateWorld env u (R+1)`) to build the new generation's first K
blocks on the batch parent `p`. The generation's origin is `p` at L1 block `R`, and `x`'s
history holds a snapshot at `R` that already shows `x`'s final storage. Every block anchors to
that snapshot. -/
structure SegmentContext (env : Environment) (x : World) (p : Header) (R : Nat)
    (keys : List Hash) (image : Hash) : Prop where
  origin : x.inbox.origin.height = p.height ∧ x.inbox.origin.l1Block = R ∧ 0 < x.inbox.generation
  parent : Custody.HeaderOf x.inbox.checkpoint p ∧ HashBound env p ∧ p.cursor = x.inbox.head
  /-- The closed snapshot at `R` already shows `x`'s storage. -/
  closed : ∃ s ∈ x.history, s.number = R ∧ s.inbox = x.inbox ∧ s.schedule = x.schedule ∧
    s.queue = x.queue ∧ s.registryHistory = x.registry.registry.history ∧ s.start = x.start
  /-- One snapshot per block number, so the snapshot at `R` is the one an anchor names. -/
  numbers : x.history.map Snapshot.number = List.range (R+2)
  /-- Each snapshot carries its block's L1 time (`Journal.Invariant.snapshots`). -/
  timed : ∀ s ∈ x.history, s.timestamp = env.time s.number
  time : p.timestamp+x.inbox.gridK+1 ≤ env.time R ∧ env.time R+8 < limit256 ∧ R+2 < limit48
  params : (parametersOf x.inbox).valid = true ∧ x.inbox.committeeConfig = env.configHash
    (Encoding.configWords x.inbox.domain.l2ChainId x.inbox.domain.registry x.inbox.configuration.unit
      x.inbox.configuration.minimum x.inbox.configuration.nMax x.inbox.configuration.unsettled)
  grid : ∃ start, x.start = some start ∧ Start.onGrid start.height x.inbox.gridK p.height = true ∧
    p.height+x.inbox.gridK < limit48
  stop : x.schedule.stopTime = 0
  /-- The schedule's fields fit their 48-bit slots (`Blocks.Valid.schedule`). -/
  fits : Rules.fits x.schedule
  rules : ∀ t, RulesetLive env (Rules.select x.schedule t) ∧ Rules.select x.schedule t ∈ env.imageRules image
  committee : CommitteeLive env x R keys
  queue : x.inbox.head ≤ x.inbox.tail ∧ (∀ i, x.inbox.head ≤ i → i < x.inbox.tail → ∃ e, (i,e) ∈ x.queue) ∧
    ∀ i e, (i,e) ∈ x.queue → ∃ raw : Blocks.Bytes, env.txHash raw = e.txHash ∧ raw.length ≤ 8192

end Etna.Design.Current.Protocol.Recovery
