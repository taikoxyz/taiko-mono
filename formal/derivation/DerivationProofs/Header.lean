import DerivationStatements.Authentication
import DerivationProofs.ExtraData

namespace TaikoSpec.Derivation

namespace Proofs

@[simp] theorem except_ok_bind {ε α β : Type} (a : α) (f : α → Except ε β) :
    (Except.ok a >>= f) = f a := rfl

@[simp] theorem except_error_bind {ε α β : Type} (e : ε) (f : α → Except ε β) :
    (Except.error e >>= f) = .error e := rfl

@[simp] theorem except_ok_map {ε α β : Type} (a : α) (f : α → β) :
    f <$> (Except.ok a : Except ε α) = .ok (f a) := rfl

@[simp] theorem except_error_map {ε α β : Type} (e : ε) (f : α → β) :
    f <$> (Except.error e : Except ε α) = .error e := rfl

variable {c : ChainParams} {ctx : HeaderContext} {p : HeaderParent} {b : DerivedBlock}
  {h : HeaderPlan}

theorem requireRoot_ok {value : Option Root} {missing zero : HeaderError} {r : Root}
    (h : requireRoot value missing zero = .ok r) : value = some r ∧ r ≠ 0 := by
  cases value with
  | none => simp [requireRoot] at h
  | some v =>
    by_cases hv : v = 0
    · simp [requireRoot, hv] at h
    · simp [requireRoot, hv] at h
      subst r
      exact ⟨rfl, hv⟩

/-- Successful construction exposes every output field and both checked inputs. -/
theorem buildHeader_fields (ok : buildHeader c ctx p b = .ok h) :
    h.block = b ∧ h.gasLimit = b.gasLimit + anchorGasReserve c b.timestamp ∧
    h.transactions = candidateTransactions c b ∧
    selectHeaderRoot c ctx p b = .ok h.beaconRoot ∧
    headerExtraData c ctx b = .ok h.extraData := by
  cases hr : selectHeaderRoot c ctx p b with
  | error e => simp [buildHeader, hr] at ok
  | ok r =>
    cases he : headerExtraData c ctx b with
    | error e => simp [buildHeader, hr, he] at ok
    | ok bytes =>
      simp [buildHeader, hr, he] at ok
      subst h
      exact ⟨rfl, rfl, rfl, rfl, rfl⟩

theorem requireRoot_present {value : Option Root} {missing zero : HeaderError}
    {root : Option Root}
    (ok : (requireRoot value missing zero).map some = .ok root) :
    ∃ r, root = some r ∧ r ≠ 0 := by
  cases hr : requireRoot value missing zero with
  | error e => simp [hr, Except.map] at ok
  | ok r =>
    simp [hr, Except.map] at ok
    exact ⟨r, ok.symm, (requireRoot_ok hr).2⟩

/-- Every successful Etna selection is present and nonzero. -/
theorem selectRoot_etna_nonzero {root : Option Root}
    (etna : isEtna c b.timestamp = true)
    (ok : selectHeaderRoot c ctx p b = .ok root) : ∃ r, root = some r ∧ r ≠ 0 := by
  unfold selectHeaderRoot at ok
  simp only [etna, ↓reduceIte] at ok
  split at ok <;> exact requireRoot_present ok

theorem buildHeader_etna_nonzero (etna : isEtna c b.timestamp = true)
    (ok : buildHeader c ctx p b = .ok h) : ∃ r, h.beaconRoot = some r ∧ r ≠ 0 :=
  selectRoot_etna_nonzero etna (buildHeader_fields ok).2.2.2.1

theorem buildHeader_etna_layout (etna : isEtna c b.timestamp = true)
    (ok : buildHeader c ctx p b = .ok h) : h.extraData.length = 13 := by
  have he := (buildHeader_fields ok).2.2.2.2
  simp only [headerExtraData, etna, ↓reduceIte] at he
  cases hec : encodeEtnaExtraData ctx.baseFeeSharing ctx.proposalId b.anchorBlockNumber with
  | error e => simp [hec, Except.mapError] at he
  | ok bytes =>
    simp [hec, Except.mapError] at he
    subst bytes
    exact etna_encoding_length hec

