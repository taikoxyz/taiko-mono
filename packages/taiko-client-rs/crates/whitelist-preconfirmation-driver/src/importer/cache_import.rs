//! Cache re-import flow for out-of-order envelopes once parents arrive.

use std::{sync::Arc, time::Instant};

use driver::PreconfPayload;
use tokio::sync::Mutex;
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
        self.reconcile_preconf_reorg_state().await?;

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

    /// Reconcile importer-local unsafe state after the event scanner reports an L1 reorg.
    pub(super) async fn reconcile_preconf_reorg_state(&mut self) -> Result<()> {
        let current_generation = self.event_syncer.preconf_reorg_generation();
        if current_generation == self.observed_preconf_reorg_generation {
            return Ok(());
        }

        self.observed_preconf_reorg_generation = current_generation;
        self.cache.clear();
        self.recent_cache.clear();
        self.cache_state.clear().await;

        let Some(boundary) = self.head_l1_origin_block_id().await? else {
            self.preconf_import_cursor = None;
            self.sync_ready = false;
            self.update_cache_gauges();
            warn!(
                preconf_reorg_generation = current_generation,
                "cleared whitelist preconfirmation caches after reorg without head l1 origin"
            );
            return Ok(());
        };

        self.preconf_import_cursor = Some(boundary);
        if let Some(ref highest) = self.highest_unsafe_l2_payload_block_id {
            set_highest_unsafe_block_id(highest, boundary).await;
        }
        self.update_cache_gauges();
        info!(
            preconf_reorg_generation = current_generation,
            head_l1_origin_block_id = boundary,
            "reset whitelist preconfirmation unsafe state after event scanner reorg"
        );
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
            record_materialized_preconf_block(
                &mut self.preconf_import_cursor,
                self.highest_unsafe_l2_payload_block_id.as_ref(),
                block_number,
            )
            .await;
            debug!(
                block_number,
                block_hash = %block_hash,
                "dropping already-inserted whitelist preconfirmation payload"
            );
            return Ok(true);
        }

        let parent_hash = payload.parent_hash;
        let parent_number = block_number.saturating_sub(1);
        if block_number == 0 {
            return Ok(true);
        }

        if !preconf_reorg_cursor_allows_block(self.preconf_import_cursor, block_number) {
            if self.preconf_import_cursor.is_some_and(|cursor| block_number <= cursor) {
                debug!(
                    block_number,
                    block_hash = %block_hash,
                    preconf_import_cursor = ?self.preconf_import_cursor,
                    "dropping cached whitelist preconfirmation payload at or before reorg cursor"
                );
                return Ok(true);
            }

            self.request_missing_parent(parent_hash, block_number, block_hash).await;
            debug!(
                block_number,
                block_hash = %block_hash,
                preconf_import_cursor = ?self.preconf_import_cursor,
                "deferring cached whitelist preconfirmation payload until reorg cursor advances"
            );
            return Ok(false);
        }

        if self.block_hash_by_number(parent_number).await? != Some(parent_hash) {
            self.request_missing_parent(parent_hash, block_number, block_hash).await;
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

        info!(
            block_number,
            block_hash = %block_hash,
            parent_hash = %parent_hash,
            end_of_sequencing,
            "inserted whitelist preconfirmation block"
        );

        if let Some(ref highest) = self.highest_unsafe_l2_payload_block_id {
            if self.preconf_import_cursor.is_some() {
                set_highest_unsafe_block_id(highest, block_number).await;
            } else {
                advance_highest_unsafe_block_id(highest, block_number).await;
            }
        }
        advance_preconf_import_cursor(&mut self.preconf_import_cursor, block_number);

        Ok(true)
    }

    /// Publish or throttle a request for a missing parent payload.
    async fn request_missing_parent(
        &mut self,
        parent_hash: alloy_primitives::B256,
        block_number: u64,
        block_hash: alloy_primitives::B256,
    ) {
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
            debug!(
                block_number,
                block_hash = %block_hash,
                parent_hash = %parent_hash,
                "suppressed duplicate whitelist preconfirmation parent request due to cooldown"
            );
        }
    }
}

