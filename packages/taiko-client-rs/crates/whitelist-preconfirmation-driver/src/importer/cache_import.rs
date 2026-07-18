//! Cache re-import flow for out-of-order envelopes once parents arrive.

use std::time::Instant;

use alethia_reth_primitives::payload::attributes::TaikoPayloadAttributes;
use driver::{PreconfPayload, PreconfSubmissionOutcome};
use tracing::{debug, info, warn};

use crate::{
    codec::{WhitelistExecutionPayloadEnvelope, decompress_tx_list},
    error::{Result, WhitelistPreconfirmationDriverError},
    metrics::WhitelistPreconfirmationDriverMetrics,
};

use super::WhitelistPreconfirmationImporter;

/// Build the driver payload from a whitelist envelope.
fn driver_payload_from_envelope(
    envelope: &WhitelistExecutionPayloadEnvelope,
) -> Result<TaikoPayloadAttributes> {
    let compressed_tx_list = envelope.execution_payload.transactions.first().ok_or_else(|| {
        WhitelistPreconfirmationDriverError::invalid_payload("missing transactions list")
    })?;
    let tx_list = decompress_tx_list(compressed_tx_list)?;

    Ok(crate::payload::build_driver_payload(
        &envelope.execution_payload,
        tx_list,
        envelope.parent_beacon_block_root,
        envelope.is_forced_inclusion.unwrap_or(false),
        envelope.signature.unwrap_or([0u8; 65]),
    ))
}

impl WhitelistPreconfirmationImporter {
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
            // One confirmed-boundary snapshot per drain pass instead of one RPC per
            // envelope. If the boundary advances mid-pass the stale snapshot only
            // under-drops here and the already-inserted check below still drops
            // just-confirmed duplicates; if a reorg reset lowers it mid-pass, a
            // stale-high snapshot can over-drop a cached block, which is the safe
            // direction and self-heals via re-gossip or a parent request. Either way
            // the driver's preconf ingress re-reads the boundary per submitted payload
            // (WLP-INV-003 stays enforced at the ingress path). An unwritten origin
            // means no confirmed boundary yet (genesis cold start).
            let head_l1_origin_block_id = self.head_l1_origin_block_id().await?.unwrap_or(0);
            let hashes = self.cache.sorted_hashes_by_block_number();

            for hash in hashes {
                let Some(entry) = self.cache.get(&hash).cloned() else {
                    continue;
                };
                match self.try_import_cached(&entry, head_l1_origin_block_id).await {
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
                    Err(err) => match classify_cached_import_error(&err) {
                        CachedImportDisposition::Defer => {
                            WhitelistPreconfirmationDriverMetrics::inc_cache_import_result(
                                "deferred_error",
                            );
                            debug!(
                                block_hash = %hash,
                                error = %err,
                                "deferring cached whitelist preconfirmation payload import for retry"
                            );
                        }
                        CachedImportDisposition::Drop => {
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
                        CachedImportDisposition::Propagate => {
                            WhitelistPreconfirmationDriverMetrics::inc_cache_import_result(
                                "fatal_error",
                            );
                            self.update_pending_cache_gauge();
                            return Err(err);
                        }
                    },
                }
            }

            if !progressed {
                break;
            }
        }

