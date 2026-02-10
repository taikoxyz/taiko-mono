use std::time::{Duration, Instant};

use alloy_eips::{BlockId, BlockNumberOrTag};
use alloy_primitives::Address;
use alloy_provider::Provider;
use bindings::preconf_whitelist::PreconfWhitelist::operatorsReturn;
use tracing::debug;

use crate::error::{Result, WhitelistPreconfirmationDriverError};

use super::WhitelistPreconfirmationImporter;

/// Maximum age for stale-cache fallback when node timing data lags epoch start.
const MAX_STALE_FALLBACK_SECS: u64 = 12 * 64;
/// Retry once when pinning detects a transient reorg/load-balancer inconsistency.
const SNAPSHOT_FETCH_MAX_ATTEMPTS: usize = 2;

/// Result of a cached sequencer lookup, including whether values came from cache.
struct CachedSequencers {
    current: Address,
    next: Address,
    /// True when at least one value was served from cache rather than freshly fetched.
    any_from_cache: bool,
}

/// Snapshot of sequencer addresses used for signer validation.
struct WhitelistSequencerSnapshot {
    current: Address,
    next: Address,
    current_epoch_start_timestamp: u64,
    block_timestamp: u64,
}

impl<P> WhitelistPreconfirmationImporter<P>
where
    P: Provider + Clone + Send + Sync + 'static,
{
    /// Ensure the signer is allowed in the whitelist.
    ///
    /// First checks cache. On a cache miss (signer not in cached set), only re-fetches
    /// from L1 if cached values were returned. When values were freshly fetched, rejects
    /// immediately to prevent spam from bypassing cache.
    pub(super) async fn ensure_signer_allowed(&mut self, signer: Address) -> Result<()> {
        let now = Instant::now();
        let result = self.cached_whitelist_sequencers(now).await?;

        if signer == result.current || signer == result.next {
            return Ok(());
        }

        // If values were freshly fetched already, reject immediately.
        if !result.any_from_cache {
            return Err(WhitelistPreconfirmationDriverError::InvalidSignature(format!(
                "signer {signer} is not current ({}) or next ({}) whitelist sequencer",
                result.current, result.next
            )));
        }

        if !self.sequencer_cache.allow_miss_refresh(now) {
            debug!(
                %signer,
                cached_current = %result.current,
                cached_next = %result.next,
                "signer mismatch refresh cooldown active; rejecting without L1 re-fetch"
            );
            return Err(WhitelistPreconfirmationDriverError::InvalidSignature(format!(
                "signer {signer} is not current ({}) or next ({}) whitelist sequencer",
                result.current, result.next
            )));
        }

        debug!(
            %signer,
            cached_current = %result.current,
            cached_next = %result.next,
            "signer not in cached whitelist; re-fetching from L1"
        );
        self.sequencer_cache.invalidate();
        let fresh = self.cached_whitelist_sequencers(now).await?;

        if signer == fresh.current || signer == fresh.next {
            return Ok(());
        }

        Err(WhitelistPreconfirmationDriverError::InvalidSignature(format!(
            "signer {signer} is not current ({}) or next ({}) whitelist sequencer",
            fresh.current, fresh.next
        )))
    }

    /// Return (current, next) sequencer addresses, using cache when fresh.
    async fn cached_whitelist_sequencers(&mut self, now: Instant) -> Result<CachedSequencers> {
        // Access here is serialized by `&mut self` on the importer's event loop,
        // so a single importer instance cannot stampede concurrent L1 lookups.
        if let (Some(current), Some(next)) =
            (self.sequencer_cache.get_current(now), self.sequencer_cache.get_next(now))
        {
            return Ok(CachedSequencers { current, next, any_from_cache: true });
        }

        let snapshot = self.fetch_whitelist_sequencers_snapshot_with_retry().await?;

        // If the node is behind and reports a block before the current epoch start, keep serving
        // stale cache values when available instead of failing open/closed on inconsistent timing.
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

        // If a lagging node answers after we already cached a newer epoch snapshot,
        // keep the previous snapshot instead of regressing.
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
            now,
        );

        Ok(CachedSequencers {
            current: snapshot.current,
            next: snapshot.next,
            any_from_cache: false,
        })
    }

    /// Fetch current/next sequencer addresses pinned to one block number.
    ///
    /// It first fetches the latest block header, then executes all whitelist contract reads
    /// pinned to that exact block to avoid load-balancer cross-node inconsistency.
    async fn fetch_whitelist_sequencers_snapshot_with_retry(
        &self,
    ) -> Result<WhitelistSequencerSnapshot> {
        for attempt in 1..=SNAPSHOT_FETCH_MAX_ATTEMPTS {
            match self.fetch_whitelist_sequencers_snapshot().await {
                Ok(snapshot) => return Ok(snapshot),
                Err(err)
                    if attempt < SNAPSHOT_FETCH_MAX_ATTEMPTS &&
                        should_retry_snapshot_fetch(&err) =>
                {
                    debug!(
                        attempt,
                        max_attempts = SNAPSHOT_FETCH_MAX_ATTEMPTS,
                        error = %err,
                        "retrying whitelist snapshot fetch after transient inconsistency"
                    );
                }
                Err(err) => return Err(err),
            }
        }

        unreachable!("snapshot fetch loop must return on success or final error")
    }

    async fn fetch_whitelist_sequencers_snapshot(&self) -> Result<WhitelistSequencerSnapshot> {
        let latest_block = self
            .rpc
            .l1_provider
            .get_block_by_number(BlockNumberOrTag::Latest)
            .await
            .map_err(|err| {
                WhitelistPreconfirmationDriverError::WhitelistLookup(format!(
                    "failed to fetch latest block for whitelist snapshot: {err}"
                ))
            })?
            .ok_or_else(|| {
                WhitelistPreconfirmationDriverError::WhitelistLookup(
                    "missing latest block while fetching whitelist snapshot".to_string(),
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
                    WhitelistPreconfirmationDriverError::WhitelistLookup(format!(
                        "failed to fetch current operator at block {block_number}: {err}"
                    ))
                })
        };
        let next_operator_fut = async {
            self.whitelist
                .getOperatorForNextEpoch()
                .block(BlockId::Number(block_number.into()))
                .call()
                .await
                .map_err(|err| {
                    WhitelistPreconfirmationDriverError::WhitelistLookup(format!(
                        "failed to fetch next operator at block {block_number}: {err}"
                    ))
                })
        };
        let epoch_start_timestamp_fut = async {
            self.whitelist
                .epochStartTimestamp(Default::default())
                .block(BlockId::Number(block_number.into()))
                .call()
                .await
                .map_err(|err| {
                    WhitelistPreconfirmationDriverError::WhitelistLookup(format!(
                        "failed to fetch epochStartTimestamp at block {block_number}: {err}"
                    ))
                })
        };

        let (current_proposer, next_proposer, current_epoch_start_timestamp) =
            tokio::try_join!(current_operator_fut, next_operator_fut, epoch_start_timestamp_fut)?;

        let current_sequencer_fut = async {
            self.whitelist
                .operators(current_proposer)
                .block(BlockId::Number(block_number.into()))
                .call()
                .await
                .map_err(|err| {
                    WhitelistPreconfirmationDriverError::WhitelistLookup(format!(
                        "failed to fetch current operators() entry at block {block_number}: {err}"
                    ))
                })
        };
        let next_sequencer_fut = async {
            self.whitelist
                .operators(next_proposer)
                .block(BlockId::Number(block_number.into()))
                .call()
                .await
                .map_err(|err| {
                    WhitelistPreconfirmationDriverError::WhitelistLookup(format!(
                        "failed to fetch next operators() entry at block {block_number}: {err}"
                    ))
                })
        };
        let pinned_block_fut = async {
            self.rpc
                .l1_provider
                .get_block_by_number(BlockNumberOrTag::Number(block_number))
                .await
                .map_err(|err| {
                    WhitelistPreconfirmationDriverError::WhitelistLookup(format!(
                        "failed to fetch pinned block {block_number} for whitelist verification: \
                         {err}"
                    ))
                })
        };

        let (current_seq, next_seq, pinned_block_opt): (operatorsReturn, operatorsReturn, _) =
            tokio::try_join!(current_sequencer_fut, next_sequencer_fut, pinned_block_fut)?;

        let pinned_block = pinned_block_opt.ok_or_else(|| {
            WhitelistPreconfirmationDriverError::WhitelistLookup(format!(
                "missing pinned block {block_number} while verifying whitelist batches"
            ))
        })?;
        let pinned_block_hash = pinned_block.hash();
        if pinned_block_hash != block_hash {
            return Err(WhitelistPreconfirmationDriverError::WhitelistLookup(format!(
                "block hash changed between whitelist batches at block {block_number}"
            )));
        }

        if current_seq.sequencerAddress == Address::ZERO ||
            next_seq.sequencerAddress == Address::ZERO
        {
            return Err(WhitelistPreconfirmationDriverError::WhitelistLookup(
                "received zero address for whitelist sequencer".to_string(),
            ));
        }

        Ok(WhitelistSequencerSnapshot {
            current: current_seq.sequencerAddress,
            next: next_seq.sequencerAddress,
            current_epoch_start_timestamp: u64::from(current_epoch_start_timestamp),
            block_timestamp,
        })
    }
}

