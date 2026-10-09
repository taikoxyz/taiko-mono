//! The CometBFT genesis `app_state` of the Etna PoS chain (spec §5.1).
//!
//! `genesis.json`'s `app_state` is the JSON object `{"witness": "0x<hex>"}`, where the hex string
//! is the RLP of a [`GenesisWitness`]: the `L1_0` header, the Inbox proofs of the activation slots
//! and `committee[e_0]`, and the committee witness of epoch `e_0`. `InitChain` decodes it with
//! [`decode_app_state`] and re-verifies every fact against the node's own L1; nothing in it is
//! trusted. The `abci-genesis` builder that reads these facts from L1 lives here too (task 14).

use alloy_consensus::Header;
use alloy_primitives::Bytes;
use alloy_rlp::{Decodable, RlpDecodable, RlpEncodable};
use serde::{Deserialize, Serialize};

use crate::{envelope::CommitteeWitness, types::AccountWitness};

/// Everything `InitChain` verifies to start the chain, carried in the genesis `app_state`.
///
/// RLP: `[l1_header, inbox, committee]`.
#[derive(Clone, Debug, PartialEq, Eq, RlpEncodable, RlpDecodable)]
pub struct GenesisWitness {
    /// The L1 header of block `L1_0`; its `stateRoot` is the root of both proofs.
    pub l1_header: Header,
    /// EIP-1186 proof of the Inbox account and `layout::inbox::genesis_slots(E0)`, in slot order.
    pub inbox: AccountWitness,
    /// The committee witness of epoch `e_0` (target epoch 0, parent anchor `L1_0`), proven
    /// against the same `stateRoot`.
    pub committee: CommitteeWitness,
}

/// The JSON shape of the genesis `app_state`: `{"witness": "0x<hex rlp(GenesisWitness)>"}`.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct AppStateJson {
    /// `rlp(GenesisWitness)`, serialized as a `0x`-prefixed hex string.
    pub witness: Bytes,
}

