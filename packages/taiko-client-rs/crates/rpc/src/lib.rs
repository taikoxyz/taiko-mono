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
use anyhow::Result;

pub mod auth;
pub mod client;

pub use auth::TxPoolContentParams;

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
            SubscriptionSource::Ipc(path) => {
                ProviderBuilder::new().connect_ipc(IpcConnect::new(path.clone())).await?
            }
            SubscriptionSource::Ws(url) => {
                ProviderBuilder::new().connect_ws(WsConnect::new(url.to_string())).await?
            }
        };

        Ok(provider)
    }

    /// Convert the `SubscriptionSource` into a `FillProvider` with wallet built via
    /// `ProviderBuilder::new()`.
    pub async fn to_provider_with_wallet(
        &self,
        sender_private_key: B256,
    ) -> Result<FillProvider<JoinedRecommendedFillersWithWallet, RootProvider>> {
        let signer = PrivateKeySigner::from_bytes(&sender_private_key)?;
        let wallet = EthereumWallet::new(signer);

        let provider = match self {
            SubscriptionSource::Ipc(path) => {
                ProviderBuilder::new()
                    .wallet(wallet)
                    .connect_ipc(IpcConnect::new(path.clone()))
                    .await?
            }
            SubscriptionSource::Ws(url) => {
                ProviderBuilder::new()
                    .wallet(wallet)
                    .connect_ws(WsConnect::new(url.to_string()))
                    .await?
            }
        };

        Ok(provider)
    }
}
