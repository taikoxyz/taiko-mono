import EtnaModel.CurrentCoherentCustody
import EtnaModel.CurrentEconomics
import EtnaModel.CurrentQueueIntegrity
import EtnaModel.CurrentUnzen
import EtnaModel.CurrentGovernance
import EtnaModel.CurrentCheckpointRisk
import EtnaModel.CurrentRecovery

/-! Current conditional safety (H1–H3) and recoverability (H4) over a closed decoded machine.
Raw deployment, commitment and cryptographic facts remain explicit; their joint accepting
realization is checked in EtnaWitnesses.NonVacuity.Current, and one environment meeting H1–H3's
and H4's premises together in EtnaWitnesses.NonVacuity.CurrentRecovery. -/
namespace Etna.Statements.Current
open Etna.Design Etna.Design.Current Etna.Design.Current.Protocol

def CatalogueHash (env : Environment) : Prop :=
  ∀ id definition, env.catalogue id = some definition → definition.bytes.hashBytes = env.txHash

def bytes (env : Environment) (definition : Blocks.Definition) : ActualQueue.Primitives :=
  { definition.bytes with hashBytes := env.txHash }

/-- The five premises H1 rests on. None concerns consensus: no signature soundness, codec,
vote attribution or honesty, so H1 holds whatever the committee signs. -/
structure FundPremises (env : Environment) (registry : RegistryMachine.State) : Prop where
  currentPrimitives : Custody.Primitives env
  currentVerifierSound : VerifierSound env (empty env registry)
  currentReferenceBinding : ReferenceBinding env
  currentRegistryGenesis : RegistryMachine.Genesis registry
  currentUnzenExtension : Custody.UnzenExtension env env.unzenParent

/-- All fifteen premises: H1's five and the ten more that H2 and H3 use. -/
structure Premises (env : Environment) (registry : RegistryMachine.State)
    (engine : Finality.Engine) : Prop extends FundPremises env registry where
  currentStandardToken : ProtocolFinality.StandardToken env
  currentSignatureAgreement : Finality.SignatureRefinement registry env.signature
  currentBountyBound : registry.config.slashBountyBps < 10000
  currentCodec : ∀ w, Trace env (empty env registry) w → ProtocolFinality.CodecSound env w
  currentVoteAttribution : ∀ w, Trace env (empty env registry) w → ProtocolFinality.VoteAttribution engine env w
  currentClock : ∀ m n, m < n → env.time m < env.time n
  currentCatalogueHash : CatalogueHash env
  currentSignatureSound : Finality.SignatureSound registry env.signature
  currentSelfAllowance : env.initialToken.allowances env.token.registryAddress env.token.registryAddress = 0
  /-- PARAM-11-11 deployment policy; not an initializeInbox contract check. -/
  currentEvidenceWindow : 0 < env.evidenceWindow ∧ env.evidenceWindow ≤ registry.config.withdrawalDelay

/-- An accepted statement fixes its complete canonical closed reference prefix, including
actual Inbox balances and storage. This is independent of later calls after that cut. -/
def ReferenceAuthority (env : Environment) (w : World) : Prop :=
  ∀ other a, statement env other a = statement env w a →
    referencePrefix other a.input.l1ReferenceBlockNumber = referencePrefix w a.input.l1ReferenceBlockNumber

