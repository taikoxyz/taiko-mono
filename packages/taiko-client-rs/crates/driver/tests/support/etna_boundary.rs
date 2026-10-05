//! Etna boundary scenario: crosses Unzen -> Etna mid-run against the docker harness.
//!
//! Runs only in the `Etna boundary` job (`ETNA_BOUNDARY=true TEST_CRATE=driver just test
//! --run-ignored only -E 'test(etna_boundary)'`), where both alethia-reth nodes and the
//! in-process client share `DEVNET_ETNA_TIMESTAMP`, one hour after the pinned L1 genesis.

use super::{
    raw_proposal::{submit_raw_proposal, with_blob_payload},
    *,
};
use alloy::rpc::types::TransactionRequest;
use alloy_eips::{BlockId, BlockNumberOrTag, eip7594::BlobTransactionSidecarVariant};
use driver::metrics::DriverMetrics;
use protocol::shasta::decode_etna_anchor_block_number;
use test_harness::{advance_l1_time, mine_l1_blocks};

/// Deadline for an Etna-boundary proposal to be event-synced.
const ETNA_PROPOSAL_TIMEOUT: Duration = Duration::from_secs(60);

/// Seconds L1 time moves past the Etna activation before the first Etna proposal, whose manifest
/// timestamp is the L1 head time.
const ETNA_JUMP_MARGIN_SECS: u64 = 12;

/// Anvil's `finalized` tag trails its head by 64 blocks. Mined between the two Etna proposals,
/// these blocks finalize the first one but not the second, so a fresh syncer's finalized-bounded
/// resume target is the first Etna block and it replays both Etna proposals.
const FINALITY_BLOCKS: usize = 70;

/// Gas reserved for the anchor transaction in every pre-Etna block header.
const ANCHOR_GAS_RESERVE: u64 = 1_000_000;

/// Length of a pre-Etna (Shasta/Unzen) block's `extraData`.
const PRE_ETNA_EXTRA_DATA_LEN: usize = 7;

/// Length of an Etna block's `extraData`.
const ETNA_EXTRA_DATA_LEN: usize = 13;

async fn full_block(client: &Client, number: u64) -> Result<alloy_rpc_types::Block> {
    client
        .l2_provider
        .get_block_by_number(number.into())
        .full()
        .await?
        .with_context(|| format!("missing L2 block {number}"))
}

async fn l1_state_root(client: &Client, number: u64) -> Result<B256> {
    Ok(client
        .l1_provider
        .get_block_by_number(number.into())
        .await?
        .with_context(|| format!("missing L1 block {number}"))?
        .header
        .state_root)
}

/// `Anchor.getBlockState()` (anchor block number, ancestors hash) at an L2 block.
async fn anchor_block_state(client: &Client, block_hash: B256) -> Result<(u64, B256)> {
    let state =
        client.shasta.anchor.getBlockState().block(BlockId::hash(block_hash)).call().await?;
    Ok((state.anchorBlockNumber.to::<u64>(), state.ancestorsHash))
}

/// Decodes the anchor number an Etna block carries in its 13-byte `extraData`.
fn etna_anchor(block: &alloy_rpc_types::Block) -> Result<u64> {
    ensure!(
        block.header.extra_data.len() == ETNA_EXTRA_DATA_LEN,
        "Etna block {} carries {} bytes of extraData",
        block.header.number,
        block.header.extra_data.len()
    );
    Ok(decode_etna_anchor_block_number(block.header.number, &block.header.extra_data)?)
}

/// A valid proposal whose blob holds no supported manifest (a zero version word), so derivation
/// falls back to the protocol default block.
async fn build_undecodable_proposal(
    env: &ShastaEnv,
    proposer: &Client,
) -> Result<(TransactionRequest, BlobTransactionSidecarVariant)> {
    with_blob_payload(&build_empty_proposal(env, proposer).await?, &[0u8; 64])
}

