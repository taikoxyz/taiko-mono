import DerivationStatements
import DerivationProofs.Properties

namespace TaikoSpec.Derivation.Proofs

open Statements

/-- The normalized derivation claims follow from the retained detailed properties. -/
theorem derivation_safety : DerivationSafety := by
  intro c ctx p
  refine ⟨source_block_count c ctx p, ?_, ?_, ?_, ?_⟩
  · intro xs ys
    exact ⟨derive_append c ctx p xs ys, earlier_sources_unaffected c ctx p xs ys⟩
  · intro sources
    exact ⟨numbers_consecutive c ctx p sources, timestamps_increasing c ctx p sources,
      timestamp_drift c ctx p sources, anchors_nondecreasing c ctx p sources⟩
  · intro bounds sources b hb
    exact ⟨anchors_not_after_origin c ctx p sources bounds.anchorNotAfterOrigin b hb,
      gas_limits_in_range c ctx p sources bounds.gasMinimum bounds.gasMaximum b hb⟩
  · intro src m bs hf
    exact proposer_source_accepted_iff c ctx p src m bs hf

/-- Header plans keep the derived sequence and the Unzen layout, the recorded anchor follows
the derived anchors, and the parent rebuilt from the last header and that anchor continues
derivation. -/
theorem header_safety : HeaderSafety := by
  intro c ctx hc p sources
  exact ⟨proposal_headers_preserve_derivation c ctx p hc sources,
    deriveHeaders_unzen hc p sources, anchor_state_follows_derivation c ctx p hc sources,
    next_parent_from_headers c ctx p hc sources, blocks_after_unzen c ctx p hc sources⟩

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
    exact ⟨forced_inclusion_accepted_iff c ctx p src b forced,
      forced_inclusion_preserves_transactions_iff c ctx p src b forced,
      forced_default_iff b forced⟩
  · intro src
    rfl

/-- Exact proof of the conjunction reviewed in the statements library. -/
theorem claims : Claims := ⟨derivation_safety, header_safety, forced_inclusion_safety⟩

end TaikoSpec.Derivation.Proofs
