import DerivationStatements
import DerivationProofs.Properties

namespace TaikoSpec.Derivation.Proofs

open Statements

/-- The normalized derivation claims follow from the retained detailed properties. -/
theorem derivation_safety : DerivationSafety := by
  intro c ctx p
  refine ⟨source_block_count c ctx p, ?_, ?_, ?_⟩
  · intro xs ys
    exact ⟨derive_append c ctx p xs ys, earlier_sources_unaffected c ctx p xs ys⟩
  · intro sources
    exact ⟨numbers_consecutive c ctx p sources, timestamps_increasing c ctx p sources,
      timestamp_drift c ctx p sources, anchors_nondecreasing c ctx p sources⟩
  · intro bounds sources b hb
    exact ⟨anchors_not_after_origin c ctx p sources bounds.anchorNotAfterOrigin b hb,
      gas_limits_in_range c ctx p sources bounds.gasMinimum bounds.gasMaximum b hb⟩

/-- A single successful header obeys the child's fork policy. -/
theorem buildHeader_fork_policy {c : ChainParams} {hc : HeaderContext} {hp : HeaderParent}
    {b : DerivedBlock} {h : HeaderPlan} (ok : buildHeader c hc hp b = .ok h) :
    HeaderForkPolicy c h := by
  have fields := (buildHeader_fields ok).1
  constructor
  · intro etna
    rw [fields] at etna ⊢
    exact etna_header_invariants c hc hp b h etna ok
  · intro etna
    rw [fields] at etna ⊢
    exact pre_etna_header_invariants c hc hp b h etna ok

/-- Lift the per-header fork policy through sequential construction, retaining every member. -/
theorem buildHeaders_fork_policy {c : ChainParams} {hc : HeaderContext} {hp : HeaderParent}
    {bs : List DerivedBlock} {hs : List HeaderPlan}
    (ok : buildHeaders c hc hp bs = .ok hs) : ∀ h ∈ hs, HeaderForkPolicy c h := by
  induction bs generalizing hp hs with
  | nil =>
    simp [buildHeaders] at ok
    subst hs
    simp
  | cons b bs ih =>
    cases hb : buildHeader c hc hp b with
    | error e => simp [buildHeaders, hb] at ok
    | ok h =>
      cases ht : buildHeaders c hc (advanceHeader h) bs with
      | error e => simp [buildHeaders, hb, ht] at ok
      | ok tail =>
        simp [buildHeaders, hb, ht] at ok
        subst hs
        intro x hx
        rcases List.mem_cons.mp hx with rfl | hx
        · exact buildHeader_fork_policy hb
        · exact ih ht x hx

/-- Successful proposals preserve derivation, enforce fork policy and authenticate roots. -/
theorem header_safety : HeaderSafety := by
  intro c ctx hc hp sources hs ok
  refine ⟨proposal_headers_preserve_derivation c ctx hc hp sources hs ok, ?_, ?_⟩
  · exact buildHeaders_fork_policy ok
  · intro history premises
    exact buildHeaders_correspondence premises.lookupsSound premises.parentAuthenticated ok

/-- Default fallback is exactly the complement of acceptance for a one-block forced source. -/
theorem forced_default_iff {c : ChainParams} {ctx : ProposalCtx} {p : Parent}
    {src : Source} (b : BlockManifest) (forced : src.isForcedInclusion = true) :
    finalizeSource c ctx p src (some [b]) = .defaulted (defaultBlock c ctx p) ↔
      ¬ ForcedAcceptance c ctx p := by
  unfold ForcedAcceptance
  rw [← forced_inclusion_accepted_iff c ctx p src b forced]
  simp only [finalizeSource, forced, ite_true]
  split <;> simp [SourceOutcome.isAccepted]

/-- Forced inclusion permits the specified fallback while preserving earlier-source isolation. -/
theorem forced_inclusion_safety : ForcedInclusionSafety := by
  intro c ctx p
  refine ⟨?_, ?_, earlier_sources_unaffected c ctx p⟩
  · intro src b forced
    exact ⟨forced_inclusion_accepted_iff c ctx p src b forced, forced_default_iff b forced⟩
  · intro src
    rfl

/-- Exact proof of the conjunction reviewed in the statements library. -/
theorem claims : Claims := ⟨derivation_safety, header_safety, forced_inclusion_safety⟩

end TaikoSpec.Derivation.Proofs
