import EtnaProofs.Reconstruction
import EtnaWitnesses.Regressions.FirstBatch

/-! Finite execution fixture, not an EVM/KZG/zlib implementation. Public header bytes
encode the fixture's complete header context; state includes beacon/history writes and
an ordered-transaction effect. Accepted guest fixtures constrain their actual predicates,
so the codec/EL laws have a nonempty domain rather than relying on permissive flags. -/
namespace Etna.Design.ReconstructionRegression
open Reconstruction

set_option maxRecDepth 10000
set_option maxHeartbeats 2000000

def headerBytes (h : Nat) : Bytes := [UInt8.ofNat h]
def publicBlock (h : Nat) : PublicBlock := ⟨headerBytes h,[[7]]⟩
def stateImage (h : Nat) : Bytes := [UInt8.ofNat h,UInt8.ofNat (h+if h < 5 then 20 else 30),UInt8.ofNat (h+if h < 5 then 10 else 20),UInt8.ofNat (h-1),7]
def rootOf (s : Bytes) : Hash := 10000+(s.headD 0).toNat

def readHeader : Bytes → Option HeaderFields
  | [n] => some ⟨n.toNat,1000+n.toNat-1,10000+n.toNat,n.toNat+(if n.toNat < 5 then 10 else 20),n.toNat+(if n.toNat < 5 then 20 else 30)⟩
  | _ => none

def blobHash : Bytes → Hash
  | [] => 0
  | b :: rest => b.toNat+1+256*blobHash rest

def decode (version : Nat) (raw : List Bytes) : Option (List PublicBlock) :=
  if version ≠ 6 then none
  else if raw.map blobHash = [3] then some [publicBlock 1,publicBlock 2]
  else if raw.map blobHash = [5] then some [publicBlock 1,publicBlock 2,publicBlock 3,publicBlock 4]
  else if raw.map blobHash = [7] then some [publicBlock 5,publicBlock 6]
  else none

/-- Both system effects precede the fixture transaction: beacon root/timestamp and
parent-hash slot are stored alongside the transaction's 7. The real EIP bytecode and
state commitment implementation remain external to this finite non-vacuity witness. -/
def fullBlock (state : Bytes) (b : PublicBlock) : Option Bytes := do
  let h ← readHeader b.header
  if rootOf state+1 = h.stateRoot ∧ b.transactions = [[7]] then some (stateImage h.height) else none

def el : Primitives :=
  ⟨[42],1,readHeader,(fun raw => 1000+(raw.headD 0).toNat),rootOf,blobHash,decode,fullBlock,
    (fun _ => true),(fun _ => true)⟩

def pair (p : BlockValidity.Header) (b : BlockValidity.Block) : Prop :=
  (p = FirstBatch.parent ∧ b = FirstBatch.block1) ∨
  (p = FirstBatch.block1.header ∧ b = FirstBatch.block2) ∨
  (p = FirstBatch.block2.header ∧ b = FirstBatch.block3) ∨
  (p = FirstBatch.block3.header ∧ b = FirstBatch.block4) ∨
  (p = FirstBatch.block4.header ∧ b = FirstBatch.recovery5) ∨
  (p = FirstBatch.recovery5.header ∧ b = FirstBatch.recovery6)
instance (p : BlockValidity.Header) (b : BlockValidity.Block) : Decidable (pair p b) :=
  inferInstanceAs (Decidable (_ ∨ _))

def rules : BlockValidity.Rules :=
  { FirstBatch.rules with
    executionValid := fun p b => decide (pair p b)
    batchPayloadValid := fun hashes bs => decide
      ((hashes = [3] ∧ bs = [FirstBatch.block1,FirstBatch.block2]) ∨
       (hashes = [5] ∧ bs = FirstBatch.batch) ∨
       (hashes = [7] ∧ bs = [FirstBatch.recovery5,FirstBatch.recovery6])) }
def recoveryRules : BlockValidity.Rules :=
  { FirstBatch.recoveryRules with executionValid := rules.executionValid, batchPayloadValid := rules.batchPayloadValid }
instance : DecidablePred recoveryRules.signature := fun _ => inferInstanceAs (Decidable True)

instance : DecidablePred rules.signature := fun _ => inferInstanceAs (Decidable True)

