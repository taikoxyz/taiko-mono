//! Preconfirmation client configuration.

use std::{
    fmt::{Debug, Formatter, Result as FmtResult},
    sync::Arc,
    time::Duration,
};

use preconfirmation_net::{LookaheadResolver, P2pConfig};
use preconfirmation_types::{Bytes20, MAX_TXLIST_BYTES};

/// Configuration for the txlist codec used by the SDK.
#[derive(Clone, Debug)]
pub struct TxListCodecConfig {
    /// Maximum accepted compressed txlist size in bytes.
    pub max_txlist_bytes: usize,
}

impl Default for TxListCodecConfig {
    /// Builds a default codec configuration aligned with protocol constants.
    fn default() -> Self {
        Self { max_txlist_bytes: MAX_TXLIST_BYTES }
    }
}

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
    /// Interval between catch-up batch requests.
    pub catchup_interval: Duration,
    /// Codec configuration used to bound txlist payloads.
    pub txlist_codec: TxListCodecConfig,
    /// Optional lookahead resolver used for signer/slot validation.
    pub lookahead_resolver: Option<Arc<dyn LookaheadResolver>>,
}

impl Debug for PreconfirmationClientConfig {
    /// Format the config without requiring the lookahead resolver to be debug-printable.
    fn fmt(&self, f: &mut Formatter<'_>) -> FmtResult {
        f.debug_struct("PreconfirmationClientConfig")
            .field("p2p", &self.p2p)
            .field("expected_slasher", &self.expected_slasher)
            .field("request_timeout", &self.request_timeout)
            .field("catchup_batch_size", &self.catchup_batch_size)
            .field("catchup_interval", &self.catchup_interval)
            .field("txlist_codec", &self.txlist_codec)
            .field("lookahead_resolver", &self.lookahead_resolver.is_some())
            .finish()
    }
}

impl Default for PreconfirmationClientConfig {
    /// Builds a default configuration suitable for local development.
    fn default() -> Self {
        // Start from the network defaults to keep P2P settings consistent.
        let p2p = P2pConfig::default();
        Self {
            p2p,
            expected_slasher: None,
            request_timeout: Duration::from_secs(10),
            catchup_batch_size: 64,
            catchup_interval: Duration::from_secs(1),
            txlist_codec: TxListCodecConfig::default(),
            lookahead_resolver: None,
        }
    }
}

#[cfg(test)]
/// Tests for default configuration values.
mod tests {
    use super::PreconfirmationClientConfig;

    /// Default config exposes a positive catch-up batch size.
    #[test]
    fn default_config_has_catchup_batch() {
        // Build a default config for the assertion.
        let cfg = PreconfirmationClientConfig::default();
        assert!(cfg.catchup_batch_size > 0);
    }
}
