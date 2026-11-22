import EtnaModel.PerBlockCommittee

namespace Etna.Design.PerBlockCommittee

/-- A decoded candidate has all 128 storage records and satisfies the validator-set checks. -/
theorem candidateMembers_valid {rules : Rules} {seats : List SnapshotSeat}
    {members : List Member} (selected : candidateMembers rules seats = some members) :
    seats.length = seatCount ∧ validMembers rules members = true := by
  unfold candidateMembers at selected
  split at selected
  · contradiction
  next lengthOk =>
    obtain ⟨decoded, _, selected⟩ := Option.bind_eq_some_iff.mp selected
    split at selected
    next valid =>
      cases Option.some.inj selected
      exact ⟨Decidable.not_not.mp lengthOk, valid⟩
    next => contradiction

/-- Candidate activation depends on the full height word, stake threshold and valid records. -/
theorem usableCandidate_requirements {rules : Rules} {height threshold : Nat}
    {snapshot : Snapshot} {members : List Member}
    (selected : usableCandidate rules height threshold snapshot = some members) :
    snapshot.heightWord = height ∧ threshold ≠ forceFallback ∧
    threshold ≤ snapshot.totalStake ∧ snapshot.totalStake < limit256 ∧
    snapshot.seats.length = seatCount ∧ validMembers rules members = true := by
  unfold usableCandidate at selected
  split at selected
  next checks =>
    obtain ⟨enabled, fresh, stake, word⟩ := checks
    exact ⟨fresh, enabled, stake, word, candidateMembers_valid selected⟩
  next => contradiction

/-- The sentinel's outcome is independent of every field of the L2 snapshot. -/
theorem decision_forceFallback (rules : Rules) (height : Nat) (snapshot : Snapshot)
    (anchor : Anchor) (keys : List Hash)
    (wellFormed : height < limit48 ∧ anchor.minTotalStake < limit256 ∧
      anchor.fallbackKeysHash < limit256) (forced : anchor.minTotalStake = forceFallback) :
    decision rules height snapshot anchor keys = fallback rules anchor.fallbackKeysHash keys := by
  unfold decision
  rw [ite_eq_left wellFormed]
  simp [usableCandidate, forced]

/-- An accepted fallback opening authenticates its keys and assigns each exactly one vote. -/
theorem fallback_unitPower {rules : Rules} {expectedHash : Hash} {keys : List Hash}
    {members : List Member} (selected : fallback rules expectedHash keys = some members) :
    rules.hashFallbackKeys keys = expectedHash ∧ validFallbackKeys rules keys = true ∧
      members.map Member.key = keys ∧ members.map Member.power = keys.map (fun _ ↦ 1) := by
  unfold fallback at selected
  split at selected
  next checks =>
    cases Option.some.inj selected
    refine ⟨checks.2.1, checks.2.2, ?_, by simp⟩
    rw [List.map_map]
    exact List.map_id keys
  next => contradiction

/-- Both initially scheduled sets come from this generation's origin commitment. -/
theorem signingSet_first_two (rules : Rules) (origin : GenerationOrigin) (originKeys : List Hash)
    (inputAt : Nat → Option DecisionInput) :
    signingSet rules origin originKeys inputAt (origin.height + 1) =
      fallback rules origin.fallbackKeysHash originKeys ∧
    signingSet rules origin originKeys inputAt (origin.height + 2) =
      fallback rules origin.fallbackKeysHash originKeys := by
  simp [signingSet, show ¬ origin.height + 1 ≤ origin.height by omega,
    show ¬ origin.height + 2 ≤ origin.height by omega,
    show origin.height + 1 ≤ origin.height + 2 by omega]

/-- Every decision after origin is read at H to derive the set that signs H+2. -/
theorem signingSet_at_hplus2 (rules : Rules) (origin : GenerationOrigin) (originKeys : List Hash)
    (inputAt : Nat → Option DecisionInput) {height : Nat} (afterOrigin : origin.height < height) :
    signingSet rules origin originKeys inputAt (height + 2) =
      (inputAt height).bind (fun input ↦
        decision rules height input.snapshot input.anchor input.fallbackKeys) := by
  unfold signingSet
  rw [ite_eq_right (by omega), ite_eq_right (by omega)]
  simp

private theorem seatBitmap_bit_iff (seats : List Nat) (seat : Nat) :
    (seatBitmap seats).testBit seat = true ↔ seat ∈ seats := by
  induction seats with
  | nil => simp [seatBitmap]
  | cons s rest ih =>
    simp only [seatBitmap, Nat.testBit_or, Nat.testBit_two_pow, Bool.or_eq_true_iff,
      decide_eq_true_eq, ih, List.mem_cons]
    exact or_congr ⟨Eq.symm, Eq.symm⟩ Iff.rfl

/-- A generation's first block must have empty LastCommit flags and zero miss bits. -/
theorem missBitmap_first (parentAddresses flags : List Nat) (liveWord : Nat → Nat) :
    missBitmap true parentAddresses flags liveWord = some 0 ↔ flags = [] := by
  cases flags <;> simp [missBitmap]

/-- Each bit is the disjunction of the misses for all parent validators mapped to that seat. -/
theorem missBitmap_bit_iff {parentAddresses flags : List Nat} {liveWord : Nat → Nat}
    {bitmap : Nat} (accepted : missBitmap false parentAddresses flags liveWord = some bitmap)
    (seat : Nat) : bitmap.testBit seat = true ↔ ∃ address flag,
      (address, flag) ∈ parentAddresses.zip flags ∧ flag ≠ commitFlag ∧
        liveSeat (liveWord address) = some seat := by
  simp only [missBitmap, Bool.false_eq_true, ite_false] at accepted
  split at accepted
  · cases Option.some.inj accepted
    rw [seatBitmap_bit_iff]
    simp only [missingSeats, List.mem_filterMap]
    constructor
    · rintro ⟨⟨address, flag⟩, parentEntry, picked⟩
      by_cases committed : flag = commitFlag
      · simp [committed] at picked
      · exact ⟨address, flag, parentEntry, committed, by simpa [committed] using picked⟩
    · rintro ⟨address, flag, parentEntry, missing, picked⟩
      exact ⟨(address, flag), parentEntry, by simpa [missing] using picked⟩
  · contradiction

/-- The miss bitmap has no set bit outside the 128 real seat positions. -/
theorem missBitmap_high_bits_clear {parentAddresses flags : List Nat} {liveWord : Nat → Nat}
    {bitmap seat : Nat} (accepted : missBitmap false parentAddresses flags liveWord = some bitmap)
    (high : seatCount ≤ seat) : bitmap.testBit seat = false := by
  apply Bool.eq_false_of_ne_true
  intro setBit
  obtain ⟨address, _, _, _, picked⟩ := (missBitmap_bit_iff accepted seat).mp setBit
  simp only [liveSeat] at picked
  split at picked
  next wellFormed =>
    have same := Option.some.inj picked
    omega
  next => contradiction

end Etna.Design.PerBlockCommittee
