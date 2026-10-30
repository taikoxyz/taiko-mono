//! Actual pinned-contract landing scenarios. Docker scenarios use real Osaka blob transactions.
mod support;

use alloy::{
    consensus::Transaction, rpc::types::TransactionReceipt, signers::SignerSync, sol_types::SolCall,
};
use alloy_consensus::{
    SignableTransaction, TxEip4844, TxEip4844Variant, TxEip4844WithSidecar, TxEnvelope,
};
use alloy_eips::eip2718::Encodable2718;
use alloy_primitives::{B256, Bytes, U256};
use alloy_provider::Provider;
use alloy_rpc_types::TransactionRequest;
use anyhow::{Context, Result};
use lander::{
    DummyProofProvider, ProofProvider, ProofRequest, SidecarMode,
    contracts::IEtnaInbox::landCall,
    runner::ran_out_of_gas,
    tx::{
        FeeCaps, RpcTransactionTransport, SignedTransaction, TransactionTransport, land_calldata,
    },
};
use support::{
    ContractFixture,
    contracts::{
        EPOCH_LEN, EtnaInbox, EtnaStakingRegistry, SignalService, receipt, transact, view,
    },
    fixtures::FixtureChain,
};
use test_harness::{anvil_request, dev_signer, mine_l1_blocks};

/// The transport's fee caps.
const FEES: FeeCaps = FeeCaps {
    max_fee_per_gas: 20_000_000_000,
    max_priority_fee_per_gas: 1_000_000_000,
    max_fee_per_blob_gas: 20_000_000_000,
};

fn transport(fixture: &ContractFixture) -> Result<RpcTransactionTransport> {
    Ok(RpcTransactionTransport::new(fixture.anvil.provider.clone(), dev_signer(), FEES)?)
}

/// Signs `request`'s landing as the production signer does, except that the gas limit is the
/// deliberately insufficient execution gas. Returns the normal estimate too.
async fn sign_with_insufficient_gas(
    fixture: &ContractFixture,
    request: &ProofRequest,
    proof: &Bytes,
) -> Result<(u64, SignedTransaction)> {
    let p = &fixture.anvil.provider;
    let sender = dev_signer().address();
    let batch = &request.batch;
    let mut tx = TxEip4844 {
        chain_id: p.get_chain_id().await?,
        nonce: p.get_transaction_count(sender).await?,
        gas_limit: 0,
        max_fee_per_gas: FEES.max_fee_per_gas,
        max_priority_fee_per_gas: FEES.max_priority_fee_per_gas,
        to: fixture.inbox,
        value: U256::ZERO,
        access_list: Default::default(),
        blob_versioned_hashes: batch.blobs.versioned_hashes.clone(),
        max_fee_per_blob_gas: FEES.max_fee_per_blob_gas,
        input: land_calldata(batch, proof).into(),
    };
    let mut estimate = TransactionRequest::from_transaction(tx.clone()).from(sender);
    estimate.gas = None;
    let estimated = p.estimate_gas(estimate).await?;
    tx.gas_limit = estimated * 3 / 4;
    let variant: TxEip4844Variant =
        TxEip4844WithSidecar::from_tx_and_sidecar(tx.clone(), batch.blobs.sidecar.clone()).into();
    let signature = dev_signer().sign_hash_sync(&variant.signature_hash())?;
    let signed = variant.into_signed(signature);
    let hash = *signed.hash();
    let network_bytes = TxEnvelope::Eip4844(signed).encoded_2718().into();
    Ok((estimated, SignedTransaction { network_bytes, hash, sender, nonce: tx.nonce }))
}

/// Lands the fixture through `last`, visiting derivation and late-epoch checkpoints to
/// exercise historical committee reconstruction before the next test extends the range.
async fn land_through(
    fixture: &ContractFixture,
    chain: &mut FixtureChain,
    last: u64,
) -> Result<()> {
    assert!(last <= EPOCH_LEN);
    for cut in (6..=last).step_by(6) {
        mine_l1_blocks(&fixture.anvil.provider, 3).await?;
        chain.extend(fixture, cut).await?;
        let request = chain.prepare(fixture, cut, SidecarMode::Eip7594).await?;
        fixture.expect_statement(request.batch.statement_hash).await?;
        assert_landed(fixture, &request, &sign(fixture, &request).await?).await?;
    }
    Ok(())
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
    assert_eq!(first.batch.committees.len(), 1);
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
    // A later prefix crosses the epoch boundary and lands in one batch.
    let h = schedule.h_first(1);
    for last in [18, 24] {
        mine_l1_blocks(p, 3).await?;
        chain.extend(&fixture, last).await?;
        assert!(chain.anchors[usize::try_from(switch_height)?].number >= exit_block);
        let next = chain.prepare(&fixture, last, SidecarMode::Eip7594).await?;
        assert_eq!(next.batch.input.lastHeight, last);
        assert_eq!(
            next.batch.input.activeCommitteeSnapshot,
            if last < h { fixture.genesis.genesis_cutoff } else { immutable_snapshot }
        );
        let incoming = next
            .batch
            .committee_witnesses
            .iter()
            .find(|c| c.witness.record.target_epoch == 1)
            .context("incoming epoch")?;
        assert_eq!(incoming.witness.record.cutoff_l1_block, immutable_snapshot);
        assert_eq!(
            incoming.derivation_parent.as_ref().context("D header")?.number,
            derivation_height
        );
        if last == 18 {
            assert_eq!(next.batch.snapshot.checkpoint_height, derivation_height);
            let later_anchor = &chain.anchors[usize::try_from(switch_height)?];
            assert_eq!(incoming.anchor.number, later_anchor.number);
            assert_eq!(incoming.anchor.hash, later_anchor.hash);
            assert!(incoming.anchor.number > immutable_snapshot);
            let witness = &incoming.witness;
            assert_eq!(
                witness.registry.storage.iter().map(|word| word.slot).collect::<Vec<_>>(),
                abci::committee::snapshot_slots(witness.record.checkpoint_index, true),
                "historical snapshot retains selected checkpoint and successor trace proofs"
            );
            let storage = &witness.registry.storage;
            let selected_l1 = abci::l1::layout::word_u48(storage[1].value, 0);
            let next_l1 = abci::l1::layout::word_u48(storage[3].value, 0);
            assert!(selected_l1 <= immutable_snapshot);
            assert!(immutable_snapshot < next_l1);
            assert!(next_l1 <= incoming.anchor.number);
            assert!(storage[0].value > U256::from(witness.record.checkpoint_index) + U256::from(1));
        }
        fixture.expect_statement(next.batch.statement_hash).await?;
        assert_landed(&fixture, &next, &sign(&fixture, &next).await?).await?;
    }
    fixture.anvil.stop().await
}

