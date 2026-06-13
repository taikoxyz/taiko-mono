//! Shared constructor for the base transaction manager.
//!
//! Both the prover and proposer crates build a [`SimpleTxManager`] from an L1
//! [`RootProvider`] and a signing key in the same way: resolve the chain id
//! under a network timeout, classify any RPC failure, derive an
//! [`EthereumWallet`] from the private key, and hand everything to
//! [`SimpleTxManager::new`]. This helper hoists that common body so the
//! per-crate adapters reduce to a thin config-conversion wrapper.

use std::sync::Arc;

use alloy::{network::EthereumWallet, providers::Provider, signers::local::PrivateKeySigner};
use alloy_primitives::B256;
use alloy_provider::RootProvider;
use base_tx_manager::{
    RpcErrorClassifier, SimpleTxManager, TxManagerConfig, TxManagerError, TxMetrics,
};
use tokio::time::timeout;

/// Build a [`SimpleTxManager`] from an L1 root provider and a signing key.
///
/// Resolves the chain id from `provider` under `config.network_timeout`,
/// builds an [`EthereumWallet`] from `private_key`, and constructs the
/// transaction manager with the supplied `metrics` backend.
///
/// # Errors
///
/// Returns [`TxManagerError::Rpc`] if the chain-id query times out, a
/// classified [`TxManagerError`] (via [`RpcErrorClassifier`]) if the query
/// fails, [`TxManagerError::Sign`] if the private key cannot be turned into a
/// signer, and propagates any [`TxManagerError`] raised by
/// [`SimpleTxManager::new`].
pub async fn build_tx_manager(
    provider: RootProvider,
    private_key: B256,
    config: TxManagerConfig,
    metrics: Arc<dyn TxMetrics>,
) -> Result<SimpleTxManager, TxManagerError> {
    let chain_id = timeout(config.network_timeout, provider.get_chain_id())
        .await
        .map_err(|_| TxManagerError::Rpc("get_chain_id timed out".into()))?
        .map_err(|err| RpcErrorClassifier::classify_rpc_error(&err.to_string()))?;
    let signer = PrivateKeySigner::from_bytes(&private_key).map_err(|err| {
        TxManagerError::Sign(format!("failed to build signer from configured private key: {err}"))
    })?;
    let wallet = EthereumWallet::from(signer);
    SimpleTxManager::new(provider, wallet, config, chain_id, metrics).await
}

#[cfg(test)]
mod tests {
    use std::{sync::Arc, time::Duration};

    use alloy::{providers::ProviderBuilder, rpc::client::RpcClient, transports::mock::Asserter};
    use alloy_primitives::B256;
    use base_tx_manager::{BaseTxMetrics, TxManagerConfig};

    use super::build_tx_manager;

    #[tokio::test]
    async fn build_tx_manager_constructs_from_mocked_provider() {
        let asserter = Asserter::new();
        // One chain-id response for this helper, one for SimpleTxManager::new's
        // own cross-validation query.
        asserter.push_success(&1u64);
        asserter.push_success(&1u64);
        let provider = ProviderBuilder::default().connect_client(RpcClient::mocked(asserter));

        let config = TxManagerConfig {
            network_timeout: Duration::from_secs(5),
            ..TxManagerConfig::default()
        };

        build_tx_manager(
            provider,
            B256::repeat_byte(0x33),
            config,
            Arc::new(BaseTxMetrics::new("test")),
        )
        .await
        .expect("mocked provider should build a tx manager");
    }
}
