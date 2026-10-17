//! Actual pinned-contract landing scenarios. Docker scenarios use real Osaka blob transactions.
mod support;

use alloy::{
    consensus::Transaction, rpc::types::TransactionReceipt, signers::SignerSync, sol_types::SolCall,
};
use alloy_consensus::{
    SignableTransaction, TxEip4844, TxEip4844Variant, TxEip4844WithSidecar, TxEnvelope,
};
use alloy_eips::{BlockId, eip2718::Encodable2718};
use alloy_primitives::{B256, Bytes, U256, aliases::U48};
use alloy_provider::Provider;
use alloy_rpc_types::TransactionRequest;
use anyhow::{Context, Result};
use lander::{
    DummyProofProvider, ProofProvider, ProofRequest, SidecarMode,
    contracts::IEtnaInbox::landCall,
    runner::{ran_out_of_gas, successful_landing},
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
    let schedule = abci::Schedule::from_genesis(&fixture.genesis);
    let derivation_height = schedule.derivation_parent_height(1).context("D height")?;
    let mut cuts = vec![5, derivation_height];
    cuts.extend(derivation_height + 1..=last);
    for cut in cuts {
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
    let event = receipt.decoded_log::<EtnaInbox::BatchLanded>().context("BatchLanded event")?;
    assert_eq!(event.data.statementHash, request.batch.statement_hash);
    assert_eq!(event.data.lastHeight, request.batch.input.lastHeight);
    assert_eq!(event.data.lander, dev_signer().address());
    let batch = &request.batch;
    assert_eq!(
        view(p, fixture.inbox, EtnaInbox::activeCommitteeSnapshotCall {}, None).await?,
        batch.input.activeCommitteeSnapshot
    );
    let reward = lander::rewards::Receipt {
        l1ChainId: batch.snapshot.l1_chain_id,
        l2ChainId: batch.snapshot.l2_chain_id,
        inbox: batch.snapshot.inbox,
        generation: batch.snapshot.generation,
        parentHeight: batch.snapshot.checkpoint_height,
        parentHash: batch.snapshot.checkpoint_hash,
        lastHeight: batch.input.lastHeight,
        lastBlockHash: batch.input.lastBlockHash,
        l2RewardRecipient: batch.input.l2RewardRecipient,
        baseFeeAmount: batch.input.baseFeeAmount,
    };
    let id = lander::rewards::batch_id(&reward);
    let event = receipt
        .decoded_log::<lander::contracts::BatchRewardRecorded>()
        .context("BatchRewardRecorded")?;
    assert_eq!(event.data.batchId, id);
    let summary = successful_landing(
        batch,
        &lander::tx::LandingReceipt {
            transaction_hash: receipt.transaction_hash,
            block_number: receipt.block_number.context("landing block number")?,
            block_hash: receipt.block_hash.context("landing block hash")?,
            success: receipt.status(),
            gas_used: receipt.gas_used,
        },
    )
    .context("successful own reward summary")?;
    assert_eq!(summary.batch_id, event.data.batchId);
    assert_eq!(summary.reward, reward);
    assert_eq!(event.data.l2RewardRecipient, reward.l2RewardRecipient);
    assert_eq!(event.data.baseFeeAmount, reward.baseFeeAmount);
    assert_eq!(event.data.parentHeight, reward.parentHeight);
    assert_eq!(event.data.lastHeight, reward.lastHeight);
    assert_eq!(
        view(p, fixture.inbox, EtnaInbox::rewardCommitmentsCall { batchId: id }, None).await?,
        lander::rewards::commitment(&reward)
    );
    assert_eq!(
        p.get_storage_at(
            fixture.inbox,
            U256::from_be_slice(lander::rewards::receipt_slot(id).as_slice())
        )
        .await?,
        U256::from_be_slice(lander::rewards::commitment(&reward).as_slice())
    );
    let tx = p.get_transaction_by_hash(hash).await?.context("landing transaction")?;
    assert_eq!(
        tx.inner.blob_versioned_hashes(),
        Some(request.batch.blobs.versioned_hashes.as_slice())
    );
    let decoded = landCall::abi_decode(tx.inner.input())?;
    assert_eq!(decoded._proof.as_ref(), &[0]);
    assert_eq!(decoded._input, request.batch.input);
    assert_eq!(
        fixture.checkpoint().await?,
        (request.batch.input.lastHeight, request.batch.input.lastBlockHash)
    );
    let saved = view(
        p,
        fixture.signal,
        SignalService::getCheckpointCall {
            _blockNumber: request.batch.input.lastHeight.try_into()?,
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
    chain.extend(&fixture, 5).await?;
    let first = chain.prepare(&fixture, 5, SidecarMode::Eip7594).await?;
    assert_eq!(first.batch.committees.len(), 1);
    fixture.expect_statement(first.batch.statement_hash).await?;
    let signed = sign(&fixture, &first).await?;
    assert_landed(&fixture, &first, &signed).await?;
    // Land exactly D, then mutate the registry after the immutable derivation snapshot.
    let schedule = abci::Schedule::from_genesis(&fixture.genesis);
    let derivation_height = schedule.derivation_parent_height(1).context("D height")?;
    let switch_height = schedule.h_first(1) - 2;
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
    // A later prefix crosses the epoch boundary without a reward-freeze cut.
    let h = schedule.h_first(1);
    for last in [switch_height, h + 2] {
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
        if last > switch_height {
            assert_eq!(next.batch.snapshot.checkpoint_height, switch_height);
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
            let selected_l1 = abci::l1::layout::word_u64(storage[1].value, 0);
            let next_l1 = abci::l1::layout::word_u64(storage[3].value, 0);
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
    land_through(&fixture, &mut chain, EPOCH_LEN).await?;
    mine_l1_blocks(p, 3).await?;
    chain.extend(&fixture, EPOCH_LEN + 1).await?;
    let request = chain.prepare(&fixture, EPOCH_LEN + 1, SidecarMode::Eip7594).await?;
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
    assert_eq!(fixture.checkpoint().await?.0, EPOCH_LEN);
    let rebuilt = chain.prepare(&fixture, EPOCH_LEN + 1, SidecarMode::Eip7594).await?;
    fixture.expect_statement(rebuilt.batch.statement_hash).await?;
    let signed = sign(&fixture, &rebuilt).await?;
    assert_eq!(signed.nonce, bare.nonce + 1);
    assert_landed(&fixture, &rebuilt, &signed).await?;
    fixture.anvil.stop().await
}

/// A user stores a forced inclusion on the real Inbox; the decided chain's next block after its
/// L1 block is final consumes it with a real entry proof and its blob, and landing that batch moves
/// the queue head and pays the entry's fee to the batch's `feeRecipient`, the lander's sending
/// address.
#[tokio::test]
#[ignore = "requires Docker: actual Etna contracts on Osaka anvil"]
async fn lander_actual_contract_forced_inclusion_lands_and_pays_fee() -> Result<()> {
    let fixture = ContractFixture::deploy().await?;
    let p = &fixture.anvil.provider;
    let mut chain = FixtureChain::new(&fixture).await?;
    chain.extend(&fixture, 2).await?;

    // A one-block Shasta source; the lander checks the blob's binding, not its transactions.
    use alloy_consensus::{SignableTransaction, TxEnvelope, TxLegacy};
    use alloy_eips::eip2718::Encodable2718;
    let payload = TxEnvelope::Legacy(
        TxLegacy { gas_limit: 21_000, ..Default::default() }
            .into_signed(alloy_primitives::Signature::new(U256::from(1), U256::from(1), false)),
    )
    .encoded_2718();
    let (saved, blob, fee) = fixture.save_forced_inclusion(&payload).await?;
    assert_eq!(fee, U256::from(1_000_000_000u64), "1 gwei with an empty queue");
    assert_eq!(fixture.forced_inclusion_state().await?, (0, 1));
    // Finalize the entry's L1 block, so the next block's anchor holds it.
    mine_l1_blocks(p, 3).await?;
    chain.forced_transactions.insert(0, blob.clone());
    chain.extend(&fixture, 4).await?;
    let forced = |height: usize| {
        abci::EtnaEnvelope::decode(&chain.blocks[height - 1].block.data[0]).map(|e| e.forced)
    };
    let witness = forced(3)?.context("block 3 consumes the entry")?;
    assert_eq!((witness.index, &witness.tx), (0, &blob));
    assert!(chain.anchors[3].number >= saved.block_number.context("save block")?);
    assert_eq!((forced(2)?, forced(4)?), (None, None));

    let request = chain.prepare(&fixture, 4, SidecarMode::Eip7594).await?;
    assert_eq!(request.batch.snapshot.forced_inclusion_head, 0);
    assert_eq!(request.batch.input.forcedInclusionHead, U48::from(1));
    let lander = dev_signer().address();
    let recipient = request.batch.input.feeRecipient;
    assert_eq!(recipient, lander, "the lander names its sending address");
    fixture.expect_statement(request.batch.statement_hash).await?;
    let signed = sign(&fixture, &request).await?;
    assert_landed(&fixture, &request, &signed).await?;

    let landed = receipt(p, signed.hash).await?;
    let event = landed
        .decoded_log::<EtnaInbox::ForcedInclusionsConsumed>()
        .context("ForcedInclusionsConsumed event")?;
    assert_eq!(
        (event.data.headBefore, event.data.headAfter, event.data.feesWei, event.data.recipient),
        (U48::from(0), U48::from(1), fee, recipient)
    );
    assert_eq!(fixture.forced_inclusion_state().await?, (1, 1));
    // The recipient (here the sender) moves by the fee less what the landing transaction cost.
    let block = landed.block_number.context("landing block")?;
    let balance = |number| async move {
        anyhow::Ok(p.get_balance(recipient).block_id(BlockId::number(number)).await?)
    };
    let cost = U256::from(landed.gas_used) * U256::from(landed.effective_gas_price) +
        U256::from(landed.blob_gas_used.context("blob gas")?) *
            U256::from(landed.blob_gas_price.context("blob gas price")?);
    assert_eq!(balance(block).await? + cost, balance(block - 1).await? + fee);
    fixture.anvil.stop().await
}

#[tokio::test]
#[ignore = "requires Docker: actual Etna contracts on Osaka anvil"]
async fn lander_rejecting_verifier_rolls_back_checkpoint_signal_and_committees() -> Result<()> {
    let fixture = ContractFixture::deploy().await?;
    let mut chain = FixtureChain::new(&fixture).await?;
    chain.extend(&fixture, 3).await?;
    let request = chain.prepare(&fixture, 3, SidecarMode::Eip7594).await?;
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
            SignalService::getCheckpointCall { _blockNumber: 3u64.try_into()? },
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
async fn lander_competing_sender_partial_progress_reverts_obsolete_batch() -> Result<()> {
    let fixture = ContractFixture::deploy().await?;
    let mut chain = FixtureChain::new(&fixture).await?;
    chain.extend(&fixture, 5).await?;
    let obsolete = chain.prepare(&fixture, 5, SidecarMode::Eip7594).await?;
    let loser = sign(&fixture, &obsolete).await?;
    let winner = chain.prepare(&fixture, 3, SidecarMode::Eip7594).await?;
    // The public land function accepts another account with exactly the same required proof.
    let key = "59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d".parse()?;
    let other = RpcTransactionTransport::new(
        fixture.anvil.provider.clone(),
        key,
        FeeCaps {
            max_fee_per_gas: 20_000_000_000,
            max_priority_fee_per_gas: 1_000_000_000,
            max_fee_per_blob_gas: 20_000_000_000,
        },
    )?;
    assert_eq!(other.sender(), fixture.admin);
    // The dummy verifier must bind the exact statement to model a real proof's parent binding.
    fixture.expect_statement(winner.batch.statement_hash).await?;
    let proof = Bytes::from(vec![0]);
    let transaction = other.sign(&winner, &proof).await?;
    other.broadcast(&transaction).await?;
    assert!(receipt(&fixture.anvil.provider, transaction.hash).await?.status());
    transport(&fixture)?.broadcast(&loser).await?;
    assert!(!receipt(&fixture.anvil.provider, loser.hash).await?.status());
    assert_eq!(fixture.checkpoint().await?, (3, winner.batch.input.lastBlockHash));
    let rebuilt = chain.prepare(&fixture, 5, SidecarMode::Eip7594).await?;
    assert_eq!(rebuilt.batch.committees.len(), 1, "starting context is independently derived");
    fixture.expect_statement(rebuilt.batch.statement_hash).await?;
    let signed = sign(&fixture, &rebuilt).await?;
    assert!(signed.nonce > loser.nonce, "the old nonce must settle before a new transaction");
    assert_landed(&fixture, &rebuilt, &signed).await?;
    fixture.anvil.stop().await
}

#[tokio::test]
#[ignore = "requires Docker: actual statement-bound verifier"]
async fn lander_statement_mismatch_is_refused_before_broadcast() -> Result<()> {
    let fixture = ContractFixture::deploy().await?;
    let mut chain = FixtureChain::new(&fixture).await?;
    chain.extend(&fixture, 3).await?;
    let request = chain.prepare(&fixture, 3, SidecarMode::Eip7594).await?;
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
