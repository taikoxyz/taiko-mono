import EtnaProofs.Deployment
import EtnaWitnesses.Regressions.SecondBatch

/-! Kernel-checked regressions for the deployment/recovery model fixes: a valid K = 2 chain
whose first block includes a forced transaction (cursor 0 → 1) landing twice on the grid
with overlap, and a deployment-built context at generation 1 (post-recovery origin path). -/
namespace Etna.Design.ThirdBatch

/-! K = 2 with an FI inclusion: block 1 includes queue entry 0, so the cursor advances. -/

def rules2 : BlockValidity.Rules := { FirstBatch.rules with gridK := 2 }
instance : DecidablePred rules2.signature := fun _ => inferInstanceAs (Decidable True)

def included : Forced.Witness := ⟨0,⟨50,0,0⟩,true,50,10,true,some 50,true,10⟩
def withCursor (b : BlockValidity.Block) : BlockValidity.Block := { b with header := { b.header with cursor := 1 } }
def fi1 : BlockValidity.Block :=
  { FirstBatch.block1 with
    header := { FirstBatch.block1.header with cursor := 1,anchor := { FirstBatch.anchor 1 with tail := 1 } },
    forced := some included }
def fi2 : BlockValidity.Block := withCursor FirstBatch.block2
def fi3 : BlockValidity.Block := withCursor FirstBatch.block3
def fi4 : BlockValidity.Block := withCursor FirstBatch.block4
def fiBatch : List BlockValidity.Block := [fi1,fi2,fi3,fi4]

theorem k2_fi_chain : BlockValidity.Chain rules2 FirstBatch.parent fiBatch := by decide +kernel

theorem k2_fi_cursor_steps : (BlockValidity.cuts FirstBatch.parent fiBatch).map Cut.cursor = [0,1,1,1,1] := by decide +kernel

def inbox2 : State := { FirstBatch.inbox with gridK := 2,tail := 1 }
def half : StatementData := Settlement.statement rules2 FirstBatch.parent [fi1,fi2] [111]
def full : StatementData := Settlement.statement rules2 FirstBatch.parent fiBatch [111]
def env (s : StatementData) : LandingEnv := ⟨21,200,true,[111],[(.risc0,true),(.sp1,true)],s⟩
def fullLeaves : List Leaf := gridLeaves 2 0 4 (BlockValidity.cuts FirstBatch.parent fiBatch)
def at2 : State := applyLanding inbox2 half.input
def at4 : State := applyLanding at2 full.input

/-- The grid-2 landing (0,2] lands first; the overlapping (0,4] then lands at c = 2 through
the leaf at 2, and also lands directly from c = 0. -/
theorem k2_overlapping_landings :
    land inbox2 half.input [] (env half) = some at2 ∧
    land at2 full.input fullLeaves (env full) = some at4 ∧
    land inbox2 full.input fullLeaves (env full) = some (applyLanding inbox2 full.input) ∧
    fullLeaves = [cutLeaf 2 fi2.header.cut] := by decide +kernel

theorem k2_corrupt_overlap_leaf_rejected :
    land at2 full.input [cutLeaf 2 { fi2.header.cut with cursor := 0 }] (env full) = none ∧
    land at2 full.input [] (env full) = none := by decide +kernel

theorem k2_off_grid_endpoint_rejected :
    land inbox2 (Settlement.statement rules2 FirstBatch.parent [fi1,fi2,fi3] [111]).input []
      (env (Settlement.statement rules2 FirstBatch.parent [fi1,fi2,fi3] [111])) = none := by decide +kernel

theorem k2_fi_head_advances : inbox2.head = 0 ∧ at2.head = 1 ∧ at4.head = 1 ∧ at4.checkpoint.height = 4 ∧
    at4.records.map Checkpoint.height = [4,2,0] := by decide +kernel

theorem k2_frontier_from_valid_chain : (BlockValidity.cuts FirstBatch.parent fiBatch).getD 2 default =
    ⟨at2.checkpoint.elHash,at2.checkpoint.cometHash,at2.head⟩ :=
  Settlement.accepted_frontier_from_valid_chain
    (s := at2) (t := at4) (i := full.input) (leaves := fullLeaves) (e := env full) (r := rules2)
    (p := FirstBatch.parent) (bs := fiBatch) (blobs := [111])
    (by decide +kernel) ⟨k2_fi_chain,rfl⟩ rfl (by decide) (by decide) rfl (by decide) (by decide) (by decide +kernel)

theorem k2_terminal_head_from_cursor : at4.head = (BlockValidity.terminal FirstBatch.parent fiBatch).cursor ∧
    at4.snapshot = (Consensus.activeAt rules2.consensus 4).cutoff :=
  have result := Settlement.accepted_terminal_from_valid_chain
    (s := at2) (t := at4) (i := full.input) (leaves := fullLeaves) (e := env full) (r := rules2)
    (p := FirstBatch.parent) (bs := fiBatch) (blobs := [111]) (by decide +kernel) ⟨k2_fi_chain,rfl⟩ rfl
  ⟨result.2.2.2.1,result.2.2.2.2.1⟩

