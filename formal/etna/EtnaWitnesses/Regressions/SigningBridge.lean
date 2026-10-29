import EtnaProofs.SigningBridge
import EtnaWitnesses.Counterexamples.HistoricalEscrow

/-! Concrete nonvacuity of the typed signing bridge after ordinary exit and withdrawal.
The fixture's decoded authentication and signing adapters are explicit computable
relations; they do not claim to implement canonical Comet bytes or cryptography. -/
namespace Etna.Design.SigningBridgeRegression
open SigningBridge

/-- The withdrawal preserves the Inbox landed by the original twelve-block batch. -/
theorem snapshotSource : SnapshotSource HistoricalEscrow.worldE.inbox HistoricalEscrow.historicalRules.consensus :=
  .acceptedBatch
    (before := HistoricalEscrow.worldB.inbox) (i := HistoricalEscrow.statement.input)
    (leaves := HistoricalEscrow.leaves) (e := HistoricalEscrow.landingEnv)
    (r := HistoricalEscrow.rules) (parent := NonVacuity.genesisHeader)
    (blocks := HistoricalEscrow.blocks) (blobs := [111])
    (by decide +kernel) ⟨HistoricalEscrow.ordinary_rotation_chain,by decide +kernel⟩ rfl
    ⟨rfl,rfl,rfl,rfl,rfl,rfl,rfl⟩

/-- Fully replayed local trust, including both stored checkpoint hashes, a covered
archive, own-finalized anchors, and the node's checkpoint-height/hash fence. -/
def trustedPrefix : TrustedPrefix HistoricalEscrow.worldE where
  cfg := Deployment.parameters HistoricalEscrow.worldE.inbox HistoricalEscrow.worldE.inbox.configuration
  archive := HistoricalEscrow.archive
  rules := HistoricalEscrow.historicalRules
  fixedConfiguration := rfl
  constructed := by
    unfold HistoricalContext.build
    rw [ite_eq_left (by decide +kernel)]
    rfl
  origin := NonVacuity.genesisHeader
  replay := HistoricalEscrow.blocks
  extension := []
  originHeight := by decide +kernel
  originRecord := ⟨NonVacuity.world0.inbox.checkpoint,by decide +kernel,by unfold headerMatches; decide +kernel⟩
  replayValid := by decide +kernel
  extensionValid := True.intro
  checkpoint := by unfold headerMatches; decide +kernel
  archiveCovered := by decide +kernel
  referenceFinalized := by decide +kernel
  snapshotSource := snapshotSource
  ownFinalized := fun anchor => anchor.number ≤ 30
  nodeAccepted := by unfold BlockValidity.NodeValid; decide +kernel

/-- The actual exit confirmation is included as the terminal replay checkpoint. -/
def confirmedIncluded : IncludedCheckpoint HistoricalEscrow.worldD trustedPrefix where
  before := HistoricalEscrow.blocks
  remaining := []
  decomposition := by simp [trustedPrefix]
  checkpointBinding := by unfold headerMatches; decide +kernel
  source := snapshotSource

/-- A deterministic adapter code containing every decoded signing coordinate. These
fixture words stand for the canonical signing bytes checked by a real adapter. -/
@[irreducible] def messageCode (m : SignMessage) : Hash :=
  NonVacuity.configHash ([m.domain.l1ChainId,m.domain.l2ChainId,m.domain.inbox,m.domain.registry,
    m.generation,m.height,m.round,phaseStep m.phase,m.blockId].map Encoding.natWord)

/-- The fixture accepts key 8's signatures for the next height, bound to the entire
decoded message, including the phase and the nil/non-nil block identifier. -/
def signedBy (key : Hash) (m : SignMessage) (signature : Hash) : Prop :=
  key = 8 ∧ m.domain = FirstBatch.deployment ∧ m.generation = 0 ∧ m.height = 13 ∧
    signature = messageCode m+key

instance (key : Hash) (m : SignMessage) (signature : Hash) : Decidable (signedBy key m signature) :=
  inferInstanceAs (Decidable (_ ∧ _))

