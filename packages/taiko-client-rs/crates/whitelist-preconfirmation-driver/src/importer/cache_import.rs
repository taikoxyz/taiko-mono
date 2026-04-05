use std::{sync::Arc, time::Instant};

use driver::production::PreconfPayload;
use tracing::{debug, info, warn};

use crate::{
    codec::WhitelistExecutionPayloadEnvelope,
    core::import::{ImportContext, ImportDecision, evaluate_pending_import},
    error::{Result, WhitelistPreconfirmationDriverError},
    metrics::WhitelistPreconfirmationDriverMetrics,
};

use super::WhitelistPreconfirmationImporter;

/// Outcome of one pending-envelope processing attempt.
#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub(super) enum PendingImportOutcome {
    /// The pending entry was removed or a child wake-up created forward progress.
    Progressed,
    /// The pending entry remains queued for a later retry.
    Requeue,
    /// The pending entry remains cached but should wait for another wake-up.
    Deferred,
}

/// Drain-loop action for a processed pending envelope.
#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub(super) enum PendingDrainAction {
    /// Keep draining the current ready queue without requeueing this hash.
    KeepDraining,
    /// Requeue this hash after the current drain pass completes.
    RetryNextPass,
}

/// Classify a pending-attempt result for drain-loop scheduling.
pub(super) fn classify_pending_attempt_for_drain(
    result: &Result<PendingImportOutcome>,
) -> Option<PendingDrainAction> {
    match result {
        Ok(PendingImportOutcome::Progressed) => Some(PendingDrainAction::KeepDraining),
        Ok(PendingImportOutcome::Deferred | PendingImportOutcome::Requeue) => {
            Some(PendingDrainAction::RetryNextPass)
        }
        Err(err) if should_drop_cached_import_error(err) => Some(PendingDrainAction::KeepDraining),
        Err(err) if should_defer_cached_import_error(err) => {
            Some(PendingDrainAction::RetryNextPass)
        }
        Err(_) => None,
    }
}

/// Requeue deferred hashes before returning from the current drain pass.
pub(super) fn finalize_pending_drain(
    pending: &mut crate::core::pending::PendingEnvelopeGraph,
    retry_next_pass: &mut Vec<alloy_primitives::B256>,
    result: Result<()>,
) -> Result<()> {
    pending.enqueue_many(std::mem::take(retry_next_pass));
    result
}

