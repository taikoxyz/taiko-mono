import EtnaModel.Capital

/-! Arithmetic results for the pure launch checks. These establish the stated numerical
conditions under supplied snapshot, valuation and control-classification evidence; they
do not establish acquisition cost, irreversible loss or timely discretionary forfeiture. -/
namespace Etna.Design.Capital

/-- Ceiling division is the least whole amount whose product covers the numerator. -/
theorem ceil_div_le_iff {numerator denominator amount : Nat} (positive : 0 < denominator) :
    ceilDiv numerator denominator ≤ amount ↔ numerator ≤ amount * denominator := by
  unfold ceilDiv
  rw [Nat.div_le_iff_le_mul positive]
  omega

/-- Rounding covers the numerator with strictly less than one denominator of excess. -/
theorem ceil_div_bounds {numerator denominator : Nat} (positive : 0 < denominator) :
    numerator ≤ ceilDiv numerator denominator * denominator ∧
    ceilDiv numerator denominator * denominator < numerator + denominator := by
  refine ⟨(ceil_div_le_iff positive).mp (Nat.le_refl _), ?_⟩
  have bound := Nat.div_mul_le_self (numerator + denominator - 1) denominator
  unfold ceilDiv
  omega

theorem ceil_div_positive {numerator denominator : Nat}
    (numeratorPositive : 0 < numerator) (denominatorPositive : 0 < denominator) :
    0 < ceilDiv numerator denominator := by
  have lower := (ceil_div_bounds (numerator := numerator) denominatorPositive).1
  by_cases positive : 0 < ceilDiv numerator denominator
  · exact positive
  · have zero : ceilDiv numerator denominator = 0 := by omega
    rw [zero, Nat.zero_mul] at lower
    omega

/-- One whole unit below a positive ceiling cannot cover the numerator. -/
theorem ceil_div_predecessor_insufficient {numerator denominator : Nat}
    (numeratorPositive : 0 < numerator) (denominatorPositive : 0 < denominator) :
    (ceilDiv numerator denominator - 1) * denominator < numerator := by
  have positive := ceil_div_positive numeratorPositive denominatorPositive
  have strict : ¬ ceilDiv numerator denominator ≤ ceilDiv numerator denominator - 1 := by omega
  have insufficient : ¬ numerator ≤ (ceilDiv numerator denominator - 1) * denominator :=
    fun enough => strict ((ceil_div_le_iff denominatorPositive).mpr enough)
  omega

/-- The stake floor is exactly the minimum base-unit stake covering three capital targets. -/
theorem minimum_total_stake_le_iff {capitalMin priceRef stake : Nat} (positive : 0 < priceRef) :
    minimumTotalStake capitalMin priceRef ≤ stake ↔
      3 * capitalMin * tokenScale ≤ stake * priceRef :=
  ceil_div_le_iff positive

theorem minimum_total_stake_bounds {capitalMin priceRef : Nat} (positive : 0 < priceRef) :
    3 * capitalMin * tokenScale ≤ minimumTotalStake capitalMin priceRef * priceRef ∧
    minimumTotalStake capitalMin priceRef * priceRef <
      3 * capitalMin * tokenScale + priceRef :=
  ceil_div_bounds positive

theorem minimum_total_stake_positive {capitalMin priceRef : Nat}
    (capitalPositive : 0 < capitalMin) (pricePositive : 0 < priceRef) :
    0 < minimumTotalStake capitalMin priceRef := by
  apply ceil_div_positive _ pricePositive
  exact Nat.mul_pos (Nat.mul_pos (by decide) capitalPositive) (by decide)

/-- The strict greater-than-two-thirds commit rule needs ceil(totalPower/3) withheld power. -/
theorem blocking_power_le_iff (totalPower withheldPower : Nat) :
    blockingPower totalPower ≤ withheldPower ↔ totalPower ≤ 3 * withheldPower := by
  simpa [blockingPower, Nat.mul_comm] using
    (ceil_div_le_iff (numerator := totalPower) (denominator := 3)
      (amount := withheldPower) (by decide))

/-- Arithmetic connection to commit failure; no assumption about an actual adversary. -/
theorem blocking_power_iff_commit_blocked (totalPower withheldPower : Nat) :
    blockingPower totalPower ≤ withheldPower ↔
      ¬ (2 * totalPower < 3 * (totalPower - withheldPower)) := by
  rw [blocking_power_le_iff]
  omega