def device : KeyedDevice :=
  ⟨8,⟨FirstBatch.deployment,0,1,[],true,[]⟩,messageCode,signedBy⟩

def message (phase : SignPhase) (nil : Bool) : SignMessage :=
  ⟨FirstBatch.deployment,0,13,0,phase,if nil then 0 else 113⟩

/-- All three phases and both nil and non-nil block ids can produce a fresh successful
call under every TrustedPrefix field. Each call starts from its own empty device log. -/
def call (phase : SignPhase) (nil : Bool) : ObservedCall trustedPrefix where
  device := device
  message := message phase nil
  request := messageRequest messageCode (message phase nil) true
  decoded := rfl
  observed := HistoricalEscrow.worldE
  viewToObservation := .refl _
  supplied := messageCode (message phase nil)+8
  persisted := true
  after := { device.state with log :=
    [⟨0,⟨13,0,phaseStep phase⟩,messageCode (message phase nil),messageCode (message phase nil)+8⟩] }
  returned := messageCode (message phase nil)+8
  result := rfl
  authentic := ⟨rfl,rfl,rfl,rfl,rfl⟩

theorem call_fresh (phase : SignPhase) (nil : Bool) :
    (call phase nil).after.log ≠ (call phase nil).device.state.log := by
  simp [call,device]

/-- The request producer chooses a real member of the current fixed committee at the
replayed chain's next height; nil never changes this membership obligation. -/
theorem engine_request (phase : SignPhase) (nil : Bool) :
    EngineRequest trustedPrefix (call phase nil).device.key (call phase nil).message := by
  refine ⟨rfl,rfl,?_,?_⟩
  · change 13 = trustedPrefix.tip.height+1
    decide +kernel
  · refine ⟨⟨8,1000000000000000000,17,Staking.noExit⟩,?_,rfl⟩
    change (⟨8,1000000000000000000,17,Staking.noExit⟩ : Committee.Entry) ∈
      (Consensus.activeAt trustedPrefix.rules.consensus 13).members
    decide +kernel

/-- The actual returned fresh signature is tied to the decoded request, rather than
being a cached return for an earlier message. -/
theorem fresh_call_binding (phase : SignPhase) (nil : Bool) :
    (call phase nil).returned = (call phase nil).supplied ∧
    (call phase nil).after.log =
      ⟨(call phase nil).message.generation,(call phase nil).request.position,
        (call phase nil).request.bytes,(call phase nil).supplied⟩ ::
      (call phase nil).device.state.log :=
  fresh_return_binds_message (call phase nil) (call_fresh phase nil)

/-- The endpoint snapshot bound is obtained from this prefix's actual accepted batch. -/
theorem next_request_snapshot_bound (phase : SignPhase) (nil : Bool) :
    HistoricalEscrow.worldE.inbox.snapshot ≤
      (Consensus.activeAt trustedPrefix.rules.consensus (message phase nil).height).cutoff :=
  request_snapshot_bound trustedPrefix (message phase nil)
    (by change 13 = trustedPrefix.tip.height+1; decide +kernel)

/-- The confirmation source and both checkpoint hashes match the replayed header.
The old lifetime key 7 is absent from next-height selection after its withdrawal. -/
theorem confirmed_prefix_and_old_key_absent :
    headerMatches HistoricalEscrow.worldD.inbox.checkpoint trustedPrefix.tip ∧
    HistoricalEscrow.worldD.inbox.snapshot = 24 ∧
    (HistoricalEscrow.worldD.registry.slots 0).confirmedAt = some 29 ∧
    (Consensus.activeAt trustedPrefix.rules.consensus 13).members.map Committee.Entry.key = [8] ∧
    (HistoricalEscrow.worldE.registry.slots 0).released = true := by
  unfold headerMatches
  decide +kernel

