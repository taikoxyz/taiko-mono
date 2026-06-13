//! Adapter building the prover's transaction manager (mirrors
//! `crates/proposer/src/tx_manager_adapter.rs`).

use std::sync::Arc;

use alloy_provider::RootProvider;
use base_tx_manager::{BaseTxMetrics, SimpleTxManager, TxManagerError};

use crate::{
    config::ProverConfigs,
    error::{ProverError, Result},
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
    Ok(rpc::build_tx_manager(
        provider,
        cfg.l1_prover_private_key,
        tx_manager_config,
        Arc::new(BaseTxMetrics::new("prover")),
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