#[test_context(ShastaEnv)]
#[serial]
#[ignore = "runs in the Etna boundary job: ETNA_BOUNDARY=true TEST_CRATE=driver just test --run-ignored only -E 'test(etna_boundary)'"]
#[test_log::test(tokio::test(flavor = "multi_thread"))]
async fn etna_boundary(env: &mut ShastaEnv) -> Result<()> {
    let beacon_stub = BeaconStubServer::start().await?;
    let proposer = proposer_client(env).await?;
    let etna_timestamp = etna_fork_timestamp_for_chain(proposer.chain_id)?.context(
        "Etna is unscheduled: run with ETNA_BOUNDARY=true so tests/entrypoint.sh exports \
         DEVNET_ETNA_TIMESTAMP",
    )?;

    let unzen_request = build_empty_proposal(env, &proposer).await?;
    beacon_stub.set_default_blob_sidecar(unzen_request.blob_sidecar());
    let (mut syncer, driver_client) = start_event_syncer(env, &beacon_stub).await?;

    let result: Result<(alloy_rpc_types::Block, alloy_rpc_types::Block)> = async {
        // 1. The last Unzen block starts with anchorV4 and carries a zero root and 7-byte
        //    extraData.
        let l2_head_before = driver_client.l2_provider.get_block_number().await?;
        let baseline = batch_row_baseline(&driver_client).await?;
        let (proposal_id, _) = submit_proposal(env, unzen_request).await?;
        ensure!(proposal_id == baseline.proposal_id, "proposal id diverged from core state");
        let unzen_head = wait_for_proposal_processed(
            &mut syncer,
            &driver_client,
            &baseline,
            l2_head_before,
            ETNA_PROPOSAL_TIMEOUT,
        )
        .await?;
        let unzen_block = full_block(&driver_client, unzen_head).await?;
        ensure!(
            unzen_block.header.timestamp < etna_timestamp,
            "L1 time reached Etna before the first proposal; build the test binary before \
             starting the devnet"
        );
        verify_anchor_block(&driver_client, env.taiko_anchor_address)
            .await
            .context("the last Unzen block keeps its anchor transaction")?;
        ensure!(
            unzen_block.header.parent_beacon_block_root == Some(B256::ZERO),
            "an Unzen block carries a zero root"
        );
        ensure!(
            unzen_block.header.extra_data.len() == PRE_ETNA_EXTRA_DATA_LEN,
            "an Unzen block carries 7 bytes of extraData"
        );
        let unzen_anchor_state =
            anchor_block_state(&driver_client, unzen_block.header.hash).await?;

        // 2. Move L1 past Etna and propose: the first Etna block has no anchor transaction, drops
        //    the anchor gas reserve and commits to its anchor's L1 state root.
        let l1_head = driver_client
            .l1_provider
            .get_block_by_number(BlockNumberOrTag::Latest)
            .await?
            .context("missing L1 head")?;
        let jump = etna_timestamp.saturating_sub(l1_head.header.timestamp) + ETNA_JUMP_MARGIN_SECS;
        advance_l1_time(&driver_client, jump).await?;

        let etna_request = build_empty_proposal(env, &proposer).await?;
        beacon_stub.add_default_blob_sidecar(etna_request.blob_sidecar());
        let baseline = batch_row_baseline(&driver_client).await?;
        let (proposal_id, _) = submit_proposal(env, etna_request).await?;
        ensure!(proposal_id == baseline.proposal_id, "proposal id diverged from core state");
        let etna_head = wait_for_proposal_processed(
            &mut syncer,
            &driver_client,
            &baseline,
            unzen_head,
            ETNA_PROPOSAL_TIMEOUT,
        )
        .await?;
        let etna_block = full_block(&driver_client, etna_head).await?;
        ensure!(etna_block.header.timestamp >= etna_timestamp, "the second block must be Etna");
        ensure!(etna_block.transactions.is_empty(), "an Etna block has no anchor transaction");
        ensure!(
            etna_block.header.gas_limit + ANCHOR_GAS_RESERVE == unzen_block.header.gas_limit,
            "the first Etna block drops the 1,000,000 anchor gas reserve"
        );
        let anchor = etna_anchor(&etna_block)?;
        ensure!(
            anchor > unzen_anchor_state.0,
            "the Etna anchor {anchor} must advance past the Unzen anchor {}",
            unzen_anchor_state.0
        );
        ensure!(
            etna_block.header.parent_beacon_block_root ==
                Some(l1_state_root(&driver_client, anchor).await?),
            "the Etna root is the L1 state root of its anchor block"
        );
        ensure!(
            anchor_block_state(&driver_client, etna_block.header.hash).await? == unzen_anchor_state,
            "Anchor.getBlockState() stays frozen at the last Unzen value"
        );

        // 3. Finalize the Etna proposal (see FINALITY_BLOCKS), then propose an undecodable blob:
        //    the default Etna block is empty and repeats its parent's anchor, root and gas limit.
        mine_l1_blocks(&driver_client, FINALITY_BLOCKS).await?;
        let (default_request, default_sidecar) = build_undecodable_proposal(env, &proposer).await?;
        beacon_stub.add_default_blob_sidecar(default_sidecar);
        let baseline = batch_row_baseline(&driver_client).await?;
        let (proposal_id, _) = submit_raw_proposal(env, default_request).await?;
        ensure!(proposal_id == baseline.proposal_id, "proposal id diverged from core state");
        let default_head = wait_for_proposal_processed(
            &mut syncer,
            &driver_client,
            &baseline,
            etna_head,
            ETNA_PROPOSAL_TIMEOUT,
        )
        .await?;
        ensure!(default_head == etna_head + 1, "the default source derives exactly one block");
        let default_block = full_block(&driver_client, default_head).await?;
        ensure!(default_block.transactions.is_empty(), "the default Etna block is empty");
        ensure!(default_block.header.difficulty.is_zero(), "an empty Etna block has no zk gas");
        ensure!(
            default_block.header.parent_beacon_block_root ==
                etna_block.header.parent_beacon_block_root,
            "the default block reuses its Etna parent's root"
        );
        ensure!(etna_anchor(&default_block)? == anchor, "the default block inherits the anchor");
        ensure!(
            default_block.header.gas_limit == etna_block.header.gas_limit,
            "the default block inherits its Etna parent's gas limit"
        );
        Ok((etna_block, default_block))
    }
    .await;
    let (etna_block, default_block) = syncer.finish(result).await?;

    // 4. A fresh syncer resumes from the first Etna block, whose extraData names the L1 scan start,
    //    and recognizes both Etna proposals as already canonical instead of rebuilding them.
    let hits_before = DriverMetrics::derivation_canonical_hits();
    let (fresh_syncer, fresh_client) = start_event_syncer(env, &beacon_stub).await?;
    let result: Result<()> = async {
        let hits = DriverMetrics::derivation_canonical_hits() - hits_before;
        ensure!(
            hits == 2,
            "the fresh syncer must resume from Etna block {} and recognize both Etna proposals \
             as canonical, got {hits} canonical hits",
            etna_block.header.number
        );
        let head = fresh_client
            .l2_provider
            .get_block_by_number(BlockNumberOrTag::Latest)
            .await?
            .context("missing L2 head")?;
        ensure!(
            head.header.hash == default_block.header.hash,
            "re-deriving the Etna proposals must not rebuild the head"
        );
        Ok(())
    }
    .await;
    fresh_syncer.finish(result).await
}