fn ensure_not_too_early_for_epoch(
    block_timestamp: u64,
    current_epoch_start_timestamp: u64,
) -> Result<()> {
    if block_timestamp < current_epoch_start_timestamp {
        return Err(WhitelistPreconfirmationDriverError::WhitelistLookup(format!(
            "whitelist batch returned block timestamp {block_timestamp} before epoch start \
             {current_epoch_start_timestamp}"
        )));
    }

    Ok(())
}

fn should_retry_snapshot_fetch(err: &WhitelistPreconfirmationDriverError) -> bool {
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
    fn should_retry_snapshot_fetch_for_reorg_like_hash_change() {
        let err = WhitelistPreconfirmationDriverError::WhitelistLookup(
            "block hash changed between whitelist batches at block 123".to_string(),
        );
        assert!(should_retry_snapshot_fetch(&err));
    }

    #[test]
    fn should_retry_snapshot_fetch_for_missing_pinned_block() {
        let err = WhitelistPreconfirmationDriverError::WhitelistLookup(
            "missing pinned block 123 while verifying whitelist batches".to_string(),
        );
        assert!(should_retry_snapshot_fetch(&err));
    }

    #[test]
    fn should_retry_snapshot_fetch_for_missing_block_during_call() {
        let err = WhitelistPreconfirmationDriverError::WhitelistLookup(
            "failed to fetch current operator at block 123: header not found".to_string(),
        );
        assert!(should_retry_snapshot_fetch(&err));
    }

    #[test]
    fn should_retry_snapshot_fetch_ignores_non_retryable_lookup_errors() {
        let err = WhitelistPreconfirmationDriverError::WhitelistLookup(
            "failed to fetch current operator at block 123".to_string(),
        );
        assert!(!should_retry_snapshot_fetch(&err));
    }
}
