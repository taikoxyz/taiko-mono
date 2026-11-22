//! The CometBFT genesis of the Etna PoS chain: the genesis witness carried in `app_state`, and the
//! `abci-genesis` builder that reads it from L1.
//!
//! `genesis.json`'s `app_state` is the JSON object `{"witness": "0x<hex>"}`, where the hex string
//! is the RLP of a [`GenesisWitness`]: the raw `L1_0` header and the Inbox proofs of the genesis
//! slots, generation 0's origin record among them. `InitChain` decodes it with
//! [`decode_bootstrap_state`] and re-verifies every fact against the node's own L1; nothing in it
//! is trusted. The genesis validators are the keys of the fallback key list whose hash the origin
//! record's fourth word holds, each at power 1; the list is accepted only under that hash.
//!
//! [`build_genesis`] reads the Ethereum-final genesis record from the node's own L1, checks it
//! as `InitChain` will, obtains the origin fallback key list by its hash, and assembles the whole
//! CometBFT v0.40 [`GenesisDoc`]. The codec here performs no I/O; the builder reads L1 through
//! [`L1Source`].
//!
//! [`L1Source`]: crate::l1::L1Source

use alloy_primitives::{B256, Bytes};
use alloy_rlp::{Decodable, RlpDecodable, RlpEncodable};
use serde::{Deserialize, Serialize};

use crate::{
    l1::{L1Error, WitnessError, header::RawL1Header, layout::inbox},
    types::AccountWitness,
    valstate::ValStateError,
};

/// The `abci-genesis` builder: L1 reads and self-checks.
mod build;
/// The CometBFT v0.40 `genesis.json` document.
mod doc;
/// Shared pure verification of the genesis context.
mod verify;

pub(crate) use doc::genesis_time;
pub(crate) use verify::{GenesisContext, verify_context, verify_deployment_context};

pub use build::build_genesis;
pub use doc::{
    AbciParams, AuthorityParams, BLOCK_MAX_BYTES, BlockParams, EVIDENCE_MAX_AGE_DURATION,
    EVIDENCE_MAX_AGE_NUM_BLOCKS, EvidenceParams, GenesisConsensusParams, GenesisDoc,
    GenesisValidator, ValidatorParams, VersionParams, genesis_app_hash, validator_address,
};

/// Everything `InitChain` verifies to start the chain, carried in the genesis `app_state`.
///
/// RLP: `[l1_header, inbox]`, where `l1_header` is a byte string holding the raw header RLP (as
/// in the envelope's anchor witness).
#[derive(Clone, Debug, PartialEq, Eq, RlpEncodable, RlpDecodable)]
pub struct GenesisWitness {
    /// The raw L1 header of block `L1_0`; its `stateRoot` is the root of the proof.
    pub l1_header: RawL1Header,
    /// EIP-1186 proof of the Inbox account and `layout::inbox::genesis_slots()`, in slot order.
    pub inbox: AccountWitness,
}

/// Disjoint initialization evidence for the deployment or a governance-created generation.
/// This startup-only public API carries the two witness types directly; it is never cached per
/// block.
#[allow(clippy::large_enum_variant)]
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum BootstrapWitness {
    /// Original generation-zero RLP, retained byte-for-byte.
    Initial(GenesisWitness),
    /// Versioned recovery evidence prefixed by the disjoint byte `0x01`.
    Recovery(crate::recovery::RecoveryWitness),
}

/// Decodes the shared JSON wrapper, rejecting unknown versions and trailing bytes.
/// This verifies encoding only; InitChain authenticates the evidence independently.
pub fn decode_bootstrap_state(bytes: &[u8]) -> Result<BootstrapWitness, GenesisError> {
    let json: AppStateJson = serde_json::from_slice(bytes).map_err(GenesisError::Json)?;
    let mut buf = json.witness.as_ref();
    let witness = if buf.first() == Some(&1) {
        buf = &buf[1..];
        let recovery = crate::recovery::RecoveryWitness::decode(&mut buf)?;
        if recovery.version != crate::recovery::RECOVERY_WITNESS_VERSION {
            return Err(GenesisError::UnsupportedRecovery("unsupported witness version".into()));
        }
        BootstrapWitness::Recovery(recovery)
    } else {
        BootstrapWitness::Initial(GenesisWitness::decode(&mut buf)?)
    };
    if !buf.is_empty() {
        return Err(GenesisError::TrailingBytes(buf.len()));
    }
    Ok(witness)
}

