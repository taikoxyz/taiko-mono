//! Shared whitelist sequencer fetcher used by the importer signer checker to validate
//! block signers against the L1 `PreconfWhitelist` contract.

use std::time::{Duration, Instant};

use alloy_eips::{BlockId, BlockNumberOrTag};
use alloy_primitives::Address;
use alloy_provider::Provider;
use bindings::preconf_whitelist::PreconfWhitelist::{PreconfWhitelistInstance, operatorsReturn};
use tracing::debug;

use crate::{
    cache::{L1_EPOCH_DURATION_SECS, WhitelistSequencerCache},
    error::{Result, WhitelistPreconfirmationDriverError},
    metrics::WhitelistPreconfirmationDriverMetrics,
};

/// Maximum age for stale-cache fallback when node timing data lags epoch start.
const MAX_STALE_FALLBACK_SECS: u64 = 12 * 64;
/// Retry once when whitelist snapshot fetch sees a transient inconsistency.
const SNAPSHOT_FETCH_MAX_ATTEMPTS: usize = 2;

/// Result of a cached sequencer lookup, including whether values came from cache.
#[derive(Debug)]
pub(crate) struct CachedSequencers {
    /// Current-epoch whitelist sequencer address.
    pub(crate) current: Address,
    /// Next-epoch whitelist sequencer address.
    pub(crate) next: Address,
    /// True when at least one value was served from cache rather than freshly fetched.
    pub(crate) any_from_cache: bool,
}

/// Snapshot of sequencer addresses tied to a pinned block.
#[derive(Debug)]
pub(crate) struct WhitelistSequencerSnapshot {
    /// Active sequencer address.
    pub(crate) current: Address,
    /// Next-sequencer address.
    pub(crate) next: Address,
    /// Epoch start timestamp for the cached operators.
    pub(crate) current_epoch_start_timestamp: u64,
    /// Block timestamp for the pinned block.
    pub(crate) block_timestamp: u64,
}

/// Error class returned from snapshot fetch attempts.
#[derive(Debug)]
pub(crate) enum SnapshotFetchError {
    /// Retry is safe on transient provider/chain inconsistency.
    Retryable(WhitelistPreconfirmationDriverError),
    /// Retry is not safe and should fail the lookup immediately.
    Fatal(WhitelistPreconfirmationDriverError),
}

impl From<SnapshotFetchError> for WhitelistPreconfirmationDriverError {
    fn from(err: SnapshotFetchError) -> Self {
        match err {
            SnapshotFetchError::Retryable(err) | SnapshotFetchError::Fatal(err) => err,
        }
    }
}

/// Shared fetcher for whitelist sequencer snapshots backed by a TTL cache.
#[derive(Debug)]
pub(crate) struct WhitelistSequencerFetcher<P> {
    /// Contract binding for allowlist lookup RPC calls.
    whitelist: PreconfWhitelistInstance<P>,
    /// L1 provider used for block/timestamp reads.
    l1_provider: P,
    /// TTL cache for current/next whitelist sequencer addresses.
    pub(crate) sequencer_cache: WhitelistSequencerCache,
}

