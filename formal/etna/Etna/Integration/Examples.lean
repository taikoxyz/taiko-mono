module
public import Etna.Integration.Composition
public import Etna.Integration.Rewards
public import Etna.Committee.Examples
public import Etna.FI.Examples
public import Etna.Landing.Examples
@[expose] public section
namespace Etna.Integration.Examples
open Etna.Committee.Examples

def ctx : Committee.Context := { Committee.Examples.ctx with
  authenticatedAnchor := fun hash anchor =>
    (hash = 101 ∧ anchor = ⟨800,10010,50,0⟩) ∨ (hash = 102 ∧ anchor = ⟨801,10011,51,1⟩) }
def block : Integration.Block ctx := {
  committee := {
    facts := (Committee.Examples.block 1 (by decide)).facts
    anchorEvidence := Or.inl ⟨rfl,rfl⟩
    payloadEvidence := (Committee.Examples.block 1 (by decide)).payloadEvidence }
  envelope := []
  attributes := 123
  stateRoot := 202
  hashBound := by decide }
def secondBlock : Integration.Block ctx := {
  committee := {
    facts := { (Committee.Examples.block 2 (by decide)).facts with anchor := ⟨801,10011,51,1⟩ }
    anchorEvidence := Or.inr ⟨rfl,rfl⟩
    payloadEvidence := (Committee.Examples.block 2 (by decide)).payloadEvidence }
  envelope := [1]
  attributes := 124
  stateRoot := 203
  hashBound := by decide }
def before : State := ⟨initial, 0, 201⟩
def after : State := ⟨⟨1,101,⟨800,10010,50,0⟩,[outgoingRecord]⟩, 1, 202⟩
def secondState : State := ⟨⟨2,102,⟨801,10011,51,1⟩,[outgoingRecord]⟩,1,203⟩
def witness : FI.Witness := ⟨0,⟨10,0⟩,[],[]⟩
def codec : FI.Codec := { FI.exampleCodec with
  decodeEnvelope := fun bytes => if bytes = [] then some (some witness, [[]]) else if bytes = [1] then some (none,[]) else none }
def fiAuth (parent : Nat) : FI.Authentication where
  committedParent := parent
  expectedAttributes := fun p _ => if p = 100 then 123 else 124
  committedRoot := fun hash => if hash = 801 then 10011 else 10010
  anchorTime := fun hash => if hash = 801 then 21 else 20
  queueTail := fun _ _ => 1
  storageEntry := fun root inbox slots =>
    if (root = 10010 ∨ root = 10011) ∧ inbox = 100 ∧ slots = [0,1] then some ⟨10,0⟩ else none
  verify := fun root inbox slots entry _ =>
    decide ((root = 10010 ∨ root = 10011) ∧ inbox = 100 ∧ slots = [0,1] ∧ entry = ⟨10,0⟩)
  slot := fun n => 2*n
  sound := by intros; simp_all

def auth : Integration.Authentication ctx where
  inbox := 100
  delay := 10
  codec := codec
  fiAuthentication := fiAuth
  execution := FI.exampleExecution
  payload := fun hash => if hash = 101 then some ([],123,202) else if hash = 102 then some ([1],124,203) else none
  root := fun hash => if hash = 801 then 10011 else 10010
  timestamp := fun hash => if hash = 801 then 21 else 20
  anchorNumber := fun hash => if hash = 801 then 51 else 50
  anchorCheckpoint := fun hash => if hash = 801 then 1 else 0
  genesis := fun l1 l2 inbox registry generation config =>
    if l1 = 1 ∧ l2 = 167001 ∧ inbox = 100 ∧ registry = 2 ∧ generation = 0 ∧ config = 1
    then some (schedule,3,10,9) else none
  tail := fun _ _ => 1
  checkpoint := fun height hash => if height = 0 ∧ hash = 100 then some before else if height = 1 ∧ hash = 101 then some after else none
  decodeBlobs := fun blobs => if blobs = [1] then some [block] else if blobs = [2] then some [secondBlock] else none
  ancestor := fun anchor reference => (anchor = 800 ∨ anchor = 801) ∧ reference = 2748
  treasuryCredit := fun hash => if hash = 101 then 5 else if hash = 102 then 3 else 0

def fi : FI.ValidStep before.cursor after.cursor (some 0) where
  authentication := fiAuth 100
  codec := codec
  execution := FI.exampleExecution
  context := ⟨100,123,800,10010,100,0,1,20,10⟩
  witness := some witness
  transactions := [[]]
  authenticated := by constructor <;> rfl
  parentCursor := rfl
  decision := .included 0
  classified := rfl
  resolved := rfl
  advancement := rfl

