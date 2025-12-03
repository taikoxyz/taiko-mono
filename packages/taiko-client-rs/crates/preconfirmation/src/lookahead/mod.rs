use alloy_primitives::{Address, U256};
use alloy_provider::Provider;
use bindings::{
    inbox::Inbox::InboxInstance,
    lookahead_store::{ILookaheadStore, LookaheadStore::LookaheadStoreInstance},
};
use thiserror::Error;

/// Type aliases for LookaheadStore data structures.
pub type LookaheadData = ILookaheadStore::LookaheadData;
pub type LookaheadSlot = ILookaheadStore::LookaheadSlot;
pub type ProposerContext = ILookaheadStore::ProposerContext;

/// Result alias for lookahead operations.
pub type Result<T> = std::result::Result<T, LookaheadError>;

/// Client for querying the LookaheadStore discovered via the Inbox configuration.
#[derive(Clone)]
pub struct LookaheadClient<P: Provider + Clone> {
    inbox: InboxInstance<P>,
    lookahead_store: LookaheadStoreInstance<P>,
}

/// Errors emitted by the lookahead client.
#[derive(Debug, Error)]
pub enum LookaheadError {
    /// Failed to fetch or decode Inbox configuration.
    #[error("failed to fetch inbox config: {0}")]
    InboxConfig(alloy_contract::Error),
    /// Failure when querying the LookaheadStore.
    #[error("failed to call lookahead store: {0}")]
    Lookahead(alloy_contract::Error),
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
}
