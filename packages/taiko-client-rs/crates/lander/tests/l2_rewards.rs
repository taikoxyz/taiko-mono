//! Real contract/proof/funds-flow acceptance. No storage planter or synthetic EL headers.
mod support;

use alloy::{rpc::types::TransactionRequest, signers::SignerSync, sol};
use alloy_consensus::{SignableTransaction, TxEip1559, TxEnvelope};
use alloy_eips::{BlockId, BlockNumberOrTag, eip2718::Encodable2718};
use alloy_primitives::{Address, B256, Bytes, U256};
use alloy_provider::Provider;
use anyhow::{Context, Result, ensure};
use lander::{
    LanderError, ProofRequest, SidecarMode,
    batch::{BatchBuilder, BatchBuilderConfig, BatchSource},
    claim::{
        runner::{ClaimOutcome, step},
        source::{ClaimSource, RpcClaimSource},
        store::{ClaimState, ClaimStore},
        tx::RpcClaimTransport,
    },
    comet::HttpCometSource,
    l1::{LandingSource, RpcLandingSource},
    tx::{FeeCaps, RpcTransactionTransport, TransactionTransport},
};
use std::{sync::Arc, time::Duration};
use support::{
    ContractFixture,
    contracts::{CONSENSUS_SEED, receipt},
    fixtures::limits,
};
use test_harness::{
    ContractConsensus, Fatal, ValidatorKey, dev_signer, mine_l1_blocks, send_transfer,
    set_interval_mining, wait_until,
};
sol!(Vault, "../../crates/lander/tests/fixtures/contracts/L2FeeVault.json");
const DEADLINE: Duration = Duration::from_secs(60);
const RECIPIENT: Address = Address::repeat_byte(0x88);

// Claim polls may wait for availability, but must never hide a permanent claim failure.
fn claim_poll<T>(result: lander::Result<T>) -> Result<Option<T>> {
    match result {
        Ok(value) => Ok(Some(value)),
        Err(LanderError::Temporary(_) | LanderError::Unavailable(_)) => Ok(None),
        Err(error) => Err(Fatal(error.into()).into()),
    }
}

async fn assert_claim_polling_preserves_permanent_errors() -> Result<()> {
    for permanent in [
        LanderError::Safety("authenticated contradiction".into()),
        LanderError::Configuration("wrong chain".into()),
        LanderError::Journal("journal unavailable".into()),
        LanderError::Reverted("permanent execution failure".into()),
        LanderError::Stale("obsolete claim work".into()),
        LanderError::Capacity("proof exceeds limit".into()),
        LanderError::Encoding("noncanonical proof".into()),
    ] {
        let expected_message = permanent.to_string();
        let expected_variant = std::mem::discriminant(&permanent);
        let mut script = [Err(permanent), Ok(())].into_iter();
        let mut calls = 0;
        let error = wait_until(
            "scripted permanent claim failure",
            Duration::from_secs(1),
            Duration::from_millis(1),
            || {
                calls += 1;
                let result = script.next().expect("permanent failure must stop polling");
                async move { claim_poll(result) }
            },
        )
        .await
        .expect_err("a later success must not mask a permanent claim failure");
        assert_eq!(calls, 1, "{expected_message}");
        let original = error
            .downcast_ref::<Fatal>()
            .context("permanent claim error must cross the actual wait boundary as Fatal")?
            .0
            .downcast_ref::<LanderError>()
            .context("Fatal must preserve the typed original claim error")?;
        assert_eq!(std::mem::discriminant(original), expected_variant);
        assert_eq!(original.to_string(), expected_message);
    }
    let mut script = [
        Err(LanderError::Temporary("endpoint recovering".into())),
        Err(LanderError::Unavailable("anchor lag".into())),
        Ok(42),
    ]
    .into_iter();
    let mut calls = 0;
    let value = wait_until(
        "scripted claim availability recovery",
        Duration::from_secs(1),
        Duration::from_millis(1),
        || {
            calls += 1;
            let result = script.next().expect("availability recovery takes three polls");
            async move { claim_poll(result) }
        },
    )
    .await?;
    assert_eq!(value, 42);
    assert_eq!(calls, 3);
    Ok(())
}

