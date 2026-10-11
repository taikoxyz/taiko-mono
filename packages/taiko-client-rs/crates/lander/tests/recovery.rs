//! Actual blob transaction and durable journal recovery using fully host-validated signed fixtures.
mod support;

use alloy::sol_types::SolCall;
use alloy_consensus::Transaction;
use alloy_primitives::{B256, Bytes, U256, address, keccak256};
use alloy_provider::Provider;
use anyhow::{Context, Result};
use lander::{
    SidecarMode,
    contracts::IEtnaInbox::landCall,
    store::{JournalIdentity, JournalState, ProvedJob, Store},
    tx::{FeeCaps, RpcTransactionTransport, TransactionTransport},
};
use support::{ContractFixture, fixtures::FixtureChain};
use test_harness::{anvil_request, dev_signer, mine_l1_blocks};

fn transport(f: &ContractFixture) -> Result<RpcTransactionTransport> {
    Ok(RpcTransactionTransport::new(
        f.anvil.provider.clone(),
        dev_signer(),
        FeeCaps {
            max_fee_per_gas: 20_000_000_000,
            max_priority_fee_per_gas: 1_000_000_000,
            max_fee_per_blob_gas: 20_000_000_000,
        },
    )?)
}

#[tokio::test]
#[ignore = "requires Docker: actual signed blob transaction restart"]
async fn lander_signed_and_pending_journal_restart_rebroadcasts_identical_bytes() -> Result<()> {
    let fixture = ContractFixture::deploy().await?;
    let mut chain = FixtureChain::new(&fixture).await?;
    chain.extend(&fixture, 3).await?;
    let request = chain.prepare(&fixture, 3, SidecarMode::Eip7594).await?;
    fixture.expect_statement(request.batch.statement_hash).await?;
    let proof = Bytes::from(vec![0]);
    let tx = transport(&fixture)?.sign(&request, &proof).await?;
    let dir = tempfile::tempdir()?;
    let identity = JournalIdentity {
        l1_chain_id: request.batch.snapshot.l1_chain_id,
        l2_chain_id: request.batch.snapshot.l2_chain_id,
        inbox: fixture.inbox,
        registry: fixture.registry,
        sender: dev_signer().address(),
    };
    let store = Store::open(dir.path(), identity.clone())?;
    store.save(&JournalState::Signed {
        job: Box::new(ProvedJob { request: request.clone(), proof: proof.clone() }),
        transaction: tx.clone(),
    })?;
    drop(store);
    let reopened = Store::open(dir.path(), identity.clone())?;
    let JournalState::Signed { job, transaction } = reopened.load()? else {
        panic!("signed phase lost");
    };
    assert_eq!(transaction.network_bytes, tx.network_bytes);
    assert!(!transport(&fixture)?.known(tx.hash).await?);
    anvil_request::<serde_json::Value>(
        &fixture.anvil.provider,
        "evm_setAutomine",
        serde_json::json!([false]),
    )
    .await?;
    reopened.save(&JournalState::Pending { job: job.clone(), transaction: transaction.clone() })?;
    transport(&fixture)?.broadcast(&transaction).await?;
    assert!(transport(&fixture)?.receipt(tx.hash).await?.is_none());
    drop(reopened);
    let reopened = Store::open(dir.path(), identity)?;
    let JournalState::Pending { transaction: recovered, .. } = reopened.load()? else {
        panic!("pending phase lost");
    };
    let nonce = transport(&fixture)?.nonce_state().await?;
    assert_eq!(nonce.confirmed, tx.nonce);
    assert_eq!(nonce.pending, tx.nonce + 1);
    assert_eq!(transport(&fixture)?.broadcast(&recovered).await?, tx.hash);
    mine_l1_blocks(&fixture.anvil.provider, 1).await?;
    assert!(support::contracts::receipt(&fixture.anvil.provider, tx.hash).await?.status());
    assert_eq!(fixture.checkpoint().await?, (3, request.batch.input.lastBlockHash));
    assert_eq!(transport(&fixture)?.nonce_state().await?.confirmed, tx.nonce + 1);
    drop(reopened);
    fixture.anvil.stop().await
}

