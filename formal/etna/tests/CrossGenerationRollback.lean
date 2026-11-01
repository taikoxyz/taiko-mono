import EtnaWitnesses.Regressions.CrossGenerationRollback
import EtnaProofs.CanonicalHistory

open Etna.Design ProtocolState SigningEscrow

-- A canonical source must remain below a later generation's recovery floor,
-- even though subsequent accepted landings need not be certified.
example {initial source later : World} {archive : List Nat}
    (certified : CanonicalHistory.Run initial source archive)
    (suffix : Trace source later)
    (changed : source.inbox.generation < later.inbox.generation) :
    source.inbox.snapshot < later.inbox.origin.l1Block :=
  certified_snapshot_below_later_origin certified suffix changed

example := @certified_values_trusted_across_recoveries
example := @certified_rollback_excludes_confirmed_keys
example := @initial_values_stay_trusted
example := @cleared_exit_cannot_reconfirm
example := @rollback_interval_rejects_landing
example := CrossGenerationRollbackRegression.certified_source
example := CrossGenerationRollbackRegression.adversarial_suffix
example := CrossGenerationRollbackRegression.actual_rollback
example := CrossGenerationRollbackRegression.rollback_rechecks_and_blocks
example := CrossGenerationRollbackRegression.renewed_production
example := @CrossGenerationRollbackRegression.reconfirmed_key_excluded
example := CrossGenerationRollbackRegression.trust_revalidated_sign
example := CrossGenerationRollbackRegression.rollback_nonce_and_domain

example := CrossGenerationRollbackRegression.weak_source_lacks_reference_bound
example := @rollback_retains_signer_authority

example := @CrossGenerationRollbackRegression.restored_key_excluded
example := CrossGenerationRollbackRegression.initialization_restore
example := @rollback_consumes_nonce
