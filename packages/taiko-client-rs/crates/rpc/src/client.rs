use alloy_primitives::Address;
use alloy_provider::RootProvider;
use anyhow::Result;
use bindings::{
    codec_optimized::CodecOptimized::CodecOptimizedInstance, i_inbox::IInbox::IInboxInstance,
};

use crate::SubscriptionSource;

/// Instances of Shasta protocol contracts.
#[derive(Clone, Debug)]
pub struct ShastaProtocolInstance {
    pub inbox: IInboxInstance<RootProvider>,
    pub codec: CodecOptimizedInstance<RootProvider>,
}

/// A client for interacting with L1 and L2 providers and Shasta protocol contracts.
#[derive(Clone, Debug)]
pub struct Client {
    pub l1_provider: RootProvider,
    pub l2_provider: RootProvider,
    pub shasta: ShastaProtocolInstance,
}

/// Configuration for the `Client`.
#[derive(Clone, Debug)]
pub struct ClientConfig {
    pub l1_provider: SubscriptionSource,
    pub l2_provider: SubscriptionSource,
    pub inbox_address: Address,
}

impl Client {
    /// Create a new `Client` from the given configuration.
    pub async fn new(config: ClientConfig) -> Result<Self> {
        let l1_provider = config.l1_provider.to_provider().await?;
        let l2_provider = config.l2_provider.to_provider().await?;

        let inbox = IInboxInstance::new(config.inbox_address, l1_provider.clone());
        let codec =
            CodecOptimizedInstance::new(inbox.getConfig().call().await?.codec, l1_provider.clone());

        let shasta = ShastaProtocolInstance { inbox, codec };

        Ok(Self { l1_provider, l2_provider, shasta })
    }
}
