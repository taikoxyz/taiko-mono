use alloy_primitives::Address;
use alloy_provider::Provider;

use crate::error::{Result, WhitelistPreconfirmationDriverError};

use super::WhitelistPreconfirmationImporter;

impl<P> WhitelistPreconfirmationImporter<P>
where
    P: Provider + Clone + Send + Sync + 'static,
{
    /// Ensure the signer is allowed in the whitelist.
    pub(super) async fn ensure_signer_allowed(&self, signer: Address) -> Result<()> {
        let (current, next) =
            tokio::try_join!(self.current_whitelist_sequencer(), self.next_whitelist_sequencer())?;

        if signer == current || signer == next {
            return Ok(());
        }

        Err(WhitelistPreconfirmationDriverError::InvalidSignature(format!(
            "signer {signer} is not current ({current}) or next ({next}) whitelist sequencer"
        )))
    }

    /// Get the current whitelist sequencer address.
    async fn current_whitelist_sequencer(&self) -> Result<Address> {
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

    /// Get the next whitelist sequencer address.
    async fn next_whitelist_sequencer(&self) -> Result<Address> {
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
