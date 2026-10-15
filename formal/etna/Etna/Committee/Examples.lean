module
public import Etna.Committee.Proofs
public import Etna.Refinement.Rust.Committee
@[expose] public section
set_option maxRecDepth 4096
set_option maxHeartbeats 2000000
namespace Etna.Committee.Examples
open Aeneas Aeneas.Std
open Etna.Refinement.Rust.Committee

def ordinary : Schedule := ⟨64,20,1,63⟩
def l1Overflow : Schedule := ⟨64,20,max64,63⟩
def l2Overflow : Schedule := ⟨64,max64,1,63⟩
def minimal : Schedule := ⟨0,3,1,0⟩

theorem valid_first_transition : validate ordinary 10 = .ok () ∧ first ordinary 1 = some 21 ∧
    parentHeight ordinary 1 = some 18 ∧ switchTarget ordinary 19 = some 1 ∧ l1First ordinary 1 = some 65 := ⟨rfl,rfl,rfl,rfl,rfl⟩

theorem accepted_l1_overflow : validate l1Overflow 10 = .ok () ∧ l1First l1Overflow 1 = none := by repeat' constructor <;> rfl
theorem accepted_l2_overflow : validate l2Overflow 10 = .ok () ∧ first l2Overflow 1 = none := by repeat' constructor <;> rfl
theorem intermediate_last_overflow : last minimal 6148914691236517204 = none ∧
    (6148914691236517204+1)*minimal.length = max64 := by repeat' constructor <;> rfl
theorem next_is_not_representable_switch : nextSwitch minimal (max64-1) = some 6148914691236517205 ∧
    switchTarget minimal (max64-1) = none := by repeat' constructor <;> rfl
theorem epoch_zero_special : epochOf minimal 0 = some 0 ∧ startingAt minimal 0 = none ∧ parentHeight minimal 0 = none := ⟨rfl,rfl,rfl⟩

def rustL1Overflow : etna_consensus_core.schedule.Schedule := ⟨64#u64,20#u64,18446744073709551615#u64,63#u64⟩
def rustL2Overflow : etna_consensus_core.schedule.Schedule := ⟨64#u64,18446744073709551615#u64,1#u64,63#u64⟩
def rustOrdinary : etna_consensus_core.schedule.Schedule := ⟨64#u64,20#u64,1#u64,63#u64⟩

/-- Actual generated source counterexamples; no full synthetic-genesis integration is asserted. -/
theorem rust_accepted_l1_overflow :
    etna_consensus_core.schedule.Schedule.validate rustL1Overflow 10#u64 = .ok (.Ok ()) ∧
    etna_consensus_core.schedule.Schedule.checked_l1_first rustL1Overflow 1#u64 = .ok none := by
  rw [rust_validate_refines, rust_l1First_refines]
  constructor <;> rfl

theorem rust_accepted_l2_overflow :
    etna_consensus_core.schedule.Schedule.validate rustL2Overflow 10#u64 = .ok (.Ok ()) ∧
    etna_consensus_core.schedule.Schedule.h_first rustL2Overflow 1#u64 = .ok none := by
  rw [rust_validate_refines, rust_first_refines]
  constructor <;> rfl

theorem rust_valid_first_transition :
    etna_consensus_core.schedule.Schedule.validate rustOrdinary 10#u64 = .ok (.Ok ()) ∧
    etna_consensus_core.schedule.Schedule.h_first rustOrdinary 1#u64 = .ok (some 21#u64) ∧
    etna_consensus_core.schedule.Schedule.checked_l1_first rustOrdinary 1#u64 = .ok (some 65#u64) := by
  rw [rust_validate_refines, rust_first_refines, rust_l1First_refines]
  constructor
  · rfl
  constructor <;> rfl

