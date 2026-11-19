import EtnaProofs.Current

namespace CurrentAdmissionTests
open Etna.Design Etna.Design.Current
set_option maxRecDepth 50000
set_option maxHeartbeats 16000000

def bond (slot amount : Nat) : Registry.Bond :=
  ⟨⟨slot+1,7,amount,1,Staking.noExit,false,none,0,0⟩,some slot⟩

def full : Registry.State :=
  { nextId := 4096, bonds := fun i => if i < 4096 then some (bond i 20) else none,
    slots := fun i => if i < 4096 then some i else none,
    keyId := fun k => if 0 < k ∧ k ≤ 4096 then some (k-1) else none }

-- Every slot held: no admission slot, also with a zero balance in slot 17, whatever the amount.
def zeroBalance : Registry.State :=
  { full with bonds := fun i => if i < 4096 then some (bond i (if i = 17 then 0 else 20)) else none }
example : Registry.admissionSlot full = none := by decide +kernel
example : Registry.admissionSlot zeroBalance = none := by decide +kernel
example : Registry.register zeroBalance 9000 8 1000 10 = none := by decide +kernel

-- Omitting slot 4095 misses the only empty slot; including slot 4096 selects a slot that
-- does not exist in `full`.
def lastEmpty : Registry.State :=
  { nextId := 4095, bonds := fun i => if i < 4095 then some (bond i 20) else none,
    slots := fun i => if i < 4095 then some i else none,
    keyId := fun k => if 0 < k ∧ k ≤ 4095 then some (k-1) else none }
example : Registry.admissionSlot lastEmpty = some 4095 := by decide +kernel
example : ((Registry.register lastEmpty 9000 8 10 10).map fun result =>
    (result.2,result.1.slots 4095,result.1.slots 4096,(result.1.bonds 4095).map fun b => b.slot)) =
      some (4095,some 4095,none,some (some 4095)) := by decide +kernel

-- Bonds 0, 1 and 2 hold slots 0, 2 and 3: slot 1 is the lowest empty slot, below 4 to 4095.
def gaps : Registry.State :=
  { nextId := 3, bonds := fun i => if i < 3 then some ⟨(bond i 20).value,some (if i = 0 then 0 else i+1)⟩ else none,
    slots := fun i => if i = 0 then some 0 else if i = 2 ∨ i = 3 then some (i-1) else none,
    keyId := fun k => if 0 < k ∧ k ≤ 3 then some (k-1) else none }
example : Registry.admissionSlot gaps = some 1 := by decide +kernel
example : ((Registry.register gaps 9000 8 10 10).map fun result =>
    (result.2,result.1.slots 1,result.1.slots 4,result.1.slots 2)) =
      some (3,some 3,none,some 1) := by decide +kernel

end CurrentAdmissionTests