private theorem valid_pair {r : BlockValidity.Rules} {p : BlockValidity.Header} {b : BlockValidity.Block}
    (sound : r = rules ∨ r = recoveryRules) (valid : BlockValidity.Valid r p b) : pair p b := by
  rcases sound with rfl | rfl
  all_goals exact of_decide_eq_true valid.2.2.2.2.2.2.2.1

private theorem batch_choices {r : BlockValidity.Rules} {p : BlockValidity.Header}
    {bs : List BlockValidity.Block} {hashes : List Hash}
    (sound : r = rules ∨ r = recoveryRules) (valid : Settlement.BatchValid r p bs hashes) :
    (hashes = [3] ∧ bs = [FirstBatch.block1,FirstBatch.block2]) ∨
    (hashes = [5] ∧ bs = FirstBatch.batch) ∨
    (hashes = [7] ∧ bs = [FirstBatch.recovery5,FirstBatch.recovery6]) := by
  rcases sound with rfl | rfl
  all_goals exact of_decide_eq_true valid.2

private theorem origin_of_batch {r : BlockValidity.Rules} {p : BlockValidity.Header}
    {bs : List BlockValidity.Block} {hashes : List Hash}
    (sound : r = rules ∨ r = recoveryRules) (valid : Settlement.BatchValid r p bs hashes) :
    p = FirstBatch.parent ∨ p = FirstBatch.block4.header := by
  rcases batch_choices sound valid with ⟨_,rfl⟩ | ⟨_,rfl⟩ | ⟨_,rfl⟩
  all_goals
    have paired := valid_pair sound valid.1.1
    simp only [pair] at paired
    rcases paired with ⟨rfl,bad⟩ | ⟨_,bad⟩ | ⟨_,bad⟩ | ⟨_,bad⟩ | ⟨rfl,bad⟩ | ⟨_,bad⟩
    all_goals first | exact Or.inl rfl | exact Or.inr rfl |
      have impossible := congrArg (fun b : BlockValidity.Block => b.header.height) bad
      contradiction

def laws : ProjectionLaws el where
  guestRules := fun r => r = rules ∨ r = recoveryRules
  project := fun b => publicBlock b.header.height
  parentBytes := fun p => headerBytes p.height
  parent := by
    intro r p bs hashes valid sound
    rcases origin_of_batch sound valid with rfl | rfl
    all_goals exact ⟨_,rfl,rfl,rfl,rfl⟩
  fields := by
    intro r p b valid sound
    rcases valid_pair sound valid with ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩
    all_goals rfl
  headerBound := by
    intro r p b valid sound
    rcases valid_pair sound valid with ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩
    all_goals rfl
  payload := by
    intro r p bs hashes raw valid sound binding
    have choices := batch_choices sound valid
    change raw.map blobHash = hashes at binding
    rcases choices with ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩
    all_goals simp [el,decode,binding,FirstBatch.batch,FirstBatch.block1,FirstBatch.block2,FirstBatch.block3,FirstBatch.block4,FirstBatch.recovery5,FirstBatch.recovery6]
  fullEL := by
    intro r p b state valid sound root
    refine ⟨stateImage b.header.height,?_,?_⟩
    · rcases valid_pair sound valid with ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩
      all_goals
        change (if rootOf state+1 = _ ∧ _ then _ else none) = _
        change rootOf state = _ at root
        simp only [root]
        decide +kernel
    · rcases valid_pair sound valid with ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩ | ⟨rfl,rfl⟩
      all_goals rfl

def start : Start := ⟨0,FirstBatch.inbox.origin,FirstBatch.genesisRecord,10000,0,[42],1,[]⟩
def initial : Rebuilt := ⟨0,start.origin,start.checkpoint,0,stateImage 0,[(0,headerBytes 0)],[],0⟩
def statement2 : StatementData := Settlement.statement rules FirstBatch.parent [FirstBatch.block1,FirstBatch.block2] [3]
def environment2 : LandingEnv := ⟨21,200,true,[3],[(.risc0,true),(.sp1,true)],statement2⟩
def inbox2 : State := applyLanding FirstBatch.inbox statement2.input
def first : Landing := landingRecord FirstBatch.inbox statement2.input environment2 1 (some [[2]]) []
def atTwo : Rebuilt := ⟨0,start.origin,inbox2.checkpoint,0,stateImage 2,
  [(2,headerBytes 2),(1,headerBytes 1),(0,headerBytes 0)],[1,2],1⟩