impl<P> WhitelistPreconfirmationImporter<P>
where
    P: alloy_provider::Provider + Clone + Send + Sync + 'static,
{
    /// Attempt to import pending envelopes if sync is ready.
    pub(crate) async fn maybe_import_from_cache(&mut self) -> Result<()> {
        let _ = self.refresh_sync_ready().await?;
        if !self.sync_ready || self.pending.is_empty() {
            return Ok(());
        }

        self.import_from_pending().await
    }

    /// Drain the explicit pending-import queue without sweeping the whole cache.
    pub(super) async fn import_from_pending(&mut self) -> Result<()> {
        let mut retry_next_pass = Vec::new();
        while let Some(hash) = self.pending.pop_ready() {
            metrics::counter!(WhitelistPreconfirmationDriverMetrics::CACHE_IMPORT_ATTEMPTS_TOTAL)
                .increment(1);
            let result = self.try_import_pending(hash).await;
            let drain_action = classify_pending_attempt_for_drain(&result);
            match result {
                Ok(PendingImportOutcome::Progressed) => {
                    metrics::counter!(
                        WhitelistPreconfirmationDriverMetrics::CACHE_IMPORT_RESULTS_TOTAL,
                        "result" => "progressed",
                    )
                    .increment(1);
                }
                Ok(PendingImportOutcome::Deferred) => {
                    metrics::counter!(
                        WhitelistPreconfirmationDriverMetrics::CACHE_IMPORT_RESULTS_TOTAL,
                        "result" => "deferred",
                    )
                    .increment(1);
                }
                Ok(PendingImportOutcome::Requeue) => {
                    metrics::counter!(
                        WhitelistPreconfirmationDriverMetrics::CACHE_IMPORT_RESULTS_TOTAL,
                        "result" => "deferred_error",
                    )
                    .increment(1);
                }
                Err(err) if should_drop_cached_import_error(&err) => {
                    metrics::counter!(
                        WhitelistPreconfirmationDriverMetrics::CACHE_IMPORT_RESULTS_TOTAL,
                        "result" => "dropped_error",
                    )
                    .increment(1);
                    warn!(
                        block_hash = %hash,
                        error = %err,
                        "dropping pending whitelist preconfirmation payload after invalid import"
                    );
                    self.pending.remove(&hash);
                }
                Err(err) if should_defer_cached_import_error(&err) => {
                    metrics::counter!(
                        WhitelistPreconfirmationDriverMetrics::CACHE_IMPORT_RESULTS_TOTAL,
                        "result" => "deferred_error",
                    )
                    .increment(1);
                    debug!(
                        block_hash = %hash,
                        error = %err,
                        "deferring pending whitelist preconfirmation payload import for retry"
                    );
                }
                Err(err) => {
                    metrics::counter!(
                        WhitelistPreconfirmationDriverMetrics::CACHE_IMPORT_RESULTS_TOTAL,
                        "result" => "fatal_error",
                    )
                    .increment(1);
                    self.update_cache_gauges();
                    return finalize_pending_drain(
                        &mut self.pending,
                        &mut retry_next_pass,
                        Err(err),
                    );
                }
            }

            if let Some(PendingDrainAction::RetryNextPass) = drain_action {
                retry_next_pass.push(hash);
            }
        }

        finalize_pending_drain(&mut self.pending, &mut retry_next_pass, Ok(()))?;
        self.update_cache_gauges();
        Ok(())
    }

    /// Try to import one pending envelope and wake any children if it succeeds.
    async fn try_import_pending(
        &mut self,
        hash: alloy_primitives::B256,
    ) -> Result<PendingImportOutcome> {
        let Some(envelope) = self.pending.get(&hash) else {
            return Ok(PendingImportOutcome::Deferred);
        };

        let payload = &envelope.execution_payload;
        let block_number = payload.block_number;
        let block_hash = payload.block_hash;
        let end_of_sequencing = envelope.end_of_sequencing.unwrap_or(false);
        let parent_hash = payload.parent_hash;
        let head_l1_origin_block_id = self.head_l1_origin_block_id().await?;
        let current_block_hash = self.block_hash_by_number(block_number).await?;
        let parent_block_hash = if block_number == 0 {
            None
        } else {
            self.block_hash_by_number(block_number.saturating_sub(1)).await?
        };
        let parent_number = block_number.saturating_sub(1);
        let parent_missing = block_number > 0 && parent_block_hash != Some(parent_hash);
        let parent_recovery_blocked = head_l1_origin_block_id
            .is_some_and(|head_l1_origin| parent_missing && parent_number <= head_l1_origin);
        let allow_parent_request = if parent_missing && !parent_recovery_blocked {
            self.pending.should_request_parent(parent_hash, Instant::now())
        } else {
            false
        };

        match evaluate_pending_import(
            envelope.clone(),
            ImportContext {
                head_l1_origin_block_id,
                current_block_hash,
                parent_block_hash,
                allow_parent_request,
            },
        ) {
            ImportDecision::Drop => {
                debug!(
                    block_number,
                    block_hash = %block_hash,
                    head_l1_origin_block_id,
                    "dropping pending whitelist preconfirmation payload"
                );
                self.pending.remove(&hash);
                return Ok(PendingImportOutcome::Progressed);
            }
            ImportDecision::Cache => {
                if parent_missing && !parent_recovery_blocked {
                    metrics::counter!(
                        WhitelistPreconfirmationDriverMetrics::PARENT_REQUESTS_TOTAL,
                        "result" => "throttled",
                    )
                    .increment(1);
                    debug!(
                        block_number,
                        block_hash = %block_hash,
                        parent_hash = %parent_hash,
                        "suppressed duplicate whitelist preconfirmation parent request due to cooldown"
                    );
                }
                return Ok(PendingImportOutcome::Deferred);
            }
            ImportDecision::RequestParent(parent_hash) => {
                let result =
                    if self.request_block(parent_hash).await { "issued" } else { "queue_failed" };
                metrics::counter!(
                    WhitelistPreconfirmationDriverMetrics::PARENT_REQUESTS_TOTAL,
                    "result" => result,
                )
                .increment(1);
                return Ok(PendingImportOutcome::Requeue);
            }
            ImportDecision::Respond(_) => return Ok(PendingImportOutcome::Deferred),
            ImportDecision::Import(envelope) => {
                self.submit_pending_envelope(envelope, end_of_sequencing).await?;
            }
        }

        self.pending.remove(&hash);
        self.pending.enqueue_children(block_hash);
        Ok(PendingImportOutcome::Progressed)
    }

    /// Submit one importable pending envelope into the driver.
    async fn submit_pending_envelope(
        &mut self,
        envelope: Arc<WhitelistExecutionPayloadEnvelope>,
        end_of_sequencing: bool,
    ) -> Result<()> {
        let payload = &envelope.execution_payload;
        let block_number = payload.block_number;
        let block_hash = payload.block_hash;
        let parent_hash = payload.parent_hash;

        let driver_payload = self.build_driver_payload(&envelope)?;
        let submit_start = Instant::now();
        let submit_result = self
            .event_syncer
            .submit_preconfirmation_payload(PreconfPayload::new(driver_payload))
            .await;
        metrics::histogram!(WhitelistPreconfirmationDriverMetrics::DRIVER_SUBMIT_DURATION_SECONDS)
            .record(submit_start.elapsed().as_secs_f64());

        if let Err(err) = submit_result {
            metrics::counter!(
                WhitelistPreconfirmationDriverMetrics::DRIVER_SUBMIT_TOTAL,
                "result" => "failure",
            )
            .increment(1);
            return Err(err.into());
        }
        metrics::counter!(
            WhitelistPreconfirmationDriverMetrics::DRIVER_SUBMIT_TOTAL,
            "result" => "success",
        )
        .increment(1);

        let inserted_hash = self
            .block_hash_by_number(block_number)
            .await?
            .ok_or(WhitelistPreconfirmationDriverError::MissingInsertedBlock(block_number))?;

        if inserted_hash != block_hash {
            return Err(WhitelistPreconfirmationDriverError::InsertedBlockHashMismatch {
                block_number,
                expected: block_hash,
                actual: inserted_hash,
            });
        }

        info!(
            block_number,
            block_hash = %block_hash,
            parent_hash = %parent_hash,
            end_of_sequencing,
            "inserted whitelist preconfirmation block"
        );

        self.shared_state.update_highest_unsafe(block_number).await;

        Ok(())
    }
}