async fn land(f: &ContractFixture, c: &ContractConsensus) -> Result<(ProofRequest, B256)> {
    let source = Arc::new(RpcLandingSource::new(
        f.anvil.provider.clone(),
        f.l2.provider.clone(),
        f.params.clone(),
    ));
    let builder = BatchBuilder::new(
        Arc::new(HttpCometSource::new(c.cmt.url(), Duration::from_secs(10), 16 * 1024 * 1024)?),
        source.clone(),
        BatchBuilderConfig {
            params: f.params.clone(),
            limits: limits(),
            mode: SidecarMode::Eip7594,
            fee_recipient: f.admin,
            l2_reward_recipient: RECIPIENT,
            engine: Arc::new(f.l2.engine()?),
            engine_timeout: Duration::from_secs(10),
        },
    )?;
    let request =
        builder.prepare(source.snapshot().await?).await?.context("nonempty executed batch")?;
    f.expect_statement(request.batch.statement_hash).await?;
    let transport = RpcTransactionTransport::new(
        f.anvil.provider.clone(),
        dev_signer(),
        FeeCaps {
            max_fee_per_gas: 20_000_000_000,
            max_priority_fee_per_gas: 1_000_000_000,
            max_fee_per_blob_gas: 20_000_000_000,
        },
    )?;
    let tx = transport.sign(&request, &Bytes::from(vec![0])).await?;
    transport.broadcast(&tx).await?;
    let landed = receipt(&f.anvil.provider, tx.hash).await?;
    ensure!(landed.status(), "real landing reverted");
    let event = landed
        .decoded_log::<lander::contracts::BatchRewardRecorded>()
        .context("real reward event")?;
    assert_eq!(event.data.baseFeeAmount, request.batch.input.baseFeeAmount);
    assert_eq!(event.data.l2RewardRecipient, RECIPIENT);
    assert_eq!(f.checkpoint().await?.0, request.batch.input.lastHeight);
    eprintln!(
        "land tx={} range=({},{}] amount={} batch={}",
        tx.hash,
        request.batch.snapshot.checkpoint_height,
        request.batch.input.lastHeight,
        event.data.baseFeeAmount,
        event.data.batchId
    );
    Ok((request, tx.hash))
}

/// Reconstruct a landed EL prefix on a fresh node using only archived blobs and public L1
/// checkpoint fields. Dummy contract verification tests the data plumbing, not ZK soundness.
async fn recover_landed_execution(
    fixture: &ContractFixture,
    archived: &[alloy_eips::eip4844::Blob],
    checkpoint: &lander::contracts::IEtnaInbox::LandInput,
) -> Result<()> {
    use abci::{Engine, PayloadVerdict};
    let recovered =
        test_harness::StandaloneReth::start(&fixture.anvil.provider, fixture.inbox).await?;
    assert_eq!(recovered.genesis.hash, fixture.genesis.genesis_hash);
    assert!(recovered.provider.get_block_by_number(1.into()).await?.is_none());
    let limits = lander::Limits {
        max_blocks: 100,
        max_blobs: 6,
        max_payload_bytes: 6 * lander::blob::PAYLOAD_BYTES_PER_BLOB,
        max_message_bytes: 22_020_096,
        max_decompressed_bytes: 64 << 20,
    };
    let payload = lander::blob::decode(archived, &limits)?;
    let blocks = lander::codec::decode(&payload, &limits)?;
    let engine = recovered.engine()?;
    for published in &blocks {
        assert_eq!(engine.new_payload(&published.block).await?, PayloadVerdict::Valid);
        let hash = published.block.header.hash_slow();
        assert_eq!(engine.forkchoice(hash, hash, B256::ZERO).await?, PayloadVerdict::Valid);
    }
    let terminal =
        engine.header_by_number(checkpoint.lastHeight).await?.context("recovered EL head")?;
    assert_eq!(terminal.hash_slow(), checkpoint.lastBlockHash);
    assert_eq!(terminal.state_root, checkpoint.lastStateRoot);
    let mut tampered = blocks.last().context("published block")?.block.clone();
    tampered.header.state_root = B256::repeat_byte(0xee);
    assert_ne!(engine.new_payload(&tampered).await?, PayloadVerdict::Valid);
    recovered.stop().await
}

async fn fee_sum(f: &ContractFixture, from: u64, through: u64) -> Result<U256> {
    let mut sum = U256::ZERO;
    for h in from..=through {
        let b =
            f.l2.provider
                .get_block_by_number(BlockNumberOrTag::Number(h))
                .await?
                .context("executed header")?;
        assert_eq!(b.header.hash, b.header.inner.hash_slow());
        sum += U256::from(b.header.base_fee_per_gas.context("base fee")?) *
            U256::from(b.header.gas_used);
    }
    Ok(sum)
}

