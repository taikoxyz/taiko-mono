import EtnaProofs.NormalSigning
import EtnaWitnesses.Regressions.SigningBridge

/-! Genuine initialized ordinary rotation, exit/withdrawal, slot reuse, another landing,
normal recovery and a post-recovery ordinary handover. Real source/request functions are
used throughout; decoded crypto/EL/history fixtures do not certify production adapters. -/
namespace Etna.Design.NormalSigningRegression
open ProtocolState SigningBridge NormalSigning

private theorem initial_unconfirmed (id : Nat) :
    (NonVacuity.world0.registry.slots id).confirmedAt = none := by
  change (if id = 0 then (⟨7,51,1000000000000000000,12,Staking.noExit,false,none,0,0⟩ : Staking.Bond)
    else RegistryHistory.vacant).confirmedAt = none
  split <;> rfl

/-- The real initialized ordinary landing supplies coverage, not a SnapshotUpdate input. -/
theorem confirmation_run : Run NonVacuity.world0 HistoricalEscrow.worldD := by
  have before : Run NonVacuity.world0 HistoricalEscrow.worldB :=
    .other (.other (.refl _)
      (.registration (key := 8) (owner := 52) (amount := 1000000000000000000) (by decide) (by rfl)) (by decide))
      (.modification (id := 0) (action := .requestExit 51) (by decide) rfl (by rfl)) (by decide)
  have landed : Run NonVacuity.world0 HistoricalEscrow.worldC :=
    .landing (s := HistoricalEscrow.worldC.inbox) (i := HistoricalEscrow.statement.input)
      (leaves := HistoricalEscrow.leaves) (e := HistoricalEscrow.landingEnv) (r := HistoricalEscrow.rules) (parent := NonVacuity.genesisHeader)
      (blocks := HistoricalEscrow.blocks) (blobs := [111])
      (archive := HistoricalEscrow.archive) (template := HistoricalEscrow.fixture.template 28 2800)
      before (by decide) (by decide +kernel)
      (NonVacuity.build_rulesFor (by decide +kernel) (by decide +kernel))
      ⟨HistoricalEscrow.ordinary_rotation_chain,by decide +kernel⟩ rfl (.atFloor rfl) (by decide +kernel)
  exact .other landed (.modification (id := 0) (action := .confirm) (by decide) rfl (by rfl)) (by decide)

def preLandingWorld : World := HistoricalEscrow.worldE

def archive0 : List Nat := HistoricalEscrow.archive ++ [32,33]
def fixture : Etna.Statements.Environment := { NonVacuity.relations with
  signature := fun v => v.key = 8 ∨ v.key = 9,
  anchorAuthenticated := fun a => decide
    (a.number = a.timestamp ∧ a.stateRoot = a.number+10 ∧ a.tail = 0 ∧
      ((a.checkpointHeight = 12 ∧ a.checkpointHash = (HistoricalEscrow.header 12).elHash ∧ a.generation = 0) ∨
       (a.checkpointHeight = 14 ∧ a.checkpointHash = (hashedHeader 14).elHash ∧ a.generation = 1))) }
where
  hashedHeader (h : Nat) : BlockValidity.Header :=
    NonVacuity.hashed ⟨h,0,50+h,100+h,0,19+h,
      ⟨19+h,19+h,29+h,12,(HistoricalEscrow.header 12).elHash,0,0⟩⟩

def anchor0 (h : Nat) : BlockValidity.Anchor :=
  ⟨19+h,19+h,29+h,12,(HistoricalEscrow.header 12).elHash,0,0⟩
def header0 (h : Nat) : BlockValidity.Header :=
  NonVacuity.hashed ⟨h,0,50+h,100+h,0,19+h,anchor0 h⟩
def rules0 : BlockValidity.Rules := NonVacuity.rulesFor fixture preLandingWorld archive0 34 3400
instance : DecidablePred rules0.signature := fun v => inferInstanceAs (Decidable (v.key = 8 ∨ v.key = 9))
def block0 (h : Nat) : BlockValidity.Block :=
  ⟨header0 h,(if h = 13 then HistoricalEscrow.header 12 else header0 (h-1)).elHash,some (99+h),
    FirstBatch.deployment,0,19+h,100,100,true,none,12,12,(anchor0 h).stateRoot,0,
    [⟨FirstBatch.deployment,0,h,0,2,100+h,8⟩],none,.completedEmpty⟩
def blocks0 : List BlockValidity.Block := [block0 13,block0 14]
def statement0 : StatementData := Settlement.statement rules0 (HistoricalEscrow.header 12) blocks0 [111]
def leaves0 : List Leaf := gridLeaves 1 12 14 (BlockValidity.cuts (HistoricalEscrow.header 12) blocks0)
def landing0 : LandingEnv := ⟨35,3400,true,[111],NonVacuity.proofs,statement0⟩
def landedWorld : World := landed preLandingWorld (applyLanding preLandingWorld.inbox statement0.input) 35

