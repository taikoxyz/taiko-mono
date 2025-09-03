use std::time::Duration;

use alloy_primitives::Address;
use rpc::RpcClientConfig;

/// Configuration for the `Proposer`.
#[derive(Debug, Clone)]
pub struct ProposerConfig {
    pub rpc_client_config: RpcClientConfig,
    pub l2_suggested_fee_recipient: Address,
    pub proposal_interval: Duration,
    pub min_tip: u64,
}
