//! Actual pinned-contract landing scenarios. Docker scenarios use real Osaka blob transactions.
mod support;

use alloy::{consensus::Transaction, rpc::types::TransactionReceipt, sol_types::SolCall};
use alloy_eips::eip2718::Encodable2718;
use alloy_primitives::{B256, Bytes, U256};
use alloy_provider::Provider;
use anyhow::{Context, Result};
use lander::{
    DummyProofProvider, ProofProvider, ProofRequest, SidecarMode,
    contracts::IEtnaInbox::landCall,
    tx::{FeeCaps, RpcTransactionTransport, SignedTransaction, TransactionTransport},
};
use support::{
    ContractFixture,
    contracts::{EtnaInbox, EtnaStakingRegistry, SignalService, receipt, transact, view},
    fixtures::FixtureChain,
};
use test_harness::{dev_signer, mine_l1_blocks};

/// The transport's fee caps.
const FEES: FeeCaps = FeeCaps {
    max_fee_per_gas: 20_000_000_000,
    max_priority_fee_per_gas: 1_000_000_000,
    max_fee_per_blob_gas: 20_000_000_000,
};

fn transport(fixture: &ContractFixture) -> Result<RpcTransactionTransport> {
    Ok(RpcTransactionTransport::new(fixture.anvil.provider.clone(), dev_signer(), FEES)?)
}

async fn sign(fixture: &ContractFixture, request: &ProofRequest) -> Result<SignedTransaction> {
    let proof = DummyProofProvider.prove(request).await?;
    assert_eq!(proof.as_ref(), &[0]);
    let signed = transport(fixture)?.sign(request, &proof).await?;
    signed.validate(request, &proof)?;
    assert!(
        transport(fixture)?.receipt(signed.hash).await?.is_none(),
        "signing must not broadcast"
    );
    Ok(signed)
}

async fn assert_landed(
    fixture: &ContractFixture,
    request: &ProofRequest,
    signed: &SignedTransaction,
) -> Result<TransactionReceipt> {
    let p = &fixture.anvil.provider;
    let hash = transport(fixture)?.broadcast(signed).await?;
    assert_eq!(hash, signed.hash);
    let receipt = receipt(p, hash).await?;
    assert!(receipt.status());
    assert_eq!(receipt.to, Some(fixture.inbox));
    assert_eq!(
        receipt.blob_gas_used,
        Some(131_072 * u64::try_from(request.batch.blobs.versioned_hashes.len())?)
    );
    let event = receipt.decoded_log::<EtnaInbox::Landed>().context("Landed event")?;
    assert_eq!(event.data.version, 1);
    assert_eq!(event.data.parentHeight, request.batch.input.parentHeight);
    assert_eq!(event.data.checkpointHeight, U256::from(request.batch.snapshot.checkpoint_height));
    assert_eq!(event.data.lastHeight, request.batch.input.lastHeight);
    let batch = &request.batch;
    assert_eq!(
        view(p, fixture.inbox, EtnaInbox::activeCommitteeSnapshotCall {}, None).await?,
        batch.input.activeCommitteeSnapshot
    );
    let tx = p.get_transaction_by_hash(hash).await?.context("landing transaction")?;
    assert_eq!(
        tx.inner.blob_versioned_hashes(),
        Some(request.batch.blobs.versioned_hashes.as_slice())
    );
    let decoded = landCall::abi_decode(tx.inner.input())?;
    assert_eq!(decoded._proof.as_ref(), &[0]);
    assert_eq!(decoded._input, request.batch.input);
    assert_eq!(decoded._leaves, request.batch.leaves);
    assert_eq!(
        fixture.checkpoint().await?,
        (request.batch.input.lastHeight.to(), request.batch.input.lastBlockHash)
    );
    // The landed record holds the terminal EL and Comet hashes (STOR-B-9).
    let record = view(
        p,
        fixture.inbox,
        EtnaInbox::landingsCall { _height: request.batch.input.lastHeight },
        None,
    )
    .await?;
    assert_eq!(
        (record.parentHeight, record.elHash, record.cometHash),
        (
            request.batch.input.parentHeight.to(),
            request.batch.input.lastBlockHash,
            request.batch.input.lastCometHash
        )
    );
    let saved = view(
        p,
        fixture.signal,
        SignalService::getCheckpointCall {
            _blockNumber: request.batch.input.lastHeight.to::<u64>().try_into()?,
        },
        None,
    )
    .await?;
    assert_eq!(saved.blockHash, request.batch.input.lastBlockHash);
    assert_eq!(saved.stateRoot, request.batch.input.lastStateRoot);
    Ok(receipt)
}