/-- No system entry is inserted, and every candidate remains in its original position. -/
theorem buildHeader_etna_transactions (etna : isEtna c b.timestamp = true)
    (ok : buildHeader c ctx p b = .ok h) :
    h.transactions = b.transactions.map TransactionPlanEntry.manifest ∧
      TransactionPlanEntry.systemAnchor ∉ h.transactions := by
  have ht := (buildHeader_fields ok).2.2.1
  simp only [candidateTransactions, etna, ↓reduceIte] at ht
  constructor
  · exact ht
  · rw [ht]
    simp

/-- Before Etna, Unzen uses the zero root, earlier forks have no root, and the system anchor
precedes the unchanged manifest list. Fork selection depends on the child's timestamp. -/
theorem buildHeader_preEtna (etna : isEtna c b.timestamp = false)
    (ok : buildHeader c ctx p b = .ok h) :
    h.beaconRoot = (if isUnzen c b.timestamp then some 0 else none) ∧
    h.transactions = .systemAnchor :: b.transactions.map TransactionPlanEntry.manifest ∧
    h.extraData.length = 7 := by
  have fields := buildHeader_fields ok
  have hr := fields.2.2.2.1
  have he := fields.2.2.2.2
  have ht := fields.2.2.1
  simp only [candidateTransactions, etna, Bool.false_eq_true, ↓reduceIte] at ht
  simp only [headerExtraData, etna, Bool.false_eq_true, ↓reduceIte, Except.ok.injEq] at he
  have root : h.beaconRoot = (if isUnzen c b.timestamp then some 0 else none) := by
    by_cases unzen : isUnzen c b.timestamp = true
    · simpa [selectHeaderRoot, etna, unzen, Except.pure, Pure.pure] using hr.symm
    · simpa [selectHeaderRoot, etna, unzen, Except.pure, Pure.pure] using hr.symm
  exact ⟨root, ht, he ▸ legacyExtraData_length ctx.baseFeeSharing ctx.proposalId⟩

/-- Turning a successful non-genesis plan into a parent recovers manifest gas exactly. -/
theorem advanceHeader_manifest_gas (hn : b.number ≠ 0)
    (ok : buildHeader c ctx p b = .ok h) :
    effectiveGasLimit c (advanceHeader h).core = b.gasLimit := by
  rcases buildHeader_fields ok with ⟨hb, hg, _⟩
  simp [effectiveGasLimit, advanceHeader, hb, hg, hn]

/-- Root correspondence needs only sound available lookups; reuse needs no lookup at all. -/
theorem selectRoot_correspondence {history : Nat → Root} {root : Option Root}
    (sound : LookupsSound ctx history) (parent : ParentCommits c history p)
    (etna : isEtna c b.timestamp = true)
    (ok : selectHeaderRoot c ctx p b = .ok root) : root = some (history b.anchorBlockNumber) := by
  unfold selectHeaderRoot at ok
  simp only [etna, ↓reduceIte] at ok
  split at ok
  · rename_i reuse
    have parts : isEtna c p.core.timestamp = true ∧ p.core.number ≠ 0 ∧
        b.anchorBlockNumber = p.core.anchorBlockNumber := by
      simpa [reuseParentRoot, Bool.and_eq_true, and_assoc] using reuse
    cases hr : requireRoot p.beaconRoot .missingParentRoot .zeroParentRoot with
    | error e => simp [hr] at ok
    | ok r =>
      simp [hr] at ok
      have hp := parent parts.1 parts.2.1
      have hv := (requireRoot_ok hr).1
      rw [hv] at hp
      simpa [← ok, parts.2.2] using hp
  · cases hr : requireRoot (ctx.l1StateRoot b.anchorBlockNumber)
        (.missingL1Root b.anchorBlockNumber) (.zeroL1Root b.anchorBlockNumber) with
    | error e => simp [hr] at ok
    | ok r =>
      simp [hr] at ok
      rw [← ok, sound _ r (requireRoot_ok hr).1]

theorem buildHeader_correspondence {history : Nat → Root}
    (sound : LookupsSound ctx history) (parent : ParentCommits c history p)
    (ok : buildHeader c ctx p b = .ok h) : HeaderCommits c history h := by
  intro etna
  have fields := buildHeader_fields ok
  rw [fields.1] at etna ⊢
  exact selectRoot_correspondence sound parent etna fields.2.2.2.1

theorem advanceHeader_correspondence {history : Nat → Root}
    (commitment : HeaderCommits c history h) : ParentCommits c history (advanceHeader h) := by
  intro etna _
  exact commitment etna

