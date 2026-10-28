import EtnaProofs.Consensus
import EtnaProofs.BlockValidity
import EtnaProofs.Settlement

namespace Etna.Design.FirstBatch
open Consensus

def deployment : Domain := ⟨1,167000,10,20⟩
def alice : Committee.Entry := ⟨1,100,0,1000⟩
def bob : Committee.Entry := ⟨2,100,0,1000⟩
def ctx : Context := ⟨deployment,0,0,10,1,3,10,10,3,
  (fun cutoff => if cutoff ≤ 1 then [alice] else [bob]), (fun h => h+10)⟩
def vote (key : Hash) : Vote := ⟨deployment,0,1,0,2,99,key⟩

def auth (_ : Vote) : Prop := True
instance : DecidablePred auth := fun _ => inferInstanceAs (Decidable True)

theorem ordinary_handover : (activeAt ctx 1).members = [alice] ∧ (activeAt ctx 2).members = [alice] ∧
    (activeAt ctx 3).members = [alice] ∧ (activeAt ctx 4).members = [bob] := by decide +kernel
theorem valid_commit : CommitValid ctx auth 1 0 99 [vote 1] := by decide +kernel
theorem duplicate_signers_rejected : ¬ CommitValid ctx auth 1 0 99 [vote 1,vote 1] := by decide +kernel
theorem nonmember_rejected : ¬ CommitValid ctx auth 1 0 99 [vote 2] := by decide +kernel
theorem future_generation_rejected : ¬ CommitValid ctx auth 1 0 99 [{ vote 1 with generation := 1 }] := by decide +kernel
theorem foreign_deployment_rejected : ¬ CommitValid ctx auth 1 0 99 [{ vote 1 with domain := ⟨2,167000,10,20⟩ }] := by decide +kernel

-- Bob has exactly 2/3 of the selected power: that alone must fail.
def weighted : Context := { ctx with registry := fun _ => [alice,{ bob with stake := 200 }] }
theorem exact_two_thirds_rejected : ¬ CommitValid weighted auth 1 0 99 [vote 2] := by
  simp [CommitValid, ElectionValid, activeAt, initial, selected, weighted, ctx, epoch, switchHeight,
    Committee.election, Committee.chosen, Committee.eligible, Committee.rank,
    signedPower, Committee.totalPower, Committee.power, VoteValid, auth, vote, alice, bob]
  all_goals decide +kernel
theorem strict_quorum_accepted : CommitValid weighted auth 1 0 99 [vote 1,vote 2] := by
  simp [CommitValid, ElectionValid, activeAt, initial, selected, weighted, ctx, epoch, switchHeight,
    Committee.election, Committee.chosen, Committee.eligible, Committee.rank,
    signedPower, Committee.totalPower, Committee.power, VoteValid, auth, vote, alice, bob]
  all_goals decide +kernel

def recovered : Context := { ctx with generation := 1,originHeight := 2,originBlock := 20, anchorAt := fun h => if h ≤ 2 then h+10 else h+20 }
theorem recovery_cancels_old_pending : (activeAt recovered 3).cutoff = 20 ∧ (activeAt recovered 4).cutoff = 20 := by decide +kernel
-- Recovery's first block is S(2)=5; it still derives a new committee for height 7.
def onSwitch : Context := { ctx with generation := 1,originHeight := 4,originBlock := 20, anchorAt := fun h => if h ≤ 4 then h+10 else h+20 }
theorem recovery_first_switch : (activeAt onSwitch 5).cutoff = 20 ∧ (activeAt onSwitch 6).cutoff = 20 ∧
    (activeAt onSwitch 7).cutoff = 20 ∧
    (activeAt onSwitch 5).targetEpoch = 1 ∧ (activeAt onSwitch 6).targetEpoch = 1 ∧
    (activeAt onSwitch 7).targetEpoch = 2 := by decide +kernel
theorem recovery_origin_dominates_old_anchor : onSwitch.anchorAt 4 < onSwitch.originBlock ∧
    (Consensus.normal onSwitch 2).cutoff = 20 := by decide +kernel
open BlockValidity

def anchor (h : Nat) : Anchor := ⟨h+10,h+10,h+20,0,1000,0,0⟩
def parent : Header := ⟨0,1000,10000,0,0,10,anchor 0⟩
def block1 : Block := ⟨⟨1,1001,10001,99,0,11,anchor 1⟩,1000,none,deployment,0,11,
  100,100,true,none,1,1,21,0,[vote 1],none,.completedEmpty⟩
def rules : Rules := ⟨ctx,1,77,1200,60,3600,20,200,
  (fun record => record.cutoff),auth,(fun _ => true),(fun _ _ => true),
  (fun _ _ => true),(fun _ => true),(fun _ _ => true),(fun _ _ => true),(fun _ => 77),(fun _ _ => true)⟩
