use alloy_primitives::{Address, U256};
use alloy_provider::Provider;
use bindings::{
    inbox::Inbox::InboxInstance, lookahead_store::LookaheadStore::LookaheadStoreInstance,
};

use super::{LookaheadData, LookaheadError, ProposerContext, Result};

/// Thin wrapper around on-chain lookahead contracts resolved via the Inbox configuration.
#[derive(Clone)]
pub struct LookaheadClient<P: Provider + Clone> {
    inbox: InboxInstance<P>,
    lookahead_store: LookaheadStoreInstance<P>,
}

impl<P: Provider + Clone> LookaheadClient<P> {
    /// Build a new client from an Inbox contract address and provider.
    /// The LookaheadStore address is discovered via `Inbox.getConfig().proposerChecker`.
    pub async fn new(inbox_address: Address, provider: P) -> Result<Self> {
        let inbox = InboxInstance::new(inbox_address, provider.clone());
        let config = inbox.getConfig().call().await.map_err(LookaheadError::InboxConfig)?;

        let lookahead_store = LookaheadStoreInstance::new(config.proposerChecker, provider);

        Ok(Self { inbox, lookahead_store })
    }

    /// Return the Inbox contract address used by this client.
    pub fn inbox_address(&self) -> Address {
        *self.inbox.address()
    }

    /// Return the LookaheadStore contract address resolved from the Inbox config.
    pub fn lookahead_store_address(&self) -> Address {
        *self.lookahead_store.address()
    }

    /// Call `LookaheadStore.getProposerContext` with the provided payload.
    pub async fn get_proposer_context(
        &self,
        data: LookaheadData,
        epoch_timestamp: U256,
    ) -> Result<ProposerContext> {
        self.lookahead_store
            .getProposerContext(data, epoch_timestamp)
            .call()
            .await
            .map_err(LookaheadError::Lookahead)
    }

    /// Expose the underlying LookaheadStore instance for internal consumers.
    pub(crate) fn lookahead_store(&self) -> &LookaheadStoreInstance<P> {
        &self.lookahead_store
    }
}
