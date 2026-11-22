//! Regenerate CLI fixture proofs after witness slot additions, preserving authenticated roots,
//! or rebuild the CLI recovery fixture from [`recovery_fixture`](super::recovery_fixture) when
//! its committed values change.
//!
//! Run `cargo test -p abci --lib regenerate_cli_recovery_fixtures -- --ignored` (or
//! `rebuild_cli_recovery_fixture`) and format the JSON with the repository's Prettier. These
//! are manual generators, excluded from CI tests.

use std::{collections::BTreeMap, path::Path};

use alloy_primitives::{Address, Bytes};

use crate::{AccountWitness, RawL1Header, l1::layout::inbox, recovery::RecoveryWitness};

use super::TestState;

#[test]
#[ignore = "manual fixture regeneration"]
fn regenerate_cli_recovery_fixtures() {
    let root = Path::new(env!("CARGO_MANIFEST_DIR")).join("../../bin/client/src/recovery/testdata");
    for name in ["recovery"] {
        let path = root.join(format!("{name}.json"));
        let mut fixture: serde_json::Value =
            serde_json::from_slice(&std::fs::read(&path).unwrap()).unwrap();
        let inbox_address: Address =
            serde_json::from_value(fixture["params"]["inbox"].clone()).unwrap();
        let mut states = BTreeMap::new();
        for block in fixture["blocks"].as_array_mut().unwrap() {
            let header_bytes: Bytes = serde_json::from_value(block["header"].clone()).unwrap();
            let header: RawL1Header = alloy_rlp::decode_exact(&header_bytes).unwrap();
            let accounts = block["accounts"].as_array_mut().unwrap();
            let proofs: Vec<AccountWitness> = accounts
                .iter()
                .map(|account| {
                    let bytes: Bytes = serde_json::from_value(account["proof"].clone()).unwrap();
                    alloy_rlp::decode_exact(&bytes).unwrap()
                })
                .collect();
            let state = TestState::new(
                proofs
                    .iter()
                    .map(|proof| {
                        (
                            proof.address,
                            proof.nonce,
                            proof.balance,
                            proof.code_hash,
                            proof.storage.iter().map(|word| (word.slot, word.value)).collect(),
                        )
                    })
                    .collect(),
            );
            assert_eq!(
                state.state_root(),
                header.state_root(),
                "{name}: all original state is present"
            );
            for (account, proof) in accounts.iter_mut().zip(proofs) {
                let mut slots: Vec<_> = proof.storage.iter().map(|word| word.slot).collect();
                if proof.address == inbox_address &&
                    !slots.contains(&inbox::slot(inbox::RULES_SCHEDULE))
                {
                    slots.push(inbox::slot(inbox::RULES_SCHEDULE));
                }
                account["proof"] = serde_json::to_value(Bytes::from(alloy_rlp::encode(
                    state.witness(proof.address, &slots),
                )))
                .unwrap();
            }
            states.insert(header.number(), state);
        }
        let bytes: Bytes = serde_json::from_value(fixture["witness"].clone()).unwrap();
        let mut witness: RecoveryWitness = alloy_rlp::decode_exact(&bytes).unwrap();
        let address = witness.recovery_inbox.address;
        let slots = inbox::recovery_slots(witness.generation, witness.el_header.number);
        witness.recovery_inbox = states[&witness.recovery_header.number()].witness(address, &slots);
        witness.finalized_inbox =
            states[&witness.finalized_header.number()].witness(address, &slots);
        fixture["witness"] = serde_json::to_value(Bytes::from(alloy_rlp::encode(witness))).unwrap();
        std::fs::write(path, serde_json::to_string_pretty(&fixture).unwrap() + "\n").unwrap();
    }
}

/// R of the CLI fixture: far enough above `L1_0` that a log scan from R down to block 0 takes
/// 21 queries of [`LOG_CHUNK_BLOCKS`](crate::fallback::LOG_CHUNK_BLOCKS) blocks.
const CLI_R: u64 = 200_000;

