import EtnaModel.Encoding
import EtnaProofs.Landing

namespace Etna.Design.Encoding
theorem domain_tags_are_ascii :
    domain.toList.map Fin.val = ascii "TAIKO_ETNA_LAND_V1" ++ List.replicate 14 0 ∧
    cutDomain.toList.map Fin.val = ascii "ETNA_LAND_CUTS_V1" ++ List.replicate 15 0 ∧
    configDomain.toList.map Fin.val = ascii "ETNA_PARENT_ANCHOR_V1" ++ List.replicate 11 0 := by
  decide +kernel

theorem wordAt_encode (s : Statement) (i : Fin 21) : wordAt (encode s) i = (words s)[i.val] := by
  apply Vector.ext
  intro j hj
  simp only [wordAt,encode,Vector.getElem_ofFn]
  rw [Vector.getElem_flatten (xss := words s)]
  simp [Nat.add_div,Nat.add_mod,Nat.mod_eq_of_lt hj,Nat.div_eq_of_lt hj,show ¬32 ≤ j by omega]

theorem decode_encode (s : Statement) : decode (encode s) = s := by
  simp only [decode,wordAt_encode]
  cases s
  rfl

theorem encode_injective (a b : Statement) (same : encode a = encode b) : a = b := by
  have := congrArg decode same
  simpa only [decode_encode] using this

theorem statement_word_binding (s : Statement) :
    wordAt (encode s) 6 = s.parentHeight ∧ wordAt (encode s) 8 = s.parentCometHash ∧
    wordAt (encode s) 12 = s.lastCometHash ∧ wordAt (encode s) 19 = s.activeSnapshot ∧
    wordAt (encode s) 20 = s.cutHash := by
  simp only [wordAt_encode]
  exact ⟨rfl,rfl,rfl,rfl,rfl⟩

/-- Collision separation for just the two compared canonical preimages. -/
theorem hash_binding (hash : Vector Byte 672 → Hash) (a b : Statement)
    (separate : encode a ≠ encode b → hash (encode a) ≠ hash (encode b))
    (same : hash (encode a) = hash (encode b)) : a = b := by
  apply encode_injective
  apply Classical.byContradiction
  intro h
  exact separate h same

theorem natWord_byte (n : Nat) (i : Fin 32) :
    (natWord n)[i.val].val = n/256^(31-i.val)%256 := by simp [natWord]

private theorem bounded_digits_injective (width a b : Nat)
    (ha : a < 256 ^ width) (hb : b < 256 ^ width)
    (digits : ∀ k, k < width → a / 256 ^ k % 256 = b / 256 ^ k % 256) : a = b := by
  induction width generalizing a b with
  | zero => simp at ha hb; omega
  | succ width ih =>
    have qa : a / 256 < 256 ^ width := by
      apply (Nat.div_lt_iff_lt_mul (by decide)).2
      simpa [Nat.pow_succ] using ha
    have qb : b / 256 < 256 ^ width := by
      apply (Nat.div_lt_iff_lt_mul (by decide)).2
      simpa [Nat.pow_succ] using hb
    have qs := ih (a / 256) (b / 256) qa qb (by
      intro k hk
      have d := digits (k+1) (by omega)
      simpa [Nat.div_div_eq_div_mul, Nat.pow_succ, Nat.mul_comm] using d)
    have low := digits 0 (by omega)
    simp at low
    omega