impl<P> WhitelistSequencerFetcher<P>
where
    P: Provider + Clone + Send + Sync + 'static,
{
    /// Construct a new fetcher.
    pub(crate) fn new(whitelist_address: Address, l1_provider: P) -> Self {
        let whitelist = PreconfWhitelistInstance::new(whitelist_address, l1_provider.clone());
        Self { whitelist, l1_provider, sequencer_cache: WhitelistSequencerCache::default() }
    }

    /// Return (current, next) sequencer addresses, using cache when available.
    pub(crate) async fn cached_whitelist_sequencers(
        &mut self,
        now: Instant,
    ) -> Result<CachedSequencers> {
        if let (Some(current), Some(next)) =
            (self.sequencer_cache.get_current(), self.sequencer_cache.get_next())
        {
            return Ok(CachedSequencers { current, next, any_from_cache: true });
        }

        let snapshot = self.fetch_whitelist_snapshot_with_retry().await?;

        if let Err(err) = ensure_not_too_early_for_epoch(
            snapshot.block_timestamp,
            snapshot.current_epoch_start_timestamp,
        ) {
            if let Some((current, next)) = self
                .sequencer_cache
                .get_stale_pair_within(now, Duration::from_secs(MAX_STALE_FALLBACK_SECS))
            {
                debug!(
                    block_timestamp = snapshot.block_timestamp,
                    current_epoch_start_timestamp = snapshot.current_epoch_start_timestamp,
                    "using stale whitelist snapshot because latest block is before epoch start"
                );
                return Ok(CachedSequencers { current, next, any_from_cache: true });
            }
            return Err(err);
        }

        if !self.sequencer_cache.should_accept_block_timestamp(snapshot.block_timestamp) &&
            let Some((current, next)) = self
                .sequencer_cache
                .get_stale_pair_within(now, Duration::from_secs(MAX_STALE_FALLBACK_SECS))
        {
            debug!(
                block_timestamp = snapshot.block_timestamp,
                "ignoring regressive whitelist snapshot from lagging RPC node"
            );
            return Ok(CachedSequencers { current, next, any_from_cache: true });
        }

        self.sequencer_cache.set_pair(
            snapshot.current,
            snapshot.next,
            snapshot.current_epoch_start_timestamp,
            snapshot.block_timestamp,
            now,
        );

        Ok(CachedSequencers {
            current: snapshot.current,
            next: snapshot.next,
            any_from_cache: false,
        })
    }

    /// Fetch current/next sequencer snapshot with retry after transient inconsistencies.
    async fn fetch_whitelist_snapshot_with_retry(&self) -> Result<WhitelistSequencerSnapshot> {
        for attempt in 1..=SNAPSHOT_FETCH_MAX_ATTEMPTS {
            match self.fetch_whitelist_snapshot().await {
                Ok(snapshot) => return Ok(snapshot),
                Err(SnapshotFetchError::Retryable(err))
                    if attempt < SNAPSHOT_FETCH_MAX_ATTEMPTS =>
                {
                    debug!(
                        attempt,
                        max_attempts = SNAPSHOT_FETCH_MAX_ATTEMPTS,
                        error = %err,
                        "retrying whitelist snapshot fetch after transient inconsistency"
                    );
                }
                Err(err) => return Err(err.into()),
            }
        }

        unreachable!("snapshot fetch loop must return on success or final error")
    }

    /// Fetch current/next sequencer snapshot from the current pinned L1 block.
    async fn fetch_whitelist_snapshot(
        &self,
    ) -> std::result::Result<WhitelistSequencerSnapshot, SnapshotFetchError> {
        let latest_block = self
            .l1_provider
            .get_block_by_number(BlockNumberOrTag::Latest)
            .await
            .map_err(|err| {
                snapshot_fetch_error(
                    format!("failed to fetch latest block for whitelist snapshot: {err}"),
                    false,
                )
            })?
            .ok_or_else(|| {
                snapshot_fetch_error(
                    "missing latest block while fetching whitelist snapshot".to_string(),
                    false,
                )
            })?;

        let block_number = latest_block.header.number;
        let block_timestamp = latest_block.header.timestamp;
        let block_hash = latest_block.hash();

        let current_operator_fut = async {
            self.whitelist
                .getOperatorForCurrentEpoch()
                .block(BlockId::Number(block_number.into()))
                .call()
                .await
                .map_err(|err| {
                    snapshot_fetch_error(
                        format!("failed to fetch current operator at block {block_number}: {err}"),
                        true,
                    )
                })
        };
        let next_operator_fut = async {
            self.whitelist
                .getOperatorForNextEpoch()
                .block(BlockId::Number(block_number.into()))
                .call()
                .await
                .map_err(|err| {
                    snapshot_fetch_error(
                        format!("failed to fetch next operator at block {block_number}: {err}"),
                        true,
                    )
                })
        };
        let epoch_start_timestamp_fut = async {
            self.whitelist
                .epochStartTimestamp(Default::default())
                .block(BlockId::Number(block_number.into()))
                .call()
                .await
                .map_err(|err| {
                    snapshot_fetch_error(
                        format!(
                            "failed to fetch epochStartTimestamp at block {block_number}: {err}"
                        ),
                        true,
                    )
                })
        };

        let (current_proposer, next_proposer, current_epoch_start_timestamp) =
            tokio::try_join!(current_operator_fut, next_operator_fut, epoch_start_timestamp_fut)?;

        let current_seq_fut = async {
            self.whitelist
                .operators(current_proposer)
                .block(BlockId::Number(block_number.into()))
                .call()
                .await
                .map_err(|err| {
                    snapshot_fetch_error(
                        format!(
                            "failed to fetch current operators() entry at block {block_number}: \
                             {err}"
                        ),
                        true,
                    )
                })
        };
        let next_seq_fut = async {
            self.whitelist
                .operators(next_proposer)
                .block(BlockId::Number(block_number.into()))
                .call()
                .await
                .map_err(|err| {
                    snapshot_fetch_error(
                        format!(
                            "failed to fetch next operators() entry at block {block_number}: {err}"
                        ),
                        true,
                    )
                })
        };
        let pinned_block_fut = async {
            self.l1_provider
                .get_block_by_number(BlockNumberOrTag::Number(block_number))
                .await
                .map_err(|err| {
                    snapshot_fetch_error(
                        format!(
                            "failed to fetch pinned block {block_number} for whitelist \
                             verification: {err}"
                        ),
                        true,
                    )
                })
        };

        let (current_seq, next_seq, pinned_block_opt): (operatorsReturn, operatorsReturn, _) =
            tokio::try_join!(current_seq_fut, next_seq_fut, pinned_block_fut)?;

        let pinned_block = pinned_block_opt.ok_or_else(|| {
            snapshot_fetch_error(
                format!("missing pinned block {block_number} while verifying whitelist batches"),
                true,
            )
        })?;
        let pinned_block_hash = pinned_block.hash();
        if pinned_block_hash != block_hash {
            return Err(snapshot_fetch_error(
                format!("block hash changed between whitelist batches at block {block_number}"),
                true,
            ));
        }

        // Zero-address snapshots are intentionally cached and returned here.
        // Each consumer validates differently: the inbound gossip filter treats
        // zero signers as Ignore (permissive), while the importer's signer check
        // rejects them explicitly. Caching zeros avoids repeated L1 fetches when
        // the contract legitimately returns empty slots.
        if current_seq.sequencerAddress == Address::ZERO &&
            next_seq.sequencerAddress == Address::ZERO
        {
            debug!(
                current = %current_seq.sequencerAddress,
                next = %next_seq.sequencerAddress,
                block_number,
                "received empty whitelist sequencer snapshot"
            );
        }

        Ok(WhitelistSequencerSnapshot {
            current: current_seq.sequencerAddress,
            next: next_seq.sequencerAddress,
            current_epoch_start_timestamp: u64::from(current_epoch_start_timestamp),
            block_timestamp,
        })
    }

    /// Check whether the L1 head has advanced past the cached epoch boundary and, if so,
    /// invalidate the sequencer cache to force a fresh L1 read on the next access.
    pub(crate) async fn maybe_invalidate_for_epoch_advance(&mut self) -> Result<()> {
        let Some(_) = self.sequencer_cache.current_epoch_start_timestamp() else {
            return Ok(());
        };

        let latest_block =
            self.l1_provider.get_block_by_number(BlockNumberOrTag::Latest).await.map_err(
                |err| {
                    WhitelistPreconfirmationDriverError::Rpc(rpc::RpcClientError::Provider(
                        err.to_string(),
                    ))
                },
            )?;

        let Some(block) = latest_block else {
            return Ok(());
        };

        if self
            .sequencer_cache
            .should_invalidate_for_l1_timestamp(block.header.timestamp, L1_EPOCH_DURATION_SECS)
        {
            debug!(
                block_timestamp = block.header.timestamp,
                "invalidating sequencer cache after epoch boundary crossing"
            );
            self.sequencer_cache.invalidate();
        }

        Ok(())
    }
}

