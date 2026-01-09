use std::borrow::Cow;

use alloy::{eips::BlockNumberOrTag, rpc::client::NoParams, sol_types::SolCall};
use alloy_consensus::{Transaction, TxEnvelope};
use alloy_primitives::{Address, B256, FixedBytes, U256};
use alloy_provider::{
    Provider, RootProvider, fillers::FillProvider, utils::JoinedRecommendedFillers,
};
use alloy_rpc_types::{Transaction as RpcTransaction, eth::Block as RpcBlock};
use anyhow::{Context, Result, ensure};
use bindings::anchor::Anchor::anchorV4Call;
use rpc::{
    client::{Client, ClientWithWallet},
    error::RpcClientError,
};

use crate::helper::{increase_l1_time, mine_l1_block};

/// The RPC client type used in Shasta tests.
pub type RpcClient = Client<FillProvider<JoinedRecommendedFillers, RootProvider>>;

/// Number of L1 blocks to mine to ensure preconfigured operator whitelist is active.
const PRECONF_OPERATOR_ACTIVATION_BLOCKS: usize = 64;
/// L1 block time in seconds.
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
    let reverted = provider
        .raw_request::<_, bool>(Cow::Borrowed("evm_revert"), (&snapshot_id,))
        .await
        .context("reverting L1 snapshot")?;
    ensure!(reverted, "evm_revert returned false");
    Ok(())
}

/// Create a new L1 snapshot to reuse across a single test run.
pub async fn create_snapshot(phase: &'static str, provider: &RootProvider) -> Result<String> {
    provider
        .raw_request::<_, String>(Cow::Borrowed("evm_snapshot"), NoParams::default())
        .await
        .with_context(|| format!("creating L1 snapshot during {phase}"))
}

/// Fetch proposal hash from the inbox contract.
pub async fn get_proposal_hash(client: &ClientWithWallet, proposal_id: U256) -> Result<B256> {
    let hash: FixedBytes<32> = client.shasta.inbox.getProposalHash(proposal_id).call().await?;
    Ok(hash)
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