/-- The retained old landing is transported through archive extension and registry updates. -/
theorem prior_source : SnapshotSource preLandingWorld.inbox rules0.consensus :=
  .extendedArchive (before := HistoricalEscrow.worldB.inbox) (settled := HistoricalEscrow.worldC.inbox)
    (historyState := HistoricalEscrow.worldB.inbox) (i := HistoricalEscrow.statement.input)
    (leaves := HistoricalEscrow.leaves) (e := HistoricalEscrow.landingEnv)
    (r := HistoricalEscrow.rules) (parent := NonVacuity.genesisHeader)
    (blocks := HistoricalEscrow.blocks) (blobs := [111])
    (oldRegistry := HistoricalEscrow.worldB.registry) (newRegistry := preLandingWorld.registry)
    (params := Deployment.parameters preLandingWorld.inbox preLandingWorld.inbox.configuration)
    (oldArchive := HistoricalEscrow.archive) (more := [32,33])
    (by decide +kernel) ⟨HistoricalEscrow.ordinary_rotation_chain,by decide +kernel⟩ rfl rfl rfl
    (by decide +kernel) rfl rfl

theorem landing_batch : Settlement.BatchValid rules0 (HistoricalEscrow.header 12) blocks0 [111] :=
  ⟨by decide +kernel,rfl⟩

/-- All registry changes and the second actual accepted landing remain original operations. -/
theorem before_recovery_run : Run NonVacuity.world0 landedWorld := by
  have withdraw : Run NonVacuity.world0 HistoricalEscrow.worldE :=
    .other confirmation_run (.modification (id := 0) (action := .withdraw 51) (by decide) rfl (by rfl)) (by decide)
  exact .landing (s := landedWorld.inbox) (i := statement0.input) (leaves := leaves0) (e := landing0)
    (r := rules0) (parent := HistoricalEscrow.header 12) (blocks := blocks0) (blobs := [111])
    (archive := archive0) (template := fixture.template 34 3400) withdraw (by decide) (by decide +kernel)
    (NonVacuity.build_rulesFor (by decide +kernel) (by decide +kernel)) landing_batch rfl prior_source (by decide +kernel)

def recoveryRequest : Recovery.Request := ⟨0,14,[],[],landedWorld.inbox.recoveryNonce,limit256-1⟩
def recoveryOrigin : Origin := ⟨14,40,40⟩
def recoveryResult : Recovery.World :=
  Recovery.applyRecovery (recoveryView landedWorld) recoveryRequest landedWorld.adapters.recovery recoveryOrigin
def recoveredWorld : World := recovered landedWorld recoveryRequest recoveryOrigin recoveryResult
/-- Reuse occurs after the recovered committee and its next ordinary snapshot were taken. -/
def reusedRegistry : RegistryHistory.State :=
  (RegistryHistory.register recoveredWorld.registry 9 53 1000000000000000000 48).getD recoveredWorld.registry
def reusedWorld : World := registered recoveredWorld reusedRegistry 48
/-- A distinct nonce invalidation in that same L1 block remains an ordinary operation. -/
def view : World := landed reusedWorld (Recovery.applyInvalidation reusedWorld.inbox) 48

theorem recovery_call :
    Recovery.recover (recoveryView landedWorld) recoveryRequest landedWorld.adapters.recovery recoveryOrigin true true =
      some recoveryResult := Recovery.recover_of_allowed (by decide +kernel)

theorem full_run : Run NonVacuity.world0 view :=
  .other (.other (.other before_recovery_run (.recovery (by decide) recovery_call) (by decide +kernel))
    (.registration (key := 9) (owner := 53) (amount := 1000000000000000000) (by decide) (by rfl)) (by decide +kernel))
    (.invalidation (expected := reusedWorld.inbox.recoveryNonce) (owner := true) (by decide) (by decide +kernel))
    (by decide +kernel)

def archive1 : List Nat := archive0 ++ (List.range 8).map (fun i => 40+i)
def rules1 : BlockValidity.Rules := NonVacuity.rulesFor fixture view archive1 48 4800
instance : DecidablePred rules1.signature := fun v => inferInstanceAs (Decidable (v.key = 8 ∨ v.key = 9))
def anchor1 (h : Nat) : BlockValidity.Anchor :=
  ⟨25+h,25+h,35+h,14,(header0 14).elHash,1,0⟩
def header1 (h : Nat) : BlockValidity.Header :=
  NonVacuity.hashed ⟨h,0,50+h,200+h,0,25+h,anchor1 h⟩
