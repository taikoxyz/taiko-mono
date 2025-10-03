use std::{path::PathBuf, time::Duration};

use alloy::{
    primitives::{Address, B256},
    transports::http::reqwest::Url,
};
use rpc::SubscriptionSource;

/// Configuration for the proposer.
#[derive(Debug, Clone)]
pub struct ProposerConfigs {
    pub l1_provider_source: SubscriptionSource,
    pub l2_provider_source: SubscriptionSource,
    pub l2_auth_provider_url: Url,
    pub jwt_secret: PathBuf,
    pub inbox_address: Address,
    pub l2_suggested_fee_recipient: Address,
    pub propose_interval: Duration,
    pub l1_proposer_private_key: B256,
}
