//! The switch's start write and first landing on the pinned contracts: a mock live Unzen Inbox
//! serves `proposeCutoff()` and `getCoreState()`, the state root of its checkpoint at S reaches
//! the root-only L1 SignalService through the EtnaInbox forwarder, the designated multisig writes
//! the start while an unrelated account cannot, the client authenticates it from its own L1 view,
//! the lander's first batch from S carries the implementation proofs of the L2 SignalService and
//! `EtnaStaking` proxies at S and lands without reading Unzen state, and the forwarder is closed
//! afterwards. S is a real block of the fixture's EL, so both proofs verify under its state root.
mod support;

use abci::{
    Engine, ParentInfo, PayloadVerdict,
    envelope::AnchorWitness,
    l1::{
        layout::inbox,
        source::{L1Source, RpcL1Source},
        witness::verify_anchor_witness,
    },
    rules::{self, HeaderInputs},
};
use alloy::{
    rpc::types::TransactionReceipt,
    sol_types::{SolCall, SolError},
};
use alloy_consensus::Header;
use alloy_eips::BlockId;
use alloy_primitives::{Address, B256, Bytes, U256, aliases::U48, b256};
use alloy_provider::{Provider, RootProvider};
use anyhow::{Context, Result, ensure};
use lander::{
    SidecarMode,
    l1::{LandingSource, RpcLandingSource},
    tx::{FeeCaps, RpcTransactionTransport, TransactionTransport},
};
use support::{
    ContractFixture,
    contracts::{
        EtnaInbox, EtnaSignalService, ICheckpointStore, L2_CHAIN_ID, MockUnzenInbox, Switching,
        USER_KEY, receipt, transact, view,
    },
    fixtures::FixtureChain,
};
use test_harness::{anvil_request, dev_signer, mine_l1_blocks};

/// The Etna start S, the last Unzen block: the first block on the fixture's EL genesis.
const S: u64 = 1;

