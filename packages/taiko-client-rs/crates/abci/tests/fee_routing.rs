//! Real EL acceptance: missing custom genesis and incorrect fee recipients must fail.
use alloy_eips::{BlockId, BlockNumberOrTag};
use alloy_primitives::{Address, U256, address};
use alloy_provider::Provider;
use anyhow::Context;
use std::time::Duration;
use test_harness::{Devnet, DevnetSpec, dev_signer, send_transfer, wait_until};

#[tokio::test(flavor = "multi_thread")]
#[ignore = "docker"]
async fn fee_routing_custom_genesis_and_transfer() -> anyhow::Result<()> {
    let devnet = Devnet::start(DevnetSpec::default()).await?;
    let l2 = devnet.l2_provider(0);
    let genesis = test_harness::EtnaGenesis::build(devnet.l1(), devnet.params().inbox).await?;
    let repeat = test_harness::EtnaGenesis::build(devnet.l1(), devnet.params().inbox).await?;
    assert_eq!(genesis.json, repeat.json);
    let different =
        test_harness::EtnaGenesis::build(devnet.l1(), Address::repeat_byte(0xab)).await?;
    assert_ne!(
        genesis.hash, different.hash,
        "constructor Inbox must change real runtime and genesis"
    );
    assert_ne!(genesis.state_root, different.state_root);
    eprintln!(
        "custom genesis hash={} state_root={} json_keccak={} inbox={}",
        genesis.hash,
        genesis.state_root,
        keccak256(&genesis.json),
        devnet.params().inbox
    );
    let vault = address!("1670010000000000000000000000000000010001");
    let recipient = Address::repeat_byte(0x91);
    let tx = send_transfer(&l2, &dev_signer(), recipient, U256::from(123), 0).await?;
    let receipt = wait_until(
        "transfer receipt",
        Duration::from_secs(90),
        Duration::from_millis(100),
        || async { Ok(l2.get_transaction_receipt(tx).await?) },
    )
    .await?;
    assert!(receipt.status());
    let h = receipt.block_number.context("receipt height")?;
    let block = l2.get_block_by_number(BlockNumberOrTag::Number(h)).await?.context("block")?;
    let before = BlockId::number(h - 1);
    let after = BlockId::number(h);
    let fee =
        U256::from(block.header.base_fee_per_gas.unwrap()) * U256::from(block.header.gas_used);
    assert_eq!(
        l2.get_balance(vault).block_id(after).await? -
            l2.get_balance(vault).block_id(before).await?,
        fee
    );
    let proposer = block.header.beneficiary;
    assert_ne!(proposer, vault);
    assert_eq!(
        l2.get_balance(proposer).block_id(after).await? -
            l2.get_balance(proposer).block_id(before).await?,
        U256::from(receipt.gas_used) *
            U256::from(
                receipt.effective_gas_price - u128::from(block.header.base_fee_per_gas.unwrap())
            )
    );
    assert!(
        !l2.get_code_at(vault).await?.is_empty(),
        "custom genesis must install the actual immutable vault runtime"
    );
    let output = l2
        .call(
            alloy::rpc::types::TransactionRequest::default().to(vault).input(
                alloy_primitives::Bytes::copy_from_slice(
                    &alloy_primitives::keccak256("l1Inbox()")[..4],
                )
                .into(),
            ),
        )
        .await?;
    assert_eq!(
        output.as_ref(),
        alloy_primitives::U256::from_be_slice(devnet.params().inbox.as_slice()).to_be_bytes::<32>(),
        "custom genesis must bind the actual vault to this L1 Inbox"
    );
    devnet.stop().await?;
    Ok(())
}

use alloy::{
    consensus::{SignableTransaction, TxEip1559, TxEip7702, TxEnvelope},
    rpc::types::{TransactionReceipt, TransactionRequest},
    signers::{SignerSync, local::PrivateKeySigner},
};
use alloy_eips::{eip2718::Encodable2718, eip7702::Authorization};
use alloy_primitives::{Bytes, TxKind, keccak256};
use alloy_provider::RootProvider;
use serde_json::{Value, json};
use test_harness::genesis::{HISTORY, ROOTS};