def statement4 : StatementData := Settlement.statement rules FirstBatch.parent FirstBatch.batch [5]
def environment4 : LandingEnv := ⟨21,200,true,[5],[(.risc0,true),(.sp1,true)],statement4⟩
def inbox4 : State := applyLanding inbox2 statement4.input
def second : Landing := landingRecord inbox2 statement4.input environment4 2 (some [[4]]) []
def settled : Rebuilt := ⟨0,start.origin,inbox4.checkpoint,0,stateImage 4,
  [(4,headerBytes 4),(3,headerBytes 3),(2,headerBytes 2),(1,headerBytes 1),(0,headerBytes 0)],[1,2,3,4],2⟩
def overlapResult := reconstruct el initial [.landing first,.landing second]

def recovery : RecoveryRecord := ⟨3,0,start.origin,settled.checkpoint,⟨4,20,20⟩,[]⟩
def afterRecovery : Rebuilt := { settled with generation := 1, origin := recovery.nextOrigin, order := 3 }
def third : Landing := ⟨4,1,recovery.nextOrigin,settled.checkpoint,settled.checkpoint,
  ⟨4,6,1006,106,10006,30,0,20⟩,[7],6,some [[6]],[]⟩
def recovered : Rebuilt := ⟨1,recovery.nextOrigin,third.checkpoint,0,stateImage 6,
  [(6,headerBytes 6),(5,headerBytes 5),(4,headerBytes 4),(3,headerBytes 3),(2,headerBytes 2),
    (1,headerBytes 1),(0,headerBytes 0)],[1,2,3,4,5,6],4⟩
def recoveredResult := reconstruct el initial [.landing first,.landing second,.recovery recovery,.landing third]
def missingResult := Reconstruction.reconstructLanding el atTwo { second with original := none }

theorem authenticated_start : initializeState el start (headerBytes 0) (stateImage 0) = some initial := by decide +kernel
theorem overlap_succeeds : overlapResult = some settled := by decide +kernel
theorem recovery_origin_succeeds : recoveredResult = some recovered := by decide +kernel
theorem missing_rejected : missingResult = none := by decide +kernel

theorem system_effects_and_once : settled.state = [4,24,14,3,7] ∧ settled.applied = [1,2,3,4] ∧
    recovered.state = [6,36,26,5,7] ∧ recovered.applied = [1,2,3,4,5,6] := by decide +kernel

theorem competing_frontier :
    (Reconstruction.reconstructLanding el initial { second with current := initial.checkpoint }).map Rebuilt.state = some settled.state ∧
    (Reconstruction.reconstructLanding el atTwo second).map Rebuilt.state = some settled.state ∧
    (Reconstruction.reconstructLanding el atTwo second).map Rebuilt.applied = some [1,2,3,4] := by decide +kernel

theorem inconsistent_material_rejected :
    Reconstruction.reconstructLanding el atTwo { second with version := 7 } = none ∧
    Reconstruction.reconstructLanding el atTwo { second with original := some [[3]] } = none ∧
    Reconstruction.reconstructLanding el { atTwo with archive := [(2,headerBytes 2),(1,headerBytes 9),(0,headerBytes 0)] } second = none ∧
    Reconstruction.reconstructLanding el afterRecovery { third with origin := start.origin } = none ∧
    Reconstruction.reconstructLanding el afterRecovery { third with generation := 0 } = none := by decide +kernel

theorem incomplete_blocks_rejected :
    Reconstruction.reconstructLanding { el with decodePayload := fun _ _ => some [publicBlock 1,publicBlock 2,publicBlock 3] }
      atTwo second = none := by decide +kernel

def output2 : Executed := ⟨⟨2,1002⟩,stateImage 2,[(1,headerBytes 1),(2,headerBytes 2)],[1,2]⟩
def output4 : Executed := ⟨⟨4,1004⟩,stateImage 4,[(3,headerBytes 3),(4,headerBytes 4)],[3,4]⟩
def output6 : Executed := ⟨⟨6,1006⟩,stateImage 6,[(5,headerBytes 5),(6,headerBytes 6)],[5,6]⟩

private theorem execution2 : Execution el ⟨0,1000⟩ (stateImage 0) [publicBlock 1,publicBlock 2] output2 := by
  obtain ⟨out,run,_⟩ := projected_execution laws (r := rules) (p := FirstBatch.parent)
    (bs := [FirstBatch.block1,FirstBatch.block2]) (state := stateImage 0) (by decide +kernel) (Or.inl rfl) rfl
  have computed : executeSuffix el ⟨0,1000⟩ (stateImage 0) [publicBlock 1,publicBlock 2] = some output2 := by decide +kernel
  have equal := Option.some.inj ((execution_succeeds run).symm.trans computed)
  subst out
  exact run
