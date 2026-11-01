import EtnaWitnesses.Regressions.Locking

open Etna.Design

-- The unconditional lower-level derivation and raw-prefix composition contracts.
example := @Locking.commit_agreement
example := @Locking.commitValid_agreement
example := @Locking.active_committee_prefix
example := @Locking.handover_prefix_length
example := @Locking.recovery_bootstrap_prefix
example := LockingRegression.multiround_execution
example := LockingRegression.nil_certificate_unlocks
example := LockingRegression.stale_certificate_rejected

example := LockingRegression.differing_round_commits
example := LockingRegression.asynchronous_interleaving
example := LockingRegression.actual_shared_history_commits
example := LockingRegression.nil_is_not_block_zero
example := LockingRegression.recovery_is_a_new_instance
example := LockingRegression.canonical_recovery_prefix
example := LockingRegression.paper_nil_retains_lock

example := LockingRegression.interleaving_all_actual
