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
use event_scanner::{EventScanner, EventScannerBuilder, SyncFromBlock};
use robust_provider::RobustProviderBuilder;
use thiserror::Error;

/// Poll HTTP L1 providers frequently enough to keep the local harness responsive.
const HTTP_SUBSCRIPTION_POLL_INTERVAL: Duration = Duration::from_secs(1);

/// Total per-request timeout for HTTP providers, mirroring the rpc crate's
/// `DEFAULT_HTTP_TIMEOUT`. Without it a black-holed endpoint stalls every caller forever.
const HTTP_REQUEST_TIMEOUT: Duration = Duration::from_secs(12);

/// Total per-request timeout for the event scanner's HTTP provider.
///
/// Deliberately above `HTTP_REQUEST_TIMEOUT`: geth blocks `eth_getLogs` while rendering the
/// filtermaps log-index head (13-21s observed on Hoodi archive nodes), and a poll canceled by
/// a tight client timeout kills the scanner generation — closing preconfirmation ingress for
/// the whole reconnect-and-replay window. Waiting out a slow-but-alive answer is strictly
/// cheaper than that.
const SCANNER_HTTP_REQUEST_TIMEOUT: Duration = Duration::from_secs(30);

/// Connect timeout for the event scanner's HTTP provider, keeping dead-endpoint detection
/// fast despite the long total request timeout.
const SCANNER_HTTP_CONNECT_TIMEOUT: Duration = Duration::from_secs(2);

/// Build a reqwest HTTP client with a bounded total request timeout.
fn http_client_with_timeout() -> alloy::transports::http::reqwest::Client {
    alloy::transports::http::reqwest::Client::builder()
        .timeout(HTTP_REQUEST_TIMEOUT)
        .build()
        .expect("http client")
}

/// Build the event scanner's reqwest HTTP client: tolerant of slow responses, quick to fail
/// on unreachable endpoints.
fn scanner_http_client_with_timeout() -> alloy::transports::http::reqwest::Client {
    alloy::transports::http::reqwest::Client::builder()
        .timeout(SCANNER_HTTP_REQUEST_TIMEOUT)
        .connect_timeout(SCANNER_HTTP_CONNECT_TIMEOUT)
        .build()
        .expect("http client")
}

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
    /// Invalid HTTP source URL.
    #[error("invalid http url: {0}")]
    InvalidHttpUrl(String),
    /// Invalid WebSocket source URL.
    #[error("invalid websocket url: {0}")]
    InvalidWebsocketUrl(String),
    /// Unsupported source URL scheme.
    #[error("unsupported subscription source scheme: {0}")]
    UnsupportedScheme(String),
    /// Missing source URL scheme.
    #[error("subscription source must use http://, https://, ws://, or wss://")]
    MissingScheme,
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
                SubscriptionSource::Http(url) => {
                    builder.connect_reqwest(http_client_with_timeout(), url.clone())
                }
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
                SubscriptionSource::Http(url) => {
                    builder.connect_reqwest(http_client_with_timeout(), url.clone())
                }
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

    /// Convert the source into a `RobustProvider` suitable for `event-scanner`.
    async fn to_scanner_provider(
        &self,
    ) -> Result<robust_provider::RobustProvider<Ethereum>, SubscriptionSourceError> {
        // HTTP scanning gets its own client with a longer total timeout (see
        // `SCANNER_HTTP_REQUEST_TIMEOUT`); WebSocket sources reuse the shared path.
        let provider = match self {
            SubscriptionSource::Http(url) => ProviderBuilder::new()
                .connect_reqwest(scanner_http_client_with_timeout(), url.clone()),
            SubscriptionSource::Ws(_) => self.to_provider().await?,
        };
        let builder = RobustProviderBuilder::new(provider);
        let builder = if self.is_http() {
            builder.allow_http_subscriptions(true).poll_interval(HTTP_SUBSCRIPTION_POLL_INTERVAL)
        } else {
            builder
        };

        builder.build().await.map_err(|e| SubscriptionSourceError::Connection(e.to_string()))
    }
}

impl TryFrom<&str> for SubscriptionSource {
    type Error = SubscriptionSourceError;

    /// Parse an HTTP URL (`http://` / `https://`) or a WebSocket URL (`ws://` / `wss://`).
    fn try_from(value: &str) -> Result<Self, Self::Error> {
        if let Some((scheme, _)) = value.split_once("://") {
            return match scheme {
                "http" | "https" => value
                    .parse::<Url>()
                    .map(SubscriptionSource::Http)
                    .map_err(|e| SubscriptionSourceError::InvalidHttpUrl(e.to_string())),
                "ws" | "wss" => value
                    .parse::<Url>()
                    .map(SubscriptionSource::Ws)
                    .map_err(|e| SubscriptionSourceError::InvalidWebsocketUrl(e.to_string())),
                _ => Err(SubscriptionSourceError::UnsupportedScheme(scheme.to_string())),
            };
        }

        Err(SubscriptionSourceError::MissingScheme)
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
        assert!(matches!(result, Err(SubscriptionSourceError::InvalidHttpUrl(_))));
    }

    #[test]
    fn subscription_source_try_from_invalid_ws() {
        let result = SubscriptionSource::try_from("ws://[invalid");
        assert!(matches!(result, Err(SubscriptionSourceError::InvalidWebsocketUrl(_))));
    }

    #[test]
    fn subscription_source_try_from_unsupported_scheme() {
        let result = SubscriptionSource::try_from("ftp://localhost:8545");
        assert!(matches!(
            result,
            Err(SubscriptionSourceError::UnsupportedScheme(scheme)) if scheme == "ftp"
        ));
    }

    #[test]
    fn subscription_source_try_from_missing_scheme() {
        let result = SubscriptionSource::try_from("/path/to/socket");
        assert!(matches!(result, Err(SubscriptionSourceError::MissingScheme)));
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

        // 15s of headroom for loaded CI hosts: the test spawns a real anvil with a 1s block
        // time. A single `next()` await also avoids busy-spinning if the stream terminates.
        let message = timeout(Duration::from_secs(15), stream.next())
            .await
            .expect("timed out waiting for scanner live notification")
            .expect("scanner stream ended before emitting a notification");

        assert!(matches!(message, Ok(Message::Notification(Notification::SwitchingToLive))));
    }
}
