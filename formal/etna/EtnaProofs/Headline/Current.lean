import EtnaStatements.Current
import EtnaProofs.CurrentCustody
import EtnaProofs.CurrentProtocolFinality
import EtnaProofs.CurrentJournal
import EtnaProofs.CurrentCoherentCustody
import EtnaProofs.CurrentEconomics
import EtnaProofs.CurrentMetadata
import EtnaProofs.CurrentQueueIntegrity
import EtnaProofs.CurrentUnzen
import EtnaProofs.CurrentGovernance
import EtnaProofs.CurrentCheckpointRisk

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
  refine ⟨Custody.trace_coherent premises.currentRegistryGenesis premises.currentPrimitives premises.currentVerifierSound trace,
    Custody.trace_legacy_authenticated premises.currentPrimitives trace,?_,?_,?_,?_,?_,?_⟩
  · intro a t accepted
    exact Custody.landing_edge_authorized premises.currentRegistryGenesis premises.currentPrimitives premises.currentVerifierSound trace accepted
  · intro later future ever
    exact Custody.trace_start_frozen trace ever future
  · intro other a same
    exact reference_hash_binds_prefix premises.currentReferenceBinding (congrArg StatementData.referenceHash same)
  · intro cp snap member
    exact Custody.trace_snapshot_provenance trace (cp,snap) member
  · intro start written caller height hash root
    exact Custody.set_origin_once written caller height hash root
  · intro switching
    exact ⟨Custody.trace_legacy_etna_disjoint premises.currentRegistryGenesis switching premises.currentPrimitives
      premises.currentUnzenExtension premises.currentVerifierSound trace,
      Custody.trace_switching_fence premises.currentRegistryGenesis switching premises.currentPrimitives
        premises.currentUnzenExtension premises.currentVerifierSound trace⟩

theorem accountable_finality : AccountableFinality := by
  intro env registry engine premises w trace initialized
  refine ⟨?_,?_,?_,?_,?_,?_,?_⟩
  · intro common moreA moreB referenceA referenceB h round a b votesA votesB covered validA validB conflict
    exact Economics.economically_accountable premises.currentRegistryGenesis premises.currentStandardToken
      premises.currentSelfAllowance premises.currentBountyBound trace premises.currentSignatureAgreement
      initialized covered validA validB conflict
  · exact Economics.economic_safety premises.currentRegistryGenesis premises.currentStandardToken
      premises.currentSelfAllowance premises.currentBountyBound trace premises.currentSignatureSound
  · exact Economics.historical_stake_funded premises.currentRegistryGenesis premises.currentStandardToken
      premises.currentSelfAllowance premises.currentBountyBound trace
  · intro later future started same common moreA moreB h covered closed
    exact Economics.temporal_committee_agreement future
      (trace_same_generation_config trace future started same) covered closed
  · intro honesty
    exact (ProtocolFinality.current_h2 trace premises.currentStandardToken
      premises.currentSignatureAgreement initialized premises.currentBountyBound
      (premises.currentCodec w trace) honesty (premises.currentVoteAttribution w trace)).2
  · intro run started h _above candidate common moreA moreB referenceA referenceB round a b votesA votesB shape covered validA validB conflict
    exact CheckpointRisk.economically_at_risk_of_candidate run started premises.currentPrimitives
      premises.currentVerifierSound candidate premises.currentRegistryGenesis premises.currentStandardToken
      premises.currentSelfAllowance premises.currentBountyBound premises.currentSignatureAgreement
      premises.currentEvidenceWindow.2 initialized shape covered validA validB conflict
  · intro run started h _above candidate elected
    exact CheckpointRisk.committee_retained_of_candidate premises.currentRegistryGenesis
      run started premises.currentPrimitives premises.currentVerifierSound candidate elected

theorem forced_inclusion_integrity : ForcedInclusionIntegrity := by
  intro env registry engine premises w trace
  refine ⟨Journal.trace_invariant trace,QueueIntegrity.trace_head_bounds trace,?_,?_,?_,?_,?_,?_,?_,?_,?_⟩
  · intro a t accepted
    obtain ⟨segment,indices,actions,unchanged⟩ :=
      QueueIntegrity.landing_service premises.currentRegistryGenesis premises.currentVerifierSound trace accepted
    refine ⟨segment,indices,?_,unchanged⟩
    intro x member
    obtain ⟨entry,queued,first,action⟩ := actions x member
    have valid := (Blocks.consuming_pair_action segment.valid member).1
    rw [catalogue_bytes premises.currentCatalogueHash valid]
    exact ⟨entry,queued,first,action⟩
  · intro archive reference parent block entry valid queued deadline
    rw [catalogue_bytes premises.currentCatalogueHash valid]
    rcases deadline with due | late
    · exact Journal.local_due_action trace premises.currentClock valid queued due
    · exact Journal.local_late_action trace premises.currentClock valid queued late
  · intro archive reference parent block entry valid next queued early
    rw [catalogue_bytes premises.currentCatalogueHash valid]
    exact QueueIntegrity.no_early_skip trace archive reference parent block entry valid next queued early
  · exact Journal.nonlanding_never_advances trace
  · exact Journal.nonrecovery_preserves_existing env w
  · intro request t accepted
    exact ⟨Governance.recovery_preserves_head accepted,Journal.recovery_queue_exact accepted,
      QueueIntegrity.recovery_pending_guards accepted⟩
  · intro a t accepted
    exact Journal.accepted_image_certificate premises.currentVerifierSound trace accepted
  · intro raw paid refund t accepted
    exact (QueueIntegrity.admission_exact accepted).1
  · intro candidate durable t accepted
    obtain ⟨trusted,_,signer,_,_,_,_,_,headers⟩ := QueueIntegrity.node_import_closed accepted
    exact ⟨trusted,signer,headers⟩

/-- Actual instrumented raw DAO upgrade histories require explicit historical authorization.
The owner address alone does not imply the correction/rollback admissibility policy. -/
theorem deployed_claims {env : Environment} {registry : RegistryMachine.State} {engine : Finality.Engine}
    {w : World} (premises : Premises env registry engine)
    (history : Governance.DeployedTrace env (empty env registry) w)
    (authorization : Governance.AuthorizedUpgrades history) (initialized : w.initialized = true) :
    FundSafetyAt env registry w ∧ AccountableFinalityAt env registry engine w ∧ ForcedInclusionAt env w := by
  have trace := Governance.authorized_trace_refines history authorization
  exact ⟨fund_safety env registry engine premises w trace,
    accountable_finality env registry engine premises w trace initialized,
    forced_inclusion_integrity env registry engine premises w trace⟩

theorem claims : Claims := ⟨fund_safety,accountable_finality,forced_inclusion_integrity⟩

end Etna.Design.Current.Headlines
