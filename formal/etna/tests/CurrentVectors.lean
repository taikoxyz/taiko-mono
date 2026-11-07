import EtnaVectors.CurrentRegistry
import EtnaModel.CurrentStakeRisk

/-! Admission fixtures must satisfy the same released-bond metadata fence as normal
registry traces; a vacancy cannot be made by flipping only the released flag. -/
namespace CurrentVectorTests
open Etna.Design Etna.Design.Current Etna.Vectors.CurrentRegistry
set_option maxRecDepth 30000
set_option maxHeartbeats 12000000

example : ((opening {vacant := true}).registry.ledger.bonds 4095).map
    (fun b => decide (b.value.released = true → b.value.exitAt ≤ 2)) = some true := by
  decide +kernel

example : (vacancyRequest {}).isSome = true ∧ (vacancyConfirmation {}).isSome = true ∧
    (vacancyWithdrawal {}).isSome = true := by decide +kernel

example : ((vacancyConfirmation {}).map Prod.fst).bind
    (fun s => (s.registry.ledger.bonds 4095).map (fun b => b.value.confirmedAt)) =
      some (some 2) := by decide +kernel

example : (opening {vacant := true}).registry.ledger.bonds 4095 =
    some ⟨⟨4096,0,0,1,2,true,none,0,0⟩,none⟩ := by decide +kernel
example : (opening {vacant := true}).registry.ledger.keyId 4096 = some 4095 ∧
    (opening {vacant := true}).registry.ledger.nextId = 4096 ∧
    (opening {vacant := true}).registry.ledger.slots 4095 = none := by decide +kernel
example : (opening {vacant := true}).token.balances 7 = 10 ∧
    (opening {vacant := true}).token.balances 4 = 81900 := by decide +kernel

-- A registration at block 0 activates at 1; top-up is permitted only then and
-- becomes ready at 2. The seeded pending fields must match that real operation.
example : RegistryMachine.bondEdit (registry {}) (view 0) 0 (initialBond {} 4095).value
    (.topUp 4095 7 3) = none := by decide +kernel
example : RegistryMachine.bondEdit (registry {}) (view 0) 1 (initialBond {} 4095).value
    (.topUp 4095 7 3) = some (initialBond {pending := 3} 4095).value := by decide +kernel

instance (snapshot : Nat) (b : Staking.Bond) : Decidable (StakeRisk.BondMetadata snapshot b) := by
  unfold StakeRisk.BondMetadata
  infer_instance

/-- Reinstating a synthetic released/no-exit bond breaks the actual model invariant.
Check every issued bond in each of the eight executable openings, including funding. -/
def openingValid (seed : Seed) : Bool :=
  let before := opening seed
  let snapshot := if seed.vacant then 2 else 0
  (List.range 4096).all (fun id =>
    ((before.registry.ledger.bonds id).map fun b =>
      decide (StakeRisk.BondMetadata snapshot b.value)).getD false) &&
    decide (RegistryMachine.reserve before.registry.ledger = before.token.balances 4) &&
    decide (before.token.allowances 4 4 = 0)

example : ([{}, {}, {}, {low := 17,second := some 4095},
    {low := 17,pending := 1,second := some 4095}, {lowStake := 20},
    {vacant := true}, {lowStake := 7,pending := 3}] : List Seed).all openingValid = true := by
  decide +kernel

end CurrentVectorTests