        self.update_pending_cache_gauge();
        Ok(())
    }

    /// Try to import one cached envelope against the pass-level confirmed boundary.
    async fn try_import_cached(
        &mut self,
        envelope: &WhitelistExecutionPayloadEnvelope,
        head_l1_origin_block_id: u64,
    ) -> Result<bool> {
        let payload = &envelope.execution_payload;
        let block_number = payload.block_number;
        let block_hash = payload.block_hash;
        let end_of_sequencing = envelope.end_of_sequencing.unwrap_or(false);

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

        let expected_parent_hash = envelope.execution_payload.parent_hash;
        let driver_payload = driver_payload_from_envelope(envelope)?;
        let submit_start = Instant::now();
        let submit_result = self
            .event_syncer
            .submit_preconfirmation_payload(PreconfPayload::new(
                driver_payload,
                expected_parent_hash,
            ))
            .await;
        WhitelistPreconfirmationDriverMetrics::observe_driver_submit(
            if submit_result.is_ok() { "success" } else { "failure" },
            submit_start.elapsed().as_secs_f64(),
        );
        match submit_result? {
            PreconfSubmissionOutcome::Inserted { block_hash: inserted_block_hash } => {
                if inserted_block_hash == block_hash {
                    info!(
                        block_number,
                        block_hash = %block_hash,
                        parent_hash = %parent_hash,
                        end_of_sequencing,
                        "inserted whitelist preconfirmation block"
                    );
                    // Notify `/ws` subscribers only once the end-of-sequencing
                    // block has materialized, with the wall-clock epoch at push
                    // time — both matching the Go client, whose only push site
                    // runs after `TryImportingPayload` succeeds and re-reads
                    // `CurrentEpoch()`. The tracker holds hashes whose EOS flag
                    // arrived wire-signed on the payload topic; the flag on the
                    // cached envelope is deliberately not consulted, since a
                    // response-topic envelope (embedded signature covers only
                    // the block hash) could have overwritten it in either
                    // direction. Deliberate superset of Go in one respect only:
                    // deferred payload-topic imports still notify, where Go's
                    // envelope cache drops the EOS flag and loses them.
                    if self.payload_eos_tracker.take(&block_hash) {
                        self.state.notify_end_of_sequencing(self.beacon_client.current_epoch());
                    }
                } else {
                    // The operator-signed hash does not match the block its own payload
                    // produces; stop re-serving the inconsistent envelope to peers. The
                    // produced block still advanced the local unsafe head, so it is recorded.
                    warn!(
                        block_number,
                        envelope_block_hash = %block_hash,
                        inserted_block_hash = %inserted_block_hash,
                        "operator-signed envelope hash mismatches inserted block; purging envelope"
                    );
                    self.state.remove_recent(&block_hash).await;
                }
                self.state.record_inserted_block(block_number);
            }
            PreconfSubmissionOutcome::AlreadyMaterialized {
                block_hash: materialized_block_hash,
            } => {
                if materialized_block_hash == block_hash {
                    debug!(
                        block_number,
                        block_hash = %block_hash,
                        "cached preconfirmation already materialized"
                    );
                } else {
                    warn!(
                        block_number,
                        envelope_block_hash = %block_hash,
                        materialized_block_hash = %materialized_block_hash,
                        "operator-signed envelope hash mismatches materialized block; purging envelope"
                    );
                    self.state.remove_recent(&block_hash).await;
                }
            }
            PreconfSubmissionOutcome::Stale => {
                debug!(
                    block_number,
                    block_hash = %block_hash,
                    "cached preconfirmation became stale"
                );
            }
        }

        Ok(true)
    }
}

/// Disposition of a cached-envelope import error: retry later, discard the envelope, or abort
/// the drain loop.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub(super) enum CachedImportDisposition {
    /// Transient condition; keep the envelope cached and retry on a later pass.
    Defer,
    /// Envelope-scoped rejection; log and discard the envelope.
    Drop,
    /// Unexpected failure; abort the drain loop and surface the error.
    Propagate,
}

/// Classify a cached-envelope import error into exactly one disposition.
pub(super) fn classify_cached_import_error(
    err: &WhitelistPreconfirmationDriverError,
) -> CachedImportDisposition {
    match err {
        WhitelistPreconfirmationDriverError::InvalidPayload(_) |
        WhitelistPreconfirmationDriverError::InvalidSignature(_) => CachedImportDisposition::Drop,
        WhitelistPreconfirmationDriverError::Driver(driver_err) => {
            classify_cached_driver_error(driver_err)
        }
        _ => CachedImportDisposition::Propagate,
    }
}

/// Classify a driver-layer error observed while importing a cached envelope.
///
/// Envelope-scoped rejections drop the envelope, sync-related conditions defer it, and
/// anything else aborts the drain loop.
fn classify_cached_driver_error(err: &driver::DriverError) -> CachedImportDisposition {
    use driver::sync::error::EngineSubmissionError;

    match err {
        driver::DriverError::EngineInvalidPayload(_) => CachedImportDisposition::Drop,
        driver::DriverError::EngineSyncing(_) |
        driver::DriverError::BlockNotFound(_) |
        driver::DriverError::PreconfParentMismatch { .. } |
        driver::DriverError::PreconfEnqueueTimeout { .. } |
        driver::DriverError::PreconfResponseTimeout { .. } => CachedImportDisposition::Defer,
        driver::DriverError::PreconfInjectionFailed { source, .. } => match source {
            EngineSubmissionError::InvalidBlock(_, _) => CachedImportDisposition::Drop,
            EngineSubmissionError::EngineSyncing(_) |
            EngineSubmissionError::MissingPayloadId |
            EngineSubmissionError::MissingInsertedBlock(_) => CachedImportDisposition::Defer,
            _ => CachedImportDisposition::Propagate,
        },
        _ => CachedImportDisposition::Propagate,
    }
}
