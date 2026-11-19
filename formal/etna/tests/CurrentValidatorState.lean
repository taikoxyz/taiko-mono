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

end Etna.ValidatorStateRegression
