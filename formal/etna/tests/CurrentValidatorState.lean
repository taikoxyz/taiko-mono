import EtnaModel.CurrentValidatorState

namespace Etna.ValidatorStateRegression
open Etna.Design.Current.ValidatorState
set_option maxRecDepth 20000

-- These literals distinguish new-set initialization from zeroed priorities, address
-- tie-breaking from set order, and the extra genesis increment for NextValidators.
def a : Validator := ⟨10,2,3,0⟩
def b : Validator := ⟨20,1,1,0⟩
def initial : CommitState := (genesis 40 [a,b]).getD default

example : initial.height = 40 ∧
    initial.current = ⟨[⟨10,2,3,-1⟩,⟨20,1,1,1⟩],some 2⟩ ∧
    initial.next = ⟨[⟨10,2,3,2⟩,⟨20,1,1,-2⟩],some 1⟩ := by decide +kernel

example : (commit initial []).map (fun s => s.current) = some initial.next ∧
    (commit initial []).map (fun s => s.next) =
      some ⟨[⟨10,2,3,1⟩,⟨20,1,1,-1⟩],some 2⟩ := by decide +kernel

-- Removal happens after the new-member penalty has used the pre-removal total.
def changed : CommitState := (commit initial [⟨10,2,0⟩,⟨30,3,2⟩]).getD default
example : changed.current = initial.next ∧
    changed.next = ⟨[⟨30,3,2,0⟩,⟨20,1,1,0⟩],some 1⟩ := by decide +kernel
example : (commit changed []).map (fun s => s.current) = some changed.next := by decide +kernel

-- Invalid ABCI changes must fail without producing a partially changed set.
example : update initial.next [⟨30,3,0⟩] = none := by decide +kernel
example : update initial.next [⟨30,3,2⟩,⟨40,3,1⟩] = none := by decide +kernel
example : update initial.next [⟨10,2,0⟩,⟨20,1,0⟩] = none := by decide +kernel
example : genesis 0 [⟨10,2,maxPower+1,0⟩] = none := by decide +kernel

-- Go / truncates toward zero in rescaling; big.Int.Div floors during centering.
example : truncate (-5) 2 = -2 ∧ average [⟨1,1,1,-2⟩,⟨2,2,1,1⟩] = -1 := by
  decide +kernel
example : normalize [⟨10,2,3,-9⟩,⟨20,1,1,2⟩] =
    some [⟨10,2,3,-2⟩,⟨20,1,1,3⟩] := by decide +kernel
example : clip (maxInt+1) = maxInt ∧ clip (minInt-1) = minInt := by decide +kernel

-- Literal outputs from stock v0.40.0: normalization runs again at each height.
def historical : ValSet := ⟨[⟨3,3,3,5⟩,⟨2,2,2,6⟩,⟨1,1,1,-6⟩],some 3⟩
example : ((increment historical 1).bind fun s => increment s 1) =
    some ⟨[⟨3,3,3,0⟩,⟨2,2,2,2⟩,⟨1,1,1,-2⟩],some 3⟩ := by decide +kernel
example : increment historical 2 =
    some ⟨[⟨3,3,3,4⟩,⟨2,2,2,3⟩,⟨1,1,1,-5⟩],some 3⟩ := by decide +kernel

-- A recovery origin preserves the old landing hash, but starts fresh priorities.
example : openOrigin (fun _ => 17) 40 40 999 initial changed = some initial := by decide +kernel
example : openOrigin (fun _ => 17) 40 41 999 initial changed = none := by decide +kernel
example : openOrigin (fun _ => 17) 40 41 17 initial changed = some changed := by decide +kernel
example : openOrigin (fun _ => 17) 40 39 17 initial changed = none := by decide +kernel
example : openOrigin (fun _ => 17) 40 41 17 initial
    {changed with current := {changed.current with proposer := none}} = none := by decide +kernel

open Etna.Design Etna.Design.Current

def context : Consensus.Context :=
  ⟨⟨1,2,3,4⟩,1,8,5,0,10,1,1,3,
    (fun cut => if cut = 5 then [⟨10,3,0,100⟩]
      else [⟨30,2,0,100⟩]),fun _ => 6⟩
def addressOf (key : Hash) : Nat := if key = 10 then 2 else if key = 20 then 1 else 3
def policy : Blocks.Policy where
  consensus := context
  startHeight := 0
  gridK := 1
  committeeConfig := 0
  maxAnchorAge := 10
  forcedDelay := 1
  unsettled := 10
  referenceNumber := 10
  referenceHash := 0
  committeeHash := fun _ => 0
  signature := fun _ => True
  anchorAuthenticated := fun _ => true
  committeeAuthenticated := fun _ _ => true
  forcedAuthenticated := fun _ _ => true
  scheduleAuthenticated := fun _ _ => true
  batchPayloadValid := fun _ _ => true
  configHash := fun _ => 0
  historyAuthenticated := fun _ _ => true
  catalogue := fun _ => none

def blockAt (height hash : Nat) : Blocks.Block :=
  ⟨⟨⟨height,0,0,0,0,0,⟨0,0,0,0,0,0,0⟩,hash⟩,0,none,⟨1,2,3,4⟩,1,0,100,0,
    false,none,0,0,0,0,[],none,.unavailable⟩,⟨0,0,0,0,0⟩,[],none,[]⟩
def recovered : ValidatorState.CommitState := (genesisFor context addressOf).getD default

-- S(1)=9 updates the committee for H(1)=11. Both 9 and 10 still use the old set.
example : (checkRun policy addressOf (fun s => s.height+8) recovered
    [blockAt 9 17,blockAt 10 18,blockAt 11 19]).isSome = true := by decide +kernel
example : checkRun policy addressOf (fun s => s.height+8) recovered
    [blockAt 9 99,blockAt 10 18,blockAt 11 19] = none := by decide +kernel
example : checkRun policy addressOf (fun s => s.height+8) recovered
    [blockAt 10 18] = none := by decide +kernel

-- Recovering at S(1) discards the old generation's already-returned update;
-- H(1)=11 must continue with this recovery's initial set, not that old pending set.
def afterSwitchPolicy : Blocks.Policy :=
  {policy with consensus := {context with originHeight := 9}}
def afterSwitchGenesis : ValidatorState.CommitState :=
  (genesisFor afterSwitchPolicy.consensus addressOf).getD default
example : (checkRun afterSwitchPolicy addressOf (fun s => s.height+8) afterSwitchGenesis
    [blockAt 10 18,blockAt 11 19]).isSome = true := by decide +kernel

end Etna.ValidatorStateRegression
