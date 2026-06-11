//! Cache re-import flow for out-of-order envelopes once parents arrive.

use std::time::Instant;

use driver::PreconfPayload;
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
    pub(crate) async fn maybe_import_from_cache(&mut self) -> Result<()> {
        self.refresh_sync_ready().await?;
        if !self.sync_ready || self.cache.is_empty() {
            return Ok(());
        }

        self.import_from_cache().await
    }

    /// Import as many cached envelopes as possible.
    pub(super) async fn import_from_cache(&mut self) -> Result<()> {
        loop {
            let mut progressed = false;
            let hashes = self.cache.sorted_hashes_by_block_number();

            for hash in hashes {
                let Some(entry) = self.cache.get(&hash).cloned() else {
                    continue;
                };
                WhitelistPreconfirmationDriverMetrics::inc_cache_import_attempt();
                match self.try_import_cached(&entry).await {
                    Ok(true) => {
                        WhitelistPreconfirmationDriverMetrics::inc_cache_import_result(
                            "progressed",
                        );
                        self.cache.remove(&hash);
                        progressed = true;
                    }
                    Ok(false) => {
                        WhitelistPreconfirmationDriverMetrics::inc_cache_import_result("deferred");
                    }
                    Err(err) if should_defer_cached_import_error(&err) => {
                        WhitelistPreconfirmationDriverMetrics::inc_cache_import_result(
                            "deferred_error",
                        );
                        debug!(
                            block_hash = %hash,
                            error = %err,
                            "deferring cached whitelist preconfirmation payload import for retry"
                        );
                    }
                    Err(err) if should_drop_cached_import_error(&err) => {
                        WhitelistPreconfirmationDriverMetrics::inc_cache_import_result(
                            "dropped_error",
                        );
                        warn!(
                            block_hash = %hash,
                            error = %err,
                            "dropping cached whitelist preconfirmation payload after invalid import"
                        );
                        self.cache.remove(&hash);
                        progressed = true;
                    }
                    Err(err) => {
                        WhitelistPreconfirmationDriverMetrics::inc_cache_import_result(
                            "fatal_error",
                        );
                        self.update_pending_cache_gauge();
                        return Err(err);
                    }
                }
            }

            if !progressed {
                break;
            }
        }

        self.update_pending_cache_gauge();
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

        let head_l1_origin_block_id =
            confirmed_boundary_or_genesis(self.head_l1_origin_block_id().await?);

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
                WhitelistPreconfirmationDriverMetrics::inc_parent_request("issued");
                self.publish_unsafe_request(parent_hash).await;
            } else {
                WhitelistPreconfirmationDriverMetrics::inc_parent_request("throttled");
                debug!(
                    block_number,
                    block_hash = %block_hash,
                    parent_hash = %parent_hash,
                    "suppressed duplicate whitelist preconfirmation parent request due to cooldown"
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
        WhitelistPreconfirmationDriverMetrics::observe_driver_submit_duration(
            submit_start.elapsed().as_secs_f64(),
        );

        if let Err(err) = submit_result {
            WhitelistPreconfirmationDriverMetrics::inc_driver_submit("failure");
            return Err(err.into());
        }
        WhitelistPreconfirmationDriverMetrics::inc_driver_submit("success");

        info!(
            block_number,
            block_hash = %block_hash,
            parent_hash = %parent_hash,
            end_of_sequencing,
            "inserted whitelist preconfirmation block"
        );

        self.state.raise_highest_unsafe(block_number).await;

        Ok(true)
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
        driver::DriverError::EngineSyncing(_) |
        driver::DriverError::BlockNotFound(_) |
        driver::DriverError::PreconfEnqueueTimeout { .. } |
        driver::DriverError::PreconfResponseTimeout { .. } => true,
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

/// Resolve the confirmed boundary used for the cached-payload staleness check.
pub(super) fn confirmed_boundary_or_genesis(head_l1_origin_block_id: Option<u64>) -> u64 {
    head_l1_origin_block_id.unwrap_or(0)
}
