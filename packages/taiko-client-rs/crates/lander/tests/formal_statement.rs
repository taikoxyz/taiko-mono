//! The Rust leg of the Lean/real-Inbox statement comparison. Inputs contain only the
//! precall context and corpus inputs, never an expected preimage or digest.

use std::{collections::BTreeSet, path::PathBuf};

use abci::{AccountWitness, GenesisRecord, RawL1Header};
use alloy_consensus::Header;
use alloy_primitives::{Address, B256, U256, aliases::U48, hex};
use lander::{contracts::IEtnaInbox::LandInput, statement, types::LandingSnapshot};
use serde_json::{Value, json};

fn number(row: &Value, key: &str) -> u64 {
    row[key].as_u64().unwrap_or_else(|| panic!("missing integer {key}"))
}

fn parse<T: std::str::FromStr>(row: &Value, key: &str) -> T
where
    T::Err: std::fmt::Debug,
{
    row[key].as_str().unwrap_or_else(|| panic!("missing string {key}")).parse().unwrap()
}

fn observe(row: &Value) -> Value {
    let context = &row["context"];
    let snapshot = LandingSnapshot {
        l1_block_hash: B256::ZERO,
        l1_block_number: number(row, "currentBlock"),
        l1_chain_id: U256::from(number(context, "chainid")),
        l2_chain_id: number(context, "l2chainid"),
        inbox: parse(context, "proxy"),
        registry: parse(context, "registry"),
        generation: number(context, "generation"),
        checkpoint_height: number(row, "parentHeight"),
        checkpoint_hash: parse(context, "parentHash"),
        forced_inclusion_head: number(row, "headBefore"),
        forced_inclusion_tail: number(row, "tail"),
        committee_config_hash: parse(context, "config"),
        // These fields are outside the twenty-one-word statement projection. This fixture
        // does not purport to authenticate a snapshot or execute the production guest.
        genesis: GenesisRecord {
            committee_config_hash: B256::ZERO,
            genesis_height: 0,
            l1_0: 1,
            epoch_len: 20,
            epoch_len_l1: 1,
            genesis_hash: B256::ZERO,
            genesis_state_root: B256::ZERO,
            genesis_cutoff: 0,
            forced_inclusion_delay: 1,
            max_anchor_age: 1152,
        },
        genesis_committee_record_hash: B256::ZERO,
        l1_header: RawL1Header::from(&Header::default()),
        inbox_witness: AccountWitness {
            address: Address::ZERO,
            nonce: 0,
            balance: U256::ZERO,
            storage_root: B256::ZERO,
            code_hash: B256::ZERO,
            account_proof: vec![],
            storage: vec![],
        },
    };
    let input = LandInput {
        lastHeight: number(row, "lastHeight"),
        lastBlockHash: parse(row, "lastBlockHash"),
        lastStateRoot: parse(row, "lastStateRoot"),
        l1ReferenceBlockNumber: number(row, "reference"),
        forcedInclusionHead: U48::try_from(number(row, "headAfter")).unwrap(),
        feeRecipient: parse(row, "recipient"),
        l2RewardRecipient: parse(row, "l2RewardRecipient"),
        baseFeeAmount: parse(row, "baseFeeAmount"),
        activeCommitteeSnapshot: number(row, "activeCommitteeSnapshot"),
    };
    let blobs = row["blobs"]
        .as_array()
        .unwrap()
        .iter()
        .map(|value| value.as_str().unwrap().parse::<B256>().unwrap())
        .take_while(|hash| *hash != B256::ZERO)
        .collect::<Vec<_>>();
    let reference = parse(row, "referenceHash");
    let bytes = statement::preimage(&snapshot, &input, reference, &blobs);
    assert_eq!(bytes.len(), statement::PREIMAGE_BYTES);
    assert_eq!(bytes.len(), 672);
    json!({"id":row["id"], "rustPreimage":format!("0x{}",hex::encode(bytes)),
        "rustDigest":format!("{:#x}",statement::hash(&snapshot,&input,reference,&blobs)),
        "rustBlobCommitment":format!("{:#x}",statement::blob_hashes_hash(&blobs))})
}