/// The EIP-1967 implementation slot.
const IMPLEMENTATION_SLOT: B256 =
    b256!("360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc");

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
/// forwarder accepts calls from the immutable Unzen Inbox only.
///
/// Only the first call funds the Unzen Inbox. anvil keeps the state of its latest block for
/// historical reads as it stands when it mines the next one, so a balance set after the start
/// write would become part of the state of `L1_0`, the start write's block, and the genesis
/// proofs read there would no longer match its state root.
async fn forward(
    f: &ContractFixture,
    unzen: Address,
    (number, hash, root): (u64, B256, B256),
) -> Result<TransactionReceipt> {
    let p = &f.anvil.provider;
    anvil_request::<serde_json::Value>(p, "anvil_impersonateAccount", serde_json::json!([unzen]))
        .await?;
    if p.get_balance(unzen).await?.is_zero() {
        anvil_request::<serde_json::Value>(
            p,
            "anvil_setBalance",
            serde_json::json!([unzen, "0xde0b6b3a7640000"]),
        )
        .await?;
    }
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

/// Builds S on the EL's genesis through the Engine API, with no transaction, and makes it
/// canonical. The fixture's EL runs Etna from genesis, so S is an Etna-built stand-in for the last
/// Unzen block: the scenario needs only its hash, its state root and its pre-fork timestamp, the
/// anchor's. Its state holds the genesis's L2 SignalService and `EtnaStaking` proxies, each with
/// its implementation.
async fn build_start(f: &ContractFixture) -> Result<Header> {
    let source = RpcL1Source::new(f.anvil.provider.clone());
    let number = source.finalized_number().await?;
    let l1_header = source.header(number).await?;
    let witness = source.account_witness(f.inbox, &inbox::anchor_slots(), number).await?;
    let anchor = verify_anchor_witness(&AnchorWitness { l1_header, inbox: witness }, f.inbox)?;
    let genesis = &f.parent_header;
    let parent = ParentInfo {
        number: genesis.number,
        hash: genesis.hash_slow(),
        timestamp: genesis.timestamp,
        gas_limit: genesis.gas_limit,
        gas_used: genesis.gas_used,
        base_fee: genesis.base_fee_per_gas.context("genesis base fee")?,
        difficulty: genesis.difficulty,
        grandparent_timestamp: 0,
    };
    let expected = rules::expected_header(&HeaderInputs {
        height: S,
        beneficiary: f.params.fee_recipient,
        parent: &parent,
        anchor: &anchor,
        bft_time_secs: anchor.timestamp,
        generation: 0,
        miss_bitmap: 0,
        params: &f.params,
        min_base_fee: protocol::shasta::constants::min_base_fee_for_chain(L2_CHAIN_ID),
    })?;
    let engine = f.l2.engine()?;
    let attributes =
        rules::payload_attributes(&expected, anchor.hash, Some(Bytes::from_static(&[0xc0])));
    let block = engine.build_block(parent.hash, attributes).await?;
    rules::check_header(&block.header, &expected)?;
    ensure!(engine.new_payload(&block).await? == PayloadVerdict::Valid, "S is not valid");
    let hash = block.header.hash_slow();
    ensure!(
        engine.forkchoice(hash, hash, B256::ZERO).await? == PayloadVerdict::Valid,
        "S did not become canonical"
    );
    Ok(block.header)
}

/// The implementation the EIP-1967 slot of `proxy` holds in the state of L2 block `at`.
async fn implementation(f: &ContractFixture, proxy: Address, at: B256) -> Result<Address> {
    let slot = U256::from_be_bytes(IMPLEMENTATION_SLOT.0);
    let word = f.l2.provider.get_storage_at(proxy, slot).block_id(BlockId::hash(at)).await?;
    let implementation = Address::from_word(B256::from(word));
    ensure!(!implementation.is_zero(), "the proxy {proxy} has no implementation at S");
    Ok(implementation)
}

#[tokio::test]
#[ignore = "requires Docker: actual Etna contracts on Osaka anvil"]
async fn switch_start_write_comes_from_the_multisig_and_the_first_landing_reads_no_unzen_state()
-> Result<()> {
    let (mut f, Switching { unzen, fork_time, origin_multisig: multisig }) =
        ContractFixture::deploy_switching(3_600).await?;
    let p = f.anvil.provider.clone();
    let user: Address = USER_KEY.parse::<alloy::signers::local::PrivateKeySigner>()?.address();
    assert_eq!(view(&p, f.inbox, EtnaInbox::originMultisigCall {}, None).await?, multisig);
    // S, the last Unzen block, a real block of the fixture's EL; the contracts take its hash from
    // the Unzen Inbox's finalized tip and its state root from the checkpoint the final Unzen proof
    // saves. The client's switch parameters name the implementations S's proxies hold, as a
    // release builds them in.
    let start = build_start(&f).await?;
    let (hash, root) = (start.hash_slow(), start.state_root);
    assert!(start.timestamp < fork_time, "S is not before the fork time");
    let signal_service = abci::l2_signal_service_address(L2_CHAIN_ID);
    let signal_service_implementation = implementation(&f, signal_service, hash).await?;
    let staking_implementation = implementation(&f, f.params.staking, hash).await?;
    let switch = f.params.switch.as_mut().context("switching parameters")?;
    switch.signal_service_implementation = signal_service_implementation;
    switch.staking_implementation = staking_implementation;
    let set_origin = EtnaInbox::setOriginCall { _s: U48::from(S) }.abi_encode();

    // The final Unzen proof forwards S's checkpoint through the still open forwarder. The
    // root-only SignalService keeps its state root alone and answers a zero hash.
    forward(&f, unzen, (S, hash, root)).await?;
    let saved = view(
        &p,
        f.signal,
        EtnaSignalService::getCheckpointCall { _blockNumber: U48::from(S) },
        None,
    )
    .await?;
    assert_eq!((saved.blockHash, saved.stateRoot), (B256::ZERO, root));

    // Before ETNA_FORK_TIME, before the Unzen cutoff and while a proposal is unproven the
    // multisig's start write reverts.
    assert!(now(&p).await? < fork_time);
    assert_reverts(
        &p,
        multisig,
        f.inbox,
        set_origin.clone(),
        EtnaInbox::BeforeEtnaForkTime::SELECTOR,
    )
    .await?;
    anvil_request::<serde_json::Value>(
        &p,
        "evm_setNextBlockTimestamp",
        serde_json::json!([fork_time]),
    )
    .await?;
    mine_l1_blocks(&p, 1).await?;
    assert_reverts(
        &p,
        multisig,
        f.inbox,
        set_origin.clone(),
        EtnaInbox::ProposalsNotClosed::SELECTOR,
    )
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
    assert_reverts(
        &p,
        multisig,
        f.inbox,
        set_origin.clone(),
        EtnaInbox::UnzenNotFinalized::SELECTOR,
    )
    .await?;
    // A finalized Unzen tip without a hash is no start.
    let hashless = MockUnzenInbox::setCoreStateCall {
        _nextProposalId: U48::from(5),
        _lastFinalizedProposalId: U48::from(4),
        _lastFinalizedBlockHash: B256::ZERO,
    };
    transact(&p, f.admin, unzen, hashless.abi_encode()).await?;
    assert_reverts(
        &p,
        multisig,
        f.inbox,
        set_origin.clone(),
        EtnaInbox::UnzenTipHashZero::SELECTOR,
    )
    .await?;

    // Every Unzen proposal is proven at S. Every other gate passes, yet an unrelated account
    // cannot write the start; the multisig, which supplies S, writes it.
    let final_state = MockUnzenInbox::setCoreStateCall {
        _nextProposalId: U48::from(5),
        _lastFinalizedProposalId: U48::from(4),
        _lastFinalizedBlockHash: hash,
    };
    transact(&p, f.admin, unzen, final_state.abi_encode()).await?;
    assert_reverts(&p, user, f.inbox, set_origin.clone(), EtnaInbox::NotOriginMultisig::SELECTOR)
        .await?;
    let unwritten = view(&p, f.inbox, EtnaInbox::etnaStartCall {}, None).await?;
    assert_eq!((unwritten.height_.to::<u64>(), unwritten.blockHash_), (0, B256::ZERO));
    let written = transact(&p, multisig, f.inbox, set_origin.clone()).await?;
    let l1_0 = written.block_number.context("start write block")?;
    let event = written.decoded_log::<EtnaInbox::StartWritten>().context("StartWritten")?;
    assert_eq!(
        (event.data.height, event.data.blockHash, event.data.stateRoot),
        (U256::from(S), hash, root)
    );
    let recorded = view(&p, f.inbox, EtnaInbox::etnaStartCall {}, None).await?;
    assert_eq!((recorded.height_.to::<u64>(), recorded.blockHash_), (S, hash));
    assert_eq!(f.checkpoint().await?, (S, hash));
    // Written once, and the forwarder is closed at every height.
    assert_reverts(&p, multisig, f.inbox, set_origin, EtnaInbox::StartAlreadyWritten::SELECTOR)
        .await?;
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
    // proposal do not stop it, the start write having checked both.
    transact(
        &p,
        f.admin,
        unzen,
        MockUnzenInbox::setProposeCutoffRevertsCall { _reverts: true }.abi_encode(),
    )
    .await?;
    transact(&p, f.admin, unzen, unproven.abi_encode()).await?;
    // The lander's first batch from S: genuine certified blocks S + 1 and S + 2, signed by the
    // origin fallback keys, and both proxies' implementation proofs at S.
    f.parent_header = start;
    let mut chain = FixtureChain::new(&f).await?;
    chain.extend(&f, S + 2).await?;
    let request = chain.prepare(&f, S + 2, SidecarMode::Eip7594).await?;
    let batch = &request.batch;
    let witnessed = |witness: &Option<abci::AccountWitness>| witness.as_ref().map(|w| w.address);
    assert_eq!(witnessed(&batch.start_signal_service_witness), Some(signal_service));
    assert_eq!(witnessed(&batch.start_staking_witness), Some(f.params.staking));
    assert_eq!(batch.input.parentHeight, U256::from(S));
    f.expect_statement(batch.statement_hash).await?;
    let landed = land(&f, &request).await?;
    let event = landed.decoded_log::<EtnaInbox::Landed>().context("Landed")?;
    assert_eq!(event.data.parentHeight, U256::from(S));
    assert_eq!(event.data.lastHeight, U256::from(S + 2));
    assert_eq!(f.checkpoint().await?, (S + 2, chain.headers[2].hash_slow()));
    f.l2.stop().await?;
    f.anvil.stop().await
}

/// Signs `request` with the dummy proof from the dev account and lands it; requires success.
async fn land(f: &ContractFixture, request: &lander::ProofRequest) -> Result<TransactionReceipt> {
    let transport = RpcTransactionTransport::new(
        f.anvil.provider.clone(),
        dev_signer(),
        FeeCaps {
            max_fee_per_gas: 20_000_000_000,
            max_priority_fee_per_gas: 1_000_000_000,
            max_fee_per_blob_gas: 20_000_000_000,
        },
    )?;
    let signed = transport.sign(request, &Bytes::from_static(&[0])).await?;
    transport.broadcast(&signed).await?;
    let landed = receipt(&f.anvil.provider, signed.hash).await?;
    ensure!(landed.status(), "the first landing from S reverted: {}", signed.hash);
    Ok(landed)
}