def joint : JointStep auth before after block (some 0) [] where
  fi := fi
  authentication := rfl
  committee := rfl
  parent := rfl
  anchor := rfl
  root := rfl
  anchorNumber := rfl
  anchorCheckpoint := rfl
  inbox := rfl
  delay := rfl
  attributes := rfl
  payload := rfl
  decoding := rfl
  codec := rfl
  execution := rfl
  authenticatedRoot := rfl
  authenticatedTime := rfl
  authenticatedTail := rfl
  stateRoot := rfl

/-- Epoch zero's committee is the genesis record with cutoff 49 (L = 6). -/
def world : Landing.World := { Landing.exampleWorld with
  checkpoint := ⟨0,100⟩,
  head := 0, tail := 1, fee := fun _ => 1, committeeSnapshot := 49, epochLen := 6 }
def input : Landing.LandInput := ⟨1,101,202,19999,1,48879,57005,5,49,51966⟩
/-- A content-dependent toy byte hash (byte sum), not Keccak: it separates the two receipts. -/
def rewardHash (bytes : List Landing.Byte) : Word256 := ⟨(bytes.map Fin.val).sum % 2 ^ 256, Nat.mod_lt _ (by decide)⟩
def external : Landing.ExternalOutcomes := { Landing.exampleExternal with
  environment := { Landing.exampleEnvironment with blobHashes := [1] }, keccakRewardBytes := rewardHash }
def batch : BatchSummary ctx := ⟨before,after,[block],[some 0],[]⟩

/-- A finite interpretation satisfies every coupled premise, consumes a real index and
pays a positive interval. It witnesses consistency; it is not a production guest proof. -/
theorem joint_nonvacuity :
    ValidBatch auth world input external (Landing.computedStatement world input external) batch ∧
    (Landing.execLandSteps world input external).error = none ∧
    (Landing.runTransaction world (Landing.execLandSteps world input external)).world.head.val = 1 ∧
    (Landing.execLandSteps world input external).journal.current.transfers = [⟨48879,1000000000⟩] := by
  refine ⟨?_, rfl, rfl, rfl⟩
  constructor
  · exact JointTrace.cons joint (JointTrace.nil after)
  · decide
  · rfl
  · rfl
  · rfl
  · rfl
  · rfl
  · rfl
  · rfl
  · intro b member
    simp only [batch, List.mem_singleton] at member
    subst b
    exact ⟨Or.inl rfl,rfl⟩
  · decide
  · exact ⟨outgoingRecord, rfl, by decide, rfl⟩
  · rfl

/-- Empty cuts are permitted as algebraic partitions; valid landed batches separately
require nonempty blocks and strict progress. This example also exercises ordered cut joining. -/
theorem two_cuts_nonvacuity : Cuts auth before [[],[block]] [some 0] [] after := by
  exact Cuts.cons (JointTrace.nil before) (Cuts.cons (JointTrace.cons joint (JointTrace.nil after)) (Cuts.nil after))

theorem fees_nonvacuity : FeeCuts (fun _ => 1) 0 [0,1,1] 1 1 := by
  exact FeeCuts.cons (by decide) (FeeCuts.cons (by decide) (FeeCuts.cons (by decide) (FeeCuts.nil 1)))

def secondFi : FI.ValidStep after.cursor secondState.cursor none where
  authentication := fiAuth 101
  codec := codec
  execution := FI.exampleExecution
  context := ⟨101,124,801,10011,100,1,1,21,10⟩
  witness := none
  transactions := []
  authenticated := by constructor <;> rfl
  parentCursor := rfl
  decision := .ordinary
  classified := rfl
  resolved := rfl
  advancement := rfl

def secondJoint : JointStep auth after secondState secondBlock none [] where
  fi := secondFi
  authentication := rfl
  committee := rfl
  parent := rfl
  anchor := rfl
  root := rfl
  anchorNumber := rfl
  anchorCheckpoint := rfl
  inbox := rfl
  delay := rfl
  attributes := rfl
  payload := rfl
  decoding := rfl
  codec := rfl
  execution := rfl
  authenticatedRoot := rfl
  authenticatedTime := rfl
  authenticatedTail := rfl
  stateRoot := rfl