/// Returns true when a cached-envelope import error should be logged and dropped.
pub(super) fn should_drop_cached_import_error(err: &WhitelistPreconfirmationDriverError) -> bool {
    match err {
        WhitelistPreconfirmationDriverError::InvalidPayload(_) |
        WhitelistPreconfirmationDriverError::InvalidSignature(_) => true,
        WhitelistPreconfirmationDriverError::Driver(driver_err) => {
            should_drop_cached_driver_error(driver_err)
        }
        _ => false,
    }
}

/// Returns true when a cached-envelope import error should be retried later.
pub(super) fn should_defer_cached_import_error(err: &WhitelistPreconfirmationDriverError) -> bool {
    match err {
        WhitelistPreconfirmationDriverError::Driver(driver_err) => {
            should_defer_cached_driver_error(driver_err)
        }
        _ => false,
    }
}

/// Returns true when a driver error is envelope-scoped and safe to drop during cached import.
fn should_drop_cached_driver_error(err: &driver::DriverError) -> bool {
    match err {
        driver::DriverError::EngineInvalidPayload(_) => true,
        driver::DriverError::PreconfInjectionFailed { source, .. } => {
            matches!(source, driver::sync::error::EngineSubmissionError::InvalidBlock(_, _))
        }
        _ => false,
    }
}

/// Returns true when a driver error is expected to recover after sync catches up.
fn should_defer_cached_driver_error(err: &driver::DriverError) -> bool {
    match err {
        driver::DriverError::EngineSyncing(_) | driver::DriverError::BlockNotFound(_) => true,
        driver::DriverError::PreconfInjectionFailed { source, .. } => matches!(
            source,
            driver::sync::error::EngineSubmissionError::EngineSyncing(_) |
                driver::sync::error::EngineSubmissionError::MissingPayloadId |
                driver::sync::error::EngineSubmissionError::MissingParent |
                driver::sync::error::EngineSubmissionError::MissingInsertedBlock(_)
        ),
        _ => false,
    }
}