private theorem execution4 : Execution el ⟨2,1002⟩ (stateImage 2) [publicBlock 3,publicBlock 4] output4 := by
  obtain ⟨out,run,_⟩ := projected_execution laws (r := rules) (p := FirstBatch.block2.header)
    (bs := [FirstBatch.block3,FirstBatch.block4]) (state := stateImage 2) (by decide +kernel) (Or.inl rfl) rfl
  have computed : executeSuffix el ⟨2,1002⟩ (stateImage 2) [publicBlock 3,publicBlock 4] = some output4 := by decide +kernel
  have equal := Option.some.inj ((execution_succeeds run).symm.trans computed)
  subst out
  exact run
private theorem execution6 : Execution el ⟨4,1004⟩ (stateImage 4) [publicBlock 5,publicBlock 6] output6 := by
  obtain ⟨out,run,_⟩ := projected_execution laws (r := recoveryRules) (p := FirstBatch.block4.header)
    (bs := [FirstBatch.recovery5,FirstBatch.recovery6]) (state := stateImage 4) (by decide +kernel) (Or.inr rfl) rfl
  have computed : executeSuffix el ⟨4,1004⟩ (stateImage 4) [publicBlock 5,publicBlock 6] = some output6 := by decide +kernel
  have equal := Option.some.inj ((execution_succeeds run).symm.trans computed)
  subst out
  exact run

def firstCertificate : Certification el laws initial first where
  inbox := FirstBatch.inbox
  after := inbox2
  rules := rules
  parent := FirstBatch.parent
  blocks := [FirstBatch.block1,FirstBatch.block2]
  hashes := [3]
  leaves := gridLeaves 1 0 2 (BlockValidity.cuts FirstBatch.parent [FirstBatch.block1,FirstBatch.block2])
  environment := environment2
  order := 1
  raw := [[2]]
  evidence := []
  accepted := by decide +kernel
  valid := by unfold Settlement.BatchValid; decide +kernel
  soundRules := Or.inl rfl
  binding := rfl
  projected := rfl
  aligned := ⟨rfl,rfl,rfl⟩
  stored := (initialized_stored authenticated_start).1
  stateValid := by unfold Settlement.StateValid OnGrid; decide +kernel
  grid := rfl
  positive := by decide
  base := by decide
  fresh := by decide
  available := rfl
  authenticated := rfl
  separation := by
    change HeaderSeparation el [headerBytes 0] [headerBytes 0,headerBytes 1,headerBytes 2]
    simp [HeaderSeparation,el,headerBytes,readHeader]

def secondCertificate : Certification el laws atTwo second where
  inbox := inbox2
  after := inbox4
  rules := rules
  parent := FirstBatch.parent
  blocks := FirstBatch.batch
  hashes := [5]
  leaves := FirstBatch.leaves
  environment := environment4
  order := 2
  raw := [[4]]
  evidence := []
  accepted := by decide +kernel
  valid := by unfold Settlement.BatchValid; decide +kernel
  soundRules := Or.inl rfl
  binding := rfl
  projected := rfl
  aligned := ⟨rfl,rfl,rfl⟩
  stored := execution_stored firstCertificate.stored execution2
  stateValid := Settlement.landing_preserves_state firstCertificate.stateValid firstCertificate.accepted
  grid := rfl
  positive := by decide
  base := by decide
  fresh := by decide
  available := rfl
  authenticated := rfl
  separation := by
    change HeaderSeparation el [headerBytes 2,headerBytes 1,headerBytes 0]
      [headerBytes 0,headerBytes 1,headerBytes 2,headerBytes 3,headerBytes 4]
    simp [HeaderSeparation,el,headerBytes,readHeader]

def recoveryWorld : Recovery.World :=
  ⟨{ inbox4 with epochLen := 3 },[],[],⟨⟨0,1,[]⟩,none⟩⟩
def recoveryRequest : Recovery.Request := { generation := 0,checkpoint := 4,exclusions := [],fiToClear := [] }
def recoveryConfig : Recovery.Config := ⟨0,0⟩
def recoveryResult : Recovery.World := Recovery.applyRecovery recoveryWorld recoveryRequest recoveryConfig recovery.nextOrigin

