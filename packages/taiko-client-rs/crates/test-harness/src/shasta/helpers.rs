use std::borrow::Cow;

use alethia_reth_primitives::payload::attributes::{
    RpcL1Origin, TaikoBlockMetadata, TaikoPayloadAttributes,
};
use alloy::{eips::BlockNumberOrTag, rpc::client::NoParams, sol_types::SolCall};
use alloy_consensus::{Transaction, TxEnvelope};
use alloy_primitives::{Address, B256, Bytes, FixedBytes, U256};
use alloy_provider::{
    Provider, RootProvider, fillers::FillProvider, utils::JoinedRecommendedFillers,
};
use alloy_rlp::{BytesMut, encode_list};
use alloy_rpc_types::{
    Transaction as RpcTransaction,
    eth::{Block as RpcBlock, Withdrawal},
};
use alloy_rpc_types_engine::{
    ExecutionPayloadFieldV2, ExecutionPayloadInputV2, ForkchoiceState, PayloadAttributes,
    PayloadStatusEnum,
};
use anyhow::{Context, Result, ensure};
use bindings::anchor::Anchor::anchorV4Call;
use rpc::{
    client::{Client, ClientWithWallet},
    error::RpcClientError,
};
use tracing::{info, warn};

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

fn payload_status_is_ok(status: &PayloadStatusEnum) -> bool {
    matches!(status, PayloadStatusEnum::Valid | PayloadStatusEnum::Accepted)
}

/// Reset the L2 chain head to the base block (height 1) using the engine API.
pub async fn reset_to_base_block(client: &RpcClient) -> Result<()> {
    let head: RpcBlock<TxEnvelope> = client
        .l2_provider
        .get_block_by_number(BlockNumberOrTag::Latest)
        .full()
        .await?
        .ok_or_else(|| anyhow::anyhow!("latest L2 block missing"))?
        .map_transactions(|tx: RpcTransaction| tx.into());

    if head.header.number == 1 {
        info!(head_number = head.header.number, "L2 chain already at base block");
        return Ok(());
    }

    let Some(block_one) = client
        .l2_provider
        .get_block_by_number(BlockNumberOrTag::Number(1))
        .full()
        .await?
        .map(|block| block.map_transactions(|tx: RpcTransaction| tx.into()))
    else {
        warn!("block 1 missing; skipping L2 head reset");
        return Ok(());
    };

    let Some(l1_origin) = client.l1_origin_by_id(U256::from(1u64)).await? else {
        warn!("L1 origin for block 1 missing; skipping L2 head reset");
        return Ok(());
    };

    let parent_hash = block_one.header.parent_hash;
    let original_coinbase = block_one.header.beneficiary;

    info!(
        head_number = head.header.number,
        target_number = 1,
        parent_hash = ?parent_hash,
        "resetting L2 head to base block via engine API"
    );

    // Fork to a sibling block at height 1 to force reorg, then back to canonical block 1.
    let temp_coinbase = Address::random();
    fork_to(client, &block_one, &l1_origin, parent_hash, temp_coinbase).await?;
    fork_to(client, &block_one, &l1_origin, parent_hash, original_coinbase).await?;

    let new_head: RpcBlock<TxEnvelope> = client
        .l2_provider
        .get_block_by_number(BlockNumberOrTag::Latest)
        .full()
        .await?
        .ok_or_else(|| anyhow::anyhow!("latest L2 block missing after reset"))?
        .map_transactions(|tx: RpcTransaction| tx.into());

    ensure!(
        new_head.header.number == 1,
        "failed to reset L2 head to block 1 (current {})",
        new_head.header.number
    );

    Ok(())
}