instance : DecidablePred rules.signature := fun _ => inferInstanceAs (Decidable True)
theorem valid_first_block : Valid rules parent block1 := by decide +kernel
theorem wrong_parent_rejected : ¬ Valid rules parent { block1 with parentHash := 777 } := by decide +kernel
theorem first_last_block_id_rejected : ¬ Valid rules parent { block1 with lastBlockId := some 0 } := by decide +kernel
theorem missing_anchor_rejected : ¬ Valid rules parent { block1 with anchorWitness := false } := by decide +kernel
theorem wrong_validators_rejected : ¬ Valid rules parent { block1 with validatorsHash := 999 } := by decide +kernel
theorem wrong_next_validators_rejected : ¬ Valid rules parent { block1 with nextValidatorsHash := 999 } := by decide +kernel
theorem fi_jump_rejected : ¬ Valid rules parent { block1 with header := { block1.header with cursor := 1 } } := by decide +kernel
theorem single_block_chain : Chain rules parent [block1] := by decide +kernel

def block2 : Block := ⟨⟨2,1002,10002,100,0,12,anchor 2⟩,1001,some 99,deployment,0,12,
  100,100,true,some ⟨⟨1,11,[bob]⟩,22⟩,1,1,22,0,[{ vote 1 with height := 2,blockId := 100 }],none,.completedEmpty⟩
def block3 : Block := ⟨⟨3,1003,10003,101,0,13,anchor 3⟩,1002,some 100,deployment,0,13,
  100,100,true,none,1,11,23,0,[{ vote 1 with height := 3,blockId := 101 }],none,.completedEmpty⟩
def block4 : Block := ⟨⟨4,1004,10004,102,0,14,anchor 4⟩,1003,some 101,deployment,0,14,
  100,100,true,none,11,11,24,0,[{ vote 2 with height := 4,blockId := 102 }],none,.completedEmpty⟩
theorem handover_chain : Chain rules parent [block1,block2,block3,block4] := by decide +kernel
theorem missing_committee_witness_rejected : ¬ Valid rules block1.header { block2 with committeeWitness := none } := by decide +kernel
theorem old_committee_rejected : ¬ Valid rules block3.header { block4 with votes := [{ vote 1 with height := 4,blockId := 102 }] } := by decide +kernel
/-- The batch proof origin's anchor is the authenticated history value at its height: a
forged origin anchor equal to block 2's can no longer drop block 2's anchor witness. -/
theorem forged_origin_anchor_rejected :
    ¬ BlockValidity.Valid rules { block1.header with anchor := anchor 2 } { block2 with anchorWitness := false } ∧
    ¬ BlockValidity.Valid rules block1.header { block2 with anchorWitness := false } ∧
    BlockValidity.Valid rules block1.header block2 := by
  decide +kernel

theorem oversize_rejected : ¬ Valid rules parent { block1 with blockBytes := 124001 } := by decide +kernel
theorem wrong_fee_share_rejected : ¬ Valid rules parent { block1 with feeShare := 99 } := by decide +kernel

def batch : List Block := [block1,block2,block3,block4]
def publicStatement : StatementData := Settlement.statement rules parent batch [111]
theorem chain_derives_certificate : CertifiedTable 1 publicStatement (cuts parent batch) :=
  Settlement.chain_certified (by decide +kernel) (by decide) (by decide)

def genesisRecord : Checkpoint := ⟨0,1000,0,0,0,0⟩
def inbox : State :=
  { domain := deployment,committeeConfig := 77,gridK := 1,generation := 0,
    origin := ⟨0,10,10⟩,origins := [(0,⟨0,10,10⟩)],checkpoint := genesisRecord,records := [genesisRecord],
    head := 0,tail := 0,snapshot := 1,ethBalance := 0,feeAdmissions := 0,forcedETH := 0,swept := 0,
    signals := [⟨0,1000,10000⟩],maxBatchBlocks := 100 }
def env : LandingEnv := ⟨21,200,true,[111],[(.risc0,true),(.sp1,true)],publicStatement⟩
def leaves : List Leaf := gridLeaves 1 0 4 (cuts parent batch)
def at1 : State := applyLanding inbox (Settlement.statement rules parent [block1] [111]).input

def at2 : State := applyLanding at1 (Settlement.statement rules parent [block1,block2] [111]).input
def at3 : State := applyLanding at2 (Settlement.statement rules parent [block1,block2,block3] [111]).input
theorem all_frontiers_accept_same_transaction : land inbox publicStatement.input leaves env = some (applyLanding inbox publicStatement.input) ∧
    land at1 publicStatement.input leaves env = some (applyLanding at1 publicStatement.input) ∧
    land at2 publicStatement.input leaves env = some (applyLanding at2 publicStatement.input) ∧
    land at3 publicStatement.input leaves env = some (applyLanding at3 publicStatement.input) := by decide +kernel
