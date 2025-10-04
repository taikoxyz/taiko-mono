//! RPC client utilities for connecting to Taiko nodes.

use std::path::PathBuf;

use alloy::{
    network::EthereumWallet, signers::local::PrivateKeySigner, transports::http::reqwest::Url,
};
use alloy_primitives::B256;
use alloy_provider::{
    IpcConnect, ProviderBuilder, RootProvider, WsConnect,
    fillers::{FillProvider, JoinFill, WalletFiller},
    utils::JoinedRecommendedFillers,
};

pub mod auth;
pub mod client;
pub mod error;

pub use auth::TxPoolContentParams;
pub use error::{Result, RpcClientError};

/// Type alias for a provider with recommended fillers and a wallet.
pub type JoinedRecommendedFillersWithWallet =
    JoinFill<JoinedRecommendedFillers, WalletFiller<EthereumWallet>>;

/// The source from which to subscribe to events.
#[derive(Debug, Clone)]
pub enum SubscriptionSource {
    /// Consume Ethereum logs from a local IPC endpoint.
    Ipc(PathBuf),
    /// Consume Ethereum logs from a remote WebSocket endpoint.
    Ws(Url),
}

impl SubscriptionSource {
    /// Return true if the source is an IPC endpoint.
    pub fn is_ipc(&self) -> bool {
        matches!(self, SubscriptionSource::Ipc(_))
    }

    /// Return true if the source is a WebSocket endpoint.
    pub fn is_ws(&self) -> bool {
        matches!(self, SubscriptionSource::Ws(_))
    }

    /// Convert the `SubscriptionSource` into a `FillProvider` built via `ProviderBuilder::new()`.
    pub async fn to_provider(
        &self,
    ) -> Result<FillProvider<JoinedRecommendedFillers, RootProvider>> {
        let provider = match self {
            SubscriptionSource::Ipc(path) => ProviderBuilder::new()
                .connect_ipc(IpcConnect::new(path.clone()))
                .await
                .map_err(|e| RpcClientError::Connection(e.to_string()))?,
            SubscriptionSource::Ws(url) => ProviderBuilder::new()
                .connect_ws(WsConnect::new(url.to_string()))
                .await
                .map_err(|e| RpcClientError::Connection(e.to_string()))?,
        };

        Ok(provider)
    }

    /// Convert the `SubscriptionSource` into a `FillProvider` with wallet built via
    /// `ProviderBuilder::new()`.
    pub async fn to_provider_with_wallet(
        &self,
        sender_private_key: B256,
    ) -> Result<FillProvider<JoinedRecommendedFillersWithWallet, RootProvider>> {
        let signer = PrivateKeySigner::from_bytes(&sender_private_key)
            .map_err(|e| RpcClientError::Other(e.into()))?;
        let wallet = EthereumWallet::new(signer);

        let provider = match self {
            SubscriptionSource::Ipc(path) => ProviderBuilder::new()
                .wallet(wallet)
                .connect_ipc(IpcConnect::new(path.clone()))
                .await
                .map_err(|e| RpcClientError::Connection(e.to_string()))?,
            SubscriptionSource::Ws(url) => ProviderBuilder::new()
                .wallet(wallet)
                .connect_ws(WsConnect::new(url.to_string()))
                .await
                .map_err(|e| RpcClientError::Connection(e.to_string()))?,
        };

        Ok(provider)
    }
}

/// Try to convert a string to a `SubscriptionSource`.
///
/// Returns an error if the WebSocket URL is invalid.
impl TryFrom<&str> for SubscriptionSource {
    type Error = String;

    fn try_from(s: &str) -> std::result::Result<Self, Self::Error> {
        if s.starts_with("ws://") || s.starts_with("wss://") {
            s.parse::<Url>()
                .map(SubscriptionSource::Ws)
                .map_err(|e| format!("invalid websocket url: {}", e))
        } else {
            Ok(SubscriptionSource::Ipc(PathBuf::from(s)))
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_subscription_source_try_from_ipc() {
        let source = SubscriptionSource::try_from("/path/to/ipc").unwrap();
        assert!(source.is_ipc());
        assert!(!source.is_ws());
    }

    #[test]
    fn test_subscription_source_try_from_ws() {
        let source = SubscriptionSource::try_from("ws://localhost:8546").unwrap();
        assert!(source.is_ws());
        assert!(!source.is_ipc());

        let source = SubscriptionSource::try_from("wss://localhost:8546").unwrap();
        assert!(source.is_ws());
        assert!(!source.is_ipc());
    }

    #[test]
    fn test_subscription_source_try_from_invalid_ws() {
        let result = SubscriptionSource::try_from("ws://[invalid");
        assert!(result.is_err());
        assert!(result.unwrap_err().contains("invalid websocket url"));
    }
}