def block1 (h : Nat) : BlockValidity.Block :=
  ⟨header1 h,(if h = 15 then header0 14 else header1 (h-1)).elHash,
    (if h = 15 then none else some (199+h)),FirstBatch.deployment,1,25+h,100,100,true,
    (if (h+1)%10 = 0 then some ⟨Consensus.normal rules1.consensus ((h+1)/10),(anchor1 h).stateRoot⟩ else none),
    12,12,(anchor1 h).stateRoot,0,
    [⟨FirstBatch.deployment,1,h,0,2,200+h,8⟩],none,.completedEmpty⟩
def blocks1 : List BlockValidity.Block := (List.range 8).map (fun i => block1 (15+i))

theorem recovered_chain : BlockValidity.Chain rules1 (header0 14) blocks1 := by decide +kernel

theorem recovered_source : SnapshotSource view.inbox rules1.consensus :=
  .beforeRecovery (before := preLandingWorld.inbox) (settled := landedWorld.inbox)
    (i := statement0.input) (leaves := leaves0) (e := landing0)
    (r := rules0) (parent := HistoricalEscrow.header 12) (blocks := blocks0) (blobs := [111])
    (by decide +kernel) landing_batch rfl (by decide +kernel) (by decide +kernel) (by decide +kernel) rfl rfl

def trustedPrefix : TrustedPrefix view where
  cfg := Deployment.parameters view.inbox view.inbox.configuration
  archive := archive1
  rules := rules1
  fixedConfiguration := rfl
  constructed := by unfold HistoricalContext.build; rw [ite_eq_left (by decide +kernel)]; rfl
  referenceFinalized := by decide +kernel
  origin := header0 14
  replay := []
  extension := blocks1
  originHeight := by decide +kernel
  originRecord := ⟨landedWorld.inbox.checkpoint,by decide +kernel,by unfold headerMatches; decide +kernel⟩
  replayValid := True.intro
  extensionValid := recovered_chain
  checkpoint := by unfold headerMatches; decide +kernel
  archiveCovered := by decide +kernel
  snapshotSource := recovered_source
  ownFinalized := fun a => a.number ≤ 48
  nodeAccepted := by unfold BlockValidity.NodeValid; decide +kernel

/-- The old checkpoint 12 is retained below origin 14, so same-replay inclusion is impossible. -/
theorem confirmationSource : ConfirmationSource HistoricalEscrow.worldD view trustedPrefix :=
  .recovery (before := landedWorld) (s := recoveryResult) (a := recoveryRequest) (origin := recoveryOrigin)
    (owner := true) (externalOK := true)
    (.step (.step (.refl _)
      (.modification (id := 0) (action := .withdraw 51) (by decide) rfl (by rfl)))
      (.landing (i := statement0.input) (leaves := leaves0) (e := landing0) (by decide) (by decide +kernel)))
    (by decide) recovery_call
    (.step (.step (.refl _) (.registration (key := 9) (owner := 53) (amount := 1000000000000000000)
      (by decide) (by rfl)))
      (.invalidation (expected := reusedWorld.inbox.recoveryNonce) (owner := true) (by decide) (by decide +kernel)))
    (by decide +kernel) rfl

def signedBy (key : Hash) (m : SignMessage) (signature : Hash) : Prop :=
  key = 8 ∧ m.domain = FirstBatch.deployment ∧ m.generation = 1 ∧ m.height = 23 ∧
    signature = SigningBridgeRegression.messageCode m+key

def device : KeyedDevice :=
  ⟨8,Signer.openSession (Signer.switchDomain (SigningBridgeRegression.call .precommitMsg false).after
    FirstBatch.deployment 1 15 true true) 1 true true,SigningBridgeRegression.messageCode,signedBy⟩
def message (phase : SignPhase) (nil : Bool) : SignMessage :=
  ⟨FirstBatch.deployment,1,23,0,phase,if nil then 0 else 223⟩
def call (phase : SignPhase) (nil : Bool) : ObservedCall trustedPrefix where
  device := device
  message := message phase nil
  request := messageRequest device.encode (message phase nil) true
  decoded := rfl
  observed := view
  viewToObservation := .refl _
  supplied := device.encode (message phase nil)+8
  persisted := true
  after := { device.state with log :=
    ⟨1,⟨23,0,phaseStep phase⟩,device.encode (message phase nil),device.encode (message phase nil)+8⟩ :: device.state.log }
  returned := device.encode (message phase nil)+8
  result := rfl
  authentic := ⟨rfl,rfl,rfl,rfl,rfl⟩

