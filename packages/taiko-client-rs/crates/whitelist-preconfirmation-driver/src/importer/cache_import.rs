use std::time::Instant;

use driver::production::PreconfPayload;
use tracing::{debug, info, warn};

use crate::{
    codec::WhitelistExecutionPayloadEnvelope,
    error::{Result, WhitelistPreconfirmationDriverError},
    metrics::WhitelistPreconfirmationDriverMetrics,
};

use super::WhitelistPreconfirmationImporter;

impl<P> WhitelistPreconfirmationImporter<P>
where
    P: alloy_provider::Provider + Clone + Send + Sync + 'static,
{
    /// Attempt to import cached envelopes if sync is ready.
    pub(super) async fn maybe_import_from_cache(&mut self) -> Result<()> {
        let _ = self.refresh_sync_ready().await?;
        if !self.sync_ready || self.cache.is_empty() {
            return Ok(());
        }

        self.import_from_cache().await
    }

    /// Import as many cached envelopes as possible.
    pub(super) async fn import_from_cache(&mut self) -> Result<()> {
        let mut cache = std::mem::take(&mut self.cache);
        loop {
            let mut progressed = false;
            let hashes = cache.sorted_hashes_by_block_number();

            for hash in hashes {
                let Some(entry) = cache.get(&hash) else {
                    continue;
                };
                metrics::counter!(
                    WhitelistPreconfirmationDriverMetrics::CACHE_IMPORT_ATTEMPTS_TOTAL
                )
                .increment(1);
                match self.try_import_cached(entry).await {
                    Ok(true) => {
                        metrics::counter!(
                            WhitelistPreconfirmationDriverMetrics::CACHE_IMPORT_RESULTS_TOTAL,
                            "result" => "progressed",
                        )
                        .increment(1);
                        cache.remove(&hash);
                        progressed = true;
                    }
                    Ok(false) => {
                        metrics::counter!(
                            WhitelistPreconfirmationDriverMetrics::CACHE_IMPORT_RESULTS_TOTAL,
                            "result" => "deferred",
                        )
                        .increment(1);
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
                            "deferring cached whitelist preconfirmation payload import for retry"
                        );
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
                            "dropping cached whitelist preconfirmation payload after invalid import"
                        );
                        cache.remove(&hash);
                        progressed = true;
                    }
                    Err(err) => {
                        metrics::counter!(
                            WhitelistPreconfirmationDriverMetrics::CACHE_IMPORT_RESULTS_TOTAL,
                            "result" => "fatal_error",
                        )
                        .increment(1);
                        self.cache = cache;
                        self.update_cache_gauges();
                        return Err(err);
                    }
                }
            }

            if !progressed {
                break;
            }
        }

        self.cache = cache;
        self.update_cache_gauges();
        Ok(())
    }

    /// Try to import one cached envelope.
    async fn try_import_cached(
        &mut self,
        envelope: &WhitelistExecutionPayloadEnvelope,
    ) -> Result<bool> {
        let payload = &envelope.execution_payload;
        let block_number = payload.block_number;
        let block_hash = payload.block_hash;
        let end_of_sequencing = envelope.end_of_sequencing.unwrap_or(false);

        let Some(head_l1_origin_block_id) = self.head_l1_origin_block_id().await? else {
            return Ok(false);
        };

        if block_number <= head_l1_origin_block_id {
            debug!(
                block_number,
                block_hash = %block_hash,
                head_l1_origin_block_id,
                "dropping outdated cached whitelist preconfirmation payload"
            );
            return Ok(true);
        }

        if self.block_hash_by_number(block_number).await? == Some(block_hash) {
            debug!(
                block_number,
                block_hash = %block_hash,
                "dropping already-inserted whitelist preconfirmation payload"
            );
            return Ok(true);
        }

        if block_number == 0 {
            return Ok(true);
        }

        let parent_hash = payload.parent_hash;
        let parent_number = block_number.saturating_sub(1);
        if self.block_hash_by_number(parent_number).await? != Some(parent_hash) {
            if self.request_throttle.should_request(parent_hash, Instant::now()) {
                metrics::counter!(
                    WhitelistPreconfirmationDriverMetrics::PARENT_REQUESTS_TOTAL,
                    "result" => "issued",
                )
                .increment(1);
                self.publish_unsafe_request(parent_hash).await;
            } else {
                metrics::counter!(
                    WhitelistPreconfirmationDriverMetrics::PARENT_REQUESTS_TOTAL,
                    "result" => "throttled",
                )
                .increment(1);
                warn!(
                    block_number,
                    block_hash = %block_hash,
                    parent_hash = %parent_hash,
                    "throttling duplicate whitelist preconfirmation parent request"
                );
            }
            return Ok(false);
        }

        let driver_payload = self.build_driver_payload(envelope)?;
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
        // Match Go status semantics by updating highest-unsafe on import and reorg paths.
        self.runtime_state.set_highest_unsafe_l2_payload_block_id(block_number);
        if let Some(epoch) = self.end_of_sequencing_epoch(envelope) {
            self.runtime_state.set_end_of_sequencing_block_hash(epoch, block_hash).await;
            self.runtime_state.notify_end_of_sequencing(epoch);
        } else if end_of_sequencing {
            warn!(
                block_number,
                block_hash = %block_hash,
                timestamp = payload.timestamp,
                "failed to derive EOS epoch from payload timestamp; skipping EOS runtime update"
            );
        }

        info!(
            block_number,
            block_hash = %block_hash,
            parent_hash = %parent_hash,
            end_of_sequencing,
            "inserted whitelist preconfirmation block"
        );

        Ok(true)
    }
}

/// Returns true when a cached-envelope import error should be logged and dropped.
pub(super) fn should_drop_cached_import_error(err: &WhitelistPreconfirmationDriverError) -> bool {
    match err {
        WhitelistPreconfirmationDriverError::InvalidPayload(_)
        | WhitelistPreconfirmationDriverError::InvalidSignature(_) => true,
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
            driver::sync::error::EngineSubmissionError::EngineSyncing(_)
                | driver::sync::error::EngineSubmissionError::MissingPayloadId
                | driver::sync::error::EngineSubmissionError::MissingParent
                | driver::sync::error::EngineSubmissionError::MissingInsertedBlock(_)
        ),
        _ => false,
    }
}
