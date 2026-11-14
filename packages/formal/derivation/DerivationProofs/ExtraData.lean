import DerivationModel.Derivation.ExtraData

namespace TaikoSpec.Derivation.Proofs

@[simp] theorem encodeLE_length (w n : Nat) : (encodeLE w n).length = w := by
  induction w generalizing n with
  | zero => rfl
  | succ w ih => simp [encodeLE, ih]

@[simp] theorem encodeBE_length (w n : Nat) : (encodeBE w n).length = w := by
  simp [encodeBE]

/-- Truncating to a fixed byte width keeps exactly the low bits. -/
theorem decodeLE_encodeLE_mod (w n : Nat) : decodeLE (encodeLE w n) = n % 256 ^ w := by
  induction w generalizing n with
  | zero => simp [encodeLE, decodeLE, Nat.mod_one]
  | succ w ih =>
    simp only [encodeLE, decodeLE, ih]
    change n % 256 + 256 * (n / 256 % 256 ^ w) = n % 256 ^ (w + 1)
    rw [Nat.pow_succ, Nat.mul_comm (256 ^ w) 256, Nat.mod_mul]

@[simp] theorem extraData_length (s : UInt8) (p : Nat) :
    (encodeExtraData s p).length = 7 := by simp [encodeExtraData]

/-- The proposal field keeps the low six bytes, even for proposal IDs above uint48. -/
theorem extraData_proposal (s : UInt8) (p : Nat) :
    decodeExtraDataProposal (encodeExtraData s p) = some (p % uint48Limit) := by
  simp only [decodeExtraDataProposal, encodeExtraData, List.drop_succ_cons, List.drop_zero]
  simpa [decodeBE, encodeBE, uint48Limit] using decodeLE_encodeLE_mod 6 p

end TaikoSpec.Derivation.Proofs
