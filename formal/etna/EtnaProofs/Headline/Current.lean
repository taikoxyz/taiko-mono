import EtnaStatements.Current
import EtnaProofs.CurrentCustody
import EtnaProofs.CurrentProtocolFinality
import EtnaProofs.CurrentJournal

namespace Etna.Design.Current.Headlines
open Protocol Etna.Statements.Current

theorem catalogue_bytes {env : Environment} {w : World} {archive : List Blocks.Header}
    {reference : Nat} {parent : Blocks.Header} {block : Blocks.Block}
    (hashes : CatalogueHash env) (valid : Blocks.Valid (policy env w archive reference) parent block) :
    bytes env (Blocks.definition (policy env w archive reference) block) =
      (Blocks.definition (policy env w archive reference) block).bytes := by
  have same := hashes _ _ valid.selected
  simp only [policy] at same
  unfold bytes
  rw [← same]
  rfl

theorem fund_safety : FundSafety := by
  intro env registry engine premises w trace
  exact ⟨Custody.funds_authorized premises.currentPrimitives premises.currentVerifierSound trace,
    fun _ _ accepted => Custody.landing_edge_authorized premises.currentPrimitives
      premises.currentVerifierSound trace accepted⟩

theorem accountable_finality : AccountableFinality := by
  intro env registry engine premises w trace initialized
  constructor
  · intro common moreA moreB referenceA referenceB h round a b votesA votesB covered validA validB conflict
    exact ProtocolFinality.protocol_same_round_accountability trace premises.currentStandardToken
      premises.currentSignatureAgreement initialized premises.currentBountyBound covered validA validB conflict
  · intro honesty
    exact (ProtocolFinality.current_h2 trace premises.currentStandardToken
      premises.currentSignatureAgreement initialized premises.currentBountyBound
      (premises.currentCodec w trace) honesty
      (premises.currentVoteAttribution w trace)).2

theorem forced_inclusion_integrity : ForcedInclusionIntegrity := by
  intro env registry engine premises w trace
  refine ⟨Journal.trace_invariant trace,?_,?_,?_,?_,?_⟩
  · intro a t accepted
    obtain ⟨segment,indices,actions,unchanged⟩ :=
      Journal.landing_service premises.currentVerifierSound trace accepted
    refine ⟨segment,indices,?_,unchanged⟩
    intro x member
    obtain ⟨entry,queued,action⟩ := actions x member
    have valid := (Blocks.consuming_pair_action segment.valid member).1
    rw [catalogue_bytes premises.currentCatalogueHash valid]
    exact ⟨entry,queued,action⟩
  · intro archive reference parent block entry valid queued deadline
    rw [catalogue_bytes premises.currentCatalogueHash valid]
    rcases deadline with due | late
    · exact Journal.local_due_action trace premises.currentClock valid queued due
    · exact Journal.local_late_action trace premises.currentClock valid queued late
  · exact Journal.nonlanding_never_advances trace
  · exact Journal.nonrecovery_preserves_existing env w
  · intro request t accepted
    exact Journal.recovery_queue_exact accepted

theorem claims : Claims := ⟨fund_safety,accountable_finality,forced_inclusion_integrity⟩

end Etna.Design.Current.Headlines