/-- All retained Etna signals share ONE retained checkpoint chain and header map.
Legacy signals are authenticated separately by the existing Unzen proof boundary.
The last two conjuncts are SPEC section 1's finality of checkpoints: every later run without
a rollback keeps each signal and, once something has landed, each retained record and a
checkpoint at least as high; and no rollback meets its verifier-failure duty
(`Governance.RollbackAuthorized`, RECOV-8-28), because no retained record is bad.
The record and height parts wait for a landing because START-10-5c's start correction
(`correctStart`) may lower the checkpoint, and replace the start record, before any landing.
Unzen checkpoints at or below S (`legacySignals`) are not in the retention conjunct; the model
only appends to them. -/
def FundSafetyAt (env : Environment) (registry : RegistryMachine.State) (w : World) : Prop :=
    Custody.Coherent env (empty env registry) w ∧
    (∀ signal ∈ w.legacySignals, Custody.LegacySignalSafe env signal) ∧
    (∀ a t, land env w a = some t → ∃ segment : Suffix env w a,
      Custody.Path env (empty env registry) segment.parent ∧
      Custody.Path env (empty env registry) (Blocks.terminal segment.parent segment.blocks)) ∧
    (∀ later, Trace env w later → w.everLanded = true → later.start = w.start ∧ later.everLanded = true) ∧
    ReferenceAuthority env w ∧
    (∀ cp snap, (cp,snap) ∈ w.activeSnapshots → Custody.SnapshotSource env (empty env registry) cp snap) ∧
    (∀ start, w.start = some start → ∀ caller height hash root,
      setOrigin env w caller height hash root = none) ∧
    (env.core.unzenInbox ≠ 0 → Custody.LegacyEtnaDisjoint w ∧ Custody.SwitchingFence env w) ∧
    (∀ later, CheckpointRisk.RollbackFreeRun env w later →
      (∀ s ∈ w.inbox.signals, s ∈ later.inbox.signals) ∧
      (w.everLanded = true → w.inbox.checkpoint.height ≤ later.inbox.checkpoint.height ∧
        ∀ cp ∈ w.activeRecords, cp ∈ later.activeRecords)) ∧
    (∀ trusted snapshot, ¬ Governance.RollbackAuthorized env (empty env registry) w trusted snapshot)

/-- H1 needs only `FundPremises`, not the full `Premises` record. -/
def FundSafety : Prop :=
  ∀ env registry, FundPremises env registry → ∀ w, Trace env (empty env registry) w →
    FundSafetyAt env registry w

/-- General historical identity/liability result. This alone does not assert that a
selected bond remains live. NormalAccountability separately derives that fact for actual
rollback-free execution and node-authenticated candidates above the checkpoint. -/
def EconomicAccountability (env : Environment) (w : World) : Prop :=
  ∀ common moreA moreB referenceA referenceB h round a b votesA votesB,
    Finality.requiredPrefix (config w) h ≤ common.length →
    Consensus.CommitValid (policy env w (common ++ moreA) referenceA).consensus env.signature h round a votesA →
    Consensus.CommitValid (policy env w (common ++ moreB) referenceB).consensus env.signature h round b votesB →
    a ≠ b → Economics.EconomicallyAccountable env w
      (policy env w (common ++ moreA) referenceA).consensus h votesA votesB

/-- Actual later execution in the same started generation preserves committees once
their entire selection block has closed. No derived-context equality is supplied. -/
def TemporalAuthority (env : Environment) (w : World) : Prop :=
  ∀ later, Trace env w later → w.start.isSome = true → later.inbox.generation = w.inbox.generation →
    ∀ common moreA moreB h, Finality.requiredPrefix (config w) h ≤ common.length →
      Finality.cutoff (config w) common h < w.number →
      Consensus.activeAt (Finality.derive (config w) w.registry.registry (common ++ moreA)) h =
        Consensus.activeAt (Finality.derive (config later) later.registry.registry (common ++ moreB)) h

/-- At heights above the actual checkpoint, ordinary actual execution and a node's
authenticated checkpoint/ancestry fence derive the live, unconfirmed overlap. Neither
that economic conclusion nor snapshot order/cutoff bounds are supplied here. Exceptional
verifier-failure rollback is excluded explicitly; its paid withdrawals are irreversible. -/
def NormalAccountability (env : Environment) (registry : RegistryMachine.State) (w : World) : Prop :=
  ∀ _run : CheckpointRisk.RollbackFreeRun env (empty env registry) w,
    w.start.isSome = true → ∀ h, w.inbox.checkpoint.height < h →
    ∀ candidate : CheckpointRisk.Candidate env w h,
    ∀ common moreA moreB referenceA referenceB round a b votesA votesB,
      candidate.headers = common ++ moreA →
      Finality.requiredPrefix (config w) h ≤ common.length →
      Consensus.CommitValid (policy env w (common ++ moreA) referenceA).consensus env.signature h round a votesA →
      Consensus.CommitValid (policy env w (common ++ moreB) referenceB).consensus env.signature h round b votesB →
      a ≠ b → StakeRisk.AccountableAtRisk env w
        (policy env w (common ++ moreA) referenceA).consensus h votesA votesB