/// Build a snapshot-fetch error with fatality hint.
fn snapshot_fetch_error(message: String, retryable: bool) -> SnapshotFetchError {
    let error = whitelist_lookup_err(message);
    if retryable { SnapshotFetchError::Retryable(error) } else { SnapshotFetchError::Fatal(error) }
}

/// Map a whitelist lookup failure into a typed driver error and increment metric.
fn whitelist_lookup_err(message: String) -> WhitelistPreconfirmationDriverError {
    metrics::counter!(WhitelistPreconfirmationDriverMetrics::WHITELIST_LOOKUP_FAILURES_TOTAL)
        .increment(1);
    WhitelistPreconfirmationDriverError::WhitelistLookup(message)
}

/// Validate that the fetched block timestamp is not before the epoch start.
fn ensure_not_too_early_for_epoch(
    block_timestamp: u64,
    current_epoch_start_timestamp: u64,
) -> Result<()> {
    if block_timestamp < current_epoch_start_timestamp {
        return Err(whitelist_lookup_err(format!(
            "whitelist batch returned block timestamp {block_timestamp} before epoch start \
             {current_epoch_start_timestamp}"
        )));
    }

    Ok(())
}

/// Return true when a whitelist-snapshot lookup failure is considered transient.
#[cfg(test)]
fn is_retryable_snapshot_error(err: &WhitelistPreconfirmationDriverError) -> bool {
    match err {
        WhitelistPreconfirmationDriverError::WhitelistLookup(message) => {
            let lower = message.to_ascii_lowercase();
            message.contains("block hash changed between whitelist batches") ||
                message.contains("missing pinned block") ||
                (message.contains("at block") &&
                    (lower.contains("not found") || lower.contains("unknown block")))
        }
        _ => false,
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn epoch_timing_check_rejects_too_early_block() {
        let err = ensure_not_too_early_for_epoch(99, 100).expect_err("must reject too-early block");
        assert!(err.to_string().contains("before epoch start"));
    }

    #[test]
    fn epoch_timing_check_accepts_equal_or_later_block() {
        ensure_not_too_early_for_epoch(100, 100).expect("equal timestamp must pass");
        ensure_not_too_early_for_epoch(101, 100).expect("later timestamp must pass");
    }

    #[test]
    fn retryable_snapshot_error_for_reorg_like_hash_change() {
        let err = WhitelistPreconfirmationDriverError::WhitelistLookup(
            "block hash changed between whitelist batches at block 123".to_string(),
        );
        assert!(is_retryable_snapshot_error(&err));
    }

    #[test]
    fn retryable_snapshot_error_for_missing_pinned_block() {
        let err = WhitelistPreconfirmationDriverError::WhitelistLookup(
            "missing pinned block 123 while verifying whitelist batches".to_string(),
        );
        assert!(is_retryable_snapshot_error(&err));
    }

    #[test]
    fn retryable_snapshot_error_for_missing_block_during_call() {
        let err = WhitelistPreconfirmationDriverError::WhitelistLookup(
            "failed to fetch current operator at block 123: header not found".to_string(),
        );
        assert!(is_retryable_snapshot_error(&err));
    }

    #[test]
    fn retryable_snapshot_error_ignores_non_retryable_lookup_errors() {
        let err = WhitelistPreconfirmationDriverError::WhitelistLookup(
            "failed to fetch current operator at block 123".to_string(),
        );
        assert!(!is_retryable_snapshot_error(&err));
    }
}