theorem engine_request (phase : SignPhase) (nil : Bool) :
    EngineRequest trustedPrefix (call phase nil).device.key (call phase nil).message := by
  refine ⟨rfl,rfl,?_,?_⟩
  · change 23 = trustedPrefix.tip.height+1
    decide +kernel
  · refine ⟨⟨8,1000000000000000000,17,Staking.noExit⟩,?_,rfl⟩
    change (⟨8,1000000000000000000,17,Staking.noExit⟩ : Committee.Entry) ∈
      (Consensus.activeAt rules1.consensus 23).members
    decide +kernel

theorem call_fresh (phase : SignPhase) (nil : Bool) :
    (call phase nil).after.log ≠ (call phase nil).device.state.log := by
  simp [call,device]

/-- The initialized corollary is inhabited across recovery, after actual withdrawal/reuse. -/
theorem actual_event_excludes_old_key (phase : SignPhase) (nil : Bool) :
    (call phase nil).device.key ≠ (HistoricalEscrow.worldD.registry.slots 0).key :=
  initialized_fresh_signing_connection (id := 0) (c := 29) NonVacuity.premises.genesis.1 confirmation_run
    SigningBridgeRegression.initial_keys SigningBridgeRegression.initial_visible initial_unconfirmed
    trustedPrefix confirmationSource (call phase nil) (engine_request phase nil) (call_fresh phase nil)
    (by decide +kernel) (by decide +kernel) (by decide +kernel) (by decide +kernel)

theorem recovery_fresh_signature :
    ∃ event : ObservedCall trustedPrefix, EngineRequest trustedPrefix event.device.key event.message ∧
      event.after.log ≠ event.device.state.log ∧ event.message.generation = 1 ∧
      event.message.height = 23 ∧ event.device.key ≠ 7 :=
  ⟨call .precommitMsg false,engine_request .precommitMsg false,call_fresh .precommitMsg false,rfl,rfl,
    actual_event_excludes_old_key .precommitMsg false⟩


/-- A normal recovery before the first landing has a genuine initialization source too. -/
def earlyOrigin : Origin := ⟨0,20,20⟩
def earlyRequest : Recovery.Request := ⟨0,0,[],[],0,limit256-1⟩
def earlyResult : Recovery.World := Recovery.applyRecovery (recoveryView NonVacuity.world0)
  earlyRequest NonVacuity.world0.adapters.recovery earlyOrigin
def earlyWorld : World := recovered NonVacuity.world0 earlyRequest earlyOrigin earlyResult
def earlyContext : Consensus.Context := HistoricalContext.derive earlyWorld.inbox earlyWorld.registry
  (Deployment.parameters earlyWorld.inbox earlyWorld.inbox.configuration) [14]

theorem recovery_before_first_landing_source : SnapshotSource earlyWorld.inbox earlyContext ∧
    earlyWorld.inbox.snapshot = 12 ∧ Settlement.floor earlyContext = 20 := by
  refine ⟨?_,rfl,rfl⟩
  exact recovery_snapshot_source
    (cfg := Deployment.parameters earlyWorld.inbox earlyWorld.inbox.configuration) (archive := [14])
    (.refl NonVacuity.world0)
    (Deployment.genesis_snapshot_below NonVacuity.premises.genesis.1) (by decide)
    (Recovery.recover_of_allowed (by decide +kernel))
    (by unfold HistoricalContext.build; rw [ite_eq_left (by decide +kernel)]; rfl)

/-- Old confirmation is below the new origin; a reused slot has a different key, and a
real H+2 switch in the recovered generation advances cutoff without reviving key 7. -/
theorem recovery_rotation_boundaries :
    HistoricalEscrow.worldD.inbox.checkpoint.height = 12 ∧ view.inbox.origin.height = 14 ∧
    (view.registry.slots 0).key = 9 ∧ view.inbox.generation = 1 ∧
    (Consensus.activeAt rules1.consensus 20).cutoff = 40 ∧
    (Consensus.activeAt rules1.consensus 21).cutoff = 43 ∧
    (Consensus.activeAt rules1.consensus 23).members.map Committee.Entry.key = [8] ∧
    recordAt view.inbox 12 = recordAt HistoricalEscrow.worldD.inbox 12 := by
  refine ⟨by decide +kernel,by decide +kernel,by decide +kernel,by decide +kernel,
    by decide +kernel,by decide +kernel,by decide +kernel,source_retains_checkpoint confirmationSource⟩

theorem old_key_request_rejected (phase : SignPhase) (nil : Bool) :
    ¬ EngineRequest trustedPrefix 7 (message phase nil) := by
  have absent : ∀ entry ∈ (Consensus.activeAt rules1.consensus 23).members, entry.key ≠ 7 := by
    decide +kernel
  intro request
  obtain ⟨entry,member,key⟩ := request.2.2.2
  exact absent entry member key

end Etna.Design.NormalSigningRegression
