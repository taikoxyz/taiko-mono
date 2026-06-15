//! Configuration types for the proposer.

use std::{path::PathBuf, time::Duration};

use alloy::{
    primitives::{Address, B256},
    transports::http::reqwest::Url,
};
use base_tx_manager::{ConfigError, TxManagerConfig};
use rpc::{SubscriptionSource, TxManagerConfigParams};

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
    /// Translate the proposer-facing retry and fee-floor knobs into a tx-manager
    /// config via the shared [`rpc::base_tx_manager_config`] builder, passing the
    /// blob fee floor since proposal transactions carry blobs.
    ///
    /// # Errors
    ///
    /// Returns [`ConfigError`] when the derived tx-manager config violates upstream invariants,
    /// such as zero resubmission or confirmation windows.
    pub fn to_tx_manager_config(&self) -> Result<TxManagerConfig, ConfigError> {
        rpc::base_tx_manager_config(&TxManagerConfigParams {
            min_tip_cap_gwei: self.min_tip_cap_gwei,
            min_base_fee_gwei: self.min_base_fee_gwei,
            min_blob_fee_gwei: Some(self.min_blob_fee_gwei),
            retry_interval: self.retry_interval,
            confirmation_timeout: self.confirmation_timeout,
            receipt_query_interval: self.receipt_query_interval,
        })
    }
}