/// An underfunded execution attempt consumes its nonce but leaves the checkpoint untouched;
/// rebuilding retains ordinary gas estimation and lands at the next nonce.
#[tokio::test]
#[ignore = "requires Docker: actual Etna contracts on Osaka anvil"]
async fn lander_out_of_gas_landing_is_rebuilt_and_lands() -> Result<()> {
    let fixture = ContractFixture::deploy().await?;
    let p = &fixture.anvil.provider;
    let mut chain = FixtureChain::new(&fixture).await?;
    land_through(&fixture, &mut chain, 12).await?;
    mine_l1_blocks(p, 3).await?;
    chain.extend(&fixture, 18).await?;
    let request = chain.prepare(&fixture, 18, SidecarMode::Eip7594).await?;
    fixture.expect_statement(request.batch.statement_hash).await?;
    let proof = Bytes::from(vec![0]);
    let production = transport(&fixture)?.sign(&request, &proof).await?;
    let (estimated, bare) = sign_with_insufficient_gas(&fixture, &request, &proof).await?;
    assert_eq!(production.gas_limit()?, estimated + estimated.div_ceil(5));
    let before: String = anvil_request(p, "evm_snapshot", serde_json::json!([])).await?;
    assert_landed(&fixture, &request, &production).await?;
    assert!(anvil_request::<bool>(p, "evm_revert", serde_json::json!([before])).await?);
    transport(&fixture)?.broadcast(&bare).await?;
    let failed = receipt(p, bare.hash).await?;
    assert!(!failed.status());
    assert!(ran_out_of_gas(failed.gas_used, bare.gas_limit()?));
    assert_eq!(fixture.checkpoint().await?.0, 12);
    let rebuilt = chain.prepare(&fixture, 18, SidecarMode::Eip7594).await?;
    fixture.expect_statement(rebuilt.batch.statement_hash).await?;
    let signed = sign(&fixture, &rebuilt).await?;
    assert_eq!(signed.nonce, bare.nonce + 1);
    assert_landed(&fixture, &rebuilt, &signed).await?;
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
    let fixture = ContractFixture::deploy().await?;
    let mut chain = FixtureChain::new(&fixture).await?;
    chain.extend(&fixture, 12).await?;
    let original = chain.prepare(&fixture, 12, SidecarMode::Eip7594).await?;
    let signed = sign(&fixture, &original).await?;
    let bytes = signed.network_bytes.clone();
    let prefix = chain.prepare(&fixture, 6, SidecarMode::Eip7594).await?;
    let other = RpcTransactionTransport::new(
        fixture.anvil.provider.clone(),
        "59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d".parse()?,
        FEES,
    )?;
    fixture.expect_statement(prefix.batch.statement_hash).await?;
    let tx = other.sign(&prefix, &Bytes::from_static(&[0])).await?;
    other.broadcast(&tx).await?;
    assert!(receipt(&fixture.anvil.provider, tx.hash).await?.status());
    assert_eq!(fixture.checkpoint().await?.0, 6);
    fixture.expect_statement(original.batch.statement_hash).await?;
    transport(&fixture)?.broadcast(&signed).await?;
    let landed = receipt(&fixture.anvil.provider, signed.hash).await?;
    assert!(landed.status());
    let event = landed.decoded_log::<EtnaInbox::Landed>().context("overlap landed")?;
    assert_eq!(
        (event.data.parentHeight, event.data.checkpointHeight, event.data.lastHeight),
        (U256::ZERO, U256::from(6), U256::from(12))
    );
    assert_eq!(signed.network_bytes, bytes);
    assert_eq!(fixture.checkpoint().await?.0, 12);
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
