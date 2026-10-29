import EtnaModel.Capital
import EtnaModel.Staking

/-! Numerical launch-acceptance regressions, independent of protocol validity. -/
namespace Etna.Design.CapitalRegression

/-- Division with no remainder does not add an extra base unit. -/
theorem exact_stake_floor : Capital.minimumTotalStake 1 3 = 1000000000000000000 := by
  decide +kernel

/-- A nonzero remainder rounds up by one TAIKO base unit. -/
theorem rounded_stake_floor : Capital.minimumTotalStake 1 7 = 428571428571428572 := by
  decide +kernel

/-- Blocking a strict two-thirds commit uses the ceiling, including exact division. -/
theorem integer_blocking_boundaries :
    Capital.blockingPower 0 = 0 ∧ Capital.blockingPower 1 = 1 ∧
    Capital.blockingPower 3 = 1 ∧ Capital.blockingPower 4 = 2 := by
  decide +kernel

def fourIndependent : List Committee.Entry :=
  [⟨1,10,0,100⟩,⟨2,10,0,100⟩,⟨3,10,0,100⟩,⟨4,10,0,100⟩]

/-- A valid numerical launch fixture also witnesses that acceptance is satisfiable. -/
theorem independent_launch_accepted :
    Capital.launchAccepted 10 (10^18) 10 true fourIndependent id = true := by
  decide +kernel

/-- Zero capital target, reference price or power unit never passes acceptance. -/
theorem zero_inputs_rejected :
    Capital.launchAccepted 0 (10^18) 10 true fourIndependent id = false ∧
    Capital.launchAccepted 10 0 10 true fourIndependent id = false ∧
    Capital.launchAccepted 10 (10^18) 0 true fourIndependent id = false := by
  decide +kernel

/-- External valuation expiry prevents initial acceptance. -/
theorem expired_valuation_rejected :
    Capital.launchAccepted 10 (10^18) 10 false fourIndependent id = false := by
  decide +kernel

def threeEqual : List Committee.Entry := [⟨1,10,0,100⟩,⟨2,10,0,100⟩,⟨3,10,0,100⟩]

/-- Per-entry power exactly one third fails the strict concentration bound. -/
theorem entry_equality_rejected :
    Capital.launchAccepted 10 (10^18) 10 true threeEqual id = false := by
  decide +kernel

def sixEqual : List Committee.Entry :=
  [⟨1,10,0,100⟩,⟨2,10,0,100⟩,⟨3,10,0,100⟩,
   ⟨4,10,0,100⟩,⟨5,10,0,100⟩,⟨6,10,0,100⟩]

/-- Labels 1 and 2 represent a known common controller; funding alone does not assign labels. -/
def firstTwoCommon (key : Hash) : Hash := if key = 2 then 1 else key

/-- Individually small entries still fail when their known aggregate is exactly one third. -/
theorem common_control_equality_rejected :
    Capital.concentrationChecks 10 sixEqual id = true ∧
    Capital.concentrationChecks 10 sixEqual firstTwoCommon = false := by
  decide +kernel

/-- The selected-stake floor does not subsume the integer blocking-power check. -/
theorem stake_floor_alone_insufficient :
    Capital.minimumTotalStake 25 (10^18) ≤
      Capital.selectedStake (fourIndependent.map (fun e => { e with stake := 19 })) ∧
    Capital.launchAccepted 25 (10^18) 10 true
      (fourIndependent.map (fun e => { e with stake := 19 })) id = false := by
  decide +kernel

/-- Conversely, sufficient integer blocking value does not replace the total-stake floor. -/
theorem blocking_value_alone_insufficient :
    15 * (10^18) ≤ Capital.blockingPower (Committee.totalPower 10 fourIndependent) *
      10 * (10^18) ∧
    Capital.launchAccepted 15 (10^18) 10 true fourIndependent id = false := by
  decide +kernel

/-- An ineligible, unselected entry with abundant funds cannot make committee 0 pass. -/
theorem unselected_funds_excluded :
    Committee.chosen 10 10 0 4 (⟨99,10^30,1,100⟩ :: fourIndependent) = fourIndependent ∧
    Capital.launchAccepted 15 (10^18) 10 true
      (Committee.chosen 10 10 0 4 (⟨99,10^30,1,100⟩ :: fourIndependent)) id = false := by
  have selected : Committee.chosen 10 10 0 4
      (⟨99,10^30,1,100⟩ :: fourIndependent) = fourIndependent := by
    change ((fourIndependent.mergeSort Committee.rank).take 4).mergeSort
      (fun a b => decide (a.key ≤ b.key)) = fourIndependent
    have ranked : fourIndependent.mergeSort Committee.rank = fourIndependent :=
      List.mergeSort_of_pairwise (by decide +kernel)
    rw [ranked]
    change fourIndependent.mergeSort (fun a b => decide (a.key ≤ b.key)) = fourIndependent
    exact List.mergeSort_of_pairwise (by decide +kernel)
  rw [selected]
  decide +kernel

/-- Registry bonds with huge pending deposits still expose only their effective stakes. -/
def pendingBonds : List Staking.Bond :=
  fourIndependent.map (fun e =>
    ⟨e.key,e.key,e.stake,e.activeFrom,e.exitAt,false,none,10^30,1⟩)

/-- Pending liability is real principal but cannot replenish launch capital until activation. -/
theorem pending_funds_excluded :
    1000000000000000000 < (pendingBonds.map Staking.Bond.balance).sum ∧
    pendingBonds.map Staking.toEntry = fourIndependent ∧
    Capital.launchAccepted 15 (10^18) 10 true (pendingBonds.map Staking.toEntry) id = false := by
  decide +kernel

end Etna.Design.CapitalRegression
