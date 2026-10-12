//! Actual pinned-contract landing scenarios. Docker scenarios use real Osaka blob transactions.
mod support;

use alloy::{consensus::Transaction, sol_types::SolCall};
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

fn transport(fixture: &ContractFixture) -> Result<RpcTransactionTransport> {
    Ok(RpcTransactionTransport::new(
        fixture.anvil.provider.clone(),
        dev_signer(),
        FeeCaps {
            max_fee_per_gas: 20_000_000_000,
            max_priority_fee_per_gas: 1_000_000_000,
            max_fee_per_blob_gas: 20_000_000_000,
        },
    )?)
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
) -> Result<()> {
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
    Ok(())
}

#[tokio::test]
#[ignore = "requires Docker: actual Etna contracts on Osaka anvil"]
async fn lander_actual_contract_blob_landing_and_cross_epoch() -> Result<()> {
    let fixture = ContractFixture::deploy().await?;
    let mut chain = FixtureChain::new(&fixture).await?;
    chain.extend(&fixture, 5).await?;
    let first = chain.prepare(&fixture, 5, SidecarMode::Eip7594).await?;
    assert_eq!(first.batch.committees.len(), 1);
    fixture.expect_statement(first.batch.statement_hash).await?;
    let signed = sign(&fixture, &first).await?;
    assert_landed(&fixture, &first, &signed).await?;
    // Land exactly D=6, then mutate the registry after the immutable derivation snapshot.
    mine_l1_blocks(&fixture.anvil.provider, 3).await?;
    chain.extend(&fixture, 6).await?;
    let derivation = chain.prepare(&fixture, 6, SidecarMode::Eip7594).await?;
    fixture.expect_statement(derivation.batch.statement_hash).await?;
    assert_landed(&fixture, &derivation, &sign(&fixture, &derivation).await?).await?;
    transact(
        &fixture.anvil.provider,
        dev_signer().address(),
        fixture.registry,
        EtnaStakingRegistry::requestExitCall { _bondId: U256::ZERO }.abi_encode(),
    )
    .await?;
    let immutable_snapshot = chain.anchors[6].number;
    // One-block cuts before/on/after S=7, S+1=8, H=9 and within epoch 1.
    for last in 7..=11 {
        mine_l1_blocks(&fixture.anvil.provider, 3).await?;
        chain.extend(&fixture, last).await?;
        let next = chain.prepare(&fixture, last, SidecarMode::Eip7594).await?;
        assert_eq!(next.batch.blocks.len(), 1);
        let incoming = next
            .batch
            .committee_witnesses
            .iter()
            .find(|c| c.witness.record.target_epoch == 1)
            .context("incoming epoch")?;
        assert_eq!(incoming.witness.record.cutoff_l1_block, immutable_snapshot);
        assert_eq!(incoming.derivation_parent.as_ref().context("D header")?.number, 6);
        if last > 7 {
            assert!(
                incoming.anchor.number > immutable_snapshot,
                "later root must reconstruct D snapshot"
            );
            assert!(
                incoming.witness.registry.storage.len() > 3,
                "historical selected/successor proofs retained"
            );
        }
        fixture.expect_statement(next.batch.statement_hash).await?;
        let signed = sign(&fixture, &next).await?;
        assert_landed(&fixture, &next, &signed).await?;
    }
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
