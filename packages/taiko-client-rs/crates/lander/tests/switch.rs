//! The switch's start write and first landing on the pinned contracts (START-10-5/5a/5c,
//! LAND-6.1-8a): a mock live Unzen Inbox serves `proposeCutoff()` and `getCoreState()`, its
//! checkpoint at S reaches the L1 SignalService through the EtnaInbox forwarder, an account
//! with no role writes the start, the client authenticates it from its own L1 view, the first
//! landing from S reads no Unzen state, and the forwarder is closed afterwards.
mod support;

use alloy::{
    eips::eip2718::Encodable2718,
    rpc::types::{TransactionReceipt, TransactionRequest},
    signers::SignerSync,
    sol_types::{SolCall, SolError},
};
use alloy_consensus::{
    Header, SignableTransaction, TxEip4844, TxEip4844Variant, TxEip4844WithSidecar, TxEnvelope,
};
use alloy_primitives::{Address, B256, Bytes, U256, aliases::U48};
use alloy_provider::{Provider, RootProvider};
use anyhow::{Context, Result, ensure};
use lander::{
    SidecarMode,
    contracts::IEtnaInbox::{LandInput, landCall},
    l1::{LandingSource, RpcLandingSource},
};
use support::{
    ContractFixture,
    contracts::{
        EtnaInbox, ICheckpointStore, MockUnzenInbox, SignalService, Switching, USER_KEY, receipt,
        transact, view,
    },
    fixtures::limits,
};
use test_harness::{anvil_request, dev_signer, mine_l1_blocks};

/// The Etna start S, the last Unzen block.
const S: u64 = 7;

/// Calls `to` with `input` from `sender` and requires a revert carrying the custom error
/// `selector`, without mining anything.
async fn assert_reverts(
    p: &RootProvider,
    sender: Address,
    to: Address,
    input: Vec<u8>,
    selector: [u8; 4],
) -> Result<()> {
    let error = transact(p, sender, to, input).await.expect_err("the call must revert");
    let text = format!("{error:#}");
    ensure!(
        text.contains(&alloy_primitives::hex::encode(selector)),
        "expected revert {}, got {text}",
        alloy_primitives::hex::encode(selector)
    );
    Ok(())
}

/// Sends EtnaInbox `saveCheckpoint` as the Unzen Inbox, which anvil impersonates: the
/// forwarder accepts calls from the immutable Unzen Inbox only (START-10-5).
async fn forward(
    f: &ContractFixture,
    unzen: Address,
    (number, hash, root): (u64, B256, B256),
) -> Result<TransactionReceipt> {
    let p = &f.anvil.provider;
    anvil_request::<serde_json::Value>(p, "anvil_impersonateAccount", serde_json::json!([unzen]))
        .await?;
    anvil_request::<serde_json::Value>(
        p,
        "anvil_setBalance",
        serde_json::json!([unzen, "0xde0b6b3a7640000"]),
    )
    .await?;
    transact(
        p,
        unzen,
        f.inbox,
        EtnaInbox::saveCheckpointCall {
            _checkpoint: ICheckpointStore::Checkpoint {
                blockNumber: U48::from(number),
                blockHash: hash,
                stateRoot: root,
            },
        }
        .abi_encode(),
    )
    .await
}

/// The L1 head's timestamp.
async fn now(p: &RootProvider) -> Result<u64> {
    Ok(p.get_block_by_number(alloy_eips::BlockNumberOrTag::Latest)
        .await?
        .context("L1 head")?
        .header
        .timestamp)
}