theorem blocking_power_bounds (totalPower : Nat) :
    totalPower ≤ 3 * blockingPower totalPower ∧
    3 * blockingPower totalPower < totalPower + 3 := by
  simpa [blockingPower, Nat.mul_comm] using
    (ceil_div_bounds (numerator := totalPower) (denominator := 3) (by decide))

/-- Filtering to one supplied controller never adds voting power. -/
theorem common_control_power_le_total (vpUnit : Nat) (selected : List Committee.Entry)
    (controllerOf : Hash → Hash) (controller : Hash) :
    commonControlPower vpUnit selected controllerOf controller ≤ Committee.totalPower vpUnit selected := by
  induction selected with
  | nil => simp [commonControlPower, Committee.totalPower]
  | cons e es ih =>
    unfold commonControlPower at *
    by_cases same : controllerOf e.key = controller
    · simpa [List.filter_cons, same, Committee.totalPower] using
        Nat.add_le_add_left ih (Committee.power vpUnit e)
    · simpa [List.filter_cons, same, Committee.totalPower] using
        Nat.le_trans ih (Nat.le_add_left (Committee.totalPower vpUnit es) (Committee.power vpUnit e))

/-- Acceptance entails current external valuation evidence and both independent checks. -/
theorem launch_capital_requirements {capitalMin priceRef vpUnit : Nat} {valuationCurrent : Bool}
    {selected : List Committee.Entry} {controllerOf : Hash → Hash}
    (accepted : launchAccepted capitalMin priceRef vpUnit valuationCurrent selected controllerOf = true) :
    valuationCurrent = true ∧ 0 < capitalMin ∧ 0 < priceRef ∧ 0 < vpUnit ∧
    minimumTotalStake capitalMin priceRef ≤ selectedStake selected ∧
    capitalMin * tokenScale ≤
      blockingPower (Committee.totalPower vpUnit selected) * vpUnit * priceRef := by
  have capital := (Bool.and_eq_true_iff.mp accepted).1
  exact ⟨(Bool.and_eq_true_iff.mp capital).1, of_decide_eq_true (Bool.and_eq_true_iff.mp capital).2⟩

/-- Both the per-entry and the represented known common-control bound are strict. -/
theorem launch_concentration_requirements {capitalMin priceRef vpUnit : Nat}
    {valuationCurrent : Bool} {selected : List Committee.Entry} {controllerOf : Hash → Hash}
    (accepted : launchAccepted capitalMin priceRef vpUnit valuationCurrent selected controllerOf = true)
    (entry : Committee.Entry) (member : entry ∈ selected) :
    3 * Committee.power vpUnit entry < Committee.totalPower vpUnit selected ∧
    3 * commonControlPower vpUnit selected controllerOf (controllerOf entry.key) <
      Committee.totalPower vpUnit selected := by
  have concentration := (Bool.and_eq_true_iff.mp accepted).2
  have perEntry := List.all_eq_true.mp concentration entry member
  exact ⟨of_decide_eq_true (Bool.and_eq_true_iff.mp perEntry).1,
    of_decide_eq_true (Bool.and_eq_true_iff.mp perEntry).2⟩

/-- Equality at one third is rejected even when both capital checks would pass. -/
theorem entry_at_third_rejected {capitalMin priceRef vpUnit : Nat} {valuationCurrent : Bool}
    {selected : List Committee.Entry} {controllerOf : Hash → Hash}
    (entry : Committee.Entry) (member : entry ∈ selected)
    (equality : 3 * Committee.power vpUnit entry = Committee.totalPower vpUnit selected) :
    launchAccepted capitalMin priceRef vpUnit valuationCurrent selected controllerOf = false := by
  apply Bool.eq_false_iff.mpr
  intro accepted
  have strict := (launch_concentration_requirements accepted entry member).1
  omega

theorem common_control_at_third_rejected {capitalMin priceRef vpUnit : Nat}
    {valuationCurrent : Bool} {selected : List Committee.Entry} {controllerOf : Hash → Hash}
    (entry : Committee.Entry) (member : entry ∈ selected)
    (equality : 3 * commonControlPower vpUnit selected controllerOf (controllerOf entry.key) =
      Committee.totalPower vpUnit selected) :
    launchAccepted capitalMin priceRef vpUnit valuationCurrent selected controllerOf = false := by
  apply Bool.eq_false_iff.mpr
  intro accepted
  have strict := (launch_concentration_requirements accepted entry member).2
  omega

end Etna.Design.Capital