#[tokio::test]
#[ignore = "requires Docker: actual Etna contracts on Osaka anvil"]
async fn lander_actual_contract_blob_landing_and_cross_epoch() -> Result<()> {
    let fixture = ContractFixture::deploy().await?;
    let p = &fixture.anvil.provider;
    let mut chain = FixtureChain::new(&fixture).await?;
    chain.extend(&fixture, 6).await?;
    let first = chain.prepare(&fixture, 6, SidecarMode::Eip7594).await?;
    assert_eq!(first.batch.input.activeCommitteeSnapshot, fixture.genesis.genesis_cutoff);
    fixture.expect_statement(first.batch.statement_hash).await?;
    let signed = sign(&fixture, &first).await?;
    assert_landed(&fixture, &first, &signed).await?;
    // Land exactly D, then mutate the registry after the immutable derivation snapshot.
    let schedule = abci::Schedule::from_genesis(&fixture.genesis);
    let (derivation_height, switch_height, activation_height) = (12, 13, 15);
    assert_eq!(schedule.derivation_parent_height(1), Some(derivation_height));
    assert_eq!(schedule.switch_target(switch_height), Some(1));
    assert_eq!(schedule.h_first(1), activation_height);
    mine_l1_blocks(&fixture.anvil.provider, 3).await?;
    chain.extend(&fixture, derivation_height).await?;
    let derivation = chain.prepare(&fixture, derivation_height, SidecarMode::Eip7594).await?;
    fixture.expect_statement(derivation.batch.statement_hash).await?;
    assert_landed(&fixture, &derivation, &sign(&fixture, &derivation).await?).await?;
    let exit = transact(
        &fixture.anvil.provider,
        dev_signer().address(),
        fixture.registry,
        EtnaStakingRegistry::requestExitCall { _bondId: U256::ZERO }.abi_encode(),
    )
    .await?;
    let immutable_snapshot = chain.anchors[usize::try_from(derivation_height)?].number;
    let exit_block = exit.block_number.context("exit inclusion block")?;
    assert!(exit_block > immutable_snapshot);
    use abci::l1::source::{L1Source, RpcL1Source};
    let source = RpcL1Source::new(p.clone());
    for _ in 0..32 {
        if source.finalized_number().await? >= exit_block {
            break;
        }
        mine_l1_blocks(p, 1).await?;
    }
    assert!(
        source.finalized_number().await? >= exit_block,
        "exit must be finalized before S is constructed"
    );
    // A later prefix past the global schedule's first epoch start lands in one batch, still
    // signed by the genesis set: the exit changes no signing set.
    for last in [18, 24] {
        mine_l1_blocks(p, 3).await?;
        chain.extend(&fixture, last).await?;
        assert!(chain.anchors[usize::try_from(switch_height)?].number >= exit_block);
        let next = chain.prepare(&fixture, last, SidecarMode::Eip7594).await?;
        assert_eq!(next.batch.input.lastHeight, last);
        assert_eq!(next.batch.input.activeCommitteeSnapshot, fixture.genesis.genesis_cutoff);
        fixture.expect_statement(next.batch.statement_hash).await?;
        assert_landed(&fixture, &next, &sign(&fixture, &next).await?).await?;
    }
    fixture.anvil.stop().await
}

