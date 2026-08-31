use std::borrow::Cow;

use alethia_reth_primitives::payload::attributes::RpcL1Origin;
use alloy::{eips::BlockNumberOrTag, rpc::client::NoParams, sol_types::SolCall};
use alloy_consensus::{Transaction, TxEnvelope};
use alloy_primitives::{Address, B256, Bytes, FixedBytes, U256};
use alloy_provider::{Provider, RootProvider};
use alloy_rlp::{BytesMut, encode_list};
use alloy_rpc_types::{Transaction as RpcTransaction, eth::Block as RpcBlock};
use alloy_rpc_types_engine::{
    ExecutionPayloadFieldV2, ExecutionPayloadInputV2, ForkchoiceState, PayloadStatusEnum,
};
use anyhow::{Context, Result, ensure};
use bindings::anchor::Anchor::anchorV4Call;
use protocol::shasta::{PayloadAttributesInput, build_payload_attributes};
use rpc::{client::Client, error::RpcClientError};
use tracing::{info, warn};

use crate::helper::{increase_l1_time, mine_l1_blocks};

/// Number of L1 blocks to mine to ensure preconfigured operator whitelist is active.
const PRECONF_OPERATOR_ACTIVATION_BLOCKS: usize = 64;
/// L1 block time in seconds.
const L1_BLOCK_TIME_SECONDS: u64 = 12;

/// Advances L1 time and mines blocks to ensure the preconfigured operator whitelist is active.
///
/// Uses batch operations (single `evm_increaseTime` + single `anvil_mine`) instead of
/// looping 64 times, reducing RPC calls from 128 to 2.
pub async fn ensure_preconf_whitelist_active(client: &Client) -> Result<()> {
    let total_seconds = PRECONF_OPERATOR_ACTIVATION_BLOCKS as u64 * L1_BLOCK_TIME_SECONDS;
    increase_l1_time(client, total_seconds).await?;
    mine_l1_blocks(client, PRECONF_OPERATOR_ACTIVATION_BLOCKS).await?;
    Ok(())
}

/// Advances L1 time past the current L2 head's timestamp.
///
/// Teardown's `evm_revert` rewinds L1 time, but derived L2 blocks persist across tests,
/// so a fresh test can observe an L2 head stamped AHEAD of its own L1 timeline — a state
/// impossible on a real chain. Anything that builds on that head with an L1-head-derived
/// timestamp (the proposer's engine-mode FCU preview, manifest timestamp validation)
/// then fails on `attributes.timestamp < parent.timestamp` by a second or two. Ratchet
/// L1 time forward BEFORE the per-test snapshot so the fix survives teardown and L1 time
/// stays monotonic across the whole run, mirroring the real chain.
pub(crate) async fn align_l1_time_past_l2_head(client: &Client) -> Result<()> {
    let l2_head = client
        .l2_provider
        .get_block_by_number(BlockNumberOrTag::Latest)
        .await?
        .ok_or_else(|| anyhow::anyhow!("latest L2 block missing while aligning L1 time"))?;
    let l1_head = client
        .l1_provider
        .get_block_by_number(BlockNumberOrTag::Latest)
        .await?
        .ok_or_else(|| anyhow::anyhow!("latest L1 block missing while aligning L1 time"))?;

    let l2_timestamp = l2_head.header.timestamp;
    let l1_timestamp = l1_head.header.timestamp;
    if l1_timestamp > l2_timestamp {
        return Ok(());
    }

    let skip = l2_timestamp - l1_timestamp + 1;
    info!(l1_timestamp, l2_timestamp, skip, "advancing L1 time past persisted L2 head");
    increase_l1_time(client, skip).await?;
    mine_l1_blocks(client, 1).await?;
    Ok(())
}

/// Checks if the RPC error indicates a geth-style "not found" error.
fn is_not_found_error(err: &RpcClientError) -> bool {
    match err {
        RpcClientError::Rpc(err) => err.to_string().contains("not found"),
        RpcClientError::RpcMessage(message) => message.contains("not found"),
        _ => false,
    }
}

