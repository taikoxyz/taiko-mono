//! An actual blob transaction whose L1 reference crosses the BLOCKHASH/EIP-2935 boundary while
//! pending. Journal restart and receipt-reorg recovery are covered by the runner and store unit
//! tests and by the CLI SIGKILL scenario.
mod support;

use alloy_consensus::Transaction;
use alloy_primitives::{B256, Bytes, U256, address, keccak256};
use alloy_provider::Provider;
use anyhow::{Context, Result};
use lander::{
    SidecarMode,
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
#[ignore = "requires Docker: pending reference crosses BLOCKHASH/EIP-2935 boundary"]
async fn lander_pending_reference_crosses_blockhash_window() -> Result<()> {
    let fixture = ContractFixture::deploy().await?;
    let p = &fixture.anvil.provider;
    let mut chain = FixtureChain::new(&fixture).await?;
    chain.extend(&fixture, 6).await?;
    let request = chain.prepare(&fixture, 6, SidecarMode::Eip7594).await?;
    fixture.expect_statement(request.batch.statement_hash).await?;
    let reference = request.batch.input.l1ReferenceBlockNumber.to::<u64>();
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
    assert_eq!(fixture.checkpoint().await?, (6, request.batch.input.lastBlockHash));
    assert_eq!(transport(&fixture)?.nonce_state().await?.confirmed, original_nonce + 1);
    assert_eq!(transaction.network_bytes, original_bytes);
    let included =
        p.get_transaction_by_hash(original_hash).await?.context("included transaction")?;
    assert_eq!(included.inner.nonce(), original_nonce);
    assert_eq!(included.inner.input().as_ref(), lander::tx::land_calldata(&request.batch, &proof));
    assert_eq!(
        included.inner.blob_versioned_hashes(),
        Some(request.batch.blobs.versioned_hashes.as_slice())
    );
    fixture.anvil.stop().await
}
