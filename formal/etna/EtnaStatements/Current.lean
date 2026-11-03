import EtnaModel.CurrentCoherentCustody
import EtnaModel.CurrentEconomics
import EtnaModel.CurrentQueueIntegrity

/-! Current conditional safety over a closed decoded machine. Raw deployment,
commitment and cryptographic facts remain explicit; their joint accepting realization
is checked in EtnaWitnesses.NonVacuity.Current. -/
namespace Etna.Statements.Current
open Etna.Design Etna.Design.Current Etna.Design.Current.Protocol

def CatalogueHash (env : Environment) : Prop :=
  ∀ id definition, env.catalogue id = some definition → definition.bytes.hashBytes = env.txHash

def bytes (env : Environment) (definition : Blocks.Definition) : ActualQueue.Primitives :=
  { definition.bytes with hashBytes := env.txHash }

structure Premises (env : Environment) (registry : RegistryMachine.State)
    (engine : Finality.Engine) : Prop where
  currentPrimitives : Custody.Primitives env
  currentVerifierSound : VerifierSound env (empty env registry)
  currentStandardToken : ProtocolFinality.StandardToken env
  currentSignatureAgreement : Finality.SignatureRefinement registry env.signature
  currentBountyBound : registry.config.slashBountyBps ≤ 10000
  currentCodec : ∀ w, Trace env (empty env registry) w → ProtocolFinality.CodecSound env w
  currentVoteAttribution : ∀ w, Trace env (empty env registry) w → ProtocolFinality.VoteAttribution engine env w
  currentClock : ∀ m n, m < n → env.time m < env.time n
  currentCatalogueHash : CatalogueHash env
  currentReferenceBinding : ReferenceBinding env
  currentRegistryGenesis : RegistryMachine.Genesis registry
  currentSignatureSound : Finality.SignatureSound registry env.signature
  currentSelfAllowance : env.initialToken.allowances env.token.registryAddress env.token.registryAddress = 0

/-- An accepted statement fixes its complete canonical closed reference prefix, including
actual Inbox balances and storage. This is independent of later calls after that cut. -/
def ReferenceAuthority (env : Environment) (w : World) : Prop :=
  ∀ other a, statement env other a = statement env w a →
    referencePrefix other a.input.l1ReferenceBlockNumber = referencePrefix w a.input.l1ReferenceBlockNumber

/-- All retained Etna signals share ONE retained checkpoint chain and header map.
Legacy signals are authenticated separately by the existing Unzen proof boundary. -/
def FundSafety : Prop :=
  ∀ env registry engine, Premises env registry engine → ∀ w, Trace env (empty env registry) w →
    Custody.Coherent env (empty env registry) w ∧
    (∀ signal ∈ w.legacySignals, Custody.LegacySignalSafe env signal) ∧
    (∀ a t, land env w a = some t → ∃ segment : Suffix env w a,
      Custody.Path env (empty env registry) segment.parent ∧
      Custody.Path env (empty env registry) (Blocks.terminal segment.parent segment.blocks)) ∧
    (∀ later, Trace env w later → w.everLanded = true → later.start = w.start ∧ later.everLanded = true) ∧
    ReferenceAuthority env w ∧
    ∀ cp snap, (cp,snap) ∈ w.activeSnapshots → Custody.SnapshotSource env (empty env registry) cp snap

/-- Real issued identities and paid future liabilities, not fabricated history or an
assumed future cash balance. Historical committees beyond the protected evidence window
are not asserted to retain their original principal forever. -/
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

def AccountableFinality : Prop :=
  ∀ env registry engine, Premises env registry engine → ∀ w,
    Trace env (empty env registry) w → w.initialized = true →
    EconomicAccountability env w ∧ Economics.Safety env w ∧
    Economics.HistoricalStakeFunded env w ∧ TemporalAuthority env w ∧
    (ProtocolFinality.HonestExecutions engine env w → ProtocolFinality.CurrentAgreement env w)

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
def ForcedInclusionIntegrity : Prop :=
  ∀ env registry engine, Premises env registry engine → ∀ w, Trace env (empty env registry) w →
    Journal.Invariant env w ∧ w.inbox.head ≤ w.inbox.tail ∧
    (∀ a t, land env w a = some t → LandingService env w t a) ∧
    DueService env w ∧ NoEarlySkip env w ∧
    (∀ call, (∀ a, call ≠ .land a) → (transact env w call).inbox.head ≤ w.inbox.head) ∧
    (∀ call, (∀ a, call ≠ .recover a) → Journal.PreservesExisting w (transact env w call)) ∧
    (∀ request t, recover env w request = some t →
      t.queue = w.queue.map (fun (i,e) => (i,if i ∈ request.clear then Forced.clear (emptyHash env) e else e)) ∧
      request.clear.Pairwise (· < ·) ∧ ∀ i ∈ request.clear, w.inbox.head ≤ i ∧ i < w.inbox.tail) ∧
    (∀ a t, land env w a = some t → ∃ proof ∈ a.proofs,
      ImageCertifies env w proof.image (statement env w a)) ∧
    (∀ raw paid refund t, enqueue env w raw paid refund = some t →
      QueueIntegrity.AdmissionAccounting w.inbox t.inbox raw.length paid refund) ∧
    ∀ candidate durable t, nodeImport env w candidate durable = some t →
      t.node.trusted = false ∧ t.node.signer = { w.node.signer with ready := false } ∧
      ∀ n, n ∈ t.node.importedHeaders ↔ w.inbox.origin.height ≤ n ∧ n ≤ candidate.height

def Claims : Prop := FundSafety ∧ AccountableFinality ∧ ForcedInclusionIntegrity

end Etna.Statements.Current
