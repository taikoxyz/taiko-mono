import EtnaModel.Fees
import EtnaProofs.Common

/-! Proofs about `EtnaModel.Fees`. -/
namespace Etna.Design.Fees

theorem be_length (w n : Nat) : (be w n).length = w := by
  induction w generalizing n with
  | zero => rfl
  | succ w ih => simp [be, ih]

theorem be_bytes (w n : Nat) : ∀ b ∈ be w n, b < 256 := by
  induction w generalizing n with
  | zero => simp [be]
  | succ w ih =>
    intro b member
    simp only [be, List.mem_append, List.mem_singleton] at member
    rcases member with inner | rfl
    · exact ih _ b inner
    · exact Nat.mod_lt _ (by decide)

theorem beValue_append (xs : List Nat) (b : Nat) : beValue (xs ++ [b]) = beValue xs*256+b := by
  simp [beValue, List.foldl_append]

theorem beValue_be (w n : Nat) (bounded : n < 256^w) : beValue (be w n) = n := by
  induction w generalizing n with
  | zero => simp at bounded; simp [be, beValue, bounded]
  | succ w ih =>
    have q : n/256 < 256^w := by
      apply (Nat.div_lt_iff_lt_mul (by decide)).2
      simpa [Nat.pow_succ] using bounded
    simp only [be, beValue_append, ih _ q]
    omega

theorem extraData_length (share generation anchor : Nat) :
    (extraData share generation anchor).length = 13 := by
  simp [extraData, be_length]

theorem decode_extraData (share generation anchor : Nat)
    (g : generation < 2^48) (a : anchor < 2^48) :
    decodeExtra (extraData share generation anchor) = some (share,generation,anchor) := by
  have g' : generation < 256^6 := by simpa using g
  have a' : anchor < 256^6 := by simpa using a
  have six : (be 6 generation).length = 6 := be_length 6 generation
  simp only [extraData, decodeExtra, List.length_append, be_length]
  simp [List.take_left' six, List.drop_left' six, beValue_be 6 _ g', beValue_be 6 _ a']

/-- The Etna header always carries basefee share 100 = 0x64. -/
theorem etna_share_byte (generation anchor : Nat) :
    (extraData 100 generation anchor).head? = some 0x64 := rfl

theorem credits_conserve (share baseFee priority gasUsed : Nat) (cap : share ≤ 100) :
    (credits share baseFee priority gasUsed).1 + (credits share baseFee priority gasUsed).2 =
      charged baseFee priority gasUsed := by
  have le : baseFee*gasUsed*share/100 ≤ baseFee*gasUsed := by
    have := Nat.div_le_div_right (c := 100) (Nat.mul_le_mul_left (baseFee*gasUsed) cap)
    simpa using this
  simp only [credits, charged, Nat.add_mul]
  omega

theorem full_share_pays_beneficiary (baseFee priority gasUsed : Nat) :
    credits 100 baseFee priority gasUsed = (charged baseFee priority gasUsed,0) := by
  simp [credits, charged, Nat.add_mul, Nat.add_comm]

/-- Etna: the beneficiary receives every fee of the block and the treasury nothing.
In particular a proposer's own transactions cost it no net fee. -/
theorem etna_block_fees_to_beneficiary (baseFee : Nat) (txs : List Tx) :
    blockCredits 100 baseFee txs = (blockCharged baseFee txs,0) := by
  induction txs with
  | nil => rfl
  | cons tx txs ih =>
    simp only [blockCredits, List.foldr_cons] at *
    rw [ih, full_share_pays_beneficiary]
    simp [blockCharged, Nat.add_comm]

end Etna.Design.Fees