/-- Both overlapping landings form a certified trace under one context; slot 284 and old
records behave as the trace-level theorems state. -/
theorem k2_certified_trace : Settlement.CertifiedTrace rules2.consensus inbox2 at4 :=
  .step (s := at2) (i := full.input) (leaves := fullLeaves) (e := env full) (r := rules2) (p := FirstBatch.parent)
    (bs := fiBatch) (blobs := [111])
    (.step (s := inbox2) (i := half.input) (leaves := []) (e := env half) (r := rules2) (p := FirstBatch.parent)
      (bs := [fi1,fi2]) (blobs := [111]) (.refl _) (by decide +kernel) rfl ⟨by decide +kernel,rfl⟩ rfl)
    (by decide +kernel) rfl ⟨k2_fi_chain,rfl⟩ rfl

theorem k2_trace_snapshot_and_records : inbox2.snapshot ≤ at4.snapshot ∧ recordAt at4 0 = recordAt inbox2 0 := by
  have trace : Settlement.LandingTrace inbox2 at4 :=
    .step (s := at2) (i := full.input) (leaves := fullLeaves) (e := env full)
      (.step (s := inbox2) (i := half.input) (leaves := []) (e := env half) (.refl _) (by decide +kernel))
      (by decide +kernel)
  refine ⟨(Settlement.certified_trace_snapshot_monotone (by decide) ?_ (Or.inr (by decide +kernel)) k2_certified_trace).1,
    Settlement.trace_preserves_old_records trace 0 (Nat.le_refl _)⟩
  intro a b order
  change a+10 ≤ b+10
  omega

/-! Generation 1: a deployment-built context after recovery, at realistic §10 values. -/

def cfgD : Deployment.Config := ⟨1000000000,1000000000000000000,3,100⟩
def bigRegistry : RegistryHistory.State :=
  (RegistryHistory.register SecondBatch.emptyRegistry 7 51 1000000000000000000 10).getD SecondBatch.emptyRegistry
def zeroRecord : Committee.Record := ⟨0,12,[Staking.toEntry (bigRegistry.slots 0)]⟩
def deployedInbox : State :=
  { SecondBatch.sourceInbox with
    genesisCutoff := 12,committeeZero := 12,configuration := cfgD,committeeZeroRecord := zeroRecord,
    forcedDelay := 60,maxAnchorAge := 1200 }
def configHashD (words : List Encoding.Word) : Hash := if words = Deployment.words deployedInbox cfgD then 77 else 78
def deployed : ProtocolState.World :=
  ⟨deployedInbox,bigRegistry,[],Committee.recoverySchedule zeroRecord,14,⟨configHashD,fun _ => 12,SecondBatch.recoveryConfig⟩⟩

def origin1 : Origin := ⟨0,20,20⟩
def recoveredWorld : ProtocolState.World :=
  (ProtocolState.recover deployed ⟨0,0,[],[],0,limit256-1⟩ origin1 true true).getD deployed

theorem deployed_recover :
    ProtocolState.recover deployed ⟨0,0,[],[],0,limit256-1⟩ origin1 true true = some recoveredWorld := by
  have ok : (ProtocolState.recover deployed ⟨0,0,[],[],0,limit256-1⟩ origin1 true true).isSome = true := by
    decide +kernel
  unfold recoveredWorld
  cases h : ProtocolState.recover deployed ⟨0,0,[],[],0,limit256-1⟩ origin1 true true with
  | none => rw [h] at ok; contradiction
  | some w => rfl

theorem deployed_recovery_step : ProtocolState.Step deployed recoveredWorld :=
  ProtocolState.Step.recovery (w := deployed)
    (s := Recovery.applyRecovery (ProtocolState.recoveryView deployed) ⟨0,0,[],[],0,limit256-1⟩ SecondBatch.recoveryConfig origin1)
    (a := ⟨0,0,[],[],0,limit256-1⟩) (r := origin1) (owner := true) (externalOK := true)
    (by decide) (by decide +kernel)

def archive1 : List Nat := [14,20]
def template1 : BlockValidity.Rules := { SecondBatch.historicalRules with referenceNumber := 21,referenceHash := 2100 }
def rules1 : BlockValidity.Rules := (Deployment.build recoveredWorld cfgD archive1 template1).getD template1
instance : DecidablePred rules1.signature := fun _ => inferInstanceAs (Decidable True)

theorem generation_one_rules_built : Deployment.build recoveredWorld cfgD archive1 template1 = some rules1 := by
  have ok : (Deployment.build recoveredWorld cfgD archive1 template1).isSome = true := by decide +kernel
  unfold rules1
  cases h : Deployment.build recoveredWorld cfgD archive1 template1 with
  | none => rw [h] at ok; contradiction
  | some r => rfl

