use std::{borrow::Cow, sync::Arc, time::Duration};

use alloy::{eips::BlockNumberOrTag, rpc::client::NoParams, sol_types::SolCall};
use alloy_consensus::{Transaction, TxEnvelope};
use alloy_primitives::{Address, U256};
use alloy_provider::{
    Provider, RootProvider, fillers::FillProvider, utils::JoinedRecommendedFillers,
};
use alloy_rpc_types::{Transaction as RpcTransaction, eth::Block as RpcBlock};
use anyhow::{Context, Result, ensure};
use bindings::anchor::Anchor::anchorV4Call;
use event_indexer::indexer::{ProposedEventPayload, ShastaEventIndexer};
use rpc::{client::Client, error::RpcClientError};
use tokio::time::timeout;

use crate::helper::{increase_l1_time, mine_l1_block};

pub type RpcClient = Client<FillProvider<JoinedRecommendedFillers, RootProvider>>;

const PRECONF_OPERATOR_ACTIVATION_BLOCKS: usize = 64;
const L1_BLOCK_TIME_SECONDS: u64 = 12;

/// Advances L1 time and mines blocks to ensure the preconfigured operator whitelist is active.
pub async fn ensure_preconf_whitelist_active(client: &RpcClient) -> Result<()> {
    for _ in 0..PRECONF_OPERATOR_ACTIVATION_BLOCKS {
        increase_l1_time(client, L1_BLOCK_TIME_SECONDS).await?;
        mine_l1_block(client).await?;
    }
    Ok(())
}

/// Checks if the RPC error indicates a geth-style "not found" error.
fn is_not_found_error(err: &RpcClientError) -> bool {
    matches!(err, RpcClientError::Rpc(message) if message.contains("not found"))
}

/// Reset the authenticated L1 RPC head.
pub async fn reset_head_l1_origin(client: &RpcClient) -> Result<()> {
    match client.set_head_l1_origin(U256::from(1u64)).await {
        Ok(_) => Ok(()),
        Err(err) if is_not_found_error(&err) => Ok(()),
        Err(err) => Err(err.into()),
    }
}

/// Revert the L1 snapshot.
pub async fn revert_snapshot(provider: &RootProvider, snapshot_id: &str) -> Result<()> {
    provider
        .raw_request::<_, bool>(Cow::Borrowed("evm_revert"), (&snapshot_id,))
        .await
        .context("reverting L1 snapshot")?;
    Ok(())
}

/// Create a new L1 snapshot to reuse across a single test run.
pub async fn create_snapshot(phase: &'static str, provider: &RootProvider) -> Result<String> {
    provider
        .raw_request::<_, String>(Cow::Borrowed("evm_snapshot"), NoParams::default())
        .await
        .with_context(|| format!("creating L1 snapshot during {phase}"))
}

/// Ensures the latest L2 block contains an Anchor `anchorV4` call.
pub async fn verify_anchor_block<P>(client: &Client<P>, anchor_address: Address) -> Result<()>
where
    P: Provider + Clone + Send + Sync + 'static,
{
    let latest_block: RpcBlock<TxEnvelope> = client
        .l2_provider
        .get_block_by_number(BlockNumberOrTag::Latest)
        .full()
        .await?
        .ok_or_else(|| anyhow::anyhow!("latest block missing"))?
        .map_transactions(|tx: RpcTransaction| tx.into());

    let first_tx = latest_block
        .transactions
        .as_transactions()
        .and_then(|txs| txs.first())
        .ok_or_else(|| anyhow::anyhow!("block missing anchor transaction"))?;

    let selectors = [anchorV4Call::SELECTOR];
    ensure!(first_tx.input().len() >= 4, "anchor transaction input too short");
    ensure!(
        selectors.iter().any(|sel| &first_tx.input()[..sel.len()] == sel.as_slice()),
        "first transaction is not calling an Anchor anchorV4 entrypoint"
    );
    ensure!(
        first_tx.to() == Some(anchor_address),
        "anchor transaction target mismatch: expected {}, got {:?}",
        anchor_address,
        first_tx.to()
    );

    Ok(())
}

/// Waits until the indexer observes a proposal with an ID greater than `previous_id`.
pub async fn wait_for_new_proposal(
    indexer: Arc<ShastaEventIndexer>,
    previous_id: u64,
) -> Result<ProposedEventPayload> {
    let wait = async {
        loop {
            if let Some(payload) = indexer.get_last_proposal() {
                let proposal_id = payload.proposal.id.to::<u64>();
                if proposal_id > previous_id {
                    return payload;
                }
            }
            tokio::time::sleep(Duration::from_millis(100)).await;
        }
    };

    timeout(Duration::from_secs(15), wait)
        .await
        .map_err(|_| anyhow::anyhow!("timed out waiting for proposal to be indexed"))
}