def middleWorld : Landing.World := (Landing.runTransaction world (Landing.execLandSteps world input external)).world
def secondInput : Landing.LandInput := ⟨2,102,203,19999,1,48879,57005,3,49,51966⟩
def secondExternal : Landing.ExternalOutcomes := { external with
  environment := { external.environment with blobHashes := [2] } }
def secondBatch : BatchSummary ctx := ⟨after,secondState,[secondBlock],[none],[]⟩
def finalWorld : Landing.World := (Landing.runTransaction middleWorld
  (Landing.execLandSteps middleWorld secondInput secondExternal)).world

theorem second_valid : ValidBatch auth middleWorld secondInput secondExternal
    (Landing.computedStatement middleWorld secondInput secondExternal) secondBatch := by
  constructor
  · exact JointTrace.cons secondJoint (JointTrace.nil secondState)
  · decide
  · rfl
  · rfl
  · rfl
  · rfl
  · rfl
  · rfl
  · rfl
  · intro b member
    simp only [secondBatch, List.mem_singleton] at member
    subst b
    exact ⟨Or.inr rfl,rfl⟩
  · decide
  · exact ⟨outgoingRecord, rfl, by decide, rfl⟩
  · rfl

/-- Two nonempty actual model land calls, with a positive paid interval followed by an
empty interval, share the same authenticated seed/genesis and coherent L1 history. -/
theorem landed_multicall_nonvacuity :
    LandedCuts auth rewardHash world before [[block],[secondBlock]] [some 0,none] [] finalWorld secondState 1
      [Landing.receiptOf world input, Landing.receiptOf middleWorld secondInput] := by
  exact LandedCuts.cons input external joint_nonvacuity.1 joint_nonvacuity.2.1 rfl
    (LandedCuts.cons secondInput secondExternal second_valid (by decide +kernel) rfl (LandedCuts.nil finalWorld secondState))

/-- The two receipts record the 5 + 3 credited base fees, at two different parent heights,
under two different ids of the toy hash. -/
theorem landed_rewards_nonvacuity :
    ([Landing.receiptOf world input, Landing.receiptOf middleWorld secondInput].map fun r => r.amount.val).sum =
      credits auth [block, secondBlock] ∧
    (Landing.receiptOf world input).parentHeight = 0 ∧ (Landing.receiptOf middleWorld secondInput).parentHeight = 1 ∧
    Landing.rewardId world input external ≠ Landing.rewardId middleWorld secondInput secondExternal :=
  ⟨(landed_cuts_rewards landed_multicall_nonvacuity).2, rfl, rfl, by decide +kernel⟩

/-- The landed snapshot is epoch zero's genesis cutoff, and a snapshot naming another
committee cannot satisfy the guest relation even though the Inbox range check would pass. -/
theorem landed_snapshot_nonvacuity :
    finalWorld.committeeSnapshot = outgoingRecord.cutoff ∧
    ¬ ValidBatch auth world { input with activeSnapshot := 50 } external
      (Landing.computedStatement world { input with activeSnapshot := 50 } external) batch := by
  refine ⟨by decide +kernel, ?_⟩
  intro valid
  obtain ⟨r, governing, snapshot⟩ := valid_batch_active_snapshot valid
  have : r = outgoingRecord := by
    have h : Committee.authority ctx.schedule batch.terminal.committee batch.terminal.committee.height =
      some outgoingRecord := rfl
    rw [h] at governing; exact (Option.some.inj governing).symm
  subst this
  exact absurd snapshot (by decide)

/-- A wrong base-fee word cannot satisfy the guest relation for the decoded trace. -/
theorem forged_base_fee_not_valid :
    ¬ ValidBatch auth world { input with baseFeeAmount := 6 } external
      (Landing.computedStatement world { input with baseFeeAmount := 6 } external) batch := by
  intro valid
  exact absurd (valid_batch_base_fee valid) (by decide)

/-- A forged output head cannot satisfy the concrete guest relation for this decoded trace.
Normal-return/dummy acceptance alone therefore cannot establish that relation. -/
theorem forged_head_not_valid :
    ¬ ValidBatch auth world { input with headAfter := 0 } external
      (Landing.computedStatement world { input with headAfter := 0 } external) batch := by
  intro valid
  have bad := valid_batch_head valid
  norm_num [input,batch,after] at bad
/-- The fixed vault on chain 167001 for L1 chain 1's Inbox 100. -/
def vault : Landing.Vault := { l1ChainId := 1, chainId := 167001, inbox := 100 }
def firstClaim : Landing.ClaimCall := ⟨Landing.receiptOf world input, true, true, true, true⟩
def secondClaim : Landing.ClaimCall := ⟨Landing.receiptOf middleWorld secondInput, true, true, true, true⟩

