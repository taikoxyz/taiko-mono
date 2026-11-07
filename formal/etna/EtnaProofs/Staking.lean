import EtnaModel.Staking
import EtnaProofs.Committee

namespace Etna.Design.Staking

theorem fraction_bounded (remaining bps : Nat) (cap : bps ≤ 10000) : fraction remaining bps ≤ remaining := by
  have h := Nat.div_le_div_right (c := 10000) (Nat.mul_le_mul_left remaining cap)
  simpa [fraction] using h

/-- The integer penalty is exactly the upward rounding of the fixed-rate fraction. -/
theorem forfeit_penalty_ceiling (balance bps : Nat) :
    balance*bps ≤ forfeitPenalty balance bps*10000 ∧
    forfeitPenalty balance bps*10000 < balance*bps+10000 := by
  have rem := Nat.mod_lt (balance*bps+9999) (by decide : 0 < 10000)
  have div := Nat.mod_add_div (balance*bps+9999) 10000
  unfold forfeitPenalty
  omega

theorem forfeit_penalty_bounded (balance bps : Nat) (cap : bps ≤ 10000) :
    forfeitPenalty balance bps ≤ balance := by
  have mul := Nat.mul_le_mul_left balance cap
  have ceiling := forfeit_penalty_ceiling balance bps
  omega

end Etna.Design.Staking
