import EtnaModel.CurrentValidatorState
import EtnaVectors.Json

/-! Executable CometBFT v0.40.0 validator-state vectors (`testdata/etna_current_conformance`):
genesis and per-height commits of `ValidatorState`, the replica a validator-state hash commits to
(appendix A). Key numbers denote distinct valid consensus keys whose addresses ascend with the
number, so the model's address order is the consumer's. -/
namespace Etna.Vectors.CurrentValidatorState
open Etna.Design.Current.ValidatorState

def member (key power : Nat) : Validator := ⟨key,key,power,0⟩
def change (key power : Nat) : Change := ⟨key,key,power⟩

/-- Genesis at `origin`, then one commit per step with that height's FinalizeBlock updates. The
states reached, and the index (0 for genesis, i for step i) of the first rejected input. -/
def replayFrom (origin : Nat) (members : List (Nat × Nat)) (steps : List (List (Nat × Nat))) :
    List CommitState × Option Nat :=
  match genesis origin (members.map fun (k,p) => member k p) with
  | none => ([],some 0)
  | some first =>
    let rec go (s : CommitState) (index : Nat) : List (List (Nat × Nat)) → List CommitState × Option Nat
      | [] => ([],none)
      | changes :: rest =>
        match commit s (changes.map fun (k,p) => change k p) with
        | none => ([],some index)
        | some t => let (later,failed) := go t (index+1) rest; (t :: later,failed)
    let (later,failed) := go first 1 steps
    (first :: later,failed)

def jInt (n : Int) : JVal := fun _ => toString n

def pairs (xs : List (Nat × Nat)) : JVal := jArr (xs.map fun (k,p) => jRow [jNat k,jNat p])

def renderSet (s : ValSet) : JVal := jObj [
  ("members",jArr (s.members.map fun v => jRow [jNat v.key,jNat v.power,jInt v.priority])),
  ("proposer",match s.proposer with | none => jNull | some a => jNat a)]

def renderState (s : CommitState) : JVal :=
  jObj [("height",jNat s.height),("current",renderSet s.current),("next",renderSet s.next)]

def vector (name : String) (origin : Nat) (members : List (Nat × Nat))
    (steps : List (List (Nat × Nat))) : JVal :=
  let (states,failed) := replayFrom origin members steps
  jObj [
    ("id",jStr name),("rules",jRow [jStr "COMM-4.3-13",jStr "PROOF-6.2-41a"]),
    ("origin",jNat origin),("genesis",pairs members),("steps",jArr (steps.map pairs)),
    ("expect",jObj [
      ("rejectedAt",match failed with | none => jNull | some i => jNat i),
      ("states",jArr (states.map renderState))])]

def file : String :=
  jObj [
    ("schema",jStr "etna-current-validator-state-1"),
    ("cometbft",jStr "v0.40.0"),
    ("model",jStr "Etna.Design.Current.ValidatorState.genesis, Etna.Design.Current.ValidatorState.commit"),
    ("keyMeaning",jStr "Distinct valid consensus keys; a consumer assigns key numbers in ascending address order. Members are [key, power, priority]; proposer is a key number."),
    ("vectors",jArr [
      vector "genesis-unequal-rotation" 0 [(1,10),(2,20),(3,30)] [[],[],[]],
      vector "equal-power-address-order" 0 [(4,10),(2,10),(9,10)] [[],[],[],[]],
      vector "addition-signs-at-h-plus-2" 5 [(1,10),(2,10)] [[(3,10)],[],[]],
      vector "removal-and-power-change" 0 [(1,10),(2,20),(3,30)] [[(1,0),(2,25)],[],[]],
      vector "same-power-update" 0 [(1,10),(2,20)] [[(2,20)],[]],
      vector "duplicate-update-rejected" 0 [(1,10),(2,20)] [[],[(1,5),(1,6)]],
      vector "unknown-removal-rejected" 0 [(1,10),(2,20)] [[(7,0)]],
      vector "empty-set-rejected" 0 [(1,10),(2,20)] [[(1,0),(2,0)]],
      vector "genesis-zero-power-rejected" 0 [(1,0),(2,20)] [],
      vector "total-power-overflow-rejected" 0 [(1,maxPower)] [[(2,1)]]])
  ] 0 ++ "\n"

end Etna.Vectors.CurrentValidatorState
