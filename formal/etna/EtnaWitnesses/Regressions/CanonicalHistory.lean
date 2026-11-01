import EtnaProofs.CanonicalHistory
import EtnaWitnesses.Regressions.NormalSigning

/-! The initialized rotation/exit/withdrawal/recovery/reuse trace continues through an
accepted recovery-generation landing to checkpoint 22, then fresh signing at height 23.
The raw history has no SnapshotSource fields. Its recovery is the actual call at L1 40;
the general induction consumes that normalRecovery source at the later landing. -/
namespace Etna.Design.CanonicalHistoryRegression
open ProtocolState SigningBridge CanonicalHistory

private theorem confirmation_history : Run NonVacuity.world0 HistoricalEscrow.worldD HistoricalEscrow.archive := by
  have before : Run NonVacuity.world0 HistoricalEscrow.worldB [] :=
    .edit (.edit (.genesis NonVacuity.premises.genesis.1)
      (.registration (key := 8) (owner := 52) (amount := 1000000000000000000) (by decide) (by rfl)))
      (.modification (id := 0) (action := .requestExit 51) (by decide) rfl (by rfl))
  have landed : Run NonVacuity.world0 HistoricalEscrow.worldC HistoricalEscrow.archive :=
    .landing (s := HistoricalEscrow.worldC.inbox) (i := HistoricalEscrow.statement.input)
      (leaves := HistoricalEscrow.leaves) (e := HistoricalEscrow.landingEnv) (r := HistoricalEscrow.rules)
      (parent := NonVacuity.genesisHeader) (blocks := HistoricalEscrow.blocks) (blobs := [111])
      (more := HistoricalEscrow.archive) (template := HistoricalEscrow.fixture.template 28 2800)
      before (by decide) (by decide +kernel)
      (NonVacuity.build_rulesFor (by decide +kernel) (by decide +kernel))
      ⟨HistoricalEscrow.ordinary_rotation_chain,by decide +kernel⟩ rfl
      (by decide +kernel) (by decide +kernel) (by decide +kernel)
  exact .edit landed (.modification (id := 0) (action := .confirm) (by decide) rfl (by rfl))

private theorem before_recovery_history :
    Run NonVacuity.world0 NormalSigningRegression.landedWorld NormalSigningRegression.archive0 := by
  have withdraw : Run NonVacuity.world0 HistoricalEscrow.worldE HistoricalEscrow.archive :=
    .edit confirmation_history (.modification (id := 0) (action := .withdraw 51) (by decide) rfl (by rfl))
  exact .landing (s := NormalSigningRegression.landedWorld.inbox)
    (i := NormalSigningRegression.statement0.input) (leaves := NormalSigningRegression.leaves0)
    (e := NormalSigningRegression.landing0) (r := NormalSigningRegression.rules0)
    (parent := HistoricalEscrow.header 12) (blocks := NormalSigningRegression.blocks0) (blobs := [111])
    (more := [32,33]) (template := NormalSigningRegression.fixture.template 34 3400)
    withdraw (by decide) (by decide +kernel)
    (NonVacuity.build_rulesFor (by decide +kernel) (by decide +kernel))
    NormalSigningRegression.landing_batch rfl (by decide +kernel) (by decide +kernel) (by decide +kernel)

/-- Initialized actual normal history includes nonce invalidation, reuse and recovery. -/
theorem prior_history :
    Run NonVacuity.world0 NormalSigningRegression.view NormalSigningRegression.archive0 :=
  .edit (.edit (.recovery before_recovery_history (by decide) NormalSigningRegression.recovery_call)
    (.registration (key := 9) (owner := 53) (amount := 1000000000000000000) (by decide) (by rfl)))
    (.invalidation (expected := NormalSigningRegression.reusedWorld.inbox.recoveryNonce)
      (owner := true) (by decide) (by decide +kernel))

/-- Explicitly expose the exact normalRecovery source that the run induction carries across
registration and nonce invalidation and consumes in the following landing. -/
theorem actual_recovery_source : SnapshotSource NormalSigningRegression.view.inbox
    NormalSigningRegression.rules1.consensus :=
  .normalRecovery (before := NormalSigningRegression.landedWorld)
    (result := NormalSigningRegression.recoveryResult) (a := NormalSigningRegression.recoveryRequest)
    (origin := NormalSigningRegression.recoveryOrigin) (owner := true) (externalOK := true)
    (by decide) NormalSigningRegression.recovery_call
    (NormalSigning.run_snapshot_below (run_normal before_recovery_history)
      (Deployment.genesis_snapshot_below NonVacuity.premises.genesis.1)) rfl rfl rfl rfl

