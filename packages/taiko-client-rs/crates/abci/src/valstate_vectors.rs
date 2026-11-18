//! Independent stock CometBFT state vectors exercised through the ABCI validator replica.

use std::collections::BTreeMap;

use alloy::sol_types::{
    SolType,
    sol_data::{Array, FixedBytes, Int, Uint},
};
use alloy_primitives::{Address, B256, U256, hex};
use serde_json::Value;

use super::{ValEntry, ValSet, ValState};
use crate::{
    committee,
    key::ConsensusKey,
    test_utils::{test_key, vectors::at},
    types::Member,
    wire::ValidatorUpdate,
};

fn number(value: &Value) -> u64 {
    value.as_str().unwrap().parse().unwrap()
}

fn key_ring() -> BTreeMap<&'static str, ConsensusKey> {
    at("/val_state_chains/keys")
        .as_array()
        .unwrap()
        .iter()
        .map(|key| {
            let public = hex::decode(key["public_key"].as_str().unwrap()).unwrap();
            let public = ConsensusKey::from_slice(&public).unwrap();
            assert_eq!(u64::from(public.prefix()), number(&key["ck_prefix"]));
            assert_eq!(public.x(), key["ck_x"].as_str().unwrap().parse::<B256>().unwrap());
            assert_eq!(
                public.address(),
                key["ck_addr"].as_str().unwrap().parse::<Address>().unwrap()
            );
            (key["name"].as_str().unwrap(), public)
        })
        .collect()
}

fn changes(value: &Value, keys: &BTreeMap<&str, ConsensusKey>) -> Vec<(ConsensusKey, u64)> {
    value
        .as_array()
        .unwrap()
        .iter()
        .map(|row| (keys[row[0].as_str().unwrap()], number(&row[1])))
        .collect()
}

fn recorded_set(value: &Value, proposer: &Value, keys: &BTreeMap<&str, ConsensusKey>) -> ValSet {
    ValSet {
        entries: value
            .as_array()
            .unwrap()
            .iter()
            .map(|row| ValEntry {
                key: keys[row[0].as_str().unwrap()],
                power: row[1].as_str().unwrap().parse().unwrap(),
                priority: row[2].as_str().unwrap().parse().unwrap(),
            })
            .collect(),
        proposer: number(proposer).try_into().unwrap(),
    }
}

// Alloy's ABI encoder builds the expectation directly from the recorded entries, rather than
// using the replica's manual encoder (including its offsets and int64 sign extension).
fn abi_preimage(state: &ValState) -> Vec<u8> {
    type Rows = Array<(Uint<8>, FixedBytes<32>, Uint<64>, Int<64>)>;
    type Preimage = (FixedBytes<32>, Uint<256>, Rows, Uint<256>, Rows, Uint<256>);
    let rows = |set: &ValSet| {
        set.entries
            .iter()
            .map(|entry| (entry.key.prefix(), entry.key.x(), entry.power as u64, entry.priority))
            .collect::<Vec<_>>()
    };
    Preimage::abi_encode_params(&(
        B256::new(hex!("45544e415f56414c5f53544154455f5631000000000000000000000000000000")),
        U256::from(state.height),
        rows(&state.current),
        U256::from(state.current.proposer),
        rows(&state.next),
        U256::from(state.next.proposer),
    ))
}

fn members(set: &ValSet) -> Vec<Member> {
    set.entries
        .iter()
        .map(|entry| Member {
            pubkey: entry.key,
            power: entry.power.try_into().unwrap(),
            eff_stake: U256::ZERO,
        })
        .collect()
}

// Apply the actual committee update builder and native ABCI key/power codec. The stock inputs
// contain sparse changes; ABCI returns the full changed committee, including unchanged members.
fn abci_updates(previous: &ValSet, recorded: &ValSet) -> Vec<(ConsensusKey, u64)> {
    committee::validator_updates(&members(previous), &members(recorded))
        .into_iter()
        .map(|(pub_key, power)| {
            let update = ValidatorUpdate { pub_key, power: power.try_into().unwrap() };
            let decoded = ValidatorUpdate::decode(&update.encode()).unwrap();
            (decoded.pub_key, decoded.power.value())
        })
        .collect()
}