/// Reset the authenticated L1 RPC head.
pub(crate) async fn reset_head_l1_origin(client: &Client) -> Result<()> {
    // Choose the highest L2 block that actually has an L1 origin row, then repoint
    // `head_l1_origin` there. Hardcoding block 1 is brittle when tests reset chains to genesis
    // or run against nodes with sparse origin rows.
    let latest = client.l2_provider.get_block_number().await?;
    for block_id in (0..=latest).rev() {
        if client.l1_origin_by_id(U256::from(block_id)).await?.is_none() {
            continue;
        }

        return match client.set_head_l1_origin(U256::from(block_id)).await {
            Ok(_) => Ok(()),
            Err(err) if is_not_found_error(&err) => continue,
            Err(err) => Err(err.into()),
        };
    }

    warn!(
        latest_block = latest,
        "no L1 origin rows found while resetting head_l1_origin; bootstrapping genesis origin"
    );

    let genesis =
        client.l2_provider.get_block_by_number(BlockNumberOrTag::Number(0)).await?.ok_or_else(
            || anyhow::anyhow!("genesis block missing while bootstrapping L1 origin"),
        )?;
    let genesis_origin = RpcL1Origin {
        block_id: U256::ZERO,
        l2_block_hash: genesis.hash(),
        l1_block_height: Some(U256::ZERO),
        l1_block_hash: None,
        build_payload_args_id: [0u8; 8],
        is_forced_inclusion: false,
        signature: [0u8; 65],
    };

    client.update_l1_origin(&genesis_origin).await?;
    client.set_head_l1_origin(U256::ZERO).await?;
    Ok(())
}

/// Revert the L1 snapshot.
pub(crate) async fn revert_snapshot(provider: &RootProvider, snapshot_id: &str) -> Result<()> {
    let reverted = provider
        .raw_request::<_, bool>(Cow::Borrowed("evm_revert"), (&snapshot_id,))
        .await
        .context("reverting L1 snapshot")?;
    ensure!(reverted, "evm_revert returned false");
    Ok(())
}

/// Create a new L1 snapshot to reuse across a single test run.
pub(crate) async fn create_snapshot(provider: &RootProvider) -> Result<String> {
    provider
        .raw_request::<_, String>(Cow::Borrowed("evm_snapshot"), NoParams::default())
        .await
        .context("creating L1 snapshot")
}

fn payload_status_is_ok(status: &PayloadStatusEnum) -> bool {
    // Canonical insertion requires strict VALID, matching production submission: ACCEPTED
    // means the engine stored the block on a side chain without executing it.
    matches!(status, PayloadStatusEnum::Valid)
}

/// Reset the L2 chain head to the base block (height 1) using the engine API.
///
/// `base_coinbase` is the beneficiary every driver-built block carries
/// (`L2_SUGGESTED_FEE_RECIPIENT`) and is the only base-block identity a reset cannot
/// corrupt: the engine's `fork_choice_updated_v2` persists block 1's l1_origin row with
/// the hash of whichever payload was just built, so after an interrupted reset both the
/// canonical block at height 1 and the row can point at the temporary random-coinbase
/// sibling — only the coinbase still tells the two apart.
pub(crate) async fn reset_to_base_block(client: &Client, base_coinbase: Address) -> Result<()> {
    let head: RpcBlock<TxEnvelope> = client
        .l2_provider
        .get_block_by_number(BlockNumberOrTag::Latest)
        .full()
        .await?
        .ok_or_else(|| anyhow::anyhow!("latest L2 block missing"))?
        .map_transactions(|tx: RpcTransaction| tx.into());

    // "Already at base" is only trustworthy when the coinbase matches: a bare height
    // check (or a comparison against the engine-rewritten l1_origin row) would accept
    // the sibling left canonical by an interrupted earlier reset.
    if head.header.number == 1 && head.header.beneficiary == base_coinbase {
        info!(head_number = head.header.number, "L2 chain already at base block");
        return Ok(());
    }

    // By number, not by the l1_origin row's hash: the row follows whichever payload the
    // engine built last, so after an interrupted reset it can name a sibling that was
    // never imported — by-number always returns the imported canonical block.
    let Some(block_one) = client
        .l2_provider
        .get_block_by_number(BlockNumberOrTag::Number(1))
        .full()
        .await?
        .map(|block| block.map_transactions(|tx: RpcTransaction| tx.into()))
    else {
        // Distinguish a fresh-genesis chain from an interrupted earlier reset: a fresh
        // chain never has a block-1 l1_origin row (the genesis bootstrap below only
        // writes row 0), while fork_to's first engine call persists row 1 — so a row
        // with no fetchable block means a reset died between that call and newPayload,
        // parking the head at genesis. Absorbing that as "fresh" would silently restart
        // the shared chain mid-suite; fail loudly instead. (A death in the sliver after
        // the head moves but before the row persists is indistinguishable from fresh
        // and still gets absorbed — both chains are consistent, L1 included.)
        ensure!(
            client.l1_origin_by_id(U256::from(1u64)).await?.is_none(),
            "block 1 is unfetchable but its l1_origin row exists; an earlier reset was \
             interrupted mid-fork — recreate the docker env (rerun `just test`)"
        );
        warn!("block 1 missing; skipping L2 head reset");
        return Ok(());
    };

    let Some(l1_origin) = client.l1_origin_by_id(U256::from(1u64)).await? else {
        warn!("L1 origin for block 1 missing; skipping L2 head reset");
        return Ok(());
    };

    let parent_hash = block_one.header.parent_hash;
    // When block 1 is the leftover sibling, its fields differ from the original base
    // block only in the coinbase, so rebuilding with `base_coinbase` (never the
    // canonical block's own beneficiary) restores the original bit-for-bit and lets the
    // engine repair the l1_origin row along the way.
    let clean_base = block_one.header.beneficiary == base_coinbase;

    info!(
        head_number = head.header.number,
        head_hash = ?head.header.hash,
        target_number = 1,
        parent_hash = ?parent_hash,
        clean_base,
        "resetting L2 head to base block via engine API"
    );

    // Fork to a sibling block at height 1 to force reorg, then back to the base block.
    // The sibling hop is what demotes a taller chain (block 1 is an ancestor of its
    // head); when the chain already sits at height 1 on a wrong-coinbase sibling, the
    // direct promotion is that same height-1 swap.
    if head.header.number != 1 {
        let temp_coinbase = Address::random();
        fork_to(client, &block_one, &l1_origin, parent_hash, temp_coinbase).await?;
    }
    fork_to(client, &block_one, &l1_origin, parent_hash, base_coinbase).await?;

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
    ensure!(
        new_head.header.beneficiary == base_coinbase,
        "rebuilt base block beneficiary {} != expected {}; the sibling swap did not \
         restore the original base block — recreate the docker env (rerun `just test`)",
        new_head.header.beneficiary,
        base_coinbase
    );
    // The reset relies on the execution client rebuilding a byte-identical base block;
    // a divergent rebuild (e.g. a payload-construction change in a new alethia-reth
    // image) would silently poison every later test. Only checkable against a clean
    // chain — when block 1 was the sibling, the original hash is not known beforehand
    // and the beneficiary check above is the authority.
    if clean_base {
        ensure!(
            new_head.header.hash == block_one.header.hash,
            "rebuilt base block hash {} != original {}; the L2 execution image no longer \
             rebuilds block 1 byte-identically — recreate the docker env (rerun `just test`)",
            new_head.header.hash,
            block_one.header.hash
        );
    }

    Ok(())
}

