import EtnaWitnesses.Counterexamples.HistoricalEscrow
import EtnaWitnesses.Regressions.SigningBridge

/-! A decoded stale-view boundary for the actual stock signer transition. The local
prefix reaches height 9 and the durable signer has already returned its round-0
precommit at height 10, without learning that height's commit. A higher-round nil
precommit is therefore HRS-forward. Meanwhile the ordinary L1 trajectory has landed
height 12, confirmed the exit and paid the withdrawal.

This is not a claim that the latest global checkpoint permits this local height, or
a byte-level/L1-authentication implementation. The old checkpoint and committees
come from the existing decoded fixture; session authentication and the abstract
sign-byte tokens remain external adapter boundaries. The example separates an own
lagging finalized view from a newer L1 World, and fresh creation from cached retry. -/
namespace Etna.Design.SigningViewLag
open NonVacuity

/-- L1 has finalized block 26, whose contract state still has checkpoint 0.
A successful empty fee sweep advances the actual machine clock to that block. -/
def view : ProtocolState.World :=
  ProtocolState.landed HistoricalEscrow.worldB HistoricalEscrow.worldB.inbox 26
def current : ProtocolState.World := HistoricalEscrow.worldE
def localPrefix : List BlockValidity.Block := HistoricalEscrow.blocks.take 9
def tip : BlockValidity.Header := BlockValidity.terminal genesisHeader localPrefix
def key : Hash := 7

/-- The fixture's actual height-10 round-0 precommit, before learning its commit. -/
def previousVote : Consensus.Vote := vote 0 10 110

/-- All ten earlier precommits are retained in newest-first durable HRS order.
The byte and signature hashes are abstract tokens, not a raw vote encoding. -/
def durableLog : List Signer.Signed :=
  (List.range 10).reverse.map (fun i => ⟨0,⟨i+1,0,3⟩,101+i,401+i⟩)

def previous : Signer.Signed := ⟨0,⟨10,0,3⟩,110,410⟩
def closed : Signer.State := ⟨FirstBatch.deployment,0,1,[],false,durableLog⟩
def session : Signer.State := Signer.openSession closed 0 true true

/-- A nil precommit in the next round at the same local consensus height. -/
def nilVote : Consensus.Vote := ⟨FirstBatch.deployment,0,10,1,2,0,key⟩
def request : Signer.Request := ⟨FirstBatch.deployment,0,true,⟨10,1,3⟩,0⟩
def created : Signer.Signed := ⟨0,request.position,request.bytes,777⟩
def after : Signer.State := { session with log := created :: session.log }

/-- The old finalized view is itself an original-machine reachable state. Its
source block is recent enough to finalize every anchor in the retained prefix
and the block for which the previous signature was persisted. -/
theorem view_reachable : ProtocolState.Trace world0 view :=
  .step (.step (.step (.refl _)
    (.registration (key := 8) (owner := 52) (amount := 1000000000000000000)
      (by decide) (by rfl)))
    (.modification (id := 0) (action := .requestExit 51) (by decide) rfl (by rfl)))
    (.sweep (transfer := true) (by decide) (by decide +kernel))

/-- The ordinary withdrawal trajectory continues from the old view; no recovery,
rollback, lost HRS state or copied key is needed to describe the stale local view. -/
theorem view_to_withdrawal : ProtocolState.Trace view current :=
  .step (.step (.step (.refl _)
    (.landing (i := HistoricalEscrow.statement.input) (leaves := HistoricalEscrow.leaves)
      (e := HistoricalEscrow.landingEnv) (by decide) (by decide +kernel)))
    (.modification (id := 0) (action := .confirm) (by decide) rfl (by rfl)))
    (.modification (id := 0) (action := .withdraw 51) (by decide) rfl (by rfl))

/-- The local height follows its valid retained prefix and matches both old
checkpoint hashes; its selected committee still contains the lifetime key. -/
theorem old_view_and_local_height :
    BlockValidity.Chain HistoricalEscrow.rules genesisHeader localPrefix ∧
    tip.height = 9 ∧ request.position.height = tip.height+1 ∧
    view.inbox.checkpoint.height = 0 ∧ view.inbox.snapshot = 12 ∧
    (HistoricalEscrow.header view.inbox.checkpoint.height).elHash = view.inbox.checkpoint.elHash ∧
    (HistoricalEscrow.header view.inbox.checkpoint.height).cometHash = view.inbox.checkpoint.cometHash ∧
    (Consensus.activeAt HistoricalEscrow.rules.consensus request.position.height).cutoff = 12 ∧
    key ∈ (Consensus.activeAt HistoricalEscrow.rules.consensus request.position.height).members.map Committee.Entry.key ∧
    12 < (view.registry.slots 0).exitAt ∧ view.l1Block = 26 ∧
    (∀ b ∈ localPrefix, b.header.anchor.number ≤ view.l1Block) ∧
    (HistoricalEscrow.block 10).header.anchor.number ≤ view.l1Block ∧
    view.l1Block < current.l1Block := by
  decide +kernel