/// A user stores a forced inclusion, its transaction as calldata, on the real Inbox; a decided
/// block whose anchor holds the entry consumes it with a real entry proof and carries the
/// transaction first, and landing that batch moves the queue head. The fee stays in the Inbox
/// until `sweepProtocolFees` pays it to the treasury.
#[tokio::test]
#[ignore = "requires Docker: actual Etna contracts on Osaka anvil"]
async fn lander_actual_contract_forced_inclusion_lands_and_fee_is_swept_to_treasury() -> Result<()>
{
    let fixture = ContractFixture::deploy().await?;
    let p = &fixture.anvil.provider;
    let mut chain = FixtureChain::new(&fixture).await?;
    chain.extend(&fixture, 2).await?;

    let payload = test_harness::sign_transfer(
        &fixture.l2.provider,
        &dev_signer(),
        alloy_primitives::Address::repeat_byte(0x44),
        U256::from(7),
        0,
    )
    .await?
    .encoded_2718();
    let (saved, blob, fee) = fixture.save_forced_inclusion(&payload).await?;
    assert_eq!(fee, U256::from(1_000_000_000u64), "1 gwei with an empty queue");
    assert_eq!(fixture.forced_inclusion_state().await?, (0, 1));
    // Finalize the entry's L1 block, so the next block's anchor holds it.
    mine_l1_blocks(p, 3).await?;
    chain.forced_transactions.insert(0, blob.clone());
    chain.extend(&fixture, 6).await?;
    let forced = |height: usize| {
        abci::EtnaEnvelope::decode(&chain.blocks[height - 1].block.data[0]).map(|e| e.forced)
    };
    let witness = forced(3)?.context("block 3 consumes the entry")?;
    assert_eq!(witness.index, 0);
    assert!(witness.tx.is_empty());
    assert_eq!(
        abci::EtnaEnvelope::decode(&chain.blocks[2].block.data[0])?.block.transactions[0],
        blob
    );
    assert!(chain.anchors[3].number >= saved.block_number.context("save block")?);
    assert_eq!((forced(2)?, forced(4)?), (None, None));

    let request = chain.prepare(&fixture, 6, SidecarMode::Eip7594).await?;
    assert_eq!(request.batch.snapshot.forced_inclusion_head, 0);
    assert_eq!(request.batch.input.forcedInclusionHead, U256::from(1));
    fixture.expect_statement(request.batch.statement_hash).await?;
    let signed = sign(&fixture, &request).await?;
    assert_landed(&fixture, &request, &signed).await?;

    assert_eq!(fixture.forced_inclusion_state().await?, (1, 1));
    assert_eq!(
        p.get_balance(fixture.inbox).await?,
        fee,
        "landing never pays FI fees to its sender"
    );
    let before = p.get_balance(fixture.admin).await?;
    let sweep = transact(
        p,
        dev_signer().address(),
        fixture.inbox,
        EtnaInbox::sweepProtocolFeesCall {}.abi_encode(),
    )
    .await?;
    assert_eq!(
        sweep.decoded_log::<EtnaInbox::ProtocolFeesSwept>().context("treasury sweep")?.data.amount,
        fee
    );
    assert_eq!(p.get_balance(fixture.admin).await?, before + fee);
    assert_eq!(p.get_balance(fixture.inbox).await?, U256::ZERO);
    fixture.anvil.stop().await
}

#[tokio::test]
#[ignore = "requires Docker: actual Etna contracts on Osaka anvil"]
async fn lander_rejecting_verifier_rolls_back_checkpoint_signal_and_committees() -> Result<()> {
    let fixture = ContractFixture::deploy().await?;
    let mut chain = FixtureChain::new(&fixture).await?;
    chain.extend(&fixture, 6).await?;
    let request = chain.prepare(&fixture, 6, SidecarMode::Eip7594).await?;
    fixture.expect_statement(request.batch.statement_hash).await?;
    // Sign while estimation accepts the call, then change the verifier from a separate account.
    let signed = sign(&fixture, &request).await?;
    fixture.set_rejects(true).await?;
    transport(&fixture)?.broadcast(&signed).await?;
    let receipt = receipt(&fixture.anvil.provider, signed.hash).await?;
    assert!(!receipt.status());
    assert!(receipt.logs().is_empty(), "reverted call must remove all emitted protocol events");
    assert_eq!(fixture.checkpoint().await?, (0, fixture.genesis.genesis_hash));
    assert_eq!(
        view(
            &fixture.anvil.provider,
            fixture.inbox,
            EtnaInbox::genesisCommitteeRecordHashCall {},
            None
        )
        .await?,
        abci::committee::record_hash(fixture.params.l2_chain_id, &fixture.committee.record)
    );
    assert!(
        view(
            &fixture.anvil.provider,
            fixture.signal,
            SignalService::getCheckpointCall { _blockNumber: 6u64.try_into()? },
            None
        )
        .await
        .is_err()
    );
    let saved = view(
        &fixture.anvil.provider,
        fixture.signal,
        SignalService::getCheckpointCall { _blockNumber: 0u64.try_into()? },
        None,
    )
    .await?;
    assert_eq!(saved.blockHash, fixture.genesis.genesis_hash);
    fixture.anvil.stop().await
}

#[tokio::test]
#[ignore = "requires Docker: actual Etna contracts on Osaka anvil"]
async fn lander_competing_sender_partial_progress_keeps_original_signed_batch() -> Result<()> {
    competing_partial_progress(6, false).await
}

/// A competitor lands an off-grid prefix to c = 5 that consumed a forced inclusion entry at
/// height 3: the original's leaf at c carries the cursor after that entry.
#[tokio::test]
#[ignore = "requires Docker: actual Etna contracts on Osaka anvil"]
async fn lander_competing_off_grid_progress_past_a_forced_entry_keeps_original_batch() -> Result<()>
{
    competing_partial_progress(5, true).await
}

