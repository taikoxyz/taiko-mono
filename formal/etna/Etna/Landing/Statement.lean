module
public import Etna.Common.Words
public import Mathlib.Tactic
public import Init.Data.Vector.Lemmas
public section
set_option maxHeartbeats 2000000
namespace Etna.Landing
abbrev Byte := Fin 256
abbrev AbiWord := Vector Byte 32
/-- ASCII bytes32 tag: vector length checks the right padding without modular truncation. -/
@[expose] def landDomain : AbiWord :=
  #v[84, 65, 73, 75, 79, 95, 69, 84, 78, 65, 95, 76, 65, 78, 68, 95, 86, 56, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
/-- The twenty normalized V8 ABI words, including the blob commitment, not raw blobs. -/
structure LandStatement where
  domain : AbiWord
  l1ChainId : AbiWord
  l2ChainId : AbiWord
  inbox : AbiWord
  registry : AbiWord
  generation : AbiWord
  parentHeight : AbiWord
  parentHash : AbiWord
  config : AbiWord
  lastHeight : AbiWord
  lastBlockHash : AbiWord
  lastStateRoot : AbiWord
  referenceNumber : AbiWord
  referenceHash : AbiWord
  blobCommitment : AbiWord
  headBefore : AbiWord
  headAfter : AbiWord
  recipient : AbiWord
  rewardRecipient : AbiWord
  baseFeeAmount : AbiWord
  deriving DecidableEq, Repr

@[expose] def words (s : LandStatement) : Vector AbiWord 20 :=
  #v[s.domain, s.l1ChainId, s.l2ChainId, s.inbox, s.registry, s.generation,
     s.parentHeight, s.parentHash, s.config, s.lastHeight, s.lastBlockHash,
     s.lastStateRoot, s.referenceNumber, s.referenceHash, s.blobCommitment,
     s.headBefore, s.headAfter, s.recipient, s.rewardRecipient, s.baseFeeAmount]

@[expose] def encodeStatement (s : LandStatement) : Vector Byte 640 := (words s).flatten

@[expose] def wordAt (b : Vector Byte 640) (i : Fin 20) : AbiWord :=
  Vector.ofFn fun j => b[i.val * 32 + j.val]'(by omega)

@[expose] def decodeStatement (b : Vector Byte 640) : LandStatement :=
  ⟨wordAt b 0, wordAt b 1, wordAt b 2, wordAt b 3, wordAt b 4, wordAt b 5,
   wordAt b 6, wordAt b 7, wordAt b 8, wordAt b 9, wordAt b 10, wordAt b 11,
   wordAt b 12, wordAt b 13, wordAt b 14, wordAt b 15, wordAt b 16, wordAt b 17,
   wordAt b 18, wordAt b 19⟩

theorem wordAt_encode (s : LandStatement) (i : Fin 20) :
    wordAt (encodeStatement s) i = (words s)[i.val] := by
  apply Vector.ext
  intro j hj
  simp only [wordAt, encodeStatement, Vector.getElem_ofFn]
  rw [Vector.getElem_flatten (xss := words s)]
  simp [Nat.add_div, Nat.add_mod, Nat.mod_eq_of_lt hj, Nat.div_eq_of_lt hj, show ¬32 ≤ j by omega]

theorem decode_encode (s : LandStatement) : decodeStatement (encodeStatement s) = s := by
  simp only [decodeStatement, wordAt_encode]
  cases s
  rfl

theorem statement_complete (a b : LandStatement) :
    encodeStatement a = encodeStatement b ↔ a = b := by
  constructor
  · intro h
    have := congrArg decodeStatement h
    simpa only [decode_encode] using this
  · exact congrArg encodeStatement

theorem recipient_word (s : LandStatement) :
    wordAt (encodeStatement s) 17 = s.recipient := by rw [wordAt_encode]; rfl

theorem reward_recipient_word (s : LandStatement) :
    wordAt (encodeStatement s) 18 = s.rewardRecipient := by rw [wordAt_encode]; rfl