#[tokio::test]
#[ignore = "requires Docker: actual receipt reorg and identical transaction resume"]
async fn lander_receipt_reorg_rebroadcasts_the_original_signed_transaction() -> Result<()> {
    let fixture = ContractFixture::deploy().await?;
    let p = &fixture.anvil.provider;
    let mut chain = FixtureChain::new(&fixture).await?;
    chain.extend(&fixture, 3).await?;
    let request = chain.prepare(&fixture, 3, SidecarMode::Eip7594).await?;
    fixture.expect_statement(request.batch.statement_hash).await?;
    let transaction = transport(&fixture)?.sign(&request, &Bytes::from(vec![0])).await?;
    let snap: String = anvil_request(p, "evm_snapshot", serde_json::json!([])).await?;
    transport(&fixture)?.broadcast(&transaction).await?;
    let first = support::contracts::receipt(p, transaction.hash).await?;
    assert!(first.status());
    assert_eq!(fixture.checkpoint().await?.0, 3);
    assert!(anvil_request::<bool>(p, "evm_revert", serde_json::json!([snap])).await?);
    assert_eq!(fixture.checkpoint().await?.0, 0);
    assert!(transport(&fixture)?.receipt(transaction.hash).await?.is_none());
    assert_eq!(transport(&fixture)?.nonce_state().await?.confirmed, transaction.nonce);
    anvil_request::<serde_json::Value>(p, "evm_increaseTime", serde_json::json!([30])).await?;
    assert_eq!(transport(&fixture)?.broadcast(&transaction).await?, transaction.hash);
    let second = support::contracts::receipt(p, transaction.hash).await?;
    assert!(second.status());
    assert_ne!(first.block_hash, second.block_hash);
    assert_eq!(fixture.checkpoint().await?, (3, request.batch.input.lastBlockHash));
    fixture.anvil.stop().await
}

#[tokio::test]
#[ignore = "requires Docker: pending reference crosses BLOCKHASH/EIP-2935 boundary"]
async fn lander_pending_reference_crosses_blockhash_window() -> Result<()> {
    let fixture = ContractFixture::deploy().await?;
    let p = &fixture.anvil.provider;
    let mut chain = FixtureChain::new(&fixture).await?;
    chain.extend(&fixture, 3).await?;
    let request = chain.prepare(&fixture, 3, SidecarMode::Eip7594).await?;
    fixture.expect_statement(request.batch.statement_hash).await?;
    let reference = request.batch.input.l1ReferenceBlockNumber;
    let reference_hash =
        keccak256(request.batch.reference_headers.first().context("reference header")?);
    let history = address!("0000f90827f1c53a10cb7a02335b175320002935");
    anvil_request::<serde_json::Value>(p, "evm_setAutomine", serde_json::json!([false])).await?;
    let head = p.get_block_number().await?;
    assert!(head <= reference + 255);
    mine_l1_blocks(p, reference + 255 - head).await?;
    assert_eq!(p.get_block_number().await?, reference + 255);
    assert_eq!(
        B256::from(p.get_storage_at(history, U256::from(reference % 8191)).await?),
        reference_hash
    );
    let proof = Bytes::from(vec![0]);
    // The production signer estimates while BLOCKHASH still resolves the reference. Do not
    // pad the test transaction or replace its fees after the signer produces these bytes.
    let transaction = transport(&fixture)?.sign(&request, &proof).await?;
    transaction.validate(&request, &proof)?;
    let original_bytes = transaction.network_bytes.clone();
    let original_hash = transaction.hash;
    let original_nonce = transaction.nonce;
    // Hold the signature across one further empty block before broadcasting. Inclusion in
    // the following block resolves the very same reference via the more expensive history call.
    mine_l1_blocks(p, 1).await?;
    assert_eq!(p.get_block_number().await?, reference + 256);
    assert_eq!(
        B256::from(p.get_storage_at(history, U256::from(reference % 8191)).await?),
        reference_hash
    );
    assert_eq!(transport(&fixture)?.broadcast(&transaction).await?, original_hash);
    assert!(transport(&fixture)?.receipt(original_hash).await?.is_none());
    mine_l1_blocks(p, 1).await?;
    let mined = support::contracts::receipt(p, original_hash).await?;
    assert_eq!(mined.block_number.context("receipt height")? - reference, 257);
    assert!(
        mined.status(),
        "a canonical available reference must survive the resolver branch change; gas used {}",
        mined.gas_used
    );
    assert_eq!(fixture.checkpoint().await?, (3, request.batch.input.lastBlockHash));
    assert_eq!(transport(&fixture)?.nonce_state().await?.confirmed, original_nonce + 1);
    assert_eq!(transaction.network_bytes, original_bytes);
    let included =
        p.get_transaction_by_hash(original_hash).await?.context("included transaction")?;
    assert_eq!(included.inner.nonce(), original_nonce);
    assert_eq!(
        included.inner.input().as_ref(),
        landCall { _input: request.batch.input.clone(), _proof: proof }.abi_encode()
    );
    assert_eq!(
        included.inner.blob_versioned_hashes(),
        Some(request.batch.blobs.versioned_hashes.as_slice())
    );
    fixture.anvil.stop().await
}