/-- The final L1 ledger holds both landed commitments, so both proofs can be sound. -/
theorem final_ledger_nonvacuity :
    Landing.ProofSound rewardHash finalWorld.rewardCommitments firstClaim ∧
    Landing.ProofSound rewardHash finalWorld.rewardCommitments secondClaim := by
  constructor <;> intro _ <;> decide +kernel

/-- Decidable projections of a claim result; `Vault` itself carries functions. -/
def payoutsOf : Except Landing.ClaimError Landing.Vault → Option (List Landing.Transfer)
  | .ok v => some v.payouts | .error _ => none
/-- Plain (recipient, wei) pairs, decidable with core instances only. -/
def pairsOf (r : Except Landing.ClaimError Landing.Vault) : Option (List (Nat × Nat)) :=
  (payoutsOf r).map fun ts => ts.map fun t => (t.recipient.val, t.wei)
def errorOf : Except Landing.ClaimError Landing.Vault → Option Landing.ClaimError
  | .error e => some e | .ok _ => none

theorem payouts_ok {r : Except Landing.ClaimError Landing.Vault} {p : List Landing.Transfer}
    (h : payoutsOf r = some p) : ∃ v, r = .ok v ∧ v.payouts = p := by
  cases r with
  | error e => simp [payoutsOf] at h
  | ok v => exact ⟨v, rfl, by simpa [payoutsOf] using h⟩

theorem ok_of_pairs {r : Except Landing.ClaimError Landing.Vault} {p : List (Nat × Nat)}
    (h : pairsOf r = some p) : ∃ v, r = .ok v ∧ v.payouts.map (fun t => (t.recipient.val, t.wei)) = p := by
  cases r with
  | error e => simp [pairsOf, payoutsOf] at h
  | ok v => exact ⟨v, rfl, by simpa [pairsOf, payoutsOf] using h⟩

def afterFirst := Landing.claim rewardHash vault firstClaim
def afterSecond := afterFirst.bind fun v => Landing.claim rewardHash v secondClaim

/-- Both landed receipts are claimable once, paying exactly 5 and 3 to the bound recipient;
replaying the first claim reverts. -/
theorem claims_nonvacuity :
    pairsOf afterFirst = some [(57005, 5)] ∧
    pairsOf afterSecond = some [(57005, 5), (57005, 3)] ∧
    errorOf (afterSecond.bind fun v => Landing.claim rewardHash v firstClaim) = some .alreadyClaimed := by
  refine ⟨by decide +kernel, by decide +kernel, by decide +kernel⟩

/-- A receipt for another Inbox is rejected before any proof is consulted. -/
theorem foreign_inbox_rejected :
    errorOf (Landing.claim rewardHash { vault with inbox := 101 } firstClaim) = some .invalidReceipt := by
  decide +kernel

/-- The end-to-end bound is satisfiable on the two-landing, two-claim history: 8 credited wei. -/
theorem bounded_claims_nonvacuity :
    ∃ v₂, Landing.ClaimTrace rewardHash vault [firstClaim.receipt, secondClaim.receipt] v₂ ∧
      (v₂.payouts.map Landing.Transfer.wei).sum ≤ credits auth [block, secondBlock] := by
  obtain ⟨v₁, first, _⟩ := ok_of_pairs claims_nonvacuity.1
  obtain ⟨v₂, both, _⟩ := ok_of_pairs claims_nonvacuity.2.1
  have second : Landing.claim rewardHash v₁ secondClaim = .ok v₂ := by
    rw [afterSecond, first] at both; exact both
  have trace : Landing.ClaimTrace rewardHash vault [firstClaim.receipt, secondClaim.receipt] v₂ :=
    .cons firstClaim first (.cons secondClaim second (.nil v₂))
  refine ⟨v₂, trace, ?_⟩
  have bound := claims_bounded_by_credits landed_multicall_nonvacuity trace (by
    intro c member
    simp only [List.mem_cons, List.not_mem_nil, or_false] at member
    rcases member with rfl | rfl
    · exact ⟨_, List.mem_cons_self, rfl, rfl⟩
    · exact ⟨_, List.mem_cons_of_mem _ List.mem_cons_self, rfl, rfl⟩)
  simpa [vault] using bound
end Etna.Integration.Examples
