//! Adapter building the prover's transaction manager (mirrors
//! `crates/proposer/src/tx_manager_adapter.rs`).

use std::sync::Arc;

use alloy::{network::EthereumWallet, providers::Provider, signers::local::PrivateKeySigner};
use alloy_provider::RootProvider;
use base_tx_manager::{RpcErrorClassifier, SimpleTxManager, TxManagerError};
use tokio::time::timeout;

use crate::{
    config::ProverConfigs,
    error::{ProverError, Result},
    metrics::ProverTxMetrics,
};

/// Build the prover transaction manager from prover configuration and an L1
/// root provider.
pub async fn build_tx_manager(
    cfg: &ProverConfigs,
    provider: RootProvider,
) -> Result<SimpleTxManager> {
    let tx_manager_config = cfg.to_tx_manager_config().map_err(|err| {
        ProverError::from(TxManagerError::InvalidConfig(format!(
            "invalid prover tx-manager config: {err}"
        )))
    })?;
    let chain_id = timeout(tx_manager_config.network_timeout, provider.get_chain_id())
        .await
        .map_err(|_| ProverError::from(TxManagerError::Rpc("get_chain_id timed out".into())))?
        .map_err(|err| {
            ProverError::from(RpcErrorClassifier::classify_rpc_error(&err.to_string()))
        })?;
    let signer = PrivateKeySigner::from_bytes(&cfg.l1_prover_private_key).map_err(|err| {
        ProverError::from(TxManagerError::Sign(format!(
            "failed to build prover signer from configured private key: {err}"
        )))
    })?;
    let wallet = EthereumWallet::from(signer);
    Ok(SimpleTxManager::new(
        provider,
        wallet,
        tx_manager_config,
        chain_id,
        Arc::new(ProverTxMetrics::new()),
    )
    .await?)
}

#[cfg(test)]
mod tests {
    use alloy::{providers::ProviderBuilder, rpc::client::RpcClient, transports::mock::Asserter};

    use super::build_tx_manager;
    use crate::config::tests::test_configs;

    #[tokio::test]
    async fn build_tx_manager_accepts_existing_root_provider() {
        let asserter = Asserter::new();
        asserter.push_success(&1u64);
        asserter.push_success(&1u64);
        let provider = ProviderBuilder::default().connect_client(RpcClient::mocked(asserter));

        build_tx_manager(&test_configs(), provider)
            .await
            .expect("existing root provider should be reusable");
    }
}