/-- All members of an authenticated, valid committee above the checkpoint retain
unconfirmed bonds in a deployment with no rollback since its fresh genesis. This
is independent of an overlap and of a particular consensus round. -/
def NormalCommitteeRetention (env : Environment) (registry : RegistryMachine.State) (w : World) : Prop :=
  ∀ _run : CheckpointRisk.RollbackFreeRun env (empty env registry) w,
    w.start.isSome = true → ∀ h, w.inbox.checkpoint.height < h →
    ∀ candidate : CheckpointRisk.Candidate env w h,
    Consensus.ElectionValid (policy env w candidate.headers candidate.reference).consensus
      (Consensus.activeAt (policy env w candidate.headers candidate.reference).consensus h) →
    ∀ entry ∈ (Consensus.activeAt (policy env w candidate.headers candidate.reference).consensus h).members,
      ∃ id, StakeRisk.Retained w.registry.registry
        (Finality.cutoff (config w) candidate.headers h) id entry.key

def AccountableFinalityAt (env : Environment) (registry : RegistryMachine.State) (engine : Finality.Engine) (w : World) : Prop :=
  EconomicAccountability env w ∧ Economics.Safety env w ∧
  Economics.HistoricalStakeFunded env w ∧ TemporalAuthority env w ∧
  (ProtocolFinality.HonestExecutions engine env w → ProtocolFinality.CurrentAgreement env w) ∧
  NormalAccountability env registry w ∧ NormalCommitteeRetention env registry w

def AccountableFinality : Prop :=
  ∀ env registry engine, Premises env registry engine → ∀ w,
    Trace env (empty env registry) w → w.initialized = true → AccountableFinalityAt env registry engine w

def LandingService (env : Environment) (w t : World) (a : Landing) : Prop :=
  ∃ segment : Suffix env w a,
    (Blocks.consumingPairs segment.parent segment.blocks).map (fun x => x.1.cursor) =
      List.range' w.inbox.head (t.inbox.head-w.inbox.head) ∧
    (∀ x ∈ Blocks.consumingPairs segment.parent segment.blocks,
      ∃ entry, (x.1.cursor,entry) ∈ w.queue ∧ x.2.first = x.2.transactions.head? ∧
        Blocks.TimelyByteAction (bytes env (Blocks.definition
          (policy env w segment.archive a.input.l1ReferenceBlockNumber) x.2))
          w.inbox.forcedDelay x.1 x.2.body entry x.2.raw x.2.first) ∧ t.queue = w.queue

def DueService (env : Environment) (w : World) : Prop :=
  ∀ archive reference parent block entry,
    Blocks.Valid (policy env w archive reference) parent block → (parent.cursor,entry) ∈ w.queue →
    (entry.timestamp+w.inbox.forcedDelay ≤ block.header.anchor.timestamp ∨
      entry.timestamp+w.inbox.forcedDelay+w.inbox.maxAnchorAge ≤ block.header.timestamp) →
    block.header.cursor = parent.cursor+1 ∧
      ActualQueue.ByteAction (bytes env (Blocks.definition (policy env w archive reference) block))
        parent block.body entry block.raw block.first

def NoEarlySkip (env : Environment) (w : World) : Prop :=
  ∀ archive reference parent block entry,
    Blocks.Valid (policy env w archive reference) parent block →
    block.header.cursor = parent.cursor+1 → (parent.cursor,entry) ∈ w.queue →
    block.header.anchor.timestamp < entry.timestamp+w.inbox.forcedDelay →
    Blocks.Included (bytes env (Blocks.definition (policy env w archive reference) block))
      entry block.transactions.head?