/// Lands (S, S + 1] with one blob, signed by the dev account: the mock verifier accepts any
/// statement, so this checks the Inbox's own landing rules at the start.
async fn land_first(f: &ContractFixture, cutoff: u64) -> Result<TransactionReceipt> {
    let p = &f.anvil.provider;
    let signer = dev_signer();
    let blobs = lander::blob::build(&[0xc0], &limits(), SidecarMode::Eip7594)?;
    let input = LandInput {
        parentHeight: U256::from(S),
        lastHeight: U256::from(S + 1),
        lastBlockHash: B256::repeat_byte(0x51),
        lastCometHash: B256::repeat_byte(0x52),
        lastStateRoot: B256::repeat_byte(0x53),
        l1ReferenceBlockNumber: U256::from(p.get_block_number().await?),
        forcedInclusionHead: U256::ZERO,
        activeCommitteeSnapshot: U256::from(cutoff),
    };
    let mut tx = TxEip4844 {
        chain_id: p.get_chain_id().await?,
        nonce: p.get_transaction_count(signer.address()).await?,
        gas_limit: 0,
        max_fee_per_gas: 20_000_000_000,
        max_priority_fee_per_gas: 1_000_000_000,
        to: f.inbox,
        value: U256::ZERO,
        access_list: Default::default(),
        blob_versioned_hashes: blobs.versioned_hashes.clone(),
        max_fee_per_blob_gas: 20_000_000_000,
        input: landCall { _input: input, _leaves: vec![], _proof: Bytes::from_static(&[0]) }
            .abi_encode()
            .into(),
    };
    let mut estimate = TransactionRequest::from_transaction(tx.clone()).from(signer.address());
    estimate.gas = None;
    let estimated = p.estimate_gas(estimate).await.context("first landing estimate")?;
    tx.gas_limit = estimated + estimated / 5;
    let variant: TxEip4844Variant =
        TxEip4844WithSidecar::from_tx_and_sidecar(tx, blobs.sidecar).into();
    let signature = signer.sign_hash_sync(&variant.signature_hash())?;
    let network = TxEnvelope::Eip4844(variant.into_signed(signature)).encoded_2718();
    let hash = *p.send_raw_transaction(&network).await?.tx_hash();
    let landed = receipt(p, hash).await?;
    ensure!(landed.status(), "the first landing from S reverted: {hash}");
    Ok(landed)
}