async fn fork_to(
    client: &Client,
    block: &RpcBlock<TxEnvelope>,
    l1_origin: &RpcL1Origin,
    parent_hash: B256,
    coinbase: Address,
) -> Result<()> {
    let block_number = block.header.number;
    let timestamp = block.header.timestamp;
    let mix_digest = block.header.mix_hash;
    let gas_limit = block.header.gas_limit;
    let header_difficulty = block.header.difficulty;
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

    let taiko_attrs = build_payload_attributes(PayloadAttributesInput {
        beneficiary: coinbase,
        timestamp,
        mix_hash: mix_digest,
        gas_limit,
        tx_list: Some(tx_list),
        extra_data,
        base_fee_per_gas: U256::from(base_fee),
        block_number,
        l1_block_height: l1_origin.l1_block_height,
        l1_block_hash: l1_origin.l1_block_hash,
        is_forced_inclusion: l1_origin.is_forced_inclusion,
        signature: l1_origin.signature,
        parent_beacon_block_root: None,
        anchor_transaction: None,
    });

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
    ensure!(payload_status_is_ok(fc_status), "forkchoice update returned status: {fc_status:?}");

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
        header_difficulty: Some(header_difficulty),
        taiko_block: Some(true),
        block_access_list: None,
        slot_number: None,
    };

    let exec_status = client
        .engine_new_payload_v2(&payload_input, &sidecar)
        .await
        .context("engine_newPayloadV2 failed")?;
    let exec_status_value = &exec_status.status;
    ensure!(
        payload_status_is_ok(exec_status_value),
        "newPayload returned status: {exec_status_value:?}"
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
        "forkchoice promotion returned status: {promote_status:?}"
    );

    Ok(())
}

/// Fetch proposal hash from the inbox contract.
pub async fn get_proposal_hash(client: &Client, proposal_id: U256) -> Result<B256> {
    let hash: FixedBytes<32> = client.shasta.inbox.getProposalHash(proposal_id).call().await?;
    Ok(hash)
}

/// Ensures the latest L2 block contains an Anchor `anchorV4` call.
pub async fn verify_anchor_block(client: &Client, anchor_address: Address) -> Result<()> {
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

    ensure!(first_tx.input().len() >= 4, "anchor transaction input too short");
    ensure!(
        first_tx.input()[..4] == anchorV4Call::SELECTOR,
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
