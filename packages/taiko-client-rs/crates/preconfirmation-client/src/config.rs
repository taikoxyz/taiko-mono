//! Preconfirmation client configuration.

use std::{
    fmt::{Debug, Formatter, Result as FmtResult},
    sync::Arc,
    time::Duration,
};

use alloy_primitives::Address;
use alloy_provider::Provider;
use preconfirmation_net::P2pConfig;
use preconfirmation_types::Bytes20;
use protocol::preconfirmation::{LookaheadResolver, PreconfSignerResolver};

use crate::Result;

/// Default number of commitments/txlists to retain in memory.
pub const DEFAULT_RETENTION_LIMIT: usize = 384 * 10;

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
    pub lookahead_resolver: Arc<dyn PreconfSignerResolver + Send + Sync>,
    /// Maximum number of commitments/txlists retained in memory.
    pub retention_limit: usize,
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
            .field("lookahead_resolver", &"<PreconfSignerResolver>")
            .field("retention_limit", &self.retention_limit)
            .finish()
    }
}

impl PreconfirmationClientConfig {
    /// Build a configuration by resolving lookahead state from the Inbox and provider.
    pub async fn new<P>(p2p: P2pConfig, inbox_address: Address, provider: P) -> Result<Self>
    where
        P: Provider + Clone + Send + Sync + 'static,
    {
        let lookahead_resolver = Arc::new(LookaheadResolver::build(inbox_address, provider).await?);
        Ok(Self {
            p2p,
            expected_slasher: None,
            request_timeout: Duration::from_secs(10),
            catchup_batch_size: 64,
            txlist_fetch_concurrency: None,
            lookahead_resolver,
            retention_limit: DEFAULT_RETENTION_LIMIT,
        })
    }

    /// Build a configuration with a caller-provided lookahead resolver.
    pub fn new_with_resolver(
        p2p: P2pConfig,
        lookahead_resolver: Arc<dyn PreconfSignerResolver + Send + Sync>,
    ) -> Self {
        Self {
            p2p,
            expected_slasher: None,
            request_timeout: Duration::from_secs(10),
            catchup_batch_size: 64,
            txlist_fetch_concurrency: None,
            lookahead_resolver,
            retention_limit: DEFAULT_RETENTION_LIMIT,
        }
    }

    /// Validate configuration parameters.
    ///
    /// Returns an error if any parameter has an invalid value.
    pub fn validate(&self) -> Result<()> {
        use crate::error::PreconfirmationClientError;

        if self.catchup_batch_size == 0 {
            return Err(PreconfirmationClientError::Config(
                "catchup_batch_size must be greater than 0".to_string(),
            ));
        }
        if self.retention_limit == 0 {
            return Err(PreconfirmationClientError::Config(
                "retention_limit must be greater than 0".to_string(),
            ));
        }
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use std::sync::Arc;

    use alloy_primitives::Address;
    use alloy_provider::ProviderBuilder;
    use alloy_transport::mock::Asserter;
    use preconfirmation_net::P2pConfig;

    use super::{DEFAULT_RETENTION_LIMIT, PreconfirmationClientConfig};

    /// Create a minimal test config with the given parameters.
    fn test_config(catchup_batch_size: u32, retention_limit: usize) -> PreconfirmationClientConfig {
        use async_trait::async_trait;
        use protocol::preconfirmation::{PreconfSignerResolver, PreconfSlotInfo};

        struct NoopResolver;

        #[async_trait]
        impl PreconfSignerResolver for NoopResolver {
            async fn signer_for_timestamp(
                &self,
                _: alloy_primitives::U256,
            ) -> protocol::preconfirmation::Result<Address> {
                Ok(Address::ZERO)
            }
            async fn slot_info_for_timestamp(
                &self,
                _: alloy_primitives::U256,
            ) -> protocol::preconfirmation::Result<PreconfSlotInfo> {
                Ok(PreconfSlotInfo {
                    signer: Address::ZERO,
                    submission_window_end: alloy_primitives::U256::ZERO,
                })
            }
        }

        PreconfirmationClientConfig {
            p2p: P2pConfig::default(),
            expected_slasher: None,
            request_timeout: std::time::Duration::from_secs(10),
            catchup_batch_size,
            txlist_fetch_concurrency: None,
            lookahead_resolver: Arc::new(NoopResolver),
            retention_limit,
        }
    }

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

    /// Validation rejects zero catchup_batch_size.
    #[test]
    fn validate_rejects_zero_catchup_batch_size() {
        let config = test_config(0, DEFAULT_RETENTION_LIMIT);
        let result = config.validate();
        assert!(result.is_err());
        assert!(result.unwrap_err().to_string().contains("catchup_batch_size"));
    }

    /// Validation rejects zero retention_limit.
    #[test]
    fn validate_rejects_zero_retention_limit() {
        let config = test_config(64, 0);
        let result = config.validate();
        assert!(result.is_err());
        assert!(result.unwrap_err().to_string().contains("retention_limit"));
    }

    /// Validation passes for valid parameters.
    #[test]
    fn validate_accepts_valid_params() {
        let config = test_config(64, DEFAULT_RETENTION_LIMIT);
        assert!(config.validate().is_ok());
    }
}
