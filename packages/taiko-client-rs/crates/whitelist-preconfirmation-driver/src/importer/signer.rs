use std::time::Instant;

use alloy_primitives::Address;
use alloy_provider::Provider;
use tracing::debug;

use crate::error::{Result, WhitelistPreconfirmationDriverError};

use super::WhitelistPreconfirmationImporter;

/// Result of a cached sequencer lookup, including whether values came from cache.
struct CachedSequencers {
    current: Address,
    next: Address,
    /// True when at least one value was served from the TTL cache rather than freshly fetched.
    any_from_cache: bool,
}

impl<P> WhitelistPreconfirmationImporter<P>
where
    P: Provider + Clone + Send + Sync + 'static,
{
    /// Ensure the signer is allowed in the whitelist.
    ///
    /// First checks the TTL cache. On a cache miss (signer not in cached set), only re-fetches
    /// from L1 if the cached values were served from cache (could be stale due to epoch rotation).
    /// When the values were freshly fetched, rejects immediately to prevent spam from bypassing
    /// the cache.
    pub(super) async fn ensure_signer_allowed(&mut self, signer: Address) -> Result<()> {
        let now = Instant::now();
        let result = self.cached_whitelist_sequencers(now).await?;

        if signer == result.current || signer == result.next {
            return Ok(());
        }

        // Only re-fetch if at least one value was served from cache (could be stale).
        // If both were freshly fetched from L1, reject immediately — re-fetching would
        // return the same result and lets spam bypass the cache.
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

    /// Return (current, next) sequencer addresses, using the TTL cache when fresh.
    async fn cached_whitelist_sequencers(&mut self, now: Instant) -> Result<CachedSequencers> {
        // Access here is serialized by `&mut self` on the importer's event loop,
        // so a single importer instance cannot stampede concurrent L1 lookups.
        let mut any_from_cache = false;

        let current = match self.sequencer_cache.get_current(now) {
            Some(addr) => {
                any_from_cache = true;
                addr
            }
            None => {
                let addr = self.fetch_current_whitelist_sequencer().await?;
                self.sequencer_cache.set_current(addr, now);
                addr
            }
        };

        let next = match self.sequencer_cache.get_next(now) {
            Some(addr) => {
                any_from_cache = true;
                addr
            }
            None => {
                let addr = self.fetch_next_whitelist_sequencer().await?;
                self.sequencer_cache.set_next(addr, now);
                addr
            }
        };

        Ok(CachedSequencers { current, next, any_from_cache })
    }

    /// Fetch the current whitelist sequencer address from L1.
    async fn fetch_current_whitelist_sequencer(&self) -> Result<Address> {
        let proposer = self.whitelist.getOperatorForCurrentEpoch().call().await.map_err(|err| {
            WhitelistPreconfirmationDriverError::WhitelistLookup(format!(
                "failed to read current whitelist proposer: {err}"
            ))
        })?;

        self.whitelist.operators(proposer).call().await.map(|info| info.sequencerAddress).map_err(
            |err| {
                WhitelistPreconfirmationDriverError::WhitelistLookup(format!(
                    "failed to read current whitelist sequencer: {err}"
                ))
            },
        )
    }

    /// Fetch the next whitelist sequencer address from L1.
    async fn fetch_next_whitelist_sequencer(&self) -> Result<Address> {
        let proposer = self.whitelist.getOperatorForNextEpoch().call().await.map_err(|err| {
            WhitelistPreconfirmationDriverError::WhitelistLookup(format!(
                "failed to read next whitelist proposer: {err}"
            ))
        })?;

        self.whitelist.operators(proposer).call().await.map(|info| info.sequencerAddress).map_err(
            |err| {
                WhitelistPreconfirmationDriverError::WhitelistLookup(format!(
                    "failed to read next whitelist sequencer: {err}"
                ))
            },
        )
    }
}