fn selector(signature: &str) -> Bytes {
    Bytes::copy_from_slice(&keccak256(signature)[..4])
}

async fn send(
    l2: &RootProvider,
    to: TxKind,
    input: Bytes,
    value: U256,
) -> anyhow::Result<TransactionReceipt> {
    let signer = dev_signer();
    let tx = TxEip1559 {
        chain_id: l2.get_chain_id().await?,
        nonce: l2.get_transaction_count(signer.address()).await?,
        gas_limit: 1_000_000,
        max_fee_per_gas: 10_000_000_000,
        max_priority_fee_per_gas: 1_000_000_000,
        to,
        input,
        value,
        ..Default::default()
    };
    let signature = signer.sign_hash_sync(&tx.signature_hash())?;
    submit(l2, TxEnvelope::Eip1559(tx.into_signed(signature))).await
}
async fn submit(l2: &RootProvider, tx: TxEnvelope) -> anyhow::Result<TransactionReceipt> {
    let hash = *l2.send_raw_transaction(&tx.encoded_2718()).await?.tx_hash();
    wait_until(
        "fee fixture receipt",
        Duration::from_secs(60),
        Duration::from_millis(100),
        || async { Ok(l2.get_transaction_receipt(hash).await?) },
    )
    .await
}

/// No claim or forced credit is present unless explicitly supplied. Pin every balance to
/// the transaction block and subtract the proposer's ordinary transfer income separately.
async fn check_fees(
    d: &Devnet,
    receipt: &TransactionReceipt,
    movements: Movements,
) -> anyhow::Result<()> {
    let l2 = d.l2_provider(0);
    let height = receipt.block_number.context("receipt height")?;
    d.wait_for_height(0, height, Duration::from_secs(30)).await?;
    let block = l2.get_block_by_number(BlockNumberOrTag::Number(height)).await?.context("block")?;
    let h = &block.header;
    assert_eq!(h.gas_used, receipt.gas_used, "one deliberately submitted transaction per block");
    let before = BlockId::number(height - 1);
    let after = BlockId::number(height);
    let vault = d.params().fee_vault;
    let credit = l2.get_balance(vault).block_id(after).await? -
        l2.get_balance(vault).block_id(before).await?;
    let base = U256::from(h.base_fee_per_gas.unwrap()) * U256::from(h.gas_used);
    assert_eq!(
        credit - movements.forced_credit,
        base,
        "header basefee times charged gas is the fee credit"
    );
    if !movements.forced_credit.is_zero() {
        assert_ne!(credit, base, "balance delta includes non-fee income and cannot define rewards");
    }
    let tips = U256::from(receipt.effective_gas_price - u128::from(h.base_fee_per_gas.unwrap())) *
        U256::from(receipt.gas_used);
    let proposer = h.beneficiary;
    assert_eq!(proposer, d.keys()[0].reward_recipient());
    assert_ne!(proposer, vault);
    assert_ne!(proposer, dev_signer().address());
    assert_eq!(
        l2.get_balance(proposer).block_id(after).await? -
            l2.get_balance(proposer).block_id(before).await? -
            movements.proposer_transfer,
        tips
    );
    assert_eq!(
        l2.get_balance(dev_signer().address()).block_id(before).await? -
            l2.get_balance(dev_signer().address()).block_id(after).await?,
        base + tips + movements.sent_value
    );
    let root = l2
        .call(
            TransactionRequest::default()
                .to(ROOTS)
                .input(Bytes::copy_from_slice(&U256::from(h.timestamp).to_be_bytes::<32>()).into()),
        )
        .block(after)
        .await?;
    assert_eq!(root.len(), 32, "missing roots code cannot pass with empty return data");
    let (_, _, anchor) = test_harness::extra_data_of(&l2, height).await?;
    let l1 =
        d.l1().get_block_by_number(BlockNumberOrTag::Number(anchor)).await?.context("L1 anchor")?;
    assert_eq!(root.as_ref(), l1.header.state_root.as_slice());
    assert_eq!(h.parent_beacon_block_root, Some(l1.header.state_root));
    // The CometBFT envelope authenticates this root; carry forward its most recent witness.
    let mut witness_height = height;
    loop {
        let envelope = d.cmt(0).envelope(witness_height).await?;
        if let Some(witness) = envelope.anchor {
            assert_eq!(witness.l1_header.state_root(), l1.header.state_root);
            break;
        }
        assert!(witness_height > 1);
        witness_height -= 1;
    }
    let history = l2
        .call(
            TransactionRequest::default()
                .to(HISTORY)
                .input(Bytes::copy_from_slice(&U256::from(height - 1).to_be_bytes::<32>()).into()),
        )
        .block(after)
        .await?;
    assert_eq!(history.as_ref(), h.parent_hash.as_slice());
    eprintln!(
        "fee case block={height} success={} gas={} basefee={} base_credit={base} tips={tips} forced_credit={} roots={}",
        receipt.status(),
        h.gas_used,
        h.base_fee_per_gas.unwrap(),
        movements.forced_credit,
        l1.header.state_root
    );
    Ok(())
}
#[derive(Default)]
struct Movements {
    forced_credit: U256,
    proposer_transfer: U256,
    sent_value: U256,
}