#[tokio::test(flavor = "multi_thread")]
#[ignore = "docker"]
async fn real_l2_rewards_claim_and_fee_continuation() -> Result<()> {
    assert_claim_polling_preserves_permanent_errors().await?;
    let f = ContractFixture::deploy().await?;
    let p = &f.anvil.provider;
    let l2 = &f.l2.provider;
    let vault = f.params.fee_vault;
    assert_eq!(p.get_balance(f.inbox).await?, U256::ZERO, "no L1 reward pre-funding");
    assert_eq!(l2.get_balance(vault).await?, U256::ZERO, "vault starts with zero ETH");
    set_interval_mining(p, 1).await?;
    let c = ContractConsensus::start(
        f.anvil.http.clone(),
        &f.l2,
        f.params.clone(),
        ValidatorKey::from_seed(CONSENSUS_SEED),
    )
    .await?;
    let payment =
        send_transfer(l2, &dev_signer(), Address::repeat_byte(0x91), U256::from(123), 0).await?;
    let transfer = receipt(l2, payment).await?;
    assert!(transfer.status());
    let h = transfer.block_number.context("transfer height")?;
    c.wait_for_height(h + 1).await?;
    let header = l2.get_block_by_number(BlockNumberOrTag::Number(h)).await?.unwrap().header;
    let base = U256::from(header.base_fee_per_gas.unwrap()) * U256::from(transfer.gas_used);
    let tips =
        U256::from(transfer.effective_gas_price - u128::from(header.base_fee_per_gas.unwrap())) *
            U256::from(transfer.gas_used);
    assert!(base > U256::ZERO && tips > U256::ZERO);
    let proposer = header.beneficiary;
    assert_ne!(proposer, RECIPIENT);
    assert_ne!(proposer, dev_signer().address());
    assert_eq!(
        l2.get_balance(vault).block_id(BlockId::number(h)).await? -
            l2.get_balance(vault).block_id(BlockId::number(h - 1)).await?,
        base
    );
    assert_eq!(
        l2.get_balance(proposer).block_id(BlockId::number(h)).await? -
            l2.get_balance(proposer).block_id(BlockId::number(h - 1)).await?,
        tips
    );
    let (first, landing_tx) = land(&f, &c).await?;
    let amount = first.batch.input.baseFeeAmount;
    assert!(amount > U256::ZERO, "principal acceptance must pay earned fees");
    assert_eq!(amount, fee_sum(&f, 1, first.batch.input.lastHeight).await?);
    assert_eq!(first.batch.input.feeRecipient, f.admin);
    assert_ne!(first.batch.input.feeRecipient, first.batch.input.l2RewardRecipient);
    let landing = receipt(p, landing_tx).await?;
    let batch_id =
        landing.decoded_log::<lander::contracts::BatchRewardRecorded>().unwrap().data.batchId;
    mine_l1_blocks(p, 3).await?;
    let finalized =
        p.get_block_by_number(BlockNumberOrTag::Finalized).await?.context("finalized L1")?;
    assert!(finalized.header.number >= landing.block_number.context("landing height")?);
    recover_landed_execution(&f, first.batch.blobs.sidecar.blobs(), &first.batch.input).await?;
    let source = RpcClaimSource::connect(
        p.clone(),
        l2.clone(),
        landing_tx,
        batch_id,
        dev_signer().address(),
        DEADLINE,
    )
    .await?;
    let proof = wait_until(
        "executed anchor contains real receipt proof",
        DEADLINE,
        Duration::from_millis(200),
        || async { claim_poll(source.prepare(landing_tx, batch_id).await) },
    )
    .await?;
    assert!(!proof.account_proof.is_empty() && !proof.storage_proof.is_empty());
    assert_eq!(proof.receipt.baseFeeAmount, amount);
    let dir = tempfile::tempdir()?;
    let store = ClaimStore::open(dir.path(), source.identity().clone())?;
    let transport = RpcClaimTransport::new(l2.clone(), dev_signer());
    assert_eq!(
        step(&store, &source, &transport, DEADLINE).await?,
        ClaimOutcome::State(ClaimState::Pending)
    );
    let job = store.load()?.unwrap();
    let signed = job.transaction.unwrap();
    let paid = receipt(l2, signed.hash).await?;
    assert!(paid.status(), "actual vault claim must succeed");
    let claim_height = paid.block_number.unwrap();
    let before = BlockId::number(claim_height - 1);
    let after = BlockId::number(claim_height);
    assert_eq!(
        l2.get_balance(RECIPIENT).block_id(after).await? -
            l2.get_balance(RECIPIENT).block_id(before).await?,
        amount
    );
    let claim_fee = fee_sum(&f, claim_height, claim_height).await?;
    assert_eq!(
        l2.get_balance(vault).block_id(after).await? + amount,
        l2.get_balance(vault).block_id(before).await? + claim_fee
    );
    assert!(source.claimed(batch_id).await?);
    let event = paid.decoded_log::<Vault::RewardClaimed>().context("actual claim event")?;
    assert_eq!(event.data.batchId, batch_id);
    assert_eq!(event.data.recipient, RECIPIENT);
    assert_eq!(event.data.amount, amount);
    assert_eq!(
        l2.get_balance(dev_signer().address()).block_id(before).await? -
            l2.get_balance(dev_signer().address()).block_id(after).await?,
        U256::from(paid.gas_used) * U256::from(paid.effective_gas_price),
        "third-party payer pays gas and receives none of the reward"
    );
    assert_eq!(
        step(&store, &source, &transport, DEADLINE).await?,
        ClaimOutcome::State(ClaimState::Included)
    );
    // Actual EVM simulation rejects replay before signing. Later canonical roots cannot reset it.
    assert!(
        l2.call(
            TransactionRequest::default()
                .from(dev_signer().address())
                .to(vault)
                .input(proof.calldata()?.into())
        )
        .await
        .is_err()
    );
    c.wait_for_height(claim_height + 1).await?;
    let (second, _) = land(&f, &c).await?;
    assert!(second.batch.input.lastHeight >= claim_height);
    let expected =
        fee_sum(&f, first.batch.input.lastHeight + 1, second.batch.input.lastHeight).await?;
    assert!(expected > U256::ZERO);
    assert_eq!(
        second.batch.input.baseFeeAmount, expected,
        "claim expenditure never subtracts from basefee accounting"
    );
    let vault_start =
        l2.get_balance(vault).block_id(BlockId::number(first.batch.input.lastHeight)).await?;
    let vault_end =
        l2.get_balance(vault).block_id(BlockId::number(second.batch.input.lastHeight)).await?;
    assert_eq!(vault_end + amount, vault_start + expected);
    mine_l1_blocks(p, 3).await?;
    // Included is the end state: a rerun reconciles the same signed claim again.
    assert_eq!(
        step(&store, &source, &transport, DEADLINE).await?,
        ClaimOutcome::State(ClaimState::Included)
    );
    let refreshed =
        wait_until("new anchor receipt proof", DEADLINE, Duration::from_millis(200), || async {
            Ok(claim_poll(source.prepare(landing_tx, batch_id).await)?
                .filter(|next| next.anchor_timestamp > proof.anchor_timestamp))
        })
        .await?;
    assert!(
        l2.call(
            TransactionRequest::default()
                .from(dev_signer().address())
                .to(vault)
                .input(refreshed.calldata()?.into())
        )
        .await
        .is_err()
    );
    assert_eq!(
        store.load()?.unwrap().transaction.unwrap(),
        signed,
        "reruns retain the original signed bytes"
    );
    // Force a fresh-nonce replay through actual execution, bypassing estimation intentionally.
    let replay = TxEip1559 {
        chain_id: f.params.l2_chain_id,
        nonce: l2.get_transaction_count(dev_signer().address()).await?,
        gas_limit: 500_000,
        max_fee_per_gas: 10_000_000_000,
        max_priority_fee_per_gas: 1_000_000_000,
        to: vault.into(),
        input: refreshed.calldata()?,
        ..Default::default()
    };
    let signature = dev_signer().sign_hash_sync(&replay.signature_hash())?;
    let replay_hash = *l2
        .send_raw_transaction(&TxEnvelope::Eip1559(replay.into_signed(signature)).encoded_2718())
        .await?
        .tx_hash();
    let replayed = receipt(l2, replay_hash).await?;
    assert!(!replayed.status(), "new-root duplicate must revert in a real executed block");
    assert!(replayed.logs().is_empty());
    assert_eq!(
        l2.get_balance(RECIPIENT).block_id(BlockId::number(replayed.block_number.unwrap())).await?,
        amount,
        "duplicate pays nothing"
    );
    eprintln!(
        "positive payout={amount} claim={} at={claim_height} subsequent_basefee={expected} replay_old_and_new_roots=rejected",
        signed.hash
    );
    c.stop().await?;
    f.l2.stop().await?;
    f.anvil.stop().await
}