/// Rebuilds `recovery.json` from `recovery_fixture_at(1, 6, 1, CLI_R)` when a committed value or
/// a proven slot list changes (the configuration hash, an origin record, the recovery or genesis
/// slots). L1 blocks 64 (`L1_0`), [`CLI_R`] (R) and R + 10 (finalized) are the fixture's; R + 20
/// adds a later landing at 18 and R + 30 also raises the recovery generation to 2, both on the
/// state of R + 10. Each account the state still holds keeps the slot list the old file proves
/// for the block in the same position, and the Inbox also proves the genesis, recovery and
/// anchor slots, so every read the CLI tests make stays served; the proofs must cover the whole
/// state. The file also carries the origin fallback key list, which the CLI tests' L1 answers
/// `getFallbackKeys()` with.
#[test]
#[ignore = "manual fixture regeneration"]
fn rebuild_cli_recovery_fixture() {
    use alloy_primitives::{B256, U256};
    let path = Path::new(env!("CARGO_MANIFEST_DIR"))
        .join("../../bin/client/src/recovery/testdata/recovery.json");
    let old: serde_json::Value = serde_json::from_slice(&std::fs::read(&path).unwrap()).unwrap();
    let (fx, l1, _engine, witness) = super::recovery_fixture_at(1, 6, 1, CLI_R);
    let inbox_address = fx.params.inbox;
    let base = l1.state().states[&(CLI_R + 10)].clone();
    let later = base.with_storage(
        inbox_address,
        &[
            (inbox::slot(inbox::LAST_CHECKPOINT_HEIGHT), U256::from(18)),
            (inbox::slot(inbox::LAST_CHECKPOINT_HASH), U256::from_be_bytes([0x18; 32])),
        ],
    );
    let superseded = later
        .with_storage(inbox_address, &[(inbox::slot(inbox::RECOVERY_GENERATION), U256::from(2))]);
    for (number, state) in [(CLI_R + 20, later), (CLI_R + 30, superseded)] {
        l1.insert_block(super::l1_header(number, super::Fixture::l1_timestamp(number)), state);
    }
    let (headers, states) = {
        let state = l1.state();
        (state.headers.clone(), state.states.clone())
    };
    let numbers = [fx.genesis.l1_0, CLI_R, CLI_R + 10, CLI_R + 20, CLI_R + 30];
    let old_blocks = old["blocks"].as_array().unwrap();
    assert_eq!(old_blocks.len(), numbers.len(), "one old block per fixture block");
    let blocks: Vec<serde_json::Value> = old_blocks
        .iter()
        .zip(numbers)
        .map(|(block, number)| {
            let state = &states[&number];
            let mut specs = Vec::new();
            let accounts: Vec<serde_json::Value> = block["accounts"]
                .as_array()
                .unwrap()
                .iter()
                .filter(|account| {
                    let address: Address =
                        serde_json::from_value(account["address"].clone()).unwrap();
                    state.has_account(address)
                })
                .map(|account| {
                    let address: Address =
                        serde_json::from_value(account["address"].clone()).unwrap();
                    let bytes: Bytes = serde_json::from_value(account["proof"].clone()).unwrap();
                    let old_proof: AccountWitness = alloy_rlp::decode_exact(&bytes).unwrap();
                    let mut slots: Vec<B256> =
                        old_proof.storage.iter().map(|word| word.slot).collect();
                    if address == inbox_address {
                        for slot in inbox::genesis_slots()
                            .into_iter()
                            .chain(inbox::recovery_slots(1, 6))
                            .chain(inbox::anchor_slots())
                        {
                            if !slots.contains(&slot) {
                                slots.push(slot);
                            }
                        }
                    }
                    let proof = state.witness(address, &slots);
                    specs.push((
                        proof.address,
                        proof.nonce,
                        proof.balance,
                        proof.code_hash,
                        proof.storage.iter().map(|word| (word.slot, word.value)).collect(),
                    ));
                    serde_json::json!({
                        "address": address,
                        "proof": Bytes::from(alloy_rlp::encode(proof)),
                    })
                })
                .collect();
            assert_eq!(
                TestState::new(specs).state_root(),
                state.state_root(),
                "block {number}: the proofs cover the whole state"
            );
            serde_json::json!({
                "accounts": accounts,
                "header": Bytes::from(alloy_rlp::encode(&headers[&number])),
                "number": number,
            })
        })
        .collect();
    let p = &fx.params;
    let fixture = serde_json::json!({
        "blocks": blocks,
        "fallback_keys": super::recovery_fallback_keys(),
        "params": {
            "block_gas_limit": p.block_gas_limit,
            "fee_recipient": p.fee_recipient,
            "inbox": p.inbox,
            "l1_chain_id": p.l1_chain_id,
            "l2_chain_id": p.l2_chain_id,
            "staking": p.staking,
            "unsettled_limit": p.unsettled_limit,
        },
        "provenance": "abci::test_utils::recovery_fixture_at(1,6,1,200000) rebuilt by \
            rebuild_cli_recovery_fixture; finality variants 200020 (landing at 18) and 200030 \
            (generation 2) on the state of 200010",
        "witness": Bytes::from(alloy_rlp::encode(&witness)),
    });
    std::fs::write(path, serde_json::to_string_pretty(&fixture).unwrap() + "\n").unwrap();
}