async fn fork_to(
    client: &RpcClient,
    block: &RpcBlock<TxEnvelope>,
    l1_origin: &RpcL1Origin,
    parent_hash: B256,
    coinbase: Address,
) -> Result<()> {
    let block_number = block.header.number;
    let timestamp = block.header.timestamp;
    let mix_digest = block.header.mix_hash;
    let gas_limit = block.header.gas_limit;
    let extra_data = block.header.extra_data.clone();
    let base_fee = block.header.base_fee_per_gas.unwrap_or_default();

    let tx_list: Bytes = block
        .transactions
        .as_transactions()
        .map(|txs| {
            let mut buf = BytesMut::new();
            encode_list(txs, &mut buf);
            Bytes::from(buf.freeze())
        })
        .unwrap_or_default();

    let withdrawals: Vec<Withdrawal> = Vec::new();

    let payload_attributes = PayloadAttributes {
        timestamp,
        prev_randao: mix_digest,
        suggested_fee_recipient: coinbase,
        withdrawals: Some(withdrawals.clone()),
        parent_beacon_block_root: None,
    };

    let block_metadata = TaikoBlockMetadata {
        beneficiary: coinbase,
        gas_limit,
        timestamp: U256::from(timestamp),
        mix_hash: mix_digest,
        tx_list,
        extra_data,
    };

    let l1_origin_attrs = RpcL1Origin {
        block_id: U256::from(block_number),
        l2_block_hash: B256::ZERO,
        l1_block_height: l1_origin.l1_block_height,
        l1_block_hash: l1_origin.l1_block_hash,
        build_payload_args_id: [0u8; 8],
        is_forced_inclusion: l1_origin.is_forced_inclusion,
        signature: l1_origin.signature,
    };

    let taiko_attrs = TaikoPayloadAttributes {
        payload_attributes,
        base_fee_per_gas: U256::from(base_fee),
        block_metadata,
        l1_origin: l1_origin_attrs,
    };

    let forkchoice_state = ForkchoiceState {
        head_block_hash: parent_hash,
        safe_block_hash: parent_hash,
        finalized_block_hash: B256::ZERO,
    };
    let fc_response = client
        .engine_forkchoice_updated_v2(forkchoice_state, Some(taiko_attrs))
        .await
        .context("engine_forkchoiceUpdatedV2 with attributes failed")?;
    let fc_status = &fc_response.payload_status.status;
    ensure!(payload_status_is_ok(fc_status), "forkchoice update returned status: {:?}", fc_status);

    let payload_id = fc_response
        .payload_id
        .ok_or_else(|| anyhow::anyhow!("forkchoice update missing payload_id"))?;

    let envelope =
        client.engine_get_payload_v2(payload_id).await.context("engine_getPayloadV2 failed")?;
    let (payload_input, block_hash) = match envelope.execution_payload {
        ExecutionPayloadFieldV2::V1(payload) => (
            ExecutionPayloadInputV2 { execution_payload: payload.clone(), withdrawals: None },
            payload.block_hash,
        ),
        ExecutionPayloadFieldV2::V2(payload) => (
            ExecutionPayloadInputV2 {
                execution_payload: payload.payload_inner.clone(),
                withdrawals: Some(payload.withdrawals.clone()),
            },
            payload.payload_inner.block_hash,
        ),
    };

    use alloy_consensus::proofs::{calculate_withdrawals_root, ordered_trie_root_with_encoder};
    use alloy_primitives::bytes::BufMut;

    let tx_hash =
        ordered_trie_root_with_encoder(&payload_input.execution_payload.transactions, |tx, buf| {
            buf.put_slice(tx)
        });
    let withdrawals_hash =
        payload_input.withdrawals.as_ref().map(|ws| calculate_withdrawals_root(ws));

    let sidecar = alethia_reth_primitives::engine::types::TaikoExecutionDataSidecar {
        tx_hash,
        withdrawals_hash,
        taiko_block: Some(true),
    };

    let exec_status = client
        .engine_new_payload_v2(&payload_input, &sidecar)
        .await
        .context("engine_newPayloadV2 failed")?;
    let exec_status_value = &exec_status.status;
    ensure!(
        payload_status_is_ok(exec_status_value),
        "newPayload returned status: {:?}",
        exec_status_value
    );

    let promote_state = ForkchoiceState {
        head_block_hash: block_hash,
        safe_block_hash: B256::ZERO,
        finalized_block_hash: B256::ZERO,
    };
    let promote_response = client
        .engine_forkchoice_updated_v2(promote_state, None)
        .await
        .context("engine_forkchoiceUpdatedV2 promotion failed")?;
    let promote_status = &promote_response.payload_status.status;
    ensure!(
        payload_status_is_ok(promote_status),
        "forkchoice promotion returned status: {:?}",
        promote_status
    );

    Ok(())
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
