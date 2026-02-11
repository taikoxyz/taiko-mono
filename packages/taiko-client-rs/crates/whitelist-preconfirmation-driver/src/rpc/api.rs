//! Whitelist preconfirmation API trait definition.

use async_trait::async_trait;
use tokio::sync::broadcast;

use super::types::{
    BuildPreconfBlockRequest, BuildPreconfBlockResponse, EndOfSequencingNotification,
    WhitelistStatus,
};
use crate::Result;

/// Trait defining the whitelist preconfirmation driver's REST/WS API.
///
/// Implementations must be `Send + Sync` as they will be shared across
/// multiple async tasks handling concurrent API requests.
#[async_trait]
pub trait WhitelistRestApi: Send + Sync {
    /// Build, sign, and publish a preconfirmation block to the P2P network.
    async fn build_preconf_block(
        &self,
        request: BuildPreconfBlockRequest,
    ) -> Result<BuildPreconfBlockResponse>;

    /// Get the current status of the whitelist preconfirmation driver.
    async fn get_status(&self) -> Result<WhitelistStatus>;

    /// Subscribe to end-of-sequencing notifications for the REST `/ws` endpoint.
    fn subscribe_end_of_sequencing(&self) -> broadcast::Receiver<EndOfSequencingNotification>;
}