theorem generation_one_context : recoveredWorld.inbox.generation = 1 ∧ rules1.consensus.generation = 1 ∧
    rules1.consensus.originBlock = 20 ∧ (Consensus.activeAt rules1.consensus 1).cutoff = 20 ∧
    (Consensus.activeAt rules1.consensus 1).members.map Committee.Entry.key = [7] := by decide +kernel

def block1 : BlockValidity.Block := ⟨⟨1,3001,30001,301,0,20,⟨20,20,30,0,1000,1,0⟩⟩,1000,none,FirstBatch.deployment,1,20,
  100,100,true,none,12,12,30,0,[⟨FirstBatch.deployment,1,1,0,2,301,7⟩],none,.completedEmpty⟩
def statement1 : StatementData := Settlement.statement rules1 SecondBatch.parentHeader [block1] [111]
def env1 : LandingEnv := ⟨22,2100,true,[111],[(.risc0,true),(.sp1,true)],statement1⟩
def landed1 : State := applyLanding recoveredWorld.inbox statement1.input
def landedWorld1 : ProtocolState.World := ProtocolState.landed recoveredWorld landed1 22

theorem generation_one_valid_batch : Settlement.BatchValid rules1 SecondBatch.parentHeader [block1] [111] :=
  ⟨by decide +kernel,by decide +kernel⟩

theorem generation_one_landing_step : ProtocolState.Step recoveredWorld landedWorld1 :=
  ProtocolState.Step.landing (w := recoveredWorld) (s := landed1) (i := statement1.input) (leaves := []) (e := env1)
    (by decide +kernel) (show Etna.Design.land recoveredWorld.inbox statement1.input [] env1 = some landed1 by decide +kernel)

/-- HS-06 on the post-recovery origin path: the deployment-built generation-1 context derives
slot 284 = R = 20 and every deployment binding. -/
theorem generation_one_deployed_snapshot : landed1.snapshot = 20 ∧ cfgD = recoveredWorld.inbox.configuration ∧
    Deployment.genesis recoveredWorld.inbox recoveredWorld.registry cfgD archive1 = zeroRecord := by
  have result := Deployment.accepted_deployed_snapshot (w := recoveredWorld) (t := landed1) (i := statement1.input)
    (leaves := []) (e := env1) (cfg := cfgD) (archive := archive1) (template := template1) (r := rules1)
    (p := SecondBatch.parentHeader) (bs := [block1]) (blobs := [111])
    (by decide +kernel) generation_one_rules_built generation_one_valid_batch rfl (by decide)
  refine ⟨?_,result.2.1,result.2.2.2.2.2.1⟩
  rw [result.1]
  decide +kernel

/-- Slot 284 across the recovery: 12 before, R = 20 after the first generation-1 landing. -/
theorem generation_one_snapshot_monotone : deployed.inbox.snapshot ≤ landed1.snapshot := by
  have built := (Deployment.build_success generation_one_rules_built).2.2.2.2.2.2.2
  obtain ⟨c,context,result⟩ := built
  have same : c = rules1.consensus := by rw [result]
  subst same
  exact (ProtocolState.snapshot_monotone_across_recovery deployed_recover (by decide) context
    (.step (s := recoveredWorld.inbox) (i := statement1.input) (leaves := []) (e := env1) (.refl _)
      (by decide +kernel) rfl generation_one_valid_batch rfl)).1

theorem deployed_trace : ProtocolState.Trace deployed landedWorld1 :=
  .step (.step (.refl _) deployed_recovery_step) generation_one_landing_step

theorem deployed_trace_keeps_deployment : landedWorld1.inbox.configuration = cfgD ∧
    landedWorld1.inbox.committeeZeroRecord = zeroRecord ∧ landedWorld1.inbox.maxAnchorAge = 1200 ∧
    Deployment.Constraints landedWorld1.inbox cfgD := by
  have imm := ProtocolState.trace_preserves_immutables deployed_trace
  exact ⟨imm.2.2.2.2.2.2.1,imm.2.2.2.2.2.2.2.1,imm.2.2.2.2.2.2.2.2.1,
    Deployment.trace_preserves_constraints deployed_trace (by decide +kernel)⟩

/-- The mixed SecondBatch lifecycle (landing, recovery, rollback, recovery, FI, registry)
also keeps every immutable and the registry signature adapter. -/
theorem mixed_lifecycle_keeps_adapters : SecondBatch.editedWorld.registry.verify = SecondBatch.verifyEvidence ∧
    SecondBatch.editedWorld.inbox.epochLen = 3 :=
  have imm := ProtocolState.trace_preserves_immutables SecondBatch.mixed_lifecycle_trace
  ⟨imm.2.2.2.2.2.2.2.2.2.2.2.2.2.2.2.1,imm.2.2.2.1⟩

end Etna.Design.ThirdBatch