/-- Includes exact payment/refund and pending-index guards. Parser/EL results remain
relative to the explicitly fixed complete-payload interpreter. Rollback may rewind head. -/
def ForcedInclusionAt (env : Environment) (w : World) : Prop :=
    Journal.Invariant env w ∧ w.inbox.head ≤ w.inbox.tail ∧
    (∀ a t, land env w a = some t → LandingService env w t a) ∧
    DueService env w ∧ NoEarlySkip env w ∧
    (∀ call, (∀ a, call ≠ .land a) → (transact env w call).inbox.head ≤ w.inbox.head) ∧
    (∀ call, (∀ a, call ≠ .recover a) → Journal.PreservesExisting w (transact env w call)) ∧
    (∀ request t, recover env w request = some t →
      t.inbox.head = w.inbox.head ∧ t.queue = w.queue.map (fun (i,e) => (i,if i ∈ request.clear then Forced.clear (emptyHash env) e else e)) ∧
      request.clear.Pairwise (· < ·) ∧ ∀ i ∈ request.clear, w.inbox.head ≤ i ∧ i < w.inbox.tail) ∧
    (∀ a t, land env w a = some t → ∃ proof ∈ a.proofs,
      ImageCertifies env w proof.image (statement env w a)) ∧
    (∀ raw paid refund t, enqueue env w raw paid refund = some t →
      QueueIntegrity.AdmissionAccounting w.inbox t.inbox raw.length paid refund) ∧
    ∀ candidate durable t, nodeImport env w candidate durable = some t →
      t.node.trusted = false ∧ t.node.signer = { w.node.signer with ready := false } ∧
      ∀ n, n ∈ t.node.importedHeaders ↔ w.inbox.origin.height ≤ n ∧
        candidate.height+1 ≤ n+w.inbox.configuration.unsettled ∧ n ≤ candidate.height

def ForcedInclusionIntegrity : Prop :=
  ∀ env registry engine, Premises env registry engine → ∀ w, Trace env (empty env registry) w →
    ForcedInclusionAt env w

/-- MODEL-1-1/1-2: one verifier version proves every batch an image certifies, with two
proofs of that image, at least one ZK. -/
def ProofComplete (env : Environment) : Prop :=
  ∃ version, ∀ w image d, ImageCertifies env w image d →
    ∃ proofs : List Proof, dualOK (proofs.map fun p => (p.backend,true)) = true ∧
      ∀ p ∈ proofs, p.image = image ∧ env.verify version p.backend image p.bytes d = true

/-- DA (5.2, 6.3): up to six blocks within the 3.4 size bound fit in one to six blobs. -/
def PayloadLive (env : Environment) : Prop :=
  ∀ bs : List Blocks.Block, bs.length ≤ 6 → (∀ b ∈ bs, b.body.blockBytes ≤ 124000) →
    ∃ blobs : List Hash, 1 ≤ blobs.length ∧ blobs.length ≤ 6 ∧ env.payload blobs bs = true

/-- LIMIT-12-9, START-10-5: every header a valid proof of the Unzen Inbox's final proposal
authenticates is a usable Etna start. -/
def UnzenStartUsable (env : Environment) : Prop :=
  env.core.unzenInbox ≠ 0 → ∀ h proof, env.unzenValid (env.unzenNextProposal-1) h proof = true →
    0 < h.height ∧ h.height+6 < limit48 ∧ h.elHash ≠ 0 ∧ h.stateRoot ≠ 0 ∧
    env.startImplementation h.stateRoot = true ∧ ∀ s, Custody.StartsAt s h → HashBound env s