// Catches update activation one height early/late, incorrect proposer indexes, priority
// centering/rescaling/ties and treating the recovery origin as height zero. Expected hashes and
// every set row come from stock ApplyVerifiedBlock, not another replay of our arithmetic.
#[test]
fn shared_stock_chains_replay_every_abci_validator_state() {
    assert_eq!(at("/schema_version"), "6");
    assert_eq!(at("/val_state_chains/cometbft"), "v0.40.0");
    let keys = key_ring();
    let mut checked = 0;
    for chain in at("/val_state_chains/chains").as_array().unwrap() {
        let name = chain["name"].as_str().unwrap();
        let mut state =
            ValState::genesis(number(&chain["start_height"]), &changes(&chain["genesis"], &keys))
                .unwrap();
        let mut sparse_state = state.clone();
        for (index, recorded) in chain["states"].as_array().unwrap().iter().enumerate() {
            let height = number(&recorded["height"]);
            let expected = ValState {
                height,
                current: recorded_set(&recorded["current"], &recorded["current_proposer"], &keys),
                next: recorded_set(&recorded["next"], &recorded["next_proposer"], &keys),
            };
            if index > 0 {
                let switch = chain["switches"]
                    .as_array()
                    .unwrap()
                    .iter()
                    .find(|switch| number(&switch["height"]) == height);
                let sparse = switch.map_or_else(Vec::new, |switch| {
                    assert_eq!(number(&switch["activation_height"]), height + 2);
                    changes(&switch["changes"], &keys)
                });
                let updates = abci_updates(&state.next, &expected.next);
                let previous: BTreeMap<_, _> =
                    state.next.entries.iter().map(|e| (e.key, e.power as u64)).collect();
                let changed: BTreeMap<_, _> = updates
                    .iter()
                    .copied()
                    .filter(|(key, power)| previous.get(key) != Some(power))
                    .collect();
                assert_eq!(
                    changed,
                    sparse.iter().copied().collect(),
                    "{name} at {height}: updates"
                );
                state = state.advance(&updates).unwrap();
                sparse_state = sparse_state.advance(&sparse).unwrap();
            }
            assert_eq!(state, expected, "{name} at {height}: ABCI updates");
            assert_eq!(sparse_state, expected, "{name} at {height}: sparse updates");
            let preimage = abi_preimage(&expected);
            if index == 0 {
                assert_eq!(
                    preimage,
                    hex::decode(chain["start_preimage"].as_str().unwrap()).unwrap(),
                    "{name}: genesis preimage"
                );
            }
            assert_eq!(state.encode(), preimage, "{name} at {height}: preimage");
            assert_eq!(ValState::decode(&preimage), Ok(expected), "{name} at {height}: decode");
            assert_eq!(
                state.hash(),
                recorded["hash"].as_str().unwrap().parse::<B256>().unwrap(),
                "{name} at {height}: stock hash"
            );
            checked += 1;
        }
        assert_eq!(state.height, number(&chain["end_height"]), "{name}: full chain");
    }
    assert_eq!(checked, 79);
}