/// Why the genesis `app_state` could not be decoded.
#[derive(Debug, thiserror::Error)]
pub enum GenesisError {
    /// The bytes are not the JSON object `{"witness": "0x<hex>"}` (malformed JSON, a missing or
    /// unknown field, or a malformed hex string).
    #[error("genesis app_state is not {{\"witness\": \"0x<hex>\"}}: {0}")]
    Json(#[source] serde_json::Error),
    /// The witness bytes are not a well-formed RLP [`GenesisWitness`].
    #[error("malformed genesis witness RLP: {0}")]
    Rlp(#[from] alloy_rlp::Error),
    /// Bytes remain after the witness RLP list; the value is how many.
    #[error("{0} trailing bytes after the genesis witness")]
    TrailingBytes(usize),
}

/// Decodes the genesis `app_state` JSON into its [`GenesisWitness`].
///
/// Rejects anything but the exact JSON object `{"witness": "0x<hex>"}`, malformed witness RLP and
/// trailing bytes after the witness. Verifies none of the witness's facts.
pub fn decode_app_state(bytes: &[u8]) -> Result<GenesisWitness, GenesisError> {
    let json: AppStateJson = serde_json::from_slice(bytes).map_err(GenesisError::Json)?;
    let mut buf = json.witness.as_ref();
    let witness = GenesisWitness::decode(&mut buf)?;
    if !buf.is_empty() {
        return Err(GenesisError::TrailingBytes(buf.len()));
    }
    Ok(witness)
}

/// Encodes `w` as the genesis `app_state` JSON `{"witness": "0x<hex rlp(w)>"}`.
pub fn encode_app_state(w: &GenesisWitness) -> Vec<u8> {
    let json = AppStateJson { witness: alloy_rlp::encode(w).into() };
    serde_json::to_vec(&json).expect("a struct with one byte-string field always serializes")
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::{
        test_utils::l1_header,
        types::{CommitteeRecord, RegistryEntry, StorageProof},
    };
    use alloy_primitives::{Address, B256, U256, bytes};

    fn account(seed: u8) -> AccountWitness {
        AccountWitness {
            address: Address::repeat_byte(seed),
            nonce: u64::from(seed),
            balance: U256::from(seed),
            storage_root: B256::repeat_byte(seed),
            code_hash: B256::repeat_byte(seed ^ 0xff),
            account_proof: vec![bytes!("f8518080"), Bytes::from(vec![seed; 33])],
            storage: vec![StorageProof {
                slot: B256::with_last_byte(seed),
                value: U256::from(seed) << 100,
                proof: vec![Bytes::from(vec![seed; 3])],
            }],
        }
    }

    fn witness() -> GenesisWitness {
        GenesisWitness {
            l1_header: Header { state_root: B256::repeat_byte(0x5a), ..l1_header(64, 1_000) },
            inbox: account(1),
            committee: CommitteeWitness {
                record: CommitteeRecord {
                    target_epoch: 0,
                    cutoff_l1_block: 64,
                    checkpoint_index: 2,
                    set_root: B256::repeat_byte(0x77),
                    total_stake: U256::from(10).pow(U256::from(19)),
                    total_power: 10_000_000_000,
                    encoding_version: 1,
                },
                registry: account(2),
                entries: vec![RegistryEntry {
                    pubkey: B256::repeat_byte(0xed),
                    eff_stake: U256::from(10).pow(U256::from(19)),
                    active_from_l1: 0,
                    exit_effective_l1: u64::MAX,
                    last_heartbeat_at: 3,
                }],
            },
        }
    }

    #[test]
    fn app_state_round_trips() {
        let w = witness();
        assert_eq!(decode_app_state(&encode_app_state(&w)).expect("decodes"), w);
    }

    #[test]
    fn app_state_is_a_json_object_with_a_hex_witness() {
        let w = witness();
        let json: serde_json::Value =
            serde_json::from_slice(&encode_app_state(&w)).expect("app_state is JSON");
        let object = json.as_object().expect("app_state is an object");
        assert_eq!(object.len(), 1);
        let hex = object["witness"].as_str().expect("witness is a string");
        assert!(hex.starts_with("0x"), "{hex}");
        assert_eq!(hex[2..], alloy_primitives::hex::encode(alloy_rlp::encode(&w)));
    }

    #[test]
    fn witness_is_the_rlp_list_of_its_three_fields() {
        let w = witness();
        let mut fields = Vec::new();
        alloy_rlp::Encodable::encode(&w.l1_header, &mut fields);
        alloy_rlp::Encodable::encode(&w.inbox, &mut fields);
        alloy_rlp::Encodable::encode(&w.committee, &mut fields);
        let mut expected = Vec::new();
        alloy_rlp::Header { list: true, payload_length: fields.len() }.encode(&mut expected);
        expected.extend(fields);
        assert_eq!(alloy_rlp::encode(&w), expected);
    }

    #[test]
    fn non_json_or_wrong_shape_is_rejected() {
        let hex = format!("0x{}", alloy_primitives::hex::encode(alloy_rlp::encode(witness())));
        let bad = [
            b"not json".to_vec(),
            b"".to_vec(),
            b"{}".to_vec(),
            b"[]".to_vec(),
            b"{\"witness\": 7}".to_vec(),
            b"{\"witness\": \"0xzz\"}".to_vec(),
            format!("{{\"witness\": \"{hex}\", \"extra\": 1}}").into_bytes(),
        ];
        for bytes in bad {
            let err = decode_app_state(&bytes).expect_err("must reject");
            assert!(
                matches!(err, GenesisError::Json(_)),
                "{:?}: {err:?}",
                String::from_utf8_lossy(&bytes)
            );
        }
    }

    #[test]
    fn malformed_witness_rlp_is_rejected() {
        for witness in [bytes!(""), bytes!("c0"), bytes!("c3010203"), bytes!("f9")] {
            let json = serde_json::to_vec(&AppStateJson { witness }).unwrap();
            assert!(matches!(decode_app_state(&json), Err(GenesisError::Rlp(_))));
        }
    }

    #[test]
    fn trailing_bytes_after_the_witness_are_rejected() {
        let mut rlp = alloy_rlp::encode(witness());
        rlp.extend([0x80, 0x80]);
        let json = serde_json::to_vec(&AppStateJson { witness: rlp.into() }).unwrap();
        assert!(matches!(decode_app_state(&json), Err(GenesisError::TrailingBytes(2))));
    }
}
