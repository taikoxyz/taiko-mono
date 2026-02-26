use std::time::Instant;

use alloy_primitives::Address;
use alloy_provider::Provider;
use tracing::debug;

use crate::error::{Result, WhitelistPreconfirmationDriverError};

use super::WhitelistPreconfirmationImporter;

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
        let result = self.sequencer_fetcher.cached_whitelist_sequencers(now).await?;

        // Check signer match first — a valid next-operator should be accepted even
        // when current is zero (legitimate during epoch transitions).
        if signer == result.current || signer == result.next {
            return Ok(());
        }

        // Reject when both slots are zero (contract returned no operators).
        if result.current == Address::ZERO && result.next == Address::ZERO {
            return Err(WhitelistPreconfirmationDriverError::WhitelistLookup(
                "both whitelist sequencer slots are zero".to_string(),
            ));
        }

        // If values were freshly fetched already, reject immediately.
        if !result.any_from_cache {
            return Err(WhitelistPreconfirmationDriverError::InvalidSignature(format!(
                "signer {signer} is not current ({}) or next ({}) whitelist sequencer",
                result.current, result.next
            )));
        }

        if !self.sequencer_fetcher.sequencer_cache.allow_miss_refresh(now) {
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
        self.sequencer_fetcher.sequencer_cache.invalidate();
        let fresh = self.sequencer_fetcher.cached_whitelist_sequencers(now).await?;

        if signer == fresh.current || signer == fresh.next {
            return Ok(());
        }

        if fresh.current == Address::ZERO && fresh.next == Address::ZERO {
            return Err(WhitelistPreconfirmationDriverError::WhitelistLookup(
                "both whitelist sequencer slots are zero".to_string(),
            ));
        }

        Err(WhitelistPreconfirmationDriverError::InvalidSignature(format!(
            "signer {signer} is not current ({}) or next ({}) whitelist sequencer",
            fresh.current, fresh.next
        )))
    }
}
