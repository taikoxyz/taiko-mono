//! Regenerate CLI fixture proofs after witness slot additions, preserving authenticated roots.
//!
//! Run `cargo test -p abci --lib regenerate_cli_recovery_fixtures -- --ignored` and format
//! the JSON with the repository's Prettier. This is a manual generator, excluded from CI tests.

use std::{collections::BTreeMap, path::Path};

use alloy_primitives::{Address, Bytes};

use crate::{AccountWitness, RawL1Header, l1::layout::inbox, recovery::RecoveryWitness};

use super::TestState;

/// The landing heights searched for proven slot 285 records, beyond every fixture checkpoint.
const LANDING_HEIGHTS: u64 = 1_000;

#[test]
#[ignore = "manual fixture regeneration"]
fn regenerate_cli_recovery_fixtures() {
    let root = Path::new(env!("CARGO_MANIFEST_DIR")).join("../../bin/client/src/recovery/testdata");
    for name in ["recovery", "activation", "repeated", "session"] {
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
                // Slot 285 records have four words (STOR-B-9): a record proven with all three
                // older words is proven with its fourth too. A partly proven record stays so.
                if proof.address == inbox_address {
                    for height in 0..=LANDING_HEIGHTS {
                        let [packed, el, comet, val_state] = inbox::landing_slots(height);
                        if [packed, el, comet].iter().all(|word| slots.contains(word)) &&
                            !slots.contains(&val_state)
                        {
                            slots.push(val_state);
                        }
                    }
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
