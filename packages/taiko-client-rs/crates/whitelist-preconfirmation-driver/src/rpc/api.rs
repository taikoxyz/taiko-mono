//! Whitelist preconfirmation RPC API trait definition.

use async_trait::async_trait;

use super::types::{
    BuildPreconfBlockRequest, BuildPreconfBlockResponse, HealthResponse, WhitelistStatus,
};
use crate::Result;

/// Trait defining the whitelist preconfirmation driver's JSON-RPC API.
///
/// Implementations must be `Send + Sync` as they will be shared across
/// multiple async tasks handling concurrent RPC requests.
#[async_trait]
pub trait WhitelistRpcApi: Send + Sync {
    /// Build, sign, and publish a preconfirmation block to the P2P network.
    async fn build_preconf_block(
        &self,
        request: BuildPreconfBlockRequest,
    ) -> Result<BuildPreconfBlockResponse>;

    /// Get the current status of the whitelist preconfirmation driver.
    async fn get_status(&self) -> Result<WhitelistStatus>;

    /// Health check endpoint.
    async fn healthz(&self) -> Result<HealthResponse>;
}
