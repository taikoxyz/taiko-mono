import EtnaProofs.RegistryHistory
import EtnaProofs.HistoricalContext
import EtnaProofs.ProtocolState
import EtnaWitnesses.Regressions.FirstBatch

namespace Etna.Design.SecondBatch
open RegistryHistory

def verifyEvidence (key : Hash) (vote : Staking.Vote) (sig : Hash) : Bool :=
  (key == 7 && ((vote.blockId == 10 && sig == 101) || (vote.blockId == 11 && sig == 102))) ||
  (key == 8 && ((vote.blockId == 10 && sig == 201) || (vote.blockId == 11 && sig == 202)))
def emptyRegistry : RegistryHistory.State :=
  { RegistryHistory.empty with verify := verifyEvidence,activationDelay := 2,exitDelay := 1,withdrawalDelay := 1 }

def registered : RegistryHistory.State := (RegistryHistory.register emptyRegistry 7 51 100 10).getD emptyRegistry
theorem register_allocates_slot : (RegistryHistory.register emptyRegistry 7 51 100 10).isSome = true ∧
    registered.nextId = 1 ∧ (registered.slots 0).key = 7 := by decide +kernel
theorem duplicate_key_rejected : (RegistryHistory.register registered 7 52 100 11).isNone = true := by decide +kernel
theorem same_block_replaces_snapshot : latestSnapshot (recordSnapshot 11 [⟨8,100,0,1000⟩]
    (recordSnapshot 11 [⟨7,100,0,1000⟩] [])) 11 = some ⟨11,[⟨8,100,0,1000⟩]⟩ := by decide +kernel
theorem later_slot_change_preserves_snapshot : latestSnapshot (recordSnapshot 12 [⟨8,100,0,1000⟩]
    (recordSnapshot 11 [⟨7,100,0,1000⟩] [])) 11 = some ⟨11,[⟨7,100,0,1000⟩]⟩ := by decide +kernel

def parameters : HistoricalContext.Parameters := ⟨12,3,10,10,3⟩
/-- Initialized with L = 3 and the decoded configuration that recovery reads. -/
def sourceInbox : Etna.Design.State :=
  { FirstBatch.inbox with
    origin := ⟨0,14,14⟩,origins := [(0,⟨0,14,14⟩)],snapshot := 12,epochLen := 3,configuration := ⟨10,10,3,3600⟩,
    forcedFee := 1,forcedThreshold := 50,protocolFeeRecipient := 9 }
theorem context_builds_from_history : (HistoricalContext.build sourceInbox registered parameters [14]).isSome = true := by decide +kernel
theorem missing_origin_rejected : (HistoricalContext.build { sourceInbox with origins := [] } registered parameters [14]).isNone = true := by decide +kernel
theorem archive_lookup_matches : HistoricalContext.anchorAt [10,12,15] 0 = 10 ∧ HistoricalContext.anchorAt [10,12,15] 2 = 15 := by decide +kernel

def settled : Etna.Design.State := { FirstBatch.inbox with snapshot := 13 }
def requested : RegistryHistory.State := (RegistryHistory.edit registered settled 0 12 (.requestExit 51)).getD registered
def confirmed : RegistryHistory.State := (RegistryHistory.edit requested settled 0 14 .confirm).getD requested
def released : RegistryHistory.State := (RegistryHistory.edit confirmed settled 0 15 (.withdraw 51)).getD confirmed
def reused : RegistryHistory.State := (RegistryHistory.register released 8 52 100 16).getD released
theorem confirmation_does_not_checkpoint : confirmed.history = requested.history := by decide +kernel
theorem freed_slot_reused_first : released.free = [0] ∧ reused.free = [] ∧ reused.nextId = 1 ∧ (reused.slots 0).key = 8 := by decide +kernel
theorem withdrawal_does_not_release_key : (RegistryHistory.register released 7 52 100 16).isNone = true := by decide +kernel
theorem old_snapshot_survives_reuse : ((latestSnapshot reused.history 10).map (fun cp => (cp.entries[0]?).map Committee.Entry.key)) = some (some 7) := by decide +kernel
theorem missing_snapshot_rejected : (HistoricalContext.build sourceInbox { registered with history := [] } parameters [14]).isNone = true := by decide +kernel
theorem inactive_genesis_committee_rejected : (HistoricalContext.build sourceInbox registered { parameters with genesisCutoff := 10 } [14]).isNone = true := by decide +kernel