/-- A finite authentication interpretation: the verifier accepts exactly the committed snapshot.
This witnesses satisfiability of the indexed soundness premise, not an implementation of MPT. -/
def snap : Snapshot := ⟨777,50,[1,2]⟩
def auth : Authentication where
  stored root cutoff := if root = 10010 ∧ cutoff = 50 then some snap else none
  verify root cutoff snapshot proof := decide (root = 10010 ∧ cutoff = 50 ∧ snapshot = snap ∧ proof = [42])
  sound := by intros root cutoff snapshot proof accepted; simp_all
  derive t snapshot := ⟨t,snapshot.root,snapshot.cutoff,[⟨2,1⟩]⟩
def crypto : Crypto where
  valid chain h hash key signature := decide (signature = [chain,h,hash,key])
  genuine chain h hash key signature := signature = [chain,h,hash,key]
  sound := by intros chain h hash key signature valid; simpa using valid
def schedule : Schedule := ⟨50,6,1,49⟩
def ctx : Context := ⟨schedule,9,3,auth,crypto,
  (fun hash a => a.stateRoot = 10010 ∧ a.number = 50 ∧ a.checkpoint = hash-101),
  (fun parent hash => hash = parent+1)⟩
def outgoingRecord : Record := ⟨0,700,49,[⟨1,1⟩]⟩
def initial : CommitteeState := ⟨0,100,⟨800,10010,50,0⟩,[outgoingRecord]⟩
def block (h : Nat) (positive : 0 < h) : AuthenticatedBlockFacts ctx where
  facts := ⟨h,9,99+h,100+h,⟨800,10010,50,h-1⟩,
    (if h = 5 then some ⟨snap,[42]⟩ else none),
    ⟨9,h,100+h,[⟨if h < 7 then 1 else 2,.block,[9,h,100+h,if h < 7 then 1 else 2]⟩]⟩⟩
  anchorEvidence := by
    change 10010 = 10010 ∧ 50 = 50 ∧ h-1 = 100+h-101
    exact ⟨rfl,rfl,by omega⟩
  payloadEvidence := by change 100+h = 99+h+1; omega

def history : List (AuthenticatedBlockFacts ctx) :=
  [block 1 (by decide),block 2 (by decide),block 3 (by decide),block 4 (by decide),
   block 5 (by decide),block 6 (by decide),block 7 (by decide),block 8 (by decide)]
def incomingRecord : Record := auth.derive 1 snap
def finalState : CommitteeState := ⟨8,108,⟨800,10010,50,7⟩,[incomingRecord,outgoingRecord]⟩

theorem nonempty_switch_replay : replay ctx history initial =
    .ok (finalState,[(outgoingRecord,incomingRecord)]) := by rfl

theorem missing_pending_scalar : plan schedule 5 .none true false = .error (.unknown 1) := by rfl

def emptyAuth : Authentication := { auth with derive := fun t snapshot => ⟨t,snapshot.root,snapshot.cutoff,[]⟩ }
theorem empty_incoming_rejected : incoming emptyAuth schedule initial.anchor 5 (some ⟨snap,[42]⟩) = .error .empty := by rfl

def stopped : Context := { ctx with cap := 0 }
def firstStopped : AuthenticatedBlockFacts stopped := ⟨(block 1 (by decide)).facts,
  (block 1 (by decide)).anchorEvidence,(block 1 (by decide)).payloadEvidence⟩
/-- Accepted zero-cap policy, authentic checkpoint zero, exact failed first step. -/
theorem zero_cap_bootstrap : validate schedule 0 = .ok () ∧ unsettledCap 2 2 = some 0 ∧
    step stopped initial firstStopped = .error .backPressure := ⟨rfl,rfl,rfl⟩
/-- Saturated ahead-checkpoint depth is zero; do not claim all possible zero-cap anchors fail. -/
theorem zero_cap_ahead_checkpoint : (1 : Nat)-2 ≤ 0 := by rfl


def concreteComet : CometAdapter := ⟨cometView, by intros; rfl⟩
theorem nonempty_activation_pair :
    concreteComet.observed 5 outgoingRecord incomingRecord 6 = outgoingRecord ∧
    concreteComet.observed 5 outgoingRecord incomingRecord 7 = incomingRecord := ⟨rfl,rfl⟩
end Etna.Committee.Examples