/// The original batch (0, 12] is signed, then another sender lands the prefix (0, c]. The
/// original's bytes stay valid unchanged and land (c, 12] (BATCH-6.3-10). With `forced`, block 3
/// consumes entry 0 inside (0, c].
async fn competing_partial_progress(c: u64, forced: bool) -> Result<()> {
    let fixture = ContractFixture::deploy().await?;
    let p = &fixture.anvil.provider;
    let mut chain = FixtureChain::new(&fixture).await?;
    let head = u64::from(forced);
    if forced {
        // As in the forced inclusion landing test: block 3's anchor holds the entry.
        chain.extend(&fixture, 2).await?;
        let payload = test_harness::sign_transfer(
            &fixture.l2.provider,
            &dev_signer(),
            alloy_primitives::Address::repeat_byte(0x45),
            U256::from(9),
            0,
        )
        .await?
        .encoded_2718();
        let (_, blob, _) = fixture.save_forced_inclusion(&payload).await?;
        mine_l1_blocks(p, 3).await?;
        chain.forced_transactions.insert(0, blob);
    }
    chain.extend(&fixture, 12).await?;
    assert_eq!(chain.forced_cursor(), head);
    let original = chain.prepare(&fixture, 12, SidecarMode::Eip7594).await?;
    assert_eq!(original.batch.input.forcedInclusionHead, U256::from(head));
    let signed = sign(&fixture, &original).await?;
    let bytes = signed.network_bytes.clone();
    let prefix = chain.prepare(&fixture, c, SidecarMode::Eip7594).await?;
    let other = RpcTransactionTransport::new(
        p.clone(),
        "59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d".parse()?,
        FEES,
    )?;
    fixture.expect_statement(prefix.batch.statement_hash).await?;
    let tx = other.sign(&prefix, &Bytes::from_static(&[0])).await?;
    other.broadcast(&tx).await?;
    assert!(receipt(p, tx.hash).await?.status());
    assert_eq!(fixture.checkpoint().await?.0, c);
    // One leaf per interior height: the original's leaf at c sits at index c-p-1 and recomputes
    // from c's record, whose head is the cursor after c (ENC-A-29).
    let at_c =
        view(p, fixture.inbox, EtnaInbox::landingsCall { _height: U256::from(c) }, None).await?;
    assert_eq!(original.batch.leaves.len(), 11);
    assert_eq!(
        (at_c.elHash, at_c.cometHash, at_c.head.to::<u64>()),
        (prefix.batch.input.lastBlockHash, prefix.batch.input.lastCometHash, head)
    );
    assert_eq!(
        original.batch.leaves[usize::try_from(c - 1)?],
        lander::statement::cut_leaf(c, at_c.elHash, at_c.cometHash, at_c.head.to::<u64>())
    );
    fixture.expect_statement(original.batch.statement_hash).await?;
    transport(&fixture)?.broadcast(&signed).await?;
    let landed = receipt(p, signed.hash).await?;
    assert!(landed.status());
    let event = landed.decoded_log::<EtnaInbox::Landed>().context("overlap landed")?;
    assert_eq!(
        (event.data.parentHeight, event.data.checkpointHeight, event.data.lastHeight),
        (U256::ZERO, U256::from(c), U256::from(12))
    );
    assert_eq!(signed.network_bytes, bytes);
    assert_eq!(fixture.checkpoint().await?.0, 12);
    assert_eq!(fixture.forced_inclusion_state().await?, (head, head));
    fixture.anvil.stop().await
}

#[tokio::test]
#[ignore = "requires Docker: actual statement-bound verifier"]
async fn lander_statement_mismatch_is_refused_before_broadcast() -> Result<()> {
    let fixture = ContractFixture::deploy().await?;
    let mut chain = FixtureChain::new(&fixture).await?;
    chain.extend(&fixture, 6).await?;
    let request = chain.prepare(&fixture, 6, SidecarMode::Eip7594).await?;
    fixture.expect_statement(B256::repeat_byte(0xee)).await?;
    let before = transport(&fixture)?.nonce_state().await?;
    assert!(transport(&fixture)?.sign(&request, &Bytes::from(vec![0])).await.is_err());
    assert_eq!(transport(&fixture)?.nonce_state().await?, before);
    assert_eq!(fixture.checkpoint().await?, (0, fixture.genesis.genesis_hash));
    assert_eq!(
        view(
            &fixture.anvil.provider,
            fixture.inbox,
            EtnaInbox::genesisCommitteeRecordHashCall {},
            None
        )
        .await?,
        abci::committee::record_hash(fixture.params.l2_chain_id, &fixture.committee.record)
    );
    fixture.anvil.stop().await
}
