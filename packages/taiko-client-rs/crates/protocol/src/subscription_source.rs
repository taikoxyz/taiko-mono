use std::path::PathBuf;

use alloy::{
    eips::BlockNumberOrTag,
    network::{Ethereum, EthereumWallet},
    signers::local::PrivateKeySigner,
    transports::http::reqwest::Url,
};
use alloy_primitives::B256;
use alloy_provider::{
    IpcConnect, ProviderBuilder, RootProvider, WsConnect,
    fillers::{FillProvider, JoinFill, WalletFiller},
    utils::JoinedRecommendedFillers,
};
use event_scanner::{EventScanner, EventScannerBuilder, SyncFromBlock, SyncFromLatestEvents};
use thiserror::Error;

/// Convenience alias for the recommended filler stack with a wallet.
pub type JoinedRecommendedFillersWithWallet =
    JoinFill<JoinedRecommendedFillers, WalletFiller<EthereumWallet>>;

/// Source describing how to subscribe to an L1 provider.
#[derive(Debug, Clone)]
pub enum SubscriptionSource {
    /// Consume Ethereum logs from a local IPC endpoint.
    Ipc(PathBuf),
    /// Consume Ethereum logs from a remote WebSocket endpoint.
    Ws(Url),
}

/// Errors produced when building connections from a [`SubscriptionSource`].
#[derive(Debug, Error)]
pub enum SubscriptionSourceError {
    /// Provider connection failure.
    #[error("connection error: {0}")]
    Connection(String),
    /// Private key parsing or wallet construction failure.
    #[error("wallet error: {0}")]
    Wallet(String),
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

    /// Convert the source into a `FillProvider` built via `ProviderBuilder::new()`.
    pub async fn to_provider(
        &self,
    ) -> Result<FillProvider<JoinedRecommendedFillers, RootProvider>, SubscriptionSourceError> {
        let builder = ProviderBuilder::new();
        let provider = match self {
            SubscriptionSource::Ipc(path) => builder
                .connect_ipc(IpcConnect::new(path.clone()))
                .await
                .map_err(|e| SubscriptionSourceError::Connection(e.to_string()))?,
            SubscriptionSource::Ws(url) => builder
                .connect_ws(WsConnect::new(url.to_string()))
                .await
                .map_err(|e| SubscriptionSourceError::Connection(e.to_string()))?,
        };
        Ok(provider)
    }

    /// Convert the source into a wallet-enabled `FillProvider`.
    pub async fn to_provider_with_wallet(
        &self,
        sender_private_key: B256,
    ) -> Result<
        FillProvider<JoinedRecommendedFillersWithWallet, RootProvider>,
        SubscriptionSourceError,
    > {
        let signer = PrivateKeySigner::from_bytes(&sender_private_key)
            .map_err(|e| SubscriptionSourceError::Wallet(e.to_string()))?;
        let wallet = EthereumWallet::new(signer);

        let builder = ProviderBuilder::new().wallet(wallet);
        let provider = match self {
            SubscriptionSource::Ipc(path) => builder
                .connect_ipc(IpcConnect::new(path.clone()))
                .await
                .map_err(|e| SubscriptionSourceError::Connection(e.to_string()))?,
            SubscriptionSource::Ws(url) => builder
                .connect_ws(WsConnect::new(url.to_string()))
                .await
                .map_err(|e| SubscriptionSourceError::Connection(e.to_string()))?,
        };
        Ok(provider)
    }

    /// Convert the source into an `EventScanner` configured to synchronize from `start_tag`.
    pub async fn to_event_scanner_from_tag(
        &self,
        start_tag: BlockNumberOrTag,
    ) -> Result<EventScanner<SyncFromBlock, Ethereum>, SubscriptionSourceError> {
        EventScannerBuilder::sync()
            .from_block(start_tag)
            .connect(self.to_provider().await?)
            .await
            .map_err(|e| SubscriptionSourceError::Connection(e.to_string()))
    }

    /// Convert the source into an `EventScanner` configured to synchronize from the latest X events
    /// and then follow new events.
    pub async fn to_event_scanner_sync_from_latest_scanning(
        &self,
        count: usize,
    ) -> Result<EventScanner<SyncFromLatestEvents, Ethereum>, SubscriptionSourceError> {
        EventScannerBuilder::sync()
            .from_latest(count)
            .connect(self.to_provider().await?)
            .await
            .map_err(|e| SubscriptionSourceError::Connection(e.to_string()))
    }
}

/// Try to convert a string to a [`SubscriptionSource`].
///
/// Returns an error string if the WebSocket URL is invalid.
impl TryFrom<&str> for SubscriptionSource {
    type Error = String;

    fn try_from(value: &str) -> Result<Self, Self::Error> {
        if value.starts_with("ws://") || value.starts_with("wss://") {
            value
                .parse::<Url>()
                .map(SubscriptionSource::Ws)
                .map_err(|e| format!("invalid websocket url: {}", e))
        } else {
            Ok(SubscriptionSource::Ipc(PathBuf::from(value)))
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn subscription_source_try_from_ipc() {
        let source = SubscriptionSource::try_from("/path/to/ipc").unwrap();
        assert!(source.is_ipc());
        assert!(!source.is_ws());
    }

    #[test]
    fn subscription_source_try_from_ws() {
        let source = SubscriptionSource::try_from("ws://localhost:8546").unwrap();
        assert!(source.is_ws());
        assert!(!source.is_ipc());
    }

    #[test]
    fn subscription_source_try_from_invalid_ws() {
        let result = SubscriptionSource::try_from("ws://[invalid");
        assert!(result.is_err());
        assert!(result.unwrap_err().contains("invalid websocket url"));
    }
}