def oldA : Staking.Vote := ⟨FirstBatch.deployment,0,1,0,2,10⟩
def oldB : Staking.Vote := { oldA with blockId := 11 }
theorem stale_slot_evidence_rejected :
    (RegistryHistory.editBond emptyRegistry settled 17 (reused.slots 0) (.slash oldA oldB 101 102)).isNone = true := by decide +kernel

/-- The same call is rejected or accepted only by the Inbox's own initialization state:
an Inbox without its generation-0 origin record is uninitialized. -/
def uninitialized : Etna.Design.State := { settled with origins := [] }

theorem slash_before_init_rejected :
    (RegistryHistory.edit registered uninitialized 0 17 (.slash oldA oldB 101 102)).isNone = true ∧
    ((RegistryHistory.edit registered settled 0 17 (.slash oldA oldB 101 102)).map (fun s => (s.slots 0).stake)) = some 0 := by
  decide +kernel

theorem confirm_before_init_rejected :
    (RegistryHistory.edit requested uninitialized 0 14 .confirm).isNone = true ∧
    ((RegistryHistory.edit requested settled 0 14 .confirm).map (fun s => (s.slots 0).confirmedAt)) = some (some 14) := by
  decide +kernel

/-- The bounty is the registry immutable: a deployment with an out-of-range value cannot
slash at all, and no call argument can override it. -/
theorem bounty_is_registry_immutable :
    (RegistryHistory.edit { registered with slashBountyBps := 10001 } settled 0 17 (.slash oldA oldB 101 102)).isNone = true ∧
    registered.slashBountyBps = 1000 := by decide +kernel

theorem foreign_deployment_evidence_rejected :
    (RegistryHistory.editBond emptyRegistry settled 17 (registered.slots 0)
      (.slash { oldA with domain := ⟨2,167000,10,20⟩ } { oldB with domain := ⟨2,167000,10,20⟩ } 101 102)).isNone = true := by decide +kernel

theorem historical_evidence_after_recovery_admitted :
    ((RegistryHistory.editBond emptyRegistry { settled with generation := 1 } 17 (registered.slots 0)
      (.slash oldA oldB 101 102)).map Staking.Bond.stake) = some 0 := by decide +kernel

def recoveryConfig : Recovery.Config := ⟨99,0⟩
def initialWorld : ProtocolState.World :=
  ⟨sourceInbox,registered,[],Committee.recoverySchedule ⟨0,12,[Staking.toEntry (registered.slots 0)]⟩,14,
    ⟨fun _ => 77,Committee.Record.cutoff,recoveryConfig⟩⟩
def recoveryRequest : Recovery.Request := ⟨0,0,[],[],0,limit256-1⟩
def recoveryOrigin : Origin := ⟨0,20,20⟩
def afterRecovery : ProtocolState.World := (ProtocolState.recover initialWorld recoveryRequest recoveryOrigin true true).getD initialWorld

theorem unified_recovery_keeps_settlement : afterRecovery.inbox.checkpoint = initialWorld.inbox.checkpoint ∧
    afterRecovery.inbox.generation = 1 ∧ afterRecovery.schedule.pending = none := by decide +kernel

theorem unified_owner_rejected : (ProtocolState.recover initialWorld recoveryRequest recoveryOrigin false true).isNone = true := by decide +kernel

theorem independent_exclusion_entrypoint_absent : ProtocolState.publicEdit .forceExit = false ∧
    ProtocolState.publicEdit (.recheck 0) = false := by decide +kernel

theorem initial_world_core : ProtocolState.Core initialWorld := by
  refine ⟨⟨?_,by unfold FeeConserved; decide +kernel,by decide +kernel,?_⟩,⟨?_,?_,?_,?_,by decide +kernel⟩,rfl⟩
  · unfold Settlement.StateValid OnGrid
    decide +kernel
  · intro record member
    have same : record = FirstBatch.genesisRecord := by
      simpa only [initialWorld,sourceInbox,FirstBatch.inbox,List.mem_singleton] using member
    subst record
    decide +kernel
  · unfold RegistryHistory.KeysValid
    decide +kernel
  · intro id bound _
    change id < 1 at bound
    have same : id = 0 := by omega
    subst id
    decide +kernel
  · unfold RegistryHistory.Ordered
    decide +kernel
  · unfold RegistryHistory.CurrentSnapshot
    decide +kernel

def archive : List Nat := [14,15]
def parentHeader : BlockValidity.Header := ⟨0,1000,10000,0,0,14,⟨14,14,24,0,1000,0,0⟩⟩
def historicalRules : BlockValidity.Rules := { FirstBatch.rules with
  consensus := HistoricalContext.derive sourceInbox registered parameters archive, referenceNumber := 16,referenceHash := 1600 }
