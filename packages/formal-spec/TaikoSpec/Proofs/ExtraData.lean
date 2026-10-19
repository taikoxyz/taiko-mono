import TaikoSpec.Derivation.ExtraData

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

/-- The legacy field retains the low six bytes even for proposal IDs above uint48. -/
theorem legacy_proposal_truncation (s : UInt8) (p : Nat) :
    decodeExtraDataProposal (encodeLegacyExtraData s p) = some (p % uint48Limit) := by
  have ht : (encodeBE 6 p).take 6 = encodeBE 6 p := List.take_of_length_le (by simp)
  simp only [decodeExtraDataProposal, encodeLegacyExtraData, List.length_cons,
    encodeBE_length, List.drop_succ_cons, List.drop_zero, ht]
  simpa [decodeBE, encodeBE, uint48Limit] using decodeLE_encodeLE_mod 6 p

/-- Every integer in the width's domain round-trips, including leading zero bytes. -/
theorem decodeLE_encodeLE (w n : Nat) (h : n < 256 ^ w) :
    decodeLE (encodeLE w n) = n := by
  induction w generalizing n with
  | zero =>
    simp only [Nat.pow_zero] at h
    have hn : n = 0 := by omega
    simp [encodeLE, decodeLE, hn]
  | succ w ih =>
    have hd : n / 256 < 256 ^ w := by
      apply (Nat.div_lt_iff_lt_mul (by decide : 0 < 256)).2
      simpa [Nat.pow_succ, Nat.mul_comm] using h
    simp only [encodeLE, decodeLE, ih _ hd]
    exact Nat.mod_add_div n 256

/-- Fixed-width big-endian encoding round-trips on its entire valid domain. -/
theorem decodeBE_encodeBE (w n : Nat) (h : n < 256 ^ w) :
    decodeBE (encodeBE w n) = n := by
  simpa [decodeBE, encodeBE] using decodeLE_encodeLE w n h

@[simp] theorem legacyExtraData_length (s : UInt8) (p : Nat) :
    (encodeLegacyExtraData s p).length = 7 := by simp [encodeLegacyExtraData]

theorem etna_encoding_ok_iff (s : UInt8) (p a : Nat) (bs : List UInt8) :
    encodeEtnaExtraData s p a = .ok bs ↔
      p < uint48Limit ∧ a < uint48Limit ∧
      bs = encodeLegacyExtraData s p ++ encodeBE 6 a := by
  unfold encodeEtnaExtraData
  split
  · split <;> simp_all [eq_comm] <;> omega
  · simp_all
    omega

theorem etna_encoding_length {s : UInt8} {p a : Nat} {bs : List UInt8}
    (h : encodeEtnaExtraData s p a = .ok bs) : bs.length = 13 := by
  rcases (etna_encoding_ok_iff s p a bs).1 h with ⟨_, _, rfl⟩
  simp

theorem etna_anchor_roundtrip (s : UInt8) (p a number : Nat)
    (hp : p < uint48Limit) (ha : a < uint48Limit) (hn : number ≠ 0) :
    (encodeEtnaExtraData s p a).toOption.bind (decodeEtnaAnchorBlockNumber number) = some a := by
  simp [encodeEtnaExtraData, hp, ha, Except.toOption, decodeEtnaAnchorBlockNumber, hn,
    decodeBE_encodeBE 6 a ha]

/-- Legacy encoding agrees with the event's proposal ID throughout the uint48 domain. -/
theorem legacy_proposal_roundtrip (s : UInt8) (p : Nat) (hp : p < uint48Limit) :
    decodeExtraDataProposal (encodeLegacyExtraData s p) = some p := by
  have ht : (encodeBE 6 p).take 6 = encodeBE 6 p := List.take_of_length_le (by simp)
  simp [decodeExtraDataProposal, encodeLegacyExtraData, ht, decodeBE_encodeBE 6 p hp]

/-- Both checked integer fields can be recovered independently from the same layout. -/
theorem etna_proposal_roundtrip (s : UInt8) (p a : Nat)
    (hp : p < uint48Limit) (ha : a < uint48Limit) :
    (encodeEtnaExtraData s p a).toOption.bind decodeExtraDataProposal = some p := by
  simp [encodeEtnaExtraData, hp, ha, Except.toOption, decodeExtraDataProposal,
    encodeLegacyExtraData, decodeBE_encodeBE 6 p hp]

/-- The genesis convention applies to every byte layout. -/
theorem genesis_anchor_decode (bs : List UInt8) : decodeEtnaAnchorBlockNumber 0 bs = some 0 := by
  simp [decodeEtnaAnchorBlockNumber]

/-- Non-genesis malformed lengths are rejected. -/
theorem etna_anchor_bad_length (n : Nat) (bs : List UInt8) (hn : n ≠ 0)
    (hl : bs.length ≠ 13) : decodeEtnaAnchorBlockNumber n bs = none := by
  simp [decodeEtnaAnchorBlockNumber, hn, hl]

theorem etna_proposal_overflow (s : UInt8) (p a : Nat) (h : uint48Limit ≤ p) :
    encodeEtnaExtraData s p a = .error .proposalOverflow := by
  simp [encodeEtnaExtraData, Nat.not_lt.mpr h]

theorem etna_anchor_overflow (s : UInt8) (p a : Nat)
    (hp : p < uint48Limit) (ha : uint48Limit ≤ a) :
    encodeEtnaExtraData s p a = .error .anchorOverflow := by
  simp [encodeEtnaExtraData, hp, Nat.not_lt.mpr ha]

end TaikoSpec.Derivation.Proofs
