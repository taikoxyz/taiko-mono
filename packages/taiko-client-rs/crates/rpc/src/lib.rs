use std::path::PathBuf;

use alloy::transports::http::reqwest::Url;
use alloy_provider::{IpcConnect, ProviderBuilder, RootProvider, WsConnect};
use anyhow::Result;

pub mod auth;
pub mod client;

/// The source from which to subscribe to events.
#[derive(Debug, Clone)]
pub enum SubscriptionSource {
    /// Consume Ethereum logs from a local IPC endpoint.
    Ipc(PathBuf),
    /// Consume Ethereum logs from a remote WebSocket endpoint.
    Ws(Url),
}

/// Convert a string to a `SubscriptionSource`.
impl From<&str> for SubscriptionSource {
    fn from(s: &str) -> Self {
        if s.starts_with("ws://") || s.starts_with("wss://") {
            SubscriptionSource::Ws(s.parse().expect("invalid websocket url"))
        } else {
            SubscriptionSource::Ipc(PathBuf::from(s))
        }
    }
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

    /// Convert the `SubscriptionSource` into a `RootProvider`.
    pub async fn to_provider(&self) -> Result<RootProvider> {
        let provider = match self {
            SubscriptionSource::Ipc(path) => {
                ProviderBuilder::default().connect_ipc(IpcConnect::new(path.clone())).await?
            }
            SubscriptionSource::Ws(url) => {
                ProviderBuilder::default().connect_ws(WsConnect::new(url.to_string())).await?
            }
        };

        Ok(provider)
    }
}