// Catches full-size power/address ordering and priority arithmetic at MaxTotalVotingPower.
#[test]
fn shared_stock_max_committee_replays_both_recorded_hashes() {
    let fixture = at("/val_state_chains/max_committee");
    let size = number(&fixture["size"]) as usize;
    let first: U256 = fixture["first_private_key"].as_str().unwrap().parse().unwrap();
    let first: u64 = first.try_into().unwrap();
    let mut genesis = (0..size)
        .map(|index| (test_key(first - 1 + index as u64), (1_u64 << 48) + (index % 64) as u64 - 32))
        .collect::<Vec<_>>();
    genesis.last_mut().unwrap().1 = number(&fixture["total_power"]) -
        genesis[..size - 1].iter().map(|(_, power)| power).sum::<u64>();
    assert_eq!(genesis.last().unwrap().1, number(&fixture["last_member_power"]));
    let keys: BTreeMap<_, _> =
        genesis.iter().enumerate().map(|(index, (key, _))| (format!("m{index}"), *key)).collect();
    let keys: BTreeMap<_, _> = keys.iter().map(|(name, key)| (name.as_str(), *key)).collect();
    let mut state = ValState::genesis(number(&fixture["start_height"]), &genesis).unwrap();
    for (index, recorded) in fixture["states"].as_array().unwrap().iter().enumerate() {
        if index > 0 {
            state = state.advance(&[]).unwrap();
        }
        assert_eq!(state.height, number(&recorded["height"]));
        assert_eq!(state.hash(), recorded["hash"].as_str().unwrap().parse::<B256>().unwrap());
        let preimage = state.encode();
        assert_eq!(preimage.len(), number(&recorded["preimage_bytes"]) as usize);
        assert_eq!(preimage, abi_preimage(&state));
        for (name, set) in [("current", &state.current), ("next", &state.next)] {
            // Stock v0.40.0 types.NewValidatorSet(genesis).Hash(), independently computed
            // from this fixture's 4096 private scalars/powers; priority increments retain it.
            assert_eq!(
                set.validators_hash().unwrap(),
                alloy_primitives::b256!(
                    "b3e07311372bda118c862e32a3f1a5f0a2f3dc4033b8d68212906881f48dac0c"
                )
            );
            let proposer = number(&recorded[format!("{name}_proposer")]) as usize;
            assert_eq!(set.proposer, proposer);
            for (side, actual) in [("head", &set.entries[..3]), ("tail", &set.entries[size - 3..])]
            {
                let expected = recorded_set(
                    &recorded[format!("{name}_{side}")],
                    &Value::String("0".into()),
                    &keys,
                );
                assert_eq!(actual, expected.entries);
            }
        }
    }
}

// Catches accidental hashing of priorities/proposer and a cached hash surviving add/remove or
// power updates. This expected native hash was produced by the separate stock wire oracle.
#[test]
fn canonical_set_native_hash_tracks_changes_and_excludes_proposer_state() {
    let oracle: Value = serde_json::from_str(include_str!("../testdata/comet-wire.json")).unwrap();
    let entries: Vec<(ConsensusKey, u64)> = oracle["members"]
        .as_array()
        .unwrap()
        .iter()
        .map(|member| {
            (
                ConsensusKey::from_slice(&hex::decode(member["key"].as_str().unwrap()).unwrap())
                    .unwrap(),
                member["power"].as_u64().unwrap(),
            )
        })
        .collect();
    let expected: B256 = oracle["validators_hash"].as_str().unwrap().parse().unwrap();
    let mut state = ValState::genesis(0, &entries[..1]).unwrap();
    assert_ne!(state.next.validators_hash().unwrap(), expected);
    state = state.advance(&entries[1..]).unwrap();
    assert_eq!(state.next.validators_hash().unwrap(), expected);
    assert_ne!(state.current.validators_hash().unwrap(), expected);
    state = state.advance(&[]).unwrap();
    assert_eq!(state.current.validators_hash().unwrap(), expected);
    let state_hash = state.hash();
    state.next.proposer = (state.next.proposer + 1) % state.next.entries.len();
    assert_ne!(state.hash(), state_hash);
    assert_eq!(state.next.validators_hash().unwrap(), expected);
    let state_hash = state.hash();
    for (index, entry) in state.next.entries.iter_mut().enumerate() {
        entry.priority = if index == 0 { i64::MIN } else { i64::MAX };
    }
    assert_ne!(state.hash(), state_hash);
    assert_eq!(state.next.validators_hash().unwrap(), expected);
    state = state.advance(&[(entries[0].0, 11), (entries[1].0, 0)]).unwrap();
    assert_ne!(state.next.validators_hash().unwrap(), expected);
    state = state.advance(&entries).unwrap();
    assert_eq!(state.next.validators_hash().unwrap(), expected);
    state.next.entries[0].power = -1;
    assert!(state.next.validators_hash().is_err());
}