#[tokio::test]
#[ignore = "requires Docker: actual Etna contracts on Osaka anvil"]
async fn switch_start_write_is_permissionless_and_the_first_landing_reads_no_unzen_state()
-> Result<()> {
    let (mut f, Switching { unzen, fork_time }) = ContractFixture::deploy_switching(3_600).await?;
    let p = f.anvil.provider.clone();
    let user: Address = USER_KEY.parse::<alloy::signers::local::PrivateKeySigner>()?.address();
    // S, the last Unzen block, with a nonzero hash and state root; the contracts take both from
    // the checkpoint the final Unzen proof saves.
    let start = Header {
        number: S,
        parent_hash: f.parent_header.hash_slow(),
        timestamp: f.parent_header.timestamp + S,
        state_root: B256::repeat_byte(0x5a),
        ..f.parent_header.clone()
    };
    let (hash, root) = (start.hash_slow(), start.state_root);
    let set_origin = EtnaInbox::setOriginCall { _s: U48::from(S) }.abi_encode();

    // The final Unzen proof forwards S's checkpoint through the still open forwarder.
    forward(&f, unzen, (S, hash, root)).await?;
    let saved =
        view(&p, f.signal, SignalService::getCheckpointCall { _blockNumber: U48::from(S) }, None)
            .await?;
    assert_eq!((saved.blockHash, saved.stateRoot), (hash, root));

    // Before ETNA_FORK_TIME, before the Unzen cutoff and while a proposal is unproven the
    // start write reverts, whoever calls.
    assert!(now(&p).await? < fork_time);
    assert_reverts(&p, user, f.inbox, set_origin.clone(), EtnaInbox::BeforeEtnaForkTime::SELECTOR)
        .await?;
    anvil_request::<serde_json::Value>(
        &p,
        "evm_setNextBlockTimestamp",
        serde_json::json!([fork_time]),
    )
    .await?;
    mine_l1_blocks(&p, 1).await?;
    assert_reverts(&p, user, f.inbox, set_origin.clone(), EtnaInbox::ProposalsNotClosed::SELECTOR)
        .await?;
    let cutoff = U48::from(fork_time - 12);
    transact(
        &p,
        f.admin,
        unzen,
        MockUnzenInbox::setProposeCutoffCall { _cutoff: cutoff }.abi_encode(),
    )
    .await?;
    let unproven = MockUnzenInbox::setCoreStateCall {
        _nextProposalId: U48::from(5),
        _lastFinalizedProposalId: U48::from(3),
        _lastFinalizedBlockHash: hash,
    };
    transact(&p, f.admin, unzen, unproven.abi_encode()).await?;
    assert_reverts(&p, user, f.inbox, set_origin.clone(), EtnaInbox::UnzenNotFinalized::SELECTOR)
        .await?;
    // A finalized tip other than S's checkpoint is no start.
    let other = MockUnzenInbox::setCoreStateCall {
        _nextProposalId: U48::from(5),
        _lastFinalizedProposalId: U48::from(4),
        _lastFinalizedBlockHash: B256::repeat_byte(0x99),
    };
    transact(&p, f.admin, unzen, other.abi_encode()).await?;
    assert_reverts(&p, user, f.inbox, set_origin.clone(), EtnaInbox::UnzenStartMismatch::SELECTOR)
        .await?;

    // Every Unzen proposal is proven at S: an account with no role writes the start.
    let final_state = MockUnzenInbox::setCoreStateCall {
        _nextProposalId: U48::from(5),
        _lastFinalizedProposalId: U48::from(4),
        _lastFinalizedBlockHash: hash,
    };
    transact(&p, f.admin, unzen, final_state.abi_encode()).await?;
    let written = transact(&p, user, f.inbox, set_origin.clone()).await?;
    let l1_0 = written.block_number.context("start write block")?;
    let event = written.decoded_log::<EtnaInbox::StartWritten>().context("StartWritten")?;
    assert_eq!(
        (event.data.height, event.data.blockHash, event.data.stateRoot),
        (U256::from(S), hash, root)
    );
    let recorded = view(&p, f.inbox, EtnaInbox::etnaStartCall {}, None).await?;
    assert_eq!((recorded.height_.to::<u64>(), recorded.blockHash_), (S, hash));
    assert_eq!(f.checkpoint().await?, (S, hash));
    // Written once (START-10-5c), and the forwarder is closed at every height (START-10-5).
    assert_reverts(&p, user, f.inbox, set_origin, EtnaInbox::StartAlreadyWritten::SELECTOR).await?;
    for number in [S, S + 1] {
        let error = forward(&f, unzen, (number, hash, root)).await.expect_err("forwarder closed");
        let text = format!("{error:#}");
        let closed = alloy_primitives::hex::encode(EtnaInbox::ForwardingClosed::SELECTOR);
        ensure!(text.contains(&closed), "forwarder after the start write: {text}");
    }

    // The client authenticates the switching start from its own L1 view: the snapshot's start
    // record and the Comet genesis at S + 1.
    mine_l1_blocks(&p, 4).await?;
    let source = RpcLandingSource::new(p.clone(), f.l2.provider.clone(), f.params.clone());
    let snapshot = source.snapshot().await?;
    assert_eq!(snapshot.checkpoint_height, S);
    assert_eq!(snapshot.checkpoint_hash, hash);
    assert_eq!(
        (
            snapshot.genesis.genesis_height,
            snapshot.genesis.genesis_hash,
            snapshot.genesis.genesis_state_root,
            snapshot.genesis.l1_0,
        ),
        (S, hash, root, l1_0)
    );
    f.genesis = snapshot.genesis.clone();
    let doc = abci::build_genesis(&abci::RpcL1Source::new(p.clone()), &f.params).await?;
    assert_eq!(doc.initial_height, (S + 1).to_string());

    // The first landing reads no Unzen state: a reverting cutoff getter and an unproven Unzen
    // proposal do not stop it (LAND-6.1-8a moved into the start write).
    transact(
        &p,
        f.admin,
        unzen,
        MockUnzenInbox::setProposeCutoffRevertsCall { _reverts: true }.abi_encode(),
    )
    .await?;
    transact(&p, f.admin, unzen, unproven.abi_encode()).await?;
    let landed = land_first(&f, f.genesis.genesis_cutoff).await?;
    let event = landed.decoded_log::<EtnaInbox::Landed>().context("Landed")?;
    assert_eq!(event.data.parentHeight, U256::from(S));
    assert_eq!(f.checkpoint().await?, (S + 1, B256::repeat_byte(0x51)));
    f.l2.stop().await?;
    f.anvil.stop().await
}
