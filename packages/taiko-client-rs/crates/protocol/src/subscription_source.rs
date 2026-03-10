use std::time::Duration;

use alloy::{
    eips::BlockNumberOrTag,
    network::{Ethereum, EthereumWallet},
    signers::local::PrivateKeySigner,
    transports::http::reqwest::Url,
};
use alloy_primitives::B256;
use alloy_provider::{
    ProviderBuilder, RootProvider, WsConnect,
    fillers::{FillProvider, JoinFill, WalletFiller},
    utils::JoinedRecommendedFillers,
};
use event_scanner::{EventScanner, EventScannerBuilder, SyncFromBlock, SyncFromLatestEvents};
use robust_provider::RobustProviderBuilder;
use thiserror::Error;

/// Poll HTTP L1 providers frequently enough to keep the local harness responsive.
const HTTP_SUBSCRIPTION_POLL_INTERVAL: Duration = Duration::from_secs(1);

/// Convenience alias for the recommended filler stack with a wallet.
pub type JoinedRecommendedFillersWithWallet =
    JoinFill<JoinedRecommendedFillers, WalletFiller<EthereumWallet>>;

/// Source describing how to connect to an L1 provider for event following and RPC calls.
#[derive(Debug, Clone)]
pub enum SubscriptionSource {
    /// Consume Ethereum logs from a remote HTTP endpoint.
    Http(Url),
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
    /// Return true if the source is an HTTP endpoint.
    pub fn is_http(&self) -> bool {
        matches!(self, SubscriptionSource::Http(_))
    }

    /// Return true if the source is a WebSocket endpoint.
    pub fn is_ws(&self) -> bool {
        matches!(self, SubscriptionSource::Ws(_))
    }

    /// Borrow the underlying endpoint URL.
    pub fn url(&self) -> &Url {
        match self {
            SubscriptionSource::Http(url) | SubscriptionSource::Ws(url) => url,
        }
    }

    /// Convert the source into a `FillProvider` built via `ProviderBuilder::new()`.
    pub async fn to_provider(
        &self,
    ) -> Result<FillProvider<JoinedRecommendedFillers, RootProvider>, SubscriptionSourceError> {
        let builder = ProviderBuilder::new();
        let provider =
            match self {
                SubscriptionSource::Http(url) => builder.connect_http(url.clone()),
                SubscriptionSource::Ws(url) => builder
                    .connect_ws(WsConnect::new(url.as_str()))
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
        let provider =
            match self {
                SubscriptionSource::Http(url) => builder.connect_http(url.clone()),
                SubscriptionSource::Ws(url) => builder
                    .connect_ws(WsConnect::new(url.as_str()))
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
            .connect(self.to_scanner_provider().await?)
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
            .connect(self.to_scanner_provider().await?)
            .await
            .map_err(|e| SubscriptionSourceError::Connection(e.to_string()))
    }

    /// Convert the source into a `RobustProvider` suitable for `event-scanner`.
    async fn to_scanner_provider(
        &self,
    ) -> Result<robust_provider::RobustProvider<Ethereum>, SubscriptionSourceError> {
        let provider = self.to_provider().await?;
        let builder = RobustProviderBuilder::new(provider);
        let builder = if self.is_http() {
            builder
                .allow_http_subscriptions(true)
                .poll_interval(HTTP_SUBSCRIPTION_POLL_INTERVAL)
        } else {
            builder
        };

        builder.build().await.map_err(|e| SubscriptionSourceError::Connection(e.to_string()))
    }
}

/// Try to convert a string to a [`SubscriptionSource`].
///
/// Returns an error string if the URL is invalid or if an unsupported URL scheme is used.
impl TryFrom<&str> for SubscriptionSource {
    type Error = String;

    /// Parse an HTTP URL (`http://` / `https://`) or a WebSocket URL (`ws://` / `wss://`).
    fn try_from(value: &str) -> Result<Self, Self::Error> {
        if let Some((scheme, _)) = value.split_once("://") {
            return match scheme {
                "http" | "https" => value
                    .parse::<Url>()
                    .map(SubscriptionSource::Http)
                    .map_err(|e| format!("invalid http url: {e}")),
                "ws" | "wss" => value
                    .parse::<Url>()
                    .map(SubscriptionSource::Ws)
                    .map_err(|e| format!("invalid websocket url: {e}")),
                _ => Err(format!("unsupported subscription source scheme: {scheme}")),
            };
        }

        Err("subscription source must use http://, https://, ws://, or wss://".to_string())
    }
}

#[cfg(test)]
mod tests {
    use alloy::{eips::BlockNumberOrTag, node_bindings::Anvil};
    use event_scanner::{EventFilter, Message, Notification};
    use tokio::time::timeout;
    use tokio_stream::StreamExt;

    use super::*;

    #[test]
    fn subscription_source_try_from_http() {
        let source = SubscriptionSource::try_from("http://localhost:8545").unwrap();
        assert!(source.is_http());
        assert!(!source.is_ws());
    }

    #[test]
    fn subscription_source_try_from_ws() {
        let source = SubscriptionSource::try_from("ws://localhost:8546").unwrap();
        assert!(source.is_ws());
        assert!(!source.is_http());
    }

    #[test]
    fn subscription_source_try_from_invalid_http() {
        let result = SubscriptionSource::try_from("http://[invalid");
        assert!(result.is_err());
        assert!(result.unwrap_err().contains("invalid http url"));
    }

    #[test]
    fn subscription_source_try_from_invalid_ws() {
        let result = SubscriptionSource::try_from("ws://[invalid");
        assert!(result.is_err());
        assert!(result.unwrap_err().contains("invalid websocket url"));
    }

    #[test]
    fn subscription_source_try_from_unsupported_scheme() {
        let result = SubscriptionSource::try_from("ftp://localhost:8545");
        assert!(result.is_err());
        assert!(result.unwrap_err().contains("unsupported subscription source scheme: ftp"));
    }

    #[test]
    fn subscription_source_try_from_missing_scheme() {
        let result = SubscriptionSource::try_from("/path/to/socket");
        assert!(result.is_err());
        assert!(
            result
                .unwrap_err()
                .contains("subscription source must use http://, https://, ws://, or wss://")
        );
    }

    #[tokio::test]
    async fn http_event_scanner_switches_to_live_without_pubsub() {
        let anvil = Anvil::new().block_time(1).try_spawn().expect("anvil should start");
        let source = SubscriptionSource::Http(anvil.endpoint_url());
        let mut scanner = source
            .to_event_scanner_from_tag(BlockNumberOrTag::Earliest)
            .await
            .expect("http scanner should initialize");
        let subscription = scanner.subscribe(EventFilter::new());
        let proof = scanner.start().await.expect("scanner should start");
        let mut stream = subscription.stream(&proof);

        let message = timeout(Duration::from_secs(5), async {
            loop {
                if let Some(message) = stream.next().await {
                    return message;
                }
            }
        })
        .await
        .expect("timed out waiting for scanner live notification");

        assert!(matches!(
            message,
            Ok(Message::Notification(Notification::SwitchingToLive))
        ));
    }
}