/-- The previous logged precommit is exactly the fixture's height-10 vote. The
new request binds its decoded domain, generation, HRS and nil BlockID explicitly;
the zero byte token is still an abstract adapter value. -/
theorem request_binding_and_prior_vote :
    (HistoricalEscrow.block 10).votes = [previousVote] ∧
    Consensus.VoteValid HistoricalEscrow.rules.consensus HistoricalEscrow.rules.signature
      10 0 110 previousVote ∧
    request.domain = nilVote.domain ∧ request.generation = nilVote.generation ∧
    request.position.height = nilVote.height ∧ request.position.round = nilVote.round ∧
    request.position.step = nilVote.kind+1 ∧ request.bytes = nilVote.blockId ∧
    nilVote.kind = 2 ∧ nilVote.blockId = 0 ∧ nilVote.key = 7 ∧
    Consensus.VoteValid HistoricalEscrow.historicalRules.consensus
      HistoricalEscrow.historicalRules.signature 10 1 0 nilVote ∧
    Staking.doubleSign FirstBatch.deployment current.inbox.generation
      (Accountability.evidence previousVote) (Accountability.evidence nilVote) = false := by
  decide +kernel

/-- The same-generation trusted stock signer returns a newly persisted entry,
not the old signature, while newer L1 state has already paid the whole bond.
The request remains below that newer checkpoint, which is the missing freshness
condition in an unqualified global post-withdrawal signing statement. -/
theorem lagging_view_fresh_nil_signature :
    ProtocolState.Trace world0 current ∧ ProtocolState.Trace view current ∧
    current.inbox.checkpoint.height = 12 ∧ current.inbox.snapshot = 24 ∧
    (current.registry.slots 0).balance = 0 ∧ (current.registry.slots 0).released = true ∧
    session.ready = true ∧ request.trusted = true ∧
    session.domain = view.inbox.domain ∧ request.domain = session.domain ∧
    request.generation = session.activeGeneration ∧ request.generation = current.inbox.generation ∧
    Signer.latest session request.generation = some previous ∧
    Signer.before previous.position request.position = true ∧
    request.position.height < current.inbox.checkpoint.height ∧
    Signer.sign session request 777 true = some (after,777) ∧
    after.log = created :: session.log ∧ after.log.length = session.log.length+1 ∧
    after.log ≠ session.log := by
  exact ⟨HistoricalEscrow.ordinary_exit_trace,view_to_withdrawal,by decide +kernel⟩

open SigningBridge

def typedRules : BlockValidity.Rules :=
  rulesFor HistoricalEscrow.fixture view (HistoricalEscrow.archive.take 10) 26 2600

instance : DecidablePred typedRules.signature := fun v =>
  inferInstanceAs (Decidable (v.key = 7 ∨ v.key = 8))

/-- The stale view satisfies the complete typed prefix refinement. Its reference is
the own-finalized source block 26; all archived and accepted extension headers come
from the same nine-block prefix, with checkpoint 0 as the exact replay target. -/
def typedPrefix : TrustedPrefix view where
  cfg := Deployment.parameters view.inbox view.inbox.configuration
  archive := HistoricalEscrow.archive.take 10
  rules := typedRules
  fixedConfiguration := rfl
  constructed := by
    unfold HistoricalContext.build
    rw [ite_eq_left (by decide +kernel)]
    rfl
  referenceFinalized := by decide +kernel
  origin := genesisHeader
  replay := []
  extension := localPrefix
  originHeight := by decide +kernel
  originRecord := ⟨world0.inbox.checkpoint,by decide +kernel,by unfold headerMatches; decide +kernel⟩
  replayValid := True.intro
  extensionValid := by decide +kernel
  checkpoint := by unfold headerMatches; decide +kernel
  archiveCovered := by decide +kernel
  snapshotSource := .atFloor (by decide +kernel)
  ownFinalized := fun anchor => anchor.number ≤ 26
  nodeAccepted := by unfold BlockValidity.NodeValid; decide +kernel

/-- The canonical-decoding adapter is the same all-field abstract message code as
the positive bridge witness; it is not the earlier block-id-only byte token. -/
def typedPriorMessage (height : Nat) : SignMessage :=
  ⟨FirstBatch.deployment,0,height,0,.precommitMsg,100+height⟩

def typedMessage : SignMessage := ⟨FirstBatch.deployment,0,10,1,.precommitMsg,0⟩

/-- A computable fixture signature relation binds the immutable key to every
decoded signing coordinate through messageCode. Cryptography remains external. -/
def typedSignedBy (signingKey : Hash) (m : SignMessage) (signature : Hash) : Prop :=
  signingKey = key ∧ signature = SigningBridgeRegression.messageCode m+signingKey

/-- Preserve all ten earlier signatures in authoritative newest-first HRS order,
using the same entire-message encoding and fixture signature relation as the new call. -/
def typedDurableLog : List Signer.Signed :=
  (List.range 10).reverse.map (fun i =>
    ⟨0,⟨i+1,0,3⟩,SigningBridgeRegression.messageCode (typedPriorMessage (i+1)),
      SigningBridgeRegression.messageCode (typedPriorMessage (i+1))+key⟩)