/-- Canonical bounded integers (including uint160 addresses) cannot collapse in `natWord`.
Together with `decode_encode`, this recovers typed fields rather than hash identities. -/
theorem natWord_injective (a b : Nat) (ha : a < 2 ^ 256) (hb : b < 2 ^ 256)
    (same : natWord a = natWord b) : a = b := by
  apply bounded_digits_injective 32 a b (by simpa using ha) (by simpa using hb)
  intro k hk
  have h := congrArg (fun word : Word => word[31-k]'(by omega)) same
  have hv := congrArg Fin.val h
  change (natWord a)[31-k].val = (natWord b)[31-k].val at hv
  rw [natWord_byte a ⟨31-k, by omega⟩, natWord_byte b ⟨31-k, by omega⟩] at hv
  simpa only [show 31 - (31 - k) = k by omega] using hv

theorem flatBytes_length (ws : List Word) : (flatBytes ws).length = 32*ws.length := by
  induction ws with
  | nil => rfl
  | cons w ws ih => simp [flatBytes] at *; omega

/-- The cutLeaf preimage is 128 bytes, the packed list 32 bytes per leaf (empty when h = p+K,
hashed as keccak256("")), and the cutHash preimage 160 bytes. -/
theorem cut_preimage_lengths (keccak : List Byte → Word) (x : Nat) (c : Cut) (r : CutHash) :
    (flatBytes (leafWords x c)).length = 128 ∧
    (packedLeaves keccak r.leaves).length = 32*r.leaves.length ∧
    packedLeaves keccak [] = [] ∧
    (flatBytes (cutHashWords keccak r)).length = 160 :=
  ⟨by simp [flatBytes_length, leafWords],by simp [packedLeaves, flatBytes_length],rfl,
   by simp [flatBytes_length, cutHashWords]⟩

theorem cut_calldata_size (keccak : List Byte → Word) (leaves : List Leaf) :
    cutCalldata keccak leaves = 32*leaves.length := by
  simp [cutCalldata, packedLeaves, flatBytes_length]

theorem config_preimage_length (a b c d e f : Nat) :
    (flatBytes (configWords a b c d e f)).length = 224 := by
  simp [flatBytes_length, configWords]

theorem packRecord_fits {c generation cursor : Nat}
    (bc : c < limit48) (bg : generation < limit48) (bh : cursor < limit48) :
    packRecord c generation cursor < 2^144 := by
  unfold packRecord
  have hB : (2:Nat)^144 = limit48*(limit48*limit48) := by unfold limit48; decide
  rw [hB]
  generalize limit48 = B at *
  have s1 : c + generation*B < B*B := by
    have := Nat.mul_le_mul_right B (Nat.succ_le_of_lt bg)
    rw [Nat.succ_mul] at this
    omega
  have s2 : B*B + cursor*(B*B) ≤ B*(B*B) := by
    have := Nat.mul_le_mul_right (B*B) (Nat.succ_le_of_lt bh)
    rw [Nat.succ_mul] at this
    omega
  simp only [Nat.mul_assoc]
  omega

theorem packRecord_injective {c₁ g₁ h₁ c₂ g₂ h₂ : Nat}
    (bc₁ : c₁ < limit48) (bg₁ : g₁ < limit48) (bc₂ : c₂ < limit48) (bg₂ : g₂ < limit48)
    (same : packRecord c₁ g₁ h₁ = packRecord c₂ g₂ h₂) : c₁ = c₂ ∧ g₁ = g₂ ∧ h₁ = h₂ := by
  have pos : 0 < limit48 := by decide
  unfold packRecord at same
  have low₁ : (c₁ + g₁*limit48 + h₁*limit48*limit48) % limit48 = c₁ := by
    rw [show c₁ + g₁*limit48 + h₁*limit48*limit48 = c₁ + limit48*(g₁ + h₁*limit48) by
      simp only [Nat.mul_add, Nat.mul_comm, Nat.mul_left_comm, Nat.add_assoc]]
    rw [Nat.add_mul_mod_self_left, Nat.mod_eq_of_lt bc₁]
  have low₂ : (c₂ + g₂*limit48 + h₂*limit48*limit48) % limit48 = c₂ := by
    rw [show c₂ + g₂*limit48 + h₂*limit48*limit48 = c₂ + limit48*(g₂ + h₂*limit48) by
      simp only [Nat.mul_add, Nat.mul_comm, Nat.mul_left_comm, Nat.add_assoc]]
    rw [Nat.add_mul_mod_self_left, Nat.mod_eq_of_lt bc₂]
  have hc : c₁ = c₂ := by rw [← low₁, ← low₂, same]
  subst hc
  have rest : g₁ + h₁*limit48 = g₂ + h₂*limit48 := by
    have e : limit48*(g₁ + h₁*limit48) = limit48*(g₂ + h₂*limit48) := by
      have := same
      simp only [Nat.mul_add, Nat.mul_comm, Nat.mul_left_comm] at this ⊢
      omega
    exact Nat.eq_of_mul_eq_mul_left pos e
  have mg₁ : (g₁ + h₁*limit48) % limit48 = g₁ := by
    rw [Nat.add_mul_mod_self_right, Nat.mod_eq_of_lt bg₁]
  have mg₂ : (g₂ + h₂*limit48) % limit48 = g₂ := by
    rw [Nat.add_mul_mod_self_right, Nat.mod_eq_of_lt bg₂]
  have hg : g₁ = g₂ := by rw [← mg₁, ← mg₂, rest]
  subst hg
  have : h₁*limit48 = h₂*limit48 := by omega
  exact ⟨rfl, rfl, Nat.eq_of_mul_eq_mul_right pos this⟩

theorem record_three_words (r : Checkpoint) : (flatBytes (recordWords r)).length = 96 := by
  simp [flatBytes_length, recordWords]

theorem ofData_binds_full_proof (d : StatementData) (keccak : List Byte → Word) :
    (ofData d keccak).parentHeight = natWord d.input.parentHeight ∧
    (ofData d keccak).parentCometHash = natWord d.parentCometHash ∧
    (ofData d keccak).headBefore = natWord d.headBefore ∧
    (ofData d keccak).cutHash = keccak (flatBytes (cutHashWords keccak d.cutHash)) := ⟨rfl,rfl,rfl,rfl⟩

end Etna.Design.Encoding