/-- Canonical commitments are invariant under sequential header construction. -/
theorem buildHeaders_correspondence {history : Nat → Root}
    (sound : LookupsSound ctx history) {bs : List DerivedBlock} {hs : List HeaderPlan}
    (parent : ParentCommits c history p) (ok : buildHeaders c ctx p bs = .ok hs) :
    (∀ h ∈ hs, HeaderCommits c history h) ∧
      ParentCommits c history (hs.foldl (fun _ h => advanceHeader h) p) := by
  induction bs generalizing p hs with
  | nil =>
    simp [buildHeaders] at ok
    subst hs
    exact ⟨by simp, parent⟩
  | cons b bs ih =>
    cases hb : buildHeader c ctx p b with
    | error e => simp [buildHeaders, hb] at ok
    | ok h =>
      cases ht : buildHeaders c ctx (advanceHeader h) bs with
      | error e => simp [buildHeaders, hb, ht] at ok
      | ok tail =>
        simp [buildHeaders, hb, ht] at ok
        subst hs
        have hc := buildHeader_correspondence sound parent hb
        have rest := ih (advanceHeader_correspondence hc) ht
        constructor
        · intro x hx
          simp only [List.mem_cons] at hx
          rcases hx with rfl | hx
          · exact hc
          · exact rest.1 x hx
        · exact rest.2

/-- Every successful plan becomes the exact normalized core parent for its derived block. -/
theorem advanceHeader_fields (ok : buildHeader c ctx p b = .ok h) :
    (advanceHeader h).core.number = b.number ∧
    (advanceHeader h).core.timestamp = b.timestamp ∧
    (advanceHeader h).core.anchorBlockNumber = b.anchorBlockNumber ∧
    (advanceHeader h).core.gasLimit = b.gasLimit + anchorGasReserve c b.timestamp ∧
    (advanceHeader h).beaconRoot = h.beaconRoot := by
  have fields := buildHeader_fields ok
  simp [advanceHeader, fields.1, fields.2.1]

/-- Successful sequential construction preserves the complete derived list in order. -/
theorem buildHeaders_blocks {bs : List DerivedBlock} {hs : List HeaderPlan}
    (ok : buildHeaders c ctx p bs = .ok hs) : hs.map (·.block) = bs := by
  induction bs generalizing p hs with
  | nil =>
    simp [buildHeaders] at ok
    subst hs
    rfl
  | cons b bs ih =>
    cases hb : buildHeader c ctx p b with
    | error e => simp [buildHeaders, hb] at ok
    | ok h =>
      cases ht : buildHeaders c ctx (advanceHeader h) bs with
      | error e => simp [buildHeaders, hb, ht] at ok
      | ok tail =>
        simp [buildHeaders, hb, ht] at ok
        subst hs
        simp [List.map_cons, (buildHeader_fields hb).1, ih ht]

/-- Header construction preserves all finalized source blocks and their original metadata. -/
theorem deriveHeaders_blocks {proposal : ProposalCtx} {sources : List (Source × Option ByteArray)}
    {hs : List HeaderPlan} (ok : deriveHeaders c proposal ctx p sources = .ok hs) :
    hs.map (·.block) = deriveSources c proposal p.core sources := buildHeaders_blocks ok

/-- Every root has a canonical 32-byte representation that recovers its full word value. -/
theorem root_bytes_roundtrip (root : Root) :
    (encodeBE 32 root.val).length = 32 ∧ decodeBE (encodeBE 32 root.val) = root.val := by
  exact ⟨encodeBE_length _ _, decodeBE_encodeBE _ _ root.isLt⟩

/-- A failure in the next block propagates unchanged. -/
theorem buildHeaders_head_error {e : HeaderError} (bs : List DerivedBlock)
    (err : buildHeader c ctx p b = .error e) :
    buildHeaders c ctx p (b :: bs) = .error e := by
  simp [buildHeaders, err]

/-- A later failure propagates unchanged even after a successful header. -/
theorem buildHeaders_tail_error {e : HeaderError} {bs : List DerivedBlock}
    (ok : buildHeader c ctx p b = .ok h)
    (err : buildHeaders c ctx (advanceHeader h) bs = .error e) :
    buildHeaders c ctx p (b :: bs) = .error e := by
  simp [buildHeaders, ok, err]

end Proofs
end TaikoSpec.Derivation