instance : DecidablePred historicalRules.signature := fun _ => inferInstanceAs (Decidable True)
def historicalBlock : BlockValidity.Block := ⟨⟨1,2001,20001,201,0,15,⟨15,15,25,0,1000,0,0⟩⟩,
  1000,none,FirstBatch.deployment,0,15,100,100,true,none,12,12,25,0,
  [⟨FirstBatch.deployment,0,1,0,2,201,7⟩],none,.completedEmpty⟩
def historicalStatement : StatementData := Settlement.statement historicalRules parentHeader [historicalBlock] [111]
def historicalEnv : LandingEnv := ⟨17,1600,true,[111],[(.risc0,true),(.sp1,true)],historicalStatement⟩
def landedWorld : ProtocolState.World := (ProtocolState.land initialWorld historicalStatement.input [] historicalEnv).getD initialWorld

theorem historical_block_valid : BlockValidity.Valid historicalRules parentHeader historicalBlock := by decide +kernel

theorem historical_context_builds : HistoricalContext.build sourceInbox registered parameters archive = some historicalRules.consensus := by
  unfold HistoricalContext.build
  rw [ite_eq_left (by decide +kernel : HistoricalContext.Ready sourceInbox registered parameters archive)]
  rfl

theorem historical_landing_step : ProtocolState.Step initialWorld landedWorld := by
  exact ProtocolState.Step.landing (w := initialWorld) (s := applyLanding sourceInbox historicalStatement.input)
    (i := historicalStatement.input) (leaves := []) (e := historicalEnv) (by decide) (by decide +kernel)

theorem snapshot_comes_from_typed_history : landedWorld.inbox.snapshot = 12 := by
  have result := ProtocolState.accepted_snapshot_from_history
    (w := initialWorld) (t := applyLanding sourceInbox historicalStatement.input) (i := historicalStatement.input)
    (leaves := []) (e := historicalEnv) (r := historicalRules) (p := parentHeader) (bs := [historicalBlock])
    (blobs := [111]) (cfg := parameters) (archive := archive)
    (by decide +kernel) ⟨by decide +kernel,rfl⟩ rfl historical_context_builds (by decide)
  exact result.1

def aboveRequest : Recovery.Request := ⟨0,1,[],[],0,limit256-1⟩
def aboveOrigin : Origin := ⟨1,20,20⟩
def aboveRecovered : ProtocolState.World := (ProtocolState.recover landedWorld aboveRequest aboveOrigin true true).getD landedWorld

theorem above_recovery_step : ProtocolState.Step landedWorld aboveRecovered := by
  exact ProtocolState.Step.recovery (w := landedWorld)
    (s := Recovery.applyRecovery (ProtocolState.recoveryView landedWorld) aboveRequest recoveryConfig aboveOrigin)
    (a := aboveRequest) (r := aboveOrigin) (owner := true) (externalOK := true)
    (by decide) (by decide +kernel)

def restored : ProtocolState.World := ProtocolState.applyRollback aboveRecovered FirstBatch.genesisRecord 12 21

theorem rollback_step : ProtocolState.Step aboveRecovered restored := by
  exact ProtocolState.Step.rollback FirstBatch.genesisRecord 12 21 (by decide) (by decide +kernel) (by decide +kernel)

theorem rollback_requires_new_recovery : restored.inbox.origin.height = 1 ∧ restored.inbox.checkpoint.height = 0 ∧
    Etna.Design.land restored.inbox historicalStatement.input [] historicalEnv = none := by decide +kernel

def againRequest : Recovery.Request := ⟨1,0,[],[],2,limit256-1⟩
def againOrigin : Origin := ⟨0,22,22⟩
def again : ProtocolState.World := (ProtocolState.recover restored againRequest againOrigin true true).getD restored

theorem second_recovery_step : ProtocolState.Step restored again := by
  exact ProtocolState.Step.recovery (w := restored)
    (s := Recovery.applyRecovery (ProtocolState.recoveryView restored) againRequest recoveryConfig againOrigin)
    (a := againRequest) (r := againOrigin) (owner := true) (externalOK := true)
    (by decide) (by decide +kernel)

def admittedInbox : State := (Forced.enqueue again.inbox 0 1000000000 true).getD again.inbox
def admittedWorld : ProtocolState.World := ProtocolState.enqueued again admittedInbox 55 230 23

theorem enqueue_step : ProtocolState.Step again admittedWorld := by
  exact ProtocolState.Step.enqueue (w := again) (s := admittedInbox) (hash := 55) (timestamp := 230)
    (now := 23) (raw := 0) (paid := 1000000000) (refund := true)
    (by decide) (by decide) (by decide) (by rfl)