def statement : StatementData := Settlement.statement NormalSigningRegression.rules1
  (NormalSigningRegression.header0 14) NormalSigningRegression.blocks1 [111]
def leaves : List Leaf := gridLeaves 1 14 22
  (BlockValidity.cuts (NormalSigningRegression.header0 14) NormalSigningRegression.blocks1)
def landing : LandingEnv := ⟨49,4800,true,[111],NonVacuity.proofs,statement⟩
def finish : World := landed NormalSigningRegression.view
  (applyLanding NormalSigningRegression.view.inbox statement.input) 49

theorem landing_accepted : Etna.Design.land NormalSigningRegression.view.inbox statement.input leaves landing =
    some finish.inbox := by decide +kernel

/-- The post-recovery landing really commits the replayed valid blocks, not merely a local
node extension. Its prior source is derived by run_normal from the recovery in prior_history. -/
theorem complete_history : Run NonVacuity.world0 finish NormalSigningRegression.archive1 :=
  .landing (s := finish.inbox) (i := statement.input) (leaves := leaves) (e := landing)
    (r := NormalSigningRegression.rules1) (parent := NormalSigningRegression.header0 14)
    (blocks := NormalSigningRegression.blocks1) (blobs := [111])
    (more := (List.range 8).map (fun i => 40+i)) (template := NormalSigningRegression.fixture.template 48 4800)
    prior_history (by decide) landing_accepted
    (NonVacuity.build_rulesFor (by decide +kernel) (by decide +kernel))
    ⟨NormalSigningRegression.recovered_chain,rfl⟩ rfl
    (by decide +kernel) (by decide +kernel) (by decide +kernel)

def signingPrefix : TrustedPrefix finish where
  cfg := Deployment.parameters finish.inbox finish.inbox.configuration
  archive := NormalSigningRegression.archive1
  rules := NormalSigningRegression.rules1
  fixedConfiguration := rfl
  constructed := by unfold HistoricalContext.build; rw [ite_eq_left (by decide +kernel)]; rfl
  referenceFinalized := by decide +kernel
  origin := NormalSigningRegression.header0 14
  replay := NormalSigningRegression.blocks1
  extension := []
  originHeight := by decide +kernel
  originRecord := ⟨NormalSigningRegression.landedWorld.inbox.checkpoint,by decide +kernel,
    by unfold headerMatches; decide +kernel⟩
  replayValid := NormalSigningRegression.recovered_chain
  extensionValid := True.intro
  checkpoint := by unfold headerMatches; decide +kernel
  archiveCovered := by decide +kernel
  snapshotSource := prior_snapshot_source (more := []) complete_history
    (NonVacuity.build_rulesFor (by decide +kernel) (by decide +kernel))
  ownFinalized := fun a => a.number ≤ 48
  nodeAccepted := by unfold BlockValidity.NodeValid; decide +kernel

def event : ObservedCall signingPrefix where
  device := NormalSigningRegression.device
  message := NormalSigningRegression.message .precommitMsg false
  request := messageRequest NormalSigningRegression.device.encode
    (NormalSigningRegression.message .precommitMsg false) true
  decoded := rfl
  observed := finish
  viewToObservation := .refl _
  supplied := (NormalSigningRegression.call .precommitMsg false).supplied
  persisted := true
  after := (NormalSigningRegression.call .precommitMsg false).after
  returned := (NormalSigningRegression.call .precommitMsg false).returned
  result := rfl
  authentic := ⟨rfl,rfl,rfl,rfl,rfl⟩

/-- Positive witness: initialized canonical trace, a real landing after recovery and a real
fresh stock Signer.sign at its next height, by the still-active key 8 rather than old key 7. -/
theorem post_recovery_landing_signs :
    Run NonVacuity.world0 finish NormalSigningRegression.archive1 ∧
    NormalSigning.Run NonVacuity.world0 finish ∧
    finish.inbox.generation = 1 ∧ finish.inbox.checkpoint.height = 22 ∧
    EngineRequest signingPrefix event.device.key event.message ∧
    event.after.log ≠ event.device.state.log ∧ event.message.height = 23 ∧ event.device.key ≠ 7 := by
  refine ⟨complete_history,run_normal complete_history,rfl,by decide +kernel,?_,?_,rfl,by decide⟩
  · refine ⟨rfl,rfl,by decide +kernel,?_⟩
    exact (NormalSigningRegression.engine_request .precommitMsg false).2.2.2
  · exact NormalSigningRegression.call_fresh .precommitMsg false

end Etna.Design.CanonicalHistoryRegression
