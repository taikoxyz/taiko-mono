module
public import Etna.Integration.Composition
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

def world : Landing.World := { Landing.exampleWorld with
  checkpoint := ⟨0,100⟩,
  head := 0, tail := 1, fee := fun _ => 1 }
def input : Landing.LandInput := ⟨1,101,202,19999,1,48879,51966⟩
def external : Landing.ExternalOutcomes := { Landing.exampleExternal with
  environment := { Landing.exampleEnvironment with blobHashes := [1] } }
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
def secondInput : Landing.LandInput := ⟨2,102,203,19999,1,48879,51966⟩
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
  · rfl

/-- Two nonempty actual model land calls, with a positive paid interval followed by an
empty interval, share the same authenticated seed/genesis and coherent L1 history. -/
theorem landed_multicall_nonvacuity :
    LandedCuts auth world before [[block],[secondBlock]] [some 0,none] [] finalWorld secondState 1 := by
  exact LandedCuts.cons input external joint_nonvacuity.1 joint_nonvacuity.2.1
    (LandedCuts.cons secondInput secondExternal second_valid rfl (LandedCuts.nil finalWorld secondState))

/-- A forged output head cannot satisfy the concrete guest relation for this decoded trace.
Normal-return/dummy acceptance alone therefore cannot establish that relation. -/
theorem forged_head_not_valid :
    ¬ ValidBatch auth world { input with headAfter := 0 } external
      (Landing.computedStatement world { input with headAfter := 0 } external) batch := by
  intro valid
  have bad := valid_batch_head valid
  norm_num [input,batch,after] at bad
end Etna.Integration.Examples