#[test]
fn formal_statement_conformance() {
    let formal = PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("../../../../formal/etna");
    let input = std::env::var_os("ETNA_STATEMENT_INPUT");
    let rows: Vec<Value> = if let Some(path) = input {
        std::fs::read_to_string(path)
            .unwrap()
            .lines()
            .map(|s| serde_json::from_str(s).unwrap())
            .collect()
    } else {
        let observations: Vec<Value> =
            std::fs::read_to_string(formal.join("reports/landing-solidity-observations.jsonl"))
                .unwrap()
                .lines()
                .map(|s| serde_json::from_str(s).unwrap())
                .collect();
        std::fs::read_to_string(formal.join("corpus/landing.jsonl"))
            .unwrap()
            .lines()
            .map(|s| {
                let mut row: Value = serde_json::from_str(s).unwrap();
                let obs = observations.iter().find(|obs| obs["id"] == row["id"]).unwrap();
                row["context"] = obs["context"].clone();
                row
            })
            .collect()
    };
    assert!(!rows.is_empty(), "empty statement corpus");
    let ids: BTreeSet<_> = rows.iter().map(|r| r["id"].as_str().unwrap()).collect();
    assert_eq!(ids.len(), rows.len(), "duplicate statement case");
    let output =
        rows.iter().map(observe).map(|v| v.to_string()).collect::<Vec<_>>().join("\n") + "\n";
    if let Some(path) = std::env::var_os("ETNA_STATEMENT_OUTPUT") {
        std::fs::write(path, output).unwrap();
    }
}

#[test]
fn formal_cut_conformance() {
    let formal = PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("../../../../formal/etna");
    let input = std::env::var_os("ETNA_CUT_INPUT")
        .map(PathBuf::from)
        .unwrap_or_else(|| formal.join("reports/landing-cuts-observations.jsonl"));
    let rows: Vec<Value> = std::fs::read_to_string(input)
        .unwrap()
        .lines()
        .map(|s| serde_json::from_str(s).unwrap())
        .collect();
    assert_eq!(rows.len(), 4);
    let mut output = Vec::new();
    for row in rows {
        let fees: Vec<u128> = row["feesGwei"]
            .as_array()
            .unwrap()
            .iter()
            .map(|v| v.as_str().unwrap().parse().unwrap())
            .collect();
        let steps = row["steps"].as_array().unwrap();
        let mut head = number(&row, "initialHead");
        let initial = head;
        let mut previous_height = 0;
        let mut intervals = Vec::new();
        let mut paid = 0_u128;
        for cut in row["cuts"].as_array().unwrap() {
            let height = cut.as_u64().unwrap() as usize;
            let before = head;
            for consume in &steps[previous_height..height] {
                let consume = consume.as_u64().unwrap();
                assert!(consume <= 1);
                head = etna_consensus_core::forced::advance_cursor(
                    head,
                    (consume == 1).then_some(head),
                )
                .unwrap();
            }
            let amount =
                fees[(before - initial) as usize..(head - initial) as usize].iter().sum::<u128>() *
                    1_000_000_000;
            paid += amount;
            intervals.push(json!({"before":before,"after":head,"paidWei":amount.to_string(),
                "lastHeight":number(&row,"initialHeight") + height as u64}));
            previous_height = height;
        }
        output.push(
            json!({"id":row["id"],"finalHead":head,
            "finalHeight":number(&row,"initialHeight") + previous_height as u64,
            "paidWei":paid.to_string(),"intervals":intervals})
            .to_string(),
        );
    }
    if let Some(path) = std::env::var_os("ETNA_CUT_OUTPUT") {
        std::fs::write(path, output.join("\n") + "\n").unwrap();
    }
}
