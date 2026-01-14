//! Configuration types for the proposer.

use std::{path::PathBuf, time::Duration};

use alloy::{
    primitives::{Address, B256},
    transports::http::reqwest::Url,
};
use rpc::SubscriptionSource;

/// Configuration for the proposer.
#[derive(Debug, Clone)]
pub struct ProposerConfigs {
    /// L1 provider connection source (HTTP/WS/IPC) for monitoring and submitting transactions.
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
}