theorem base_fee_word (s : LandStatement) :
    wordAt (encodeStatement s) 19 = s.baseFeeAmount := by rw [wordAt_encode]; rfl

/-- Independent byte-level ABI normalizer: zero-left-padded, big-endian. -/
@[expose] def natWord (n : Nat) : AbiWord :=
  Vector.ofFn fun i => ⟨n / 256 ^ (31 - i.val) % 256, Nat.mod_lt _ (by decide)⟩

theorem natWord_byte (n : Nat) (i : Fin 32) :
    (natWord n)[i.val].val = n / 256 ^ (31 - i.val) % 256 := by simp [natWord]

theorem address_padding (n : Nat) (h : n < 2 ^ 160) (i : Fin 32) (hi : i.val < 12) :
    (natWord n)[i.val].val = 0 := by
  rw [natWord_byte]
  have hp : 256 ^ 20 ≤ 256 ^ (31 - i.val) := Nat.pow_le_pow_right (by decide) (by omega)
  have hn : n < 256 ^ (31 - i.val) := by omega
  simp [Nat.div_eq_of_lt hn]

/-- Separation for the two actually compared preimages, never global Keccak injectivity. -/
@[expose] def LocalHashSeparation (hash : Vector Byte 640 → Word256) (a b : LandStatement) : Prop :=
  encodeStatement a ≠ encodeStatement b → hash (encodeStatement a) ≠ hash (encodeStatement b)

theorem hash_binding (hash : Vector Byte 640 → Word256) (a b : LandStatement)
    (separation : LocalHashSeparation hash a b)
    (matched : hash (encodeStatement a) = hash (encodeStatement b)) : a = b := by
  apply (statement_complete a b).mp
  by_contra h
  exact separation h matched