/// Returns true when the reorg import cursor permits importing `block_number`.
pub(super) fn preconf_reorg_cursor_allows_block(cursor: Option<u64>, block_number: u64) -> bool {
    match cursor {
        Some(cursor) => block_number == cursor.saturating_add(1),
        None => true,
    }
}

/// Advance the reorg import cursor after a successful unsafe payload import.
pub(super) fn advance_preconf_import_cursor(cursor: &mut Option<u64>, block_number: u64) {
    if cursor.is_some() {
        *cursor = Some(block_number);
    }
}

/// Set the shared highest unsafe block ID, allowing reorg resets to move it backward.
pub(super) async fn set_highest_unsafe_block_id(highest: &Arc<Mutex<u64>>, block_number: u64) {
    *highest.lock().await = block_number;
}

/// Advance the shared highest unsafe block ID without moving it backward.
pub(super) async fn advance_highest_unsafe_block_id(highest: &Arc<Mutex<u64>>, block_number: u64) {
    let mut guard = highest.lock().await;
    *guard = block_number.max(*guard);
}

/// Record an already-materialized block when it is the next block required by a reorg cursor.
pub(super) async fn record_materialized_preconf_block(
    cursor: &mut Option<u64>,
    highest: Option<&Arc<Mutex<u64>>>,
    block_number: u64,
) -> bool {
    if !preconf_reorg_cursor_allows_block(*cursor, block_number) {
        return false;
    }

    if let Some(highest) = highest {
        set_highest_unsafe_block_id(highest, block_number).await;
    }
    advance_preconf_import_cursor(cursor, block_number);
    true
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
        driver::DriverError::PreconfIngressNotReady |
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

#[cfg(test)]
mod tests {
    use std::sync::Arc;

    use driver::DriverError;
    use tokio::sync::Mutex;

    use super::{
        advance_preconf_import_cursor, preconf_reorg_cursor_allows_block,
        record_materialized_preconf_block, set_highest_unsafe_block_id,
        should_defer_cached_driver_error,
    };

    #[test]
    fn preconf_ingress_not_ready_defers_cached_import() {
        assert!(should_defer_cached_driver_error(&DriverError::PreconfIngressNotReady));
    }

    #[test]
    fn preconf_reorg_cursor_requires_contiguous_block_after_boundary() {
        assert!(preconf_reorg_cursor_allows_block(None, 102));
        assert!(preconf_reorg_cursor_allows_block(Some(100), 101));
        assert!(!preconf_reorg_cursor_allows_block(Some(100), 102));
        assert!(!preconf_reorg_cursor_allows_block(Some(100), 100));
    }

    #[test]
    fn preconf_reorg_cursor_advances_only_when_active() {
        let mut inactive = None;
        advance_preconf_import_cursor(&mut inactive, 101);
        assert_eq!(inactive, None);

        let mut active = Some(100);
        advance_preconf_import_cursor(&mut active, 101);
        assert_eq!(active, Some(101));
    }

    #[tokio::test]
    async fn highest_unsafe_block_id_can_move_backward_after_reorg() {
        let highest = Arc::new(Mutex::new(150));

        set_highest_unsafe_block_id(&highest, 100).await;

        assert_eq!(*highest.lock().await, 100);
    }

    #[tokio::test]
    async fn materialized_next_block_advances_active_reorg_cursor() {
        let highest = Arc::new(Mutex::new(100));
        let mut cursor = Some(100);

        let advanced = record_materialized_preconf_block(&mut cursor, Some(&highest), 101).await;

        assert!(advanced);
        assert_eq!(cursor, Some(101));
        assert_eq!(*highest.lock().await, 101);
    }

    #[tokio::test]
    async fn materialized_later_block_does_not_skip_active_reorg_cursor() {
        let highest = Arc::new(Mutex::new(100));
        let mut cursor = Some(100);

        let advanced = record_materialized_preconf_block(&mut cursor, Some(&highest), 102).await;

        assert!(!advanced);
        assert_eq!(cursor, Some(100));
        assert_eq!(*highest.lock().await, 100);
    }
}
