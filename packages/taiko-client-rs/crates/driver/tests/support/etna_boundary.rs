//! Etna boundary scenario: crosses Unzen -> Etna mid-run against the docker harness.
//!
//! Runs only in the `Etna boundary` job (`ETNA_BOUNDARY=true TEST_CRATE=driver just test
//! --run-ignored only -E 'test(etna_boundary)'`), where both alethia-reth nodes and the
//! in-process client share `DEVNET_ETNA_TIMESTAMP`, one hour after the pinned L1 genesis.

use super::{
    raw_proposal::{submit_raw_proposal, with_blob_payload},
    *,
};
use alethia_reth_primitives::payload::attributes::TaikoPayloadAttributes;
use alloy::rpc::types::TransactionRequest;
use alloy_eips::{BlockId, BlockNumberOrTag, eip7594::BlobTransactionSidecarVariant};
use alloy_primitives::Address;
use driver::{PreconfPayload, PreconfSubmissionOutcome, metrics::DriverMetrics};
use protocol::shasta::{
    PayloadAttributesInput, build_payload_attributes_with_id, calculate_shasta_mix_hash,
    constants::{calculate_next_block_eip4396_base_fee_for_parent, min_base_fee_for_chain},
    decode_etna_anchor_block_number, encode_etna_extra_data, encode_transactions,
    manifest::{BlockManifest, DerivationSourceManifest},
};
use test_harness::{advance_l1_time, mine_l1_blocks};

/// Deadline for an Etna-boundary proposal to be event-synced.
const ETNA_PROPOSAL_TIMEOUT: Duration = Duration::from_secs(60);

/// Seconds L1 time moves past the Etna activation before the first Etna proposal, whose manifest
/// timestamp is the L1 head time.
const ETNA_JUMP_MARGIN_SECS: u64 = 12;

/// Seconds L1 time moves forward to mine the anchor block of the preconfirmed Etna block.
const L1_BLOCK_TIME_SECS: u64 = 12;

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

