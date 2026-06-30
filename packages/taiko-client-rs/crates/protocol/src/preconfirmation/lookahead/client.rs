use alloy_primitives::Address;
use alloy_provider::Provider;
use bindings::{
    inbox::Inbox::InboxInstance, lookahead_store::LookaheadStore::LookaheadStoreInstance,
};

use super::{LookaheadError, Result};
use tracing::debug;

/// Thin wrapper around on-chain lookahead contracts resolved via the Inbox configuration.
#[derive(Clone)]
pub struct LookaheadClient<P: Provider + Clone> {
    /// LookaheadStore contract instance used for proposer-context queries.
    lookahead_store: LookaheadStoreInstance<P>,
}

impl<P: Provider + Clone> LookaheadClient<P> {
    /// Build a new client from an Inbox contract address and provider.
    /// The LookaheadStore address is discovered via `Inbox.getConfig().proposerChecker`.
    pub async fn new(inbox_address: Address, provider: P) -> Result<Self> {
        let inbox = InboxInstance::new(inbox_address, provider.clone());
        let config = inbox.getConfig().call().await.map_err(LookaheadError::InboxConfig)?;
        debug!("Inbox config: {:?}", config);

        let lookahead_store = LookaheadStoreInstance::new(config.proposerChecker, provider);

        Ok(Self { lookahead_store })
    }

    /// Return the LookaheadStore contract address resolved from the Inbox config.
    pub fn lookahead_store_address(&self) -> Address {
        *self.lookahead_store.address()
    }

    /// Expose the underlying LookaheadStore instance for internal consumers.
    pub(crate) fn lookahead_store(&self) -> &LookaheadStoreInstance<P> {
        &self.lookahead_store
    }
}