def sweptInbox : State := (Forced.sweep admittedWorld.inbox true).getD admittedWorld.inbox
def sweptWorld : ProtocolState.World := ProtocolState.landed admittedWorld sweptInbox 24

theorem sweep_step : ProtocolState.Step admittedWorld sweptWorld := by
  exact ProtocolState.Step.sweep (w := admittedWorld) (s := sweptInbox) (now := 24)
    (transfer := true) (by decide) (by rfl)

def nextRegistry : RegistryHistory.State := (RegistryHistory.register sweptWorld.registry 8 52 100 25).getD sweptWorld.registry
def nextWorld : ProtocolState.World := ProtocolState.registered sweptWorld nextRegistry 25

theorem registration_step : ProtocolState.Step sweptWorld nextWorld := by
  exact ProtocolState.Step.registration (w := sweptWorld) (s := nextRegistry) (key := 8) (owner := 52)
    (amount := 100) (now := 25) (by decide) (by rfl)

theorem mixed_trace : ProtocolState.Trace initialWorld nextWorld :=
  .step (.step (.step (.step (.step (.step (.step (.refl _) historical_landing_step)
    above_recovery_step) rollback_step) second_recovery_step) enqueue_step) sweep_step) registration_step

theorem mixed_trace_core : ProtocolState.Core nextWorld := ProtocolState.trace_preserves_core initial_world_core mixed_trace

theorem mixed_trace_preserves_old_snapshot : RegistryHistory.latestSnapshot nextWorld.registry.history 12 =
    RegistryHistory.latestSnapshot initialWorld.registry.history 12 :=
  ProtocolState.trace_preserves_old_snapshot mixed_trace 12 (by decide)

theorem mixed_generation_and_queue : nextWorld.inbox.generation = 2 ∧
    nextWorld.inbox.origins.map Prod.fst = [0,1,2] ∧ nextWorld.queue.map Prod.fst = [0] ∧
    nextWorld.inbox.ethBalance = 0 ∧ nextWorld.inbox.swept = 1000000000 := by decide +kernel

theorem mixed_trace_advances_recovery_nonce :
    initialWorld.inbox.recoveryNonce = 0 ∧ aboveRecovered.inbox.recoveryNonce = 1 ∧
    restored.inbox.recoveryNonce = 2 ∧ againRequest.nonce = 2 ∧ nextWorld.inbox.recoveryNonce = 3 := by
  decide +kernel

def editedRegistry : RegistryHistory.State :=
  (RegistryHistory.edit nextWorld.registry nextWorld.inbox 0 26 (.requestExit 51)).getD nextWorld.registry
def editedWorld : ProtocolState.World := ProtocolState.registered nextWorld editedRegistry 26

theorem modification_step : ProtocolState.Step nextWorld editedWorld := by
  exact ProtocolState.Step.modification (w := nextWorld) (s := editedRegistry) (id := 0)
    (now := 26) (action := .requestExit 51) (by decide) rfl (by rfl)

theorem mixed_lifecycle_trace : ProtocolState.Trace initialWorld editedWorld := .step mixed_trace modification_step

theorem mixed_lifecycle_core : ProtocolState.Core editedWorld :=
  ProtocolState.trace_preserves_core initial_world_core mixed_lifecycle_trace

def confirmationWorld : ProtocolState.World := { initialWorld with inbox := settled,registry := confirmed }
def confirmationRollback : ProtocolState.World := ProtocolState.applyRollback confirmationWorld FirstBatch.genesisRecord 12 15

theorem rollback_clears_uncovered_confirmation : (confirmationWorld.registry.slots 0).confirmedAt = some 14 ∧
    (confirmationRollback.registry.slots 0).confirmedAt = none ∧
    confirmationRollback.registry.usedKeys = confirmationWorld.registry.usedKeys ∧
    confirmationRollback.registry.history = confirmationWorld.registry.history := by decide +kernel

-- Rollback advances the nonce, so restoring the generation/checkpoint cannot revive an old authorization.
def restoredWithoutRecovery : ProtocolState.World := ProtocolState.applyRollback landedWorld FirstBatch.genesisRecord 12 18

theorem rollback_nonce_prevents_authorization_revival :
    (ProtocolState.recover landedWorld recoveryRequest ⟨0,19,19⟩ true true).isNone = true ∧
    (ProtocolState.recover restoredWithoutRecovery recoveryRequest ⟨0,19,19⟩ true true).isNone = true := by decide +kernel
end Etna.Design.SecondBatch
