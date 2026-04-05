//! Fee-recipient authority hooks for whitelist lookahead builds.

use super::*;
use crate::core::authority::SignerAuthority;

impl<P> ApiBuildRuntime<P>
where
    P: Provider + Clone + Send + Sync + 'static,
{
    /// Check whether the supplied fee recipient is allowed for the current handover window.
    pub(super) async fn ensure_fee_recipient_allowed_for_current_slot(
        &self,
        fee_recipient: Address,
    ) -> Result<()> {
        self.authority.ensure_fee_recipient_allowed(fee_recipient).await
    }
}