def typedPrevious : Signer.Signed :=
  ⟨0,⟨10,0,3⟩,SigningBridgeRegression.messageCode (typedPriorMessage 10),
    SigningBridgeRegression.messageCode (typedPriorMessage 10)+key⟩

def typedClosed : Signer.State := ⟨FirstBatch.deployment,0,1,[],false,typedDurableLog⟩
def typedSession : Signer.State := Signer.openSession typedClosed 0 true true
def typedDevice : KeyedDevice :=
  ⟨key,typedSession,SigningBridgeRegression.messageCode,typedSignedBy⟩

/-- A successful observed stock call after withdrawal, authenticated by the full
typed message adapter and an unchanged durable signer session from the stale view. -/
def typedCall : ObservedCall typedPrefix where
  device := typedDevice
  message := typedMessage
  request := messageRequest SigningBridgeRegression.messageCode typedMessage true
  decoded := rfl
  observed := current
  viewToObservation := view_to_withdrawal
  supplied := SigningBridgeRegression.messageCode typedMessage+key
  persisted := true
  after := { typedSession with log :=
    ⟨0,⟨10,1,3⟩,SigningBridgeRegression.messageCode typedMessage,
      SigningBridgeRegression.messageCode typedMessage+key⟩ :: typedSession.log }
  returned := SigningBridgeRegression.messageCode typedMessage+key
  result := rfl
  authentic := ⟨rfl,rfl⟩

/-- The previous persisted vote is the fixture's height-10 non-nil precommit;
the later-round nil request is HRS-forward without resetting any signature state. -/
theorem typed_authoritative_hrs :
    typedCall.device.key = 7 ∧ typedCall.device.state.ready = true ∧
    typedCall.device.state.log.length = 10 ∧
    Signer.latest typedCall.device.state typedCall.request.generation = some typedPrevious ∧
    Signer.before typedPrevious.position typedCall.request.position = true ∧
    (typedPriorMessage 10).domain = previousVote.domain ∧
    (typedPriorMessage 10).generation = previousVote.generation ∧
    (typedPriorMessage 10).height = previousVote.height ∧
    (typedPriorMessage 10).round = previousVote.round ∧
    (typedPriorMessage 10).blockId = previousVote.blockId := by
  exact ⟨rfl,rfl,rfl,rfl,rfl,rfl,rfl,rfl,rfl,rfl⟩

theorem typed_call_fresh : typedCall.after.log ≠ typedCall.device.state.log := by
  intro same
  have lengths := congrArg List.length same
  change 11 = 10 at lengths
  omega

/-- Nil signing obeys every engine next-height and committee-membership field. -/
theorem typed_engine_request : EngineRequest typedPrefix typedCall.device.key typedCall.message := by
  refine ⟨rfl,rfl,?_,?_⟩
  · change 10 = typedPrefix.tip.height+1
    decide +kernel
  · refine ⟨⟨7,1000000000000000000,12,Staking.noExit⟩,?_,rfl⟩
    change (⟨7,1000000000000000000,12,Staking.noExit⟩ : Committee.Entry) ∈
      (Consensus.activeAt typedPrefix.rules.consensus 10).members
    decide +kernel

/-- The newer checkpoint is absent from the stale prefix. This fails even though
the typed prefix, node acceptance, immutable key, request and actual fresh call all
hold; it cannot be supplied just by describing the old own-finalized view as latest. -/
theorem current_checkpoint_not_included : ¬Nonempty (IncludedCheckpoint current typedPrefix) := by
  intro ⟨seen⟩
  have reached := included_checkpoint_reached typedPrefix seen
  change 12 ≤ 9 at reached
  omega

/-- The own-finalized view predates the actual confirmation as well as omitting its
checkpoint; a current-confirmation-to-old-view trajectory is impossible. -/
theorem confirmation_not_observed : ¬ ProtocolState.Trace HistoricalEscrow.worldD view := by
  intro trace
  have clock := ProtocolState.trace_clock_monotone trace
  have old : view.l1Block = 26 := by decide +kernel
  have confirmed : HistoricalEscrow.worldD.l1Block = 29 := by decide +kernel
  omega

/-- A fully typed fresh signing event after ordinary withdrawal exposes both the
confirmation-to-view freshness and checkpoint-inclusion boundary. It signs at the
old local next height, rather than above the newer L1 checkpoint. -/
theorem typed_fresh_event_with_missing_inclusion :
    EngineRequest typedPrefix typedCall.device.key typedCall.message ∧
    typedCall.observed = current ∧ typedCall.device.key = 7 ∧
    typedCall.message.phase = .precommitMsg ∧ typedCall.message.blockId = 0 ∧
    typedCall.after.log ≠ typedCall.device.state.log ∧
    (typedCall.observed.registry.slots 0).balance = 0 ∧
    (typedCall.observed.registry.slots 0).released = true ∧
    ¬Nonempty (IncludedCheckpoint current typedPrefix) :=
  ⟨typed_engine_request,rfl,rfl,rfl,rfl,typed_call_fresh,by decide +kernel,
    by decide +kernel,current_checkpoint_not_included⟩

end Etna.Design.SigningViewLag
