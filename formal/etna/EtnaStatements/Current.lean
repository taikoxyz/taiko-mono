import EtnaModel.CurrentCustody
import EtnaModel.CurrentProtocolFinality
import EtnaModel.CurrentJournal

/-! Current H1–H3 over one closed, decoded transaction machine. Primitive trust and
interpreter refinement are explicit; no field assumes custody, agreement or queue service. -/
namespace Etna.Statements.Current
open Etna.Design Etna.Design.Current Etna.Design.Current.Protocol

/-- The fixed transaction hash has the same meaning in every installed interpreter. -/
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

/-- Every recognized Etna signal, and each actual accepted landing edge, has a full-header
path rooted in accepted genesis initialization or the authenticated Unzen first fence.
Refused or corrected archival starts are deliberately not asserted to be certified. -/
def FundSafety : Prop :=
  ∀ env registry engine, Premises env registry engine → ∀ w, Trace env (empty env registry) w →
    (∀ signal ∈ w.inbox.signals, Custody.SignalSafe env (empty env registry) signal) ∧
    ∀ a t, land env w a = some t → ∃ segment : Suffix env w a,
      Custody.Path env (empty env registry) segment.parent ∧
      Custody.Path env (empty env registry) (Blocks.terminal segment.parent segment.blocks)

/-- Same-round >1/3 accountable power with executable future paid slashes, together with
complete cross-round chain agreement from each chain's own committee lookback archive. -/
def AccountableFinality : Prop :=
  ∀ env registry engine, Premises env registry engine → ∀ w,
    Trace env (empty env registry) w → w.initialized = true →
    ProtocolFinality.CurrentAccountability env w ∧
      (ProtocolFinality.HonestExecutions engine env w → ProtocolFinality.CurrentAgreement env w)

def LandingService (env : Environment) (w t : World) (a : Landing) : Prop :=
  ∃ segment : Suffix env w a,
    (Blocks.consumingPairs segment.parent segment.blocks).map (fun x => x.1.cursor) =
      List.range' w.inbox.head (t.inbox.head-w.inbox.head) ∧
    (∀ x ∈ Blocks.consumingPairs segment.parent segment.blocks,
      ∃ entry, (x.1.cursor,entry) ∈ w.queue ∧
        ActualQueue.ByteAction (bytes env (Blocks.definition
          (policy env w segment.archive a.input.l1ReferenceBlockNumber) x.2))
          x.1 x.2.body entry x.2.raw x.2.first) ∧ t.queue = w.queue

def DueService (env : Environment) (w : World) : Prop :=
  ∀ archive reference parent block entry,
    Blocks.Valid (policy env w archive reference) parent block →
    (parent.cursor,entry) ∈ w.queue →
    (entry.timestamp+w.inbox.forcedDelay ≤ block.header.anchor.timestamp ∨
      entry.timestamp+w.inbox.forcedDelay+w.inbox.maxAnchorAge ≤ block.header.timestamp) →
    block.header.cursor = parent.cursor+1 ∧
      ActualQueue.ByteAction (bytes env (Blocks.definition (policy env w archive reference) block))
        parent block.body entry block.raw block.first

/-- Actual FIFO bytes and inclusive deadlines, with complete end-block journal coverage.
Only an accepted landing advances head; recovery changes precisely its listed hashes. -/
def ForcedInclusionIntegrity : Prop :=
  ∀ env registry engine, Premises env registry engine → ∀ w, Trace env (empty env registry) w →
    Journal.Invariant env w ∧
    (∀ a t, land env w a = some t → LandingService env w t a) ∧
    DueService env w ∧
    (∀ call, (∀ a, call ≠ .land a) → (transact env w call).inbox.head ≤ w.inbox.head) ∧
    (∀ call, (∀ a, call ≠ .recover a) → Journal.PreservesExisting w (transact env w call)) ∧
    ∀ request t, recover env w request = some t →
      t.queue = w.queue.map (fun (i,e) =>
        (i,if i ∈ request.clear then Forced.clear (emptyHash env) e else e))

def Claims : Prop := FundSafety ∧ AccountableFinality ∧ ForcedInclusionIntegrity

end Etna.Statements.Current
