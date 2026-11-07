import EtnaProofs.CurrentAdmission

namespace CurrentAdmissionTests
open Etna.Design Etna.Design.Current
set_option maxRecDepth 50000
set_option maxHeartbeats 16000000

def bond (slot amount pending : Nat) : Registry.Bond :=
  ⟨⟨slot+1,7,amount,1,Staking.noExit,false,none,pending,0⟩,some slot⟩

def full : Registry.State :=
  { nextId := 4096, bonds := fun i => if i < 4096 then some (bond i 20 0) else none,
    slots := fun i => if i < 4096 then some i else none,
    keyId := fun k => if 0 < k ∧ k ≤ 4096 then some (k-1) else none }

def lastMinimum : Registry.State :=
  { full with bonds := fun i => if i < 4096 then some (bond i (if i=4095 then 10 else 20) 0) else none }

-- Omitting 4095 misses the unique minimum. Including 4096 selects an illegal vacancy.
example : Registry.admissionSlot lastMinimum = 4095 := by decide +kernel
example : Registry.admissionSlot full = 0 := by decide +kernel

def tied : Registry.State :=
  { full with bonds := fun i => if i < 4096 then some (bond i (if i=17 ∨ i=4095 then 10 else 20) 0) else none }
example : Registry.admissionSlot tied = 17 := by decide +kernel

def pending : Registry.State :=
  { full with bonds := fun i => if i < 4096 then some (bond i (if i=17 ∨ i=4095 then 10 else 20)
    (if i=17 then 1 else 0)) else none }
example : Registry.admissionSlot pending = 4095 := by decide +kernel

example : (Registry.register lastMinimum 9000 8 10 10).isNone = true := by decide +kernel
example : ((Registry.register lastMinimum 9000 8 11 10).map fun result =>
    (result.1.slots 4095,result.1.slots 4096,(result.1.bonds 4095).map fun b =>
      (b.slot,b.value.balance,b.value.exitAt))) = some (some 4096,none,some (none,10,10)) := by
  decide +kernel

end CurrentAdmissionTests