/-- The genuine initialized fixture has one lifetime-unique allocated key. -/
theorem initial_keys : SigningEscrow.KeysWellFormed NonVacuity.world0.registry := by
  constructor
  · intro id range _
    have zero : id = 0 := by change id < 1 at range; omega
    subst id
    decide +kernel
  · intro key _ i ir j jr _ _
    change i < 1 at ir
    change j < 1 at jr
    omega

/-- Its initial entry has no effective exit; later finite exits arise through the
actual registry trajectory rather than an assumed historical exclusion. -/
theorem initial_visible : SigningEscrow.ExitVisible NonVacuity.world0.registry := by
  intro id range _ finite
  have zero : id = 0 := by change id < 1 at range; omega
  subst id
  exact False.elim (finite rfl)

private theorem initial_unconfirmed (id : Nat) :
    (NonVacuity.world0.registry.slots id).confirmedAt = none := by
  change (if id = 0 then (⟨7,51,1000000000000000000,12,Staking.noExit,false,none,0,0⟩ : Staking.Bond)
    else RegistryHistory.vacant).confirmedAt = none
  split <;> rfl

/-- The proper initialized World executes registration, delayed exit, an accepted
ordinary rotation batch, and confirmation, with the actual snapshot discipline. -/
theorem confirmation_trajectory :
    SigningEscrow.SnapshotTrace NonVacuity.world0 HistoricalEscrow.worldD :=
  .step (.step (.step (.step (.refl _)
    (.registration (key := 8) (owner := 52) (amount := 1000000000000000000) (by decide) (by rfl))
    (Or.inl (by decide +kernel)))
    (.modification (id := 0) (action := .requestExit 51) (by decide) rfl (by rfl))
    (Or.inl (by decide +kernel)))
    (.landing (i := HistoricalEscrow.statement.input) (leaves := HistoricalEscrow.leaves)
      (e := HistoricalEscrow.landingEnv) (by decide) (by decide +kernel))
    (Or.inl (by decide +kernel)))
    (.modification (id := 0) (action := .confirm) (by decide) rfl (by rfl))
    (Or.inl (by decide +kernel))

theorem confirmation_covered : SigningEscrow.Covered HistoricalEscrow.worldD := by
  apply SigningEscrow.trace_covered confirmation_trajectory
  intro id c present
  rw [initial_unconfirmed] at present
  contradiction

theorem withdrawal_trajectory : ProtocolState.Trace HistoricalEscrow.worldD HistoricalEscrow.worldE :=
  .step (.refl _) (.modification (id := 0) (action := .withdraw 51) (by decide) rfl (by rfl))

/-- The general event-exclusion theorem is inhabited by a fresh successful call for
every phase and nil choice, starting at the fixture's genuine deployment Genesis. -/
theorem actual_event_excludes_old_key (phase : SignPhase) (nil : Bool) :
    (call phase nil).device.key ≠ (HistoricalEscrow.worldD.registry.slots 0).key :=
  event_excludes_visible_key (c := 29) (SigningEscrow.snapshot_trace_projects confirmation_trajectory)
    (Deployment.genesis_core NonVacuity.premises.genesis.1) initial_keys initial_visible
    withdrawal_trajectory trustedPrefix confirmedIncluded (call phase nil) (engine_request phase nil)
    (by decide +kernel) (by decide +kernel) confirmation_covered (by decide +kernel) (by decide +kernel)

/-- An explicit successful non-nil precommit inhabits the complete typed bridge and
its fresh-event exclusion theorem. -/
theorem successful_fresh_signing_event :
    ∃ event : ObservedCall trustedPrefix,
      EngineRequest trustedPrefix event.device.key event.message ∧
      event.after.log ≠ event.device.state.log ∧ event.message.phase = .precommitMsg ∧
      event.message.blockId = 113 ∧
      event.device.key ≠ (HistoricalEscrow.worldD.registry.slots 0).key :=
  ⟨call .precommitMsg false,engine_request .precommitMsg false,call_fresh .precommitMsg false,
    rfl,rfl,actual_event_excludes_old_key .precommitMsg false⟩

end Etna.Design.SigningBridgeRegression