/-- Structural LAND-06; runtime conformance instantiates the word equality. -/
theorem encoding_conformance (s : LandStatement) (observedWords : Vector AbiWord 20)
    (sameFields : observedWords = words s) : observedWords.flatten = encodeStatement s := by
  subst observedWords
  rfl
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
  apply bounded_digits_injective 32 a b (by norm_num at *; exact ha) (by norm_num at *; exact hb)
  intro k hk
  have h := congrArg (fun word : AbiWord => word[31-k]'(by omega)) same
  have hv := congrArg Fin.val h
  change (natWord a)[31-k].val = (natWord b)[31-k].val at hv
  rw [natWord_byte a ⟨31-k, by omega⟩, natWord_byte b ⟨31-k, by omega⟩] at hv
  simpa only [show 31 - (31 - k) = k by omega] using hv

/-- Fixed 32-byte words preserve ordered blob list identity before hashing. -/
theorem blob_encoding_injective {n : Nat} (a b : Vector AbiWord n) :
    a.flatten = b.flatten ↔ a = b := Vector.eq_iff_flatten_eq.symm

/-- Non-identical pairs have a satisfiable finite local separation relation. This is an
existence witness for the premise shape, not an implementation of Keccak. -/
theorem local_separation_distinct_nonvacuity (a b : LandStatement) (different : a ≠ b) :
    ∃ hash : Vector Byte 640 → Word256, LocalHashSeparation hash a b := by
  refine ⟨fun bytes => if bytes = encodeStatement a then 0 else 1, ?_⟩
  intro _
  have h : encodeStatement b ≠ encodeStatement a := by
    intro same
    exact different ((statement_complete b a).mp same).symm
  simp [h]

/-- Every output byte is exactly its row-major ABI word byte; this is the unconditional
structural encoding obligation underlying cross-language conformance. -/
theorem encoding_byte (s : LandStatement) (index : Fin 640) :
    (encodeStatement s)[index.val] =
      ((words s)[index.val / 32]'(by omega))[index.val % 32]'(by omega) := by
  exact Vector.getElem_flatten index.isLt

/-- Canonical ABI-packed blob preimage, for arbitrary list lengths. Each typed hash is
exactly one big-endian32-byte word; there is no ABI length or offset prefix. -/
@[expose] def serializeBlobPrefix (blobs : List Word256) : List Byte :=
  blobs.flatMap fun hash => (natWord hash.val).toList

theorem serializeBlobPrefix_length (blobs : List Word256) :
    (serializeBlobPrefix blobs).length = blobs.length * 32 := by
  induction blobs with
  | nil => rfl
  | cons hash tail ih => simp [serializeBlobPrefix] at ih ⊢; omega

theorem serializeBlobPrefix_take (hash : Word256) (tail : List Word256) :
    (serializeBlobPrefix (hash :: tail)).take 32 = (natWord hash.val).toList := by
  simp [serializeBlobPrefix, List.flatMap_cons]

theorem serializeBlobPrefix_drop (hash : Word256) (tail : List Word256) :
    (serializeBlobPrefix (hash :: tail)).drop 32 = serializeBlobPrefix tail := by
  simp [serializeBlobPrefix, List.flatMap_cons]

/-- Unlike the fixed-length Vector lemma, this recovers both length and every typed word. -/
theorem serializeBlobPrefix_injective (a b : List Word256) :
    serializeBlobPrefix a = serializeBlobPrefix b ↔ a = b := by
  constructor
  · intro equal
    induction a generalizing b with
    | nil =>
      have lengths := congrArg List.length equal
      simp only [serializeBlobPrefix_length, List.length_nil] at lengths
      have : b.length = 0 := by omega
      exact (List.length_eq_zero_iff.mp this).symm
    | cons hash tail ih =>
      cases b with
      | nil =>
        have lengths := congrArg List.length equal
        simp only [serializeBlobPrefix_length, List.length_cons, List.length_nil] at lengths
        omega
      | cons hash' tail' =>
        have first := congrArg (List.take 32) equal
        simp only [serializeBlobPrefix_take] at first
        have values := natWord_injective hash.val hash'.val hash.isLt hash'.isLt (Vector.toList_inj.mp first)
        have heads : hash = hash' := Fin.ext values
        have rest := congrArg (List.drop 32) equal
        simp only [serializeBlobPrefix_drop] at rest
        exact congrArg₂ List.cons heads (ih tail' rest)
  · exact congrArg serializeBlobPrefix

/-- Collision separation only for the two actual serialized blob prefixes under the
model's byte-hash primitive. No equal-length premise and no global injectivity. -/
@[expose] def LocalInnerHashSeparation (hash : List Byte → Word256) (a b : List Word256) : Prop :=
  serializeBlobPrefix a ≠ serializeBlobPrefix b →
    hash (serializeBlobPrefix a) ≠ hash (serializeBlobPrefix b)

theorem inner_hash_binding (hash : List Byte → Word256) (a b : List Word256)
    (separation : LocalInnerHashSeparation hash a b)
    (matched : hash (serializeBlobPrefix a) = hash (serializeBlobPrefix b)) : a = b := by
  apply (serializeBlobPrefix_injective a b).mp
  by_contra different
  exact separation different matched

theorem inner_separation_nonvacuity (a b : List Word256) :
    ∃ hash : List Byte → Word256, LocalInnerHashSeparation hash a b := by
  refine ⟨fun bytes => if bytes = serializeBlobPrefix a then 0 else 1, ?_⟩
  intro different
  have reverse : serializeBlobPrefix b ≠ serializeBlobPrefix a := Ne.symm different
  simp [reverse]

theorem unequal_length_inner_nonvacuity :
    let hash : List Byte → Word256 := fun bytes => if bytes.length = 32 then 1 else 2
    LocalInnerHashSeparation hash [1] [1,2] ∧
    hash (serializeBlobPrefix [1]) ≠ hash (serializeBlobPrefix [1,2]) := by
  simp [LocalInnerHashSeparation, serializeBlobPrefix_length]

end Etna.Landing