theorem corrupt_frontier_rejected : land at2 publicStatement.input [cutLeaf 1 block1.header.cut, .word 999,cutLeaf 3 block3.header.cut] env = none := by decide +kernel

theorem composed_frontier : (cuts parent batch).getD 2 default =
    ⟨at2.checkpoint.elHash,at2.checkpoint.cometHash,at2.head⟩ :=
  Settlement.accepted_frontier_from_valid_chain
    (s := at2) (t := applyLanding at2 publicStatement.input) (i := publicStatement.input)
    (leaves := leaves) (e := env) (r := rules) (p := parent) (bs := batch) (blobs := [111])
    (by decide +kernel)
    ⟨by decide +kernel,rfl⟩ rfl (by decide) (by decide) rfl (by decide) (by decide) (by decide +kernel)
theorem terminal_snapshot_and_signal : (applyLanding at2 publicStatement.input).snapshot = 11 ∧
    (applyLanding at2 publicStatement.input).signals.getLast? = some ⟨4,1004,10004⟩ := by decide +kernel
theorem composed_state_invariant : Settlement.StateValid (applyLanding at2 publicStatement.input) := by
  apply Settlement.landing_preserves_state (s := at2) (i := publicStatement.input)
    (leaves := leaves) (e := env)
  · unfold Settlement.StateValid OnGrid
    decide +kernel
  · decide +kernel
theorem unbound_blobs_rejected : ¬ Settlement.BatchValid { rules with batchPayloadValid := fun _ _ => false } parent batch [111] := by
  intro h
  cases h.2
theorem wrong_config_opening_rejected : ¬ Valid { rules with configHash := fun _ => 78 } parent block1 := by decide +kernel
theorem unauthenticated_history_rejected : ¬ Valid { rules with historyAuthenticated := fun _ _ => false } parent block1 := by decide +kernel
theorem singleton_timeout_not_a_skip : ¬ Valid { rules with forcedDelay := 1 } parent
    { block1 with header := { block1.header with anchor := { block1.header.anchor with tail := 1 } }, forced := some ⟨0,⟨50,0,0⟩,true,50,10,true,none,false,0⟩,singleton := .unavailable } := by decide +kernel
theorem composed_snapshot_monotone : at2.snapshot ≤ (applyLanding at2 publicStatement.input).snapshot := by
  apply Settlement.accepted_snapshot_monotone
    (s := at2) (t := applyLanding at2 publicStatement.input) (i := publicStatement.input)
    (leaves := leaves) (e := env) (r := rules) (p := parent) (bs := batch) (blobs := [111])
  · decide +kernel
  · exact ⟨by decide +kernel,rfl⟩
  · rfl
  · decide
  · intro a b order
    change a+10 ≤ b+10
    omega
  · decide +kernel

-- The retained block's anchor is 14 < R=20. The new generation starts at S(2)=5.
def recoveryAnchor (h : Nat) : Anchor := ⟨h+20,h+20,h+30,4,1004,1,0⟩
def recoveryRules : Rules := { rules with consensus := onSwitch,referenceNumber := 30,referenceHash := 300, committeeHash := fun record => record.targetEpoch*100+record.cutoff }
instance : DecidablePred recoveryRules.signature := fun _ => inferInstanceAs (Decidable True)
def recovery5 : Block := ⟨⟨5,1005,10005,105,0,25,recoveryAnchor 5⟩,1004,none,deployment,1,25,
  100,100,true,some ⟨⟨2,20,[bob]⟩,35⟩,120,120,35,0,
  [{ vote 2 with generation := 1,height := 5,blockId := 105 }],none,.completedEmpty⟩
def recovery6 : Block := ⟨⟨6,1006,10006,106,0,26,recoveryAnchor 6⟩,1005,some 105,deployment,1,26,
  100,100,true,none,120,220,36,0,
  [{ vote 2 with generation := 1,height := 6,blockId := 106 }],none,.completedEmpty⟩
def recovery7 : Block := ⟨⟨7,1007,10007,107,0,27,recoveryAnchor 7⟩,1006,some 106,deployment,1,27,
  100,100,true,none,220,220,37,0,
  [{ vote 2 with generation := 1,height := 7,blockId := 107 }],none,.completedEmpty⟩
theorem recovery_switch_chain : Chain recoveryRules block4.header [recovery5,recovery6,recovery7] := by decide +kernel

theorem recovery_wrong_switch_root_rejected : ¬ Valid recoveryRules block4.header
    { recovery5 with committeeWitness := some ⟨⟨2,20,[bob]⟩,36⟩ } := by decide +kernel

-- This is the result of the tempting mutant that drops max(anchorD, originBlock).
theorem unfloored_cutoff_differs :
    (Consensus.selected onSwitch 2 (onSwitch.anchorAt 4)).cutoff = 14 ∧
    (Consensus.normal onSwitch 2).cutoff = 20 := by decide +kernel
end Etna.Design.FirstBatch