/// Payload attributes of an empty Etna preconfirmation block on `parent`, built as the Catalyst
/// contract requires and as derivation recomputes them when the block's proposal arrives.
///
/// The block has no anchor transaction and an empty list (`0xc0`), anchors to `anchor` (its L1
/// state root is the block's root, its number goes into the 13-byte `extraData` with the
/// predicted `proposal_id`), keeps the parent's gas limit (an Etna parent has no anchor reserve),
/// and takes its timestamp from `anchor`: derivation bounds a block's timestamp by the L1
/// timestamp of the block that includes its proposal. The base fee is the parent's EIP-4396
/// successor and the mix hash hashes the parent's difficulty with the block number, as
/// derivation computes them.
async fn etna_preconfirmation_payload(
    client: &Client,
    parent: &alloy_rpc_types::Block,
    anchor: &alloy_rpc_types::Header,
    beneficiary: Address,
    proposal_id: u64,
) -> Result<TaikoPayloadAttributes> {
    let grandparent = client
        .l2_provider
        .get_block_by_hash(parent.header.parent_hash)
        .await?
        .context("missing preconfirmation grandparent")?;
    let base_fee = calculate_next_block_eip4396_base_fee_for_parent(
        parent.header.number,
        parent.header.gas_limit,
        parent.header.gas_used,
        parent.header.timestamp,
        parent.header.base_fee_per_gas,
        grandparent.header.timestamp,
        min_base_fee_for_chain(client.chain_id),
    )
    .context("preconfirmation parent has no base fee")?;
    let basefee_sharing_pctg = client.shasta.inbox.getConfig().call().await?.basefeeSharingPctg;
    let block_number = parent.header.number + 1;
    let parent_difficulty = B256::from(parent.header.difficulty.to_be_bytes::<32>());

    Ok(build_payload_attributes_with_id(
        PayloadAttributesInput {
            beneficiary,
            timestamp: anchor.timestamp,
            mix_hash: calculate_shasta_mix_hash(parent_difficulty, block_number),
            gas_limit: parent.header.gas_limit,
            tx_list: Some(encode_transactions(&[])),
            extra_data: encode_etna_extra_data(basefee_sharing_pctg, proposal_id, anchor.number)?,
            base_fee_per_gas: U256::from(base_fee),
            block_number,
            l1_block_height: None,
            l1_block_hash: None,
            is_forced_inclusion: false,
            signature: [0u8; 65],
            parent_beacon_block_root: Some(anchor.state_root),
            anchor_transaction: None,
        },
        &parent.header.hash,
    ))
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
    let (mut fresh_syncer, fresh_client) = start_event_syncer(env, &beacon_stub).await?;
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

        // 5. Preconfirm an empty Etna block on the head through the driver's preconfirmation path,
        //    then propose the manifest that describes it: derivation must recognize the
        //    preconfirmed block as canonical. A proposer manifest must advance the anchor past its
        //    parent's, so mine a new L1 block to anchor to.
        advance_l1_time(&fresh_client, L1_BLOCK_TIME_SECS).await?;
        let anchor_block = fresh_client
            .l1_provider
            .get_block_by_number(BlockNumberOrTag::Latest)
            .await?
            .context("missing L1 head")?;
        ensure!(
            anchor_block.header.timestamp > default_block.header.timestamp,
            "the preconfirmed block must be stamped after its parent"
        );
        let proposal_id =
            fresh_client.shasta.inbox.getCoreState().call().await?.nextProposalId.to::<u64>();
        let payload = etna_preconfirmation_payload(
            &fresh_client,
            &default_block,
            &anchor_block.header,
            env.l2_suggested_fee_recipient,
            proposal_id,
        )
        .await?;
        let outcome = fresh_syncer
            .syncer
            .submit_preconfirmation_payload(PreconfPayload::new(payload, default_block.header.hash))
            .await?;
        let PreconfSubmissionOutcome::Inserted { block_hash } = outcome else {
            anyhow::bail!("the Etna preconfirmation was not inserted: {outcome:?}");
        };
        let preconf_block = full_block(&fresh_client, default_block.header.number + 1).await?;
        ensure!(preconf_block.header.hash == block_hash, "the preconfirmed block is canonical");
        ensure!(preconf_block.transactions.is_empty(), "the preconfirmed Etna block is empty");
        ensure!(
            preconf_block.header.parent_beacon_block_root == Some(anchor_block.header.state_root),
            "the preconfirmed block carries its anchor's L1 state root"
        );
        ensure!(
            etna_anchor(&preconf_block)? == anchor_block.header.number,
            "the preconfirmed block names its anchor in extraData"
        );

        let manifest = DerivationSourceManifest {
            blocks: vec![BlockManifest {
                timestamp: preconf_block.header.timestamp,
                coinbase: preconf_block.header.beneficiary,
                anchor_block_number: anchor_block.header.number,
                gas_limit: preconf_block.header.gas_limit,
                transactions: Vec::new(),
            }],
        };
        let (request, sidecar) = with_blob_payload(
            &build_empty_proposal(env, &proposer).await?,
            &manifest.encode_and_compress()?,
        )?;
        beacon_stub.add_default_blob_sidecar(sidecar);
        let hits_before = DriverMetrics::derivation_canonical_hits();
        let baseline = batch_row_baseline(&fresh_client).await?;
        let (submitted_id, _) = submit_raw_proposal(env, request).await?;
        ensure!(
            submitted_id == proposal_id && baseline.proposal_id == proposal_id,
            "the preconfirmed extraData predicted proposal {proposal_id}, got {submitted_id}"
        );
        let confirmed_head = wait_for_proposal_processed(
            &mut fresh_syncer,
            &fresh_client,
            &baseline,
            default_block.header.number,
            ETNA_PROPOSAL_TIMEOUT,
        )
        .await?;
        ensure!(
            DriverMetrics::derivation_canonical_hits() == hits_before + 1,
            "derivation must recognize the preconfirmed Etna block as canonical"
        );
        ensure!(
            confirmed_head == preconf_block.header.number,
            "the proposal confirms exactly the preconfirmed block"
        );
        let head = fresh_client
            .l2_provider
            .get_block_by_number(BlockNumberOrTag::Latest)
            .await?
            .context("missing L2 head")?;
        ensure!(
            head.header.hash == block_hash,
            "confirming the preconfirmed block must not rebuild it"
        );
        Ok(())
    }
    .await;
    fresh_syncer.finish(result).await
}
