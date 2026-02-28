use std::time::Instant;

use alloy_primitives::Address;
use alloy_provider::Provider;
use thiserror::Error;
use tracing::debug;

use crate::error::{Result, WhitelistPreconfirmationDriverError};

use super::WhitelistPreconfirmationImporter;

/// Error states produced while validating a signer against current/next whitelist entries.
#[derive(Debug, Error)]
enum SignerCheckError {
    /// The whitelist snapshot is unusable because both operator slots are empty.
    #[error("both whitelist sequencer slots are zero")]
    BothSlotsZero,
    /// The signer is not equal to either current or next whitelist operator.
    #[error("signer {signer} is not current ({current}) or next ({next}) whitelist sequencer")]
    SignerMismatch {
        /// Address recovered from the payload signature.
        signer: Address,
        /// Operator currently assigned for this epoch.
        current: Address,
        /// Operator assigned for the next epoch.
        next: Address,
    },
}

impl SignerCheckError {
    /// Convert a signer-check error into the top-level driver error used by callers.
    fn into_driver_error(self) -> WhitelistPreconfirmationDriverError {
        match self {
            Self::BothSlotsZero => {
                WhitelistPreconfirmationDriverError::WhitelistLookup(self.to_string())
            }
            Self::SignerMismatch { .. } => {
                WhitelistPreconfirmationDriverError::invalid_signature(self.to_string())
            }
        }
    }
}

/// Validate that `signer` matches either `current` or `next`, with explicit empty-snapshot guard.
fn validate_signer_pair(
    signer: Address,
    current: Address,
    next: Address,
) -> std::result::Result<(), SignerCheckError> {
    if signer == current || signer == next {
        return Ok(());
    }

    if current == Address::ZERO && next == Address::ZERO {
        return Err(SignerCheckError::BothSlotsZero);
    }

    Err(SignerCheckError::SignerMismatch { signer, current, next })
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
        let result = self.sequencer_fetcher.cached_whitelist_sequencers(now).await?;

        match validate_signer_pair(signer, result.current, result.next) {
            Ok(()) => return Ok(()),
            Err(SignerCheckError::BothSlotsZero) => {
                return Err(SignerCheckError::BothSlotsZero.into_driver_error());
            }
            Err(SignerCheckError::SignerMismatch { .. }) => {}
        }

        // If values were freshly fetched already, reject immediately.
        if !result.any_from_cache {
            return Err(SignerCheckError::SignerMismatch {
                signer,
                current: result.current,
                next: result.next,
            }
            .into_driver_error());
        }

        if !self.sequencer_fetcher.sequencer_cache.allow_miss_refresh(now) {
            debug!(
                %signer,
                cached_current = %result.current,
                cached_next = %result.next,
                "signer mismatch refresh cooldown active; rejecting without L1 re-fetch"
            );
            return Err(SignerCheckError::SignerMismatch {
                signer,
                current: result.current,
                next: result.next,
            }
            .into_driver_error());
        }

        debug!(
            %signer,
            cached_current = %result.current,
            cached_next = %result.next,
            "signer not in cached whitelist; re-fetching from L1"
        );
        self.sequencer_fetcher.sequencer_cache.invalidate();
        let fresh = self.sequencer_fetcher.cached_whitelist_sequencers(now).await?;

        validate_signer_pair(signer, fresh.current, fresh.next)
            .map_err(SignerCheckError::into_driver_error)
    }
}
