//! Signer validation hooks for whitelist payload imports.

use alloy_primitives::Address;
use alloy_provider::Provider;

use crate::{Result, core::authority::SignerAuthority};

use super::WhitelistPreconfirmationImporter;

impl<P> WhitelistPreconfirmationImporter<P>
where
    P: Provider + Clone + Send + Sync + 'static,
{
    /// Ensure the recovered payload signer is authorized by the shared whitelist authority.
    pub(super) async fn ensure_signer_allowed(&self, signer: Address) -> Result<()> {
        self.authority.ensure_payload_signer_allowed(signer).await
    }
}