#[tokio::test(flavor = "multi_thread")]
#[ignore = "docker"]
async fn fee_routing_success_revert_refund_floor_authorization_and_forced_credit()
-> anyhow::Result<()> {
    let d = Devnet::start(DevnetSpec::default()).await?;
    let l2 = d.l2_provider(0);
    let artifact: Value =
        serde_json::from_str(include_str!("../../test-harness/contracts/FeeRoutingFixture.json"))?;
    let deployed = send(
        &l2,
        TxKind::Create,
        artifact["bytecode"]["object"].as_str().context("creation bytecode")?.parse()?,
        U256::ZERO,
    )
    .await?;
    assert!(deployed.status());
    check_fees(&d, &deployed, Movements::default()).await?;
    let fixture = deployed.contract_address.context("fixture address")?;
    let value = U256::from(12345);
    let recipient = Address::repeat_byte(0x92);
    let paid = send(&l2, recipient.into(), Bytes::new(), value).await?;
    assert!(paid.status());
    check_fees(&d, &paid, Movements { sent_value: value, ..Default::default() }).await?;
    assert_eq!(
        l2.get_balance(recipient).block_id(BlockId::number(paid.block_number.unwrap())).await?,
        value
    );
    let proposer_paid =
        send(&l2, d.keys()[0].reward_recipient().into(), Bytes::new(), value).await?;
    check_fees(
        &d,
        &proposer_paid,
        Movements { sent_value: value, proposer_transfer: value, ..Default::default() },
    )
    .await?;
    let reverted = send(&l2, fixture.into(), selector("fail()"), U256::ZERO).await?;
    assert!(!reverted.status());
    assert!(reverted.gas_used > 21000);
    check_fees(&d, &reverted, Movements::default()).await?;
    let set = send(&l2, fixture.into(), selector("set()"), U256::ZERO).await?;
    assert!(set.status());
    check_fees(&d, &set, Movements::default()).await?;
    assert_eq!(
        l2.get_storage_at(fixture, U256::ZERO)
            .block_id(BlockId::number(set.block_number.unwrap()))
            .await?,
        U256::from(1)
    );
    let clear = send(&l2, fixture.into(), selector("clear()"), U256::ZERO).await?;
    assert!(clear.status());
    check_fees(&d, &clear, Movements::default()).await?;
    assert_eq!(
        l2.get_storage_at(fixture, U256::ZERO)
            .block_id(BlockId::number(clear.block_number.unwrap()))
            .await?,
        U256::ZERO
    );
    let before_refund = execution_gas(&l2, clear.transaction_hash).await?;
    assert_eq!(
        before_refund - clear.gas_used,
        4800,
        "nonzero SSTORE clear must apply the actual refund"
    );
    eprintln!("refund pre_refund={before_refund} charged={} refund=4800", clear.gas_used);
    let calldata = Bytes::from(vec![0xff; 1024]);
    let floor = send(&l2, fixture.into(), calldata.clone(), U256::ZERO).await?;
    assert!(floor.status());
    check_fees(&d, &floor, Movements::default()).await?;
    let intrinsic = 21000 + 16 * calldata.len() as u64;
    let floor_gas = 21000 + 40 * calldata.len() as u64;
    assert_eq!(floor.gas_used, floor_gas);
    let ordinary = execution_gas(&l2, floor.transaction_hash).await?;
    assert!(ordinary >= intrinsic && floor.gas_used > ordinary);
    eprintln!(
        "calldata floor intrinsic={intrinsic} measured_ordinary={ordinary} charged={}",
        floor.gas_used
    );
    assert!(
        floor.gas_used > intrinsic + 1000,
        "calldata floor exceeds ordinary intrinsic and fallback execution"
    );
    let authority: PrivateKeySigner =
        "59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d".parse()?;
    assert!(l2.get_code_at(authority.address()).await?.is_empty());
    let authorization = Authorization {
        chain_id: U256::from(l2.get_chain_id().await?),
        address: fixture,
        nonce: l2.get_transaction_count(authority.address()).await?,
    };
    let signature = authority.sign_hash_sync(&authorization.signature_hash())?;
    let tx = TxEip7702 {
        chain_id: l2.get_chain_id().await?,
        nonce: l2.get_transaction_count(dev_signer().address()).await?,
        gas_limit: 1_000_000,
        max_fee_per_gas: 10_000_000_000,
        max_priority_fee_per_gas: 1_000_000_000,
        to: authority.address(),
        input: selector("increment()"),
        authorization_list: vec![authorization.into_signed(signature)],
        ..Default::default()
    };
    let signature = dev_signer().sign_hash_sync(&tx.signature_hash())?;
    let delegated = submit(&l2, TxEnvelope::Eip7702(tx.into_signed(signature))).await?;
    assert!(delegated.status());
    check_fees(&d, &delegated, Movements::default()).await?;
    let mut delegation = vec![0xef, 0x01, 0x00];
    delegation.extend_from_slice(fixture.as_slice());
    assert_eq!(l2.get_code_at(authority.address()).await?.as_ref(), delegation);
    assert_eq!(
        l2.get_storage_at(authority.address(), U256::ZERO).await?,
        U256::from(1),
        "delegated execution must change the authority's storage"
    );
    let mut force_input = selector("forceCredit(address)").to_vec();
    force_input.extend_from_slice(
        &U256::from_be_slice(d.params().fee_vault.as_slice()).to_be_bytes::<32>(),
    );
    let forced = send(&l2, fixture.into(), force_input.into(), value).await?;
    assert!(forced.status());
    check_fees(
        &d,
        &forced,
        Movements { sent_value: value, forced_credit: value, ..Default::default() },
    )
    .await?;
    d.stop().await
}

/// Opcode gas remaining measures actual intrinsic+execution consumption independently of
/// the receipt's refund/floor-adjusted charge. These fixture calls each declare 1,000,000 gas.
async fn execution_gas(l2: &RootProvider, hash: alloy_primitives::B256) -> anyhow::Result<u64> {
    let trace: Value = l2.raw_request("debug_traceTransaction".into(), json!([hash, {}])).await?;
    let last =
        trace["structLogs"].as_array().context("opcode trace")?.last().context("last opcode")?;
    let gas = last["gas"].as_u64().context("trace gas")?;
    let cost = last["gasCost"].as_u64().context("trace gas cost")?;
    Ok(1_000_000 - gas + cost)
}