impl From<&crate::recovery::RecoveryWitness> for AppStateJson {
    /// Encodes the disjoint recovery discriminator followed by the unchanged witness RLP.
    fn from(w: &crate::recovery::RecoveryWitness) -> Self {
        let mut bytes = vec![1];
        bytes.extend(alloy_rlp::encode(w));
        Self { witness: bytes.into() }
    }
}

/// The JSON shape of the genesis `app_state`: `{"witness": "0x<hex rlp(GenesisWitness)>"}`.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct AppStateJson {
    /// Generation-zero witness RLP or `0x01 || rlp(RecoveryWitness)`, encoded as a `0x`-prefixed
    /// hex string.
    pub witness: Bytes,
}

/// Why the genesis `app_state` could not be decoded, or a genesis could not be built.
///
/// [`decode_bootstrap_state`] yields only [`GenesisError::Json`], [`GenesisError::Rlp`],
/// [`GenesisError::TrailingBytes`] and, for an unsupported recovery witness version,
/// [`GenesisError::UnsupportedRecovery`]; the other variants come from building or verifying a
/// genesis.
#[derive(Debug, thiserror::Error)]
pub enum GenesisError {
    /// Unsupported bootstrap encoding, or recovery evidence passed to the generation-zero path.
    #[error("unsupported recovery: {0}")]
    UnsupportedRecovery(String),
    /// The built-in L2 chain id, staking proxy and U do not open the configuration hash the
    /// Inbox holds in slot 269.
    #[error("configuration hash {local} differs from the authenticated {proven}")]
    ConfigMismatch {
        /// [`ChainParams::config_hash`](crate::ChainParams::config_hash) of the local values.
        local: B256,
        /// Configuration hash proven under the genesis header.
        proven: B256,
    },
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
    /// An L1 read failed.
    #[error(transparent)]
    L1(#[from] L1Error),
    /// The Inbox at the L1 `finalized` block is not in `ETNA_ACTIVE`; the value is its
    /// `migrationState`.
    #[error(
        "inbox status at the finalized L1 block is {0}, expected ETNA_ACTIVE ({active})",
        active = inbox::ETNA_ACTIVE
    )]
    NotActive(u8),
    /// The initialization block `L1_0` is above the own L1 node's `finalized` block.
    #[error("genesis L1 block {l1_0} is not final: finalized is {finalized}")]
    InitializationNotFinal {
        /// `L1_0` read from the initialized Inbox.
        l1_0: u64,
        /// The L1 node's `finalized` block number.
        finalized: u64,
    },
    /// The Inbox proofs at `L1_0` do not verify, or do not show a valid genesis (boxed, as the
    /// witness error is large).
    #[error("genesis inbox witness rejected: {0}")]
    Witness(Box<WitnessError>),
    /// The proven genesis record names an initialization L1 block different from its header.
    #[error("genesis record at L1 block {l1_0} names L1_0 = {proven}")]
    InitializationMismatch {
        /// The supplied header's number (the block the proofs are taken at).
        l1_0: u64,
        /// `L1_0` from the record proven at that block.
        proven: u64,
    },
    /// The `L1_0` timestamp (Unix seconds) is not a valid CometBFT genesis time.
    #[error("L1_0 timestamp {0} is not a valid genesis time")]
    GenesisTime(u64),
    /// The initial set is not a set CometBFT accepts, so it has no genesis validator state for
    /// the genesis `app_hash` to commit.
    #[error("the genesis validators are not a CometBFT validator set: {0}")]
    ValidatorSet(#[from] ValStateError),
    /// A generation's fallback key list hashes to another value than the `fallbackKeysHash` of
    /// its origin record.
    #[error("fallback key list hashes to {got}, the origin record holds {expected}")]
    FallbackKeysMismatch {
        /// The supplied list's hash.
        got: B256,
        /// The origin record's `fallbackKeysHash`.
        expected: B256,
    },
    /// The own L1 gave no fallback key list with this hash, the one generation zero's origin
    /// record holds; the reason says what was tried.
    #[error("the origin fallback key list {hash} is unavailable: {reason}")]
    FallbackKeysUnavailable {
        /// The origin record's `fallbackKeysHash`.
        hash: B256,
        /// What the own L1 answered.
        reason: String,
    },
    /// Recovery bootstrap evidence is unavailable, superseded or invalid; it keeps its own
    /// class, so `InitChain` retries or halts on it as on any recovery evidence.
    #[error(transparent)]
    Recovery(#[from] crate::recovery::RecoveryError),
}

impl From<WitnessError> for GenesisError {
    /// Boxes `e` into [`GenesisError::Witness`].
    fn from(e: WitnessError) -> Self {
        Self::Witness(Box::new(e))
    }
}

impl From<&GenesisWitness> for AppStateJson {
    /// The `app_state` carrying `rlp(w)`.
    fn from(w: &GenesisWitness) -> Self {
        Self { witness: alloy_rlp::encode(w).into() }
    }
}

/// Encodes `w` as the genesis `app_state` JSON `{"witness": "0x<hex rlp(w)>"}`.
#[cfg(test)]
pub(crate) fn encode_app_state(w: &GenesisWitness) -> Vec<u8> {
    serde_json::to_vec(&AppStateJson::from(w))
        .expect("a struct with one byte-string field always serializes")
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::{
        test_utils::{l1_header, raw_with_future_fields},
        types::StorageProof,
    };
    use alloy_consensus::Header;
    use alloy_primitives::{Address, B256, U256, bytes, keccak256};

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
            l1_header: RawL1Header::from(&Header {
                state_root: B256::repeat_byte(0x5a),
                ..l1_header(64, 1_000)
            }),
            inbox: account(1),
        }
    }

    #[test]
    fn app_state_round_trips() {
        let w = witness();
        assert_eq!(
            decode_bootstrap_state(&encode_app_state(&w)).expect("decodes"),
            BootstrapWitness::Initial(w)
        );
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

    /// The RLP list of `items`, each already encoded.
    fn rlp_list(items: &[Vec<u8>]) -> Vec<u8> {
        let payload = items.concat();
        let mut list = Vec::new();
        alloy_rlp::Header { list: true, payload_length: payload.len() }.encode(&mut list);
        list.extend(payload);
        list
    }

    /// The genesis witness is the RLP list of exactly two items, the `L1_0` header and the Inbox
    /// proof; a list with a third item, as the witness carried a committee before, is refused.
    #[test]
    fn genesis_witness_has_two_items() {
        let w = witness();
        let items = [alloy_rlp::encode(&w.l1_header), alloy_rlp::encode(&w.inbox)];
        assert_eq!(alloy_rlp::encode(&w), rlp_list(&items));
        let third = [items[0].clone(), items[1].clone(), alloy_rlp::encode(account(2))];
        let json = serde_json::to_vec(&AppStateJson { witness: rlp_list(&third).into() }).unwrap();
        assert!(matches!(decode_bootstrap_state(&json), Err(GenesisError::Rlp(_))));
    }

    /// The `L1_0` header travels as one RLP byte string of its raw bytes, so a header of an L1
    /// fork newer than this client (two unknown trailing fields here) round-trips unchanged.
    #[test]
    fn the_l1_header_is_carried_as_its_raw_bytes() {
        let raw = raw_with_future_fields(&l1_header(64, 1_000));
        let w = GenesisWitness {
            l1_header: RawL1Header::from_raw(raw.clone()).expect("a header"),
            ..witness()
        };
        let encoded = alloy_rlp::encode(&w);
        let mut payload = alloy_rlp::Header::decode_bytes(&mut encoded.as_slice(), true).unwrap();
        assert_eq!(
            alloy_rlp::Header::decode_bytes(&mut payload, false),
            Ok(raw.as_ref()),
            "the first field is the raw header as a byte string"
        );
        let BootstrapWitness::Initial(decoded) =
            decode_bootstrap_state(&encode_app_state(&w)).expect("decodes")
        else {
            panic!("a generation-zero witness decodes as Initial");
        };
        assert_eq!(decoded.l1_header.hash(), keccak256(&raw));
        assert_eq!(decoded, w);
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
            let err = decode_bootstrap_state(&bytes).expect_err("must reject");
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
            assert!(matches!(decode_bootstrap_state(&json), Err(GenesisError::Rlp(_))));
        }
    }

    #[test]
    fn trailing_bytes_after_the_witness_are_rejected() {
        let mut rlp = alloy_rlp::encode(witness());
        rlp.extend([0x80, 0x80]);
        let json = serde_json::to_vec(&AppStateJson { witness: rlp.into() }).unwrap();
        assert!(matches!(decode_bootstrap_state(&json), Err(GenesisError::TrailingBytes(2))));
    }
}

/// Pure bootstrap verification shared by `InitChain` and offline import.
mod import;
pub(crate) use import::named_fallback_keys;
pub use import::{GenesisExpectation, VerifiedGenesis, verify_bootstrap, verify_original_genesis};
