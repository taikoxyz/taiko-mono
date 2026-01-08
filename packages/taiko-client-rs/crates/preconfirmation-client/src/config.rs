//! Preconfirmation client configuration.

use std::{
    fmt::{Debug, Formatter, Result as FmtResult},
    time::Duration,
};

use alloy_primitives::Address;
use alloy_provider::Provider;
use preconfirmation_net::P2pConfig;
use preconfirmation_types::Bytes20;
use protocol::preconfirmation::LookaheadResolver;

use crate::Result;

/// Configuration for the preconfirmation client SDK.
#[derive(Clone)]
pub struct PreconfirmationClientConfig {
    /// P2P configuration covering chain ID, listen addresses, discovery, and bootnodes.
    pub p2p: P2pConfig,
    /// Optional slasher address expected on inbound commitments.
    pub expected_slasher: Option<Bytes20>,
    /// Timeout applied to SDK-level request/response operations.
    pub request_timeout: Duration,
    /// Maximum number of commitments requested per catch-up batch.
    pub catchup_batch_size: u32,
    /// Optional concurrency limit for catch-up txlist fetches (None = default 4).
    pub txlist_fetch_concurrency: Option<usize>,
    /// Lookahead resolver used for signer/slot validation.
    pub lookahead_resolver: LookaheadResolver,
}

impl Debug for PreconfirmationClientConfig {
    /// Format the config without requiring the lookahead resolver to be debug-printable.
    fn fmt(&self, f: &mut Formatter<'_>) -> FmtResult {
        f.debug_struct("PreconfirmationClientConfig")
            .field("p2p", &self.p2p)
            .field("expected_slasher", &self.expected_slasher)
            .field("request_timeout", &self.request_timeout)
            .field("catchup_batch_size", &self.catchup_batch_size)
            .field("txlist_fetch_concurrency", &self.txlist_fetch_concurrency)
            .field("lookahead_resolver", &"<LookaheadResolver>")
            .finish()
    }
}

impl PreconfirmationClientConfig {
    /// Build a configuration by resolving lookahead state from the Inbox and provider.
    pub async fn new<P>(p2p: P2pConfig, inbox_address: Address, provider: P) -> Result<Self>
    where
        P: Provider + Clone + Send + Sync + 'static,
    {
        let lookahead_resolver = LookaheadResolver::build(inbox_address, provider).await?;
        Ok(Self {
            p2p,
            expected_slasher: None,
            request_timeout: Duration::from_secs(10),
            catchup_batch_size: 64,
            txlist_fetch_concurrency: None,
            lookahead_resolver,
        })
    }
}

#[cfg(test)]
mod tests {
    use alloy_primitives::Address;
    use alloy_provider::ProviderBuilder;
    use alloy_transport::mock::Asserter;
    use preconfirmation_net::P2pConfig;

    use super::PreconfirmationClientConfig;

    /// Config constructor surfaces provider failures.
    #[tokio::test]
    async fn config_new_reports_provider_failure() {
        // Prepare a mocked provider that fails the first request.
        let asserter = Asserter::new();
        asserter.push_failure_msg("chain id failure");
        let provider = ProviderBuilder::new().connect_mocked_client(asserter);

        let result =
            PreconfirmationClientConfig::new(P2pConfig::default(), Address::ZERO, provider).await;

        assert!(result.is_err());
    }
}
