//! Configuration types for the proposer.

use std::{path::PathBuf, time::Duration};

use alloy::{
    primitives::{Address, B256, utils::Unit},
    transports::http::reqwest::Url,
};
use base_tx_manager::{ConfigError, TxManagerConfig};
use rpc::SubscriptionSource;

/// Configuration for the proposer.
#[derive(Debug, Clone)]
pub struct ProposerConfigs {
    /// L1 provider connection source (HTTP or WebSocket) for monitoring and submitting
    /// transactions.
    pub l1_provider_source: SubscriptionSource,
    /// L2 provider URL for fetching execution data.
    pub l2_provider_url: Url,
    /// L2 authenticated provider URL for accessing the execution engine's privileged APIs.
    pub l2_auth_provider_url: Url,
    /// Path to the JWT secret file for authenticating with the L2 execution engine.
    pub jwt_secret: PathBuf,
    /// Address of the Shasta inbox contract on L1 where proposals are submitted.
    pub inbox_address: Address,
    /// Address to receive L2 block transaction fees in proposed blocks.
    pub l2_suggested_fee_recipient: Address,
    /// Time interval between consecutive proposal attempts.
    pub propose_interval: Duration,
    /// Private key of the L1 account that signs and sends proposal transactions.
    pub l1_proposer_private_key: B256,
    /// Optional gas limit for proposal transactions. If not set, uses provider's estimation.
    pub gas_limit: Option<u64>,
    /// Whether to use Engine API mode for payload building.
    /// When true, uses FCU + get_payload instead of tx_pool_content_with_min_tip.
    pub use_engine_mode: bool,
    /// Interval between tx-manager resubmissions when a proposal transaction remains
    /// unconfirmed.
    pub retry_interval: Duration,
    /// Maximum time to keep retrying and polling before giving up on a proposal transaction.
    pub confirmation_timeout: Duration,
    /// Optional override for tx-manager receipt polling.
    ///
    /// This exists to keep integration tests responsive without changing proposer runtime defaults
    /// inherited from tx-manager.
    pub receipt_query_interval: Option<Duration>,
    /// Minimum priority fee floor, expressed in gwei, applied to proposal transactions.
    pub min_tip_cap_gwei: u64,
    /// Minimum EIP-1559 base fee floor, expressed in gwei, applied to proposal transactions.
    pub min_base_fee_gwei: u64,
    /// Minimum blob base fee floor, expressed in gwei, applied to blob proposal transactions.
    pub min_blob_fee_gwei: u64,
}

impl ProposerConfigs {
    /// Translate the proposer-facing retry and fee-floor knobs into a tx-manager config.
    ///
    /// Internal defaults stay narrow and explicit:
    /// - `num_confirmations` is pinned to `1` so proposer success still means the transaction made
    ///   it on-chain once, rather than waiting for deep confirmation depth.
    /// - `tx_not_in_mempool_timeout` matches `confirmation_timeout` so the proposer has a single
    ///   bounded retry window even when a submission never propagates into the mempool.
    /// - `receipt_query_interval` stays on `TxManagerConfig::default()` unless callers explicitly
    ///   set [`Self::receipt_query_interval`].
    /// - All other runtime controls stay on `TxManagerConfig::default()` so proposer CLI does not
    ///   expose the broader tx-manager tuning surface.
    ///
    /// # Errors
    ///
    /// Returns [`ConfigError`] when the derived tx-manager config violates upstream invariants,
    /// such as zero resubmission or confirmation windows.
    pub fn to_tx_manager_config(&self) -> Result<TxManagerConfig, ConfigError> {
        let tx_manager_config = TxManagerConfig {
            num_confirmations: 1,
            min_tip_cap: gwei_to_wei(self.min_tip_cap_gwei),
            min_basefee: gwei_to_wei(self.min_base_fee_gwei),
            resubmission_timeout: self.retry_interval,
            receipt_query_interval: self
                .receipt_query_interval
                .unwrap_or_else(|| TxManagerConfig::default().receipt_query_interval),
            tx_not_in_mempool_timeout: self.confirmation_timeout,
            confirmation_timeout: self.confirmation_timeout,
            min_blob_fee: gwei_to_wei(self.min_blob_fee_gwei),
            ..TxManagerConfig::default()
        };

        tx_manager_config.validate()?;

        Ok(tx_manager_config)
    }
}

/// Convert an integer gwei amount into wei for tx-manager configuration.
#[must_use]
fn gwei_to_wei(gwei: u64) -> u128 {
    u128::from(gwei) * Unit::GWEI.wei().to::<u128>()
}
