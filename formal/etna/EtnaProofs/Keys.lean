import EtnaModel.Keys

/-! Proofs about `EtnaModel.Keys`. -/
namespace Etna.Design.Keys

theorem decodeWith_sound {p : Nat} {input : List Byte} {x y : Nat}
    (ok : decodeWith p input = some (x, y)) :
    input.length = 33 ∧ x < p ∧ y < p ∧ onCurveMod p x y ∧
    x = beNat input.tail ∧ (input.headD 0).val = 2+y%2 ∧
    ((input.headD 0).val = 2 ∨ (input.headD 0).val = 3) ∧ compress x y = input := by
  cases input with
  | nil => simp [decodeWith] at ok
  | cons pre rest =>
    simp only [decodeWith, accept] at ok
    split at ok
    · rename_i h
      obtain ⟨len, pfx, hx, _, _, hy, par, curve, comp⟩ := h
      simp only [Option.some.injEq, Prod.mk.injEq] at ok
      obtain ⟨rfl, rfl⟩ := ok
      refine ⟨len, hx, hy, curve, rfl, ?_, pfx, comp⟩
      simp only [List.headD_cons]
      omega
    · contradiction

/-- An accepted key is a reduced on-curve point with the requested parity that
recompresses byte-for-byte to the 33-byte input. -/
theorem decompress_sound {input : List Byte} {x y : Nat}
    (ok : decompress input = some (x, y)) :
    input.length = 33 ∧ x < fieldP ∧ y < fieldP ∧ onCurve x y ∧
    x = beNat input.tail ∧ (input.headD 0).val = 2+y%2 ∧
    ((input.headD 0).val = 2 ∨ (input.headD 0).val = 3) ∧ compress x y = input :=
  decodeWith_sound ok

/-- Canonical encoding: no two distinct byte strings decode to the same point. -/
theorem decompress_injective {a b : List Byte} {v : Nat × Nat}
    (ha : decompress a = some v) (hb : decompress b = some v) : a = b := by
  obtain ⟨x, y⟩ := v
  rw [← (decompress_sound ha).2.2.2.2.2.2.2, ← (decompress_sound hb).2.2.2.2.2.2.2]

/-- Flipping the prefix of an accepted key can only yield the other root: same X,
different Y, hence a different `keccak256(ckX ‖ ckY)` address under hash injectivity. -/
theorem flipped_prefix_other_point {k : List Byte} {x y x' y' : Nat}
    (ok : decompress k = some (x, y)) (flipped : decompress (flipPrefix k) = some (x', y')) :
    x' = x ∧ y' ≠ y := by
  have s := decompress_sound ok
  have t := decompress_sound flipped
  cases k with
  | nil => simp at s
  | cons pre rest =>
    simp only [flipPrefix, List.tail_cons, List.headD_cons] at s t
    refine ⟨by rw [t.2.2.2.2.1, s.2.2.2.2.1], ?_⟩
    intro same
    subst same
    have hs := s.2.2.2.2.2.1
    have ht := t.2.2.2.2.2.1
    rcases s.2.2.2.2.2.2.1 with h2 | h3
    · simp [h2] at ht
      omega
    · simp [h3] at ht
      omega

/-- Both square roots y and p − y satisfy the same curve equation. -/
theorem neg_square_mod (p y : Nat) (le : y ≤ p) : (p-y)*(p-y) % p = y*y % p := by
  obtain ⟨q, rfl⟩ : ∃ q, p = q+y := ⟨p-y, by omega⟩
  have expand : q*q+(q+y)*(2*y) = y*y+(q+y)*(q+y) := by
    simp only [Nat.add_mul, Nat.mul_add, Nat.two_mul, Nat.mul_comm y q]
    omega
  have h := congrArg (· % (q+y)) expand
  simp only [Nat.add_mul_mod_self_left] at h
  simpa [show q+y-y = q by omega] using h

theorem generator_even_prefix : decompress (key 2 gx) = some (gx, gy) := by decide +kernel

theorem generator_odd_prefix : decompress (key 3 gx) = some (gx, fieldP-gy) := by decide +kernel

theorem leading_zero_x_kept :
    decompress (key 2 1) = some (1, oneY) ∧ decompress (key 3 1) = some (1, fieldP-oneY) := by
  decide +kernel

/-- 0³ + 7 = 7 is a quadratic non-residue mod p: X = 0 is not a point. -/
theorem non_residue_rejected : decompress (key 2 0) = none ∧ decompress (key 3 0) = none := by
  decide +kernel

/-- X must not be reduced: X = p (≡ 0) and X = p + 1 (≡ 1, a valid X) are rejected. -/
theorem unreduced_x_rejected : decompress (key 2 fieldP) = none ∧ decompress (key 2 (fieldP+1)) = none := by
  decide +kernel

theorem other_prefixes_rejected :
    decompress (key 4 gx) = none ∧ decompress (key 0 gx) = none ∧ decompress (key 6 gx) = none := by
  decide +kernel

theorem wrong_lengths_rejected :
    decompress (2 :: (beBytes32 gx).take 31) = none ∧ decompress (key 2 gx ++ [0]) = none ∧
    decompress [] = none := by
  decide +kernel

end Etna.Design.Keys
