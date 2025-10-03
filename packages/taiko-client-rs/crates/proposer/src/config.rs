use std::time::Duration;

use alloy::primitives::Address;
use rpc::SubscriptionSource;

/// Configuration for the proposer.
#[derive(Debug, Clone)]
pub struct ProposerConfigs {
    pub l1_provider: SubscriptionSource,
    pub l2_provider: SubscriptionSource,
    pub inbox_address: Address,
    pub l2_suggested_fee_recipient: Address,
    pub propose_interval: Duration,
}