/-- LIMIT-12-9: the Unzen lane has finalized its last proposal, or can from where it is. -/
def UnzenLaneLive (env : Environment) (w : World) : Prop :=
  env.core.unzenInbox ≠ 0 →
    (w.unzen.checkpointExists = true ∧ w.unzen.nextProposal = w.unzen.finalizedProposal+1) ∨
    ∃ h proof, env.unzenValid (w.unzen.nextProposal-1) h proof = true ∧
      w.unzen.finalizedProposal < w.unzen.nextProposal-1 ∧
      env.unzenParent w.unzen.finalizedProposal (w.unzen.nextProposal-1) h proof = w.unzen.finalizedHash

/-- 6.1, BATCH-6.3-1: once a start S is written, the checkpoint c is on the current grid, so
c − S is a multiple of K. -/
def OnGrid (w : World) : Prop :=
  ∀ start, w.start = some start → Start.onGrid start.height w.inbox.gridK w.inbox.checkpoint.height = true

/-- START-10.1, LIMIT-12-21, RECOV-8.3-3a: a recovery from `w` can leave live rulesets.
First case: c is on the grid, and the current rulesets are live with one image for both. A plain
recovery keeps them and K, and RECOV-8.3-3a needs c on the grid of the K it keeps. Second case:
ruleset nextRules + 1 is live with an image, and c may be off the grid. This case plays two
roles. On the grid it is a rules replacement that keeps K (LIMIT-12-21). Off the grid only a
structural recovery that installs a K whose grid holds c gets out, and a K change must be part
of the definition that the new `rules` names (START-10.1-3b, START-10.1-14e; vector 14e.g
rejects `rules` = 0), so that recovery needs this case. There it reads: ruleset nextRules + 1
is published as the current rules with K = 1, and an image implements it. Rulesets carry no K
in the model (`Blocks.Definition`, `RulesetLive`, `imageRules`), so the model does not check
that the definition includes K. -/
def LiveRules (env : Environment) (w : World) : Prop :=
  (OnGrid w ∧ RulesetLive env w.schedule.active ∧ RulesetLive env w.schedule.next ∧
    ∃ image, w.schedule.active ∈ env.imageRules image ∧ w.schedule.next ∈ env.imageRules image) ∨
  (RulesetLive env (w.schedule.next+1) ∧ ∃ image, w.schedule.next+1 ∈ env.imageRules image)

/-- The premises H4 adds to H1's. -/
structure RecoveryPremises (env : Environment) (registry : RegistryMachine.State) : Prop
    extends FundPremises env registry where
  recoveryClock : ∀ m n, m < n → env.time m < env.time n
  recoveryCatalogueHash : CatalogueHash env
  proofComplete : ProofComplete env
  payloadLive : PayloadLive env
  unzenStart : UnzenStartUsable env

/-- Per-state conditions of H4 (reports/recoverability.md, Per-state hypotheses). -/
structure LiveAt (env : Environment) (w : World) : Prop where
  generation : w.inbox.generation+2 < limit48
  nonce : w.inbox.recoveryNonce+1 < limit256
  rules : w.schedule.next+1 < limit48
  height : w.inbox.checkpoint.height+w.inbox.gridK < limit48
  window : ∃ n keys, w.number < n ∧ n+4 < limit48 ∧ WindowBound env w ≤ env.time n ∧
    env.time n+8 < limit256 ∧ CommitteeLive env w n keys
  /-- An off-grid c meets only its second case. -/
  ruleset : LiveRules env w
  unzen : UnzenLaneLive env w

def RecoverableAt (env : Environment) (w : World) : Prop :=
  ∃ u a t, RecoveryTrace env w u ∧ land env u a = some t ∧
    (w.everLanded = true → w.inbox.checkpoint.height < t.inbox.checkpoint.height)

def Recoverability : Prop :=
  ∀ env registry, RecoveryPremises env registry → ∀ w,
    Trace env (empty env registry) w → w.initialized = true → LiveAt env w →
    RecoverableAt env w

/-- The four headline claims: H1 fund safety, H2 accountable finality, H3 forced-inclusion
integrity and H4 recoverability. -/
def Claims : Prop := FundSafety ∧ AccountableFinality ∧ ForcedInclusionIntegrity ∧ Recoverability

end Etna.Statements.Current