theorem actual_recovery : Recovery.recover recoveryWorld recoveryRequest recoveryConfig recovery.nextOrigin true true =
    some recoveryResult := by decide +kernel

def statement6 : StatementData := Settlement.statement recoveryRules FirstBatch.block4.header
  [FirstBatch.recovery5,FirstBatch.recovery6] [7]
def environment6 : LandingEnv := ⟨31,300,true,[7],[(.risc0,true),(.sp1,true)],statement6⟩
def thirdCertificate : Certification el laws afterRecovery third where
  inbox := recoveryResult.inbox
  after := applyLanding recoveryResult.inbox third.input
  rules := recoveryRules
  parent := FirstBatch.block4.header
  blocks := [FirstBatch.recovery5,FirstBatch.recovery6]
  hashes := [7]
  leaves := gridLeaves 1 4 6 (BlockValidity.cuts FirstBatch.block4.header [FirstBatch.recovery5,FirstBatch.recovery6])
  environment := environment6
  order := 4
  raw := [[6]]
  evidence := []
  accepted := by decide +kernel
  valid := by unfold Settlement.BatchValid; decide +kernel
  soundRules := Or.inr rfl
  binding := rfl
  projected := rfl
  aligned := ⟨rfl,rfl,rfl⟩
  stored := execution_stored secondCertificate.stored execution4
  stateValid := by unfold Settlement.StateValid OnGrid; decide +kernel
  grid := rfl
  positive := by decide
  base := by decide
  fresh := by decide
  available := rfl
  authenticated := rfl
  separation := by
    change HeaderSeparation el [headerBytes 4,headerBytes 3,headerBytes 2,headerBytes 1,headerBytes 0]
      [headerBytes 4,headerBytes 5,headerBytes 6]
    simp [HeaderSeparation,el,headerBytes,readHeader]

/-- Nonempty sound rules and genuine accepted certificates across overlap and recovery. -/
theorem actual_certified_trace : ProjectionTrace el laws initial
    [.landing first,.landing second,.recovery recovery,.landing third] recovered :=
  .landing firstCertificate execution2 (.landing secondCertificate execution4
    (.recovery rfl (by decide) rfl rfl rfl rfl (by decide)
      (.landing thirdCertificate execution6 (.nil _))))

theorem certified_reconstruction : reconstructPublic el start (headerBytes 0) (stateImage 0)
    [.landing first,.landing second,.recovery recovery,.landing third] = some recovered :=
  checked_public_reconstruction rfl rfl (by decide +kernel) actual_certified_trace

/-- The same real accepted certificate proves exactly the two new applications at c=2. -/
theorem actual_suffix_only : ∃ out, Reconstruction.reconstructLanding el atTwo second = some (finish atTwo second out) ∧
    out.applied.Nodup ∧ ∀ h, h ∈ out.applied ↔ 2 < h ∧ h ≤ 4 :=
  certified_exactly_once secondCertificate

def repeatedRequest : Recovery.Request :=
  { recoveryRequest with generation := 1, nonce := 1 }
def repeatedWorld : Recovery.World :=
  Recovery.applyRecovery recoveryResult repeatedRequest recoveryConfig recovery.nextOrigin
def repeatedRecovery : RecoveryRecord :=
  ⟨4,1,recovery.nextOrigin,settled.checkpoint,recovery.nextOrigin,[]⟩
def afterRepeatedRecovery : Rebuilt := { afterRecovery with generation := 2, order := 4 }

/-- Two actual owner recoveries may share an L1 block; transaction order and generation/
nonce still advance. Public reconstruction preserves the settled state through both. -/
theorem same_block_recoveries :
    Recovery.recover recoveryWorld recoveryRequest recoveryConfig recovery.nextOrigin true true = some recoveryResult ∧
    Recovery.recover recoveryResult repeatedRequest recoveryConfig recovery.nextOrigin true true = some repeatedWorld ∧
    repeatedWorld.inbox.generation = 2 ∧ repeatedWorld.inbox.recoveryNonce = 2 ∧
    reconstruct el initial [.landing first,.landing second,.recovery recovery,.recovery repeatedRecovery] =
      some afterRepeatedRecovery := by
  exact ⟨actual_recovery,by decide +kernel,rfl,rfl,by decide +kernel⟩

end Etna.Design.ReconstructionRegression
