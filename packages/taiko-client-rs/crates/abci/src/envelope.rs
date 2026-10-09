//! The CometBFT block envelope (spec §4.1).
//!
//! Every CometBFT block's `Data.Txs` holds exactly one item, the envelope:
//!
//! ```text
//! envelope     = 0x01 || rlp(EtnaEnvelope)
//! EtnaEnvelope = [ block, anchor, committee ]
//! block        = [ header, transactions ]   // EL header RLP, EIP-2718 tx bytes as opaque strings
//! anchor       = [] | [ AnchorWitness ]     // empty list = absent
//! committee    = [] | [ CommitteeWitness ]
//! ```
//!
//! The inner structs are RLP lists of their fields in declaration order.

use alloy_consensus::Header;
use alloy_primitives::Bytes;
use alloy_rlp::{BufMut, Decodable, Encodable, RlpDecodable, RlpEncodable};

use crate::types::{AccountWitness, CommitteeRecord, RegistryEntry};

/// Leading version byte of every envelope.
pub const ENVELOPE_VERSION: u8 = 1;

/// The L2 execution block a CometBFT block carries.
///
/// RLP: `[header, transactions]`. The block is fully determined by these two fields: withdrawals
/// are empty and no transaction carries blobs (PRF-06).
#[derive(Clone, Debug, PartialEq, Eq, RlpEncodable, RlpDecodable)]
pub struct ExecutionBlock {
    /// The full EL header (under alethia-reth #248 `difficulty` carries the block's zk gas).
    pub header: Header,
    /// EIP-2718 encoded transactions, carried as opaque byte strings in block order.
    pub transactions: Vec<Bytes>,
}

/// The L1 anchor witness: an L1 header plus the Inbox account and storage proofs against its
/// `stateRoot` (spec §4.1, §6.2).
///
/// RLP: `[l1_header, inbox]`.
#[derive(Clone, Debug, PartialEq, Eq, RlpEncodable, RlpDecodable)]
pub struct AnchorWitness {
    /// The anchor L1 header; its hash is the anchor hash and its `stateRoot` the proof root.
    pub l1_header: Header,
    /// EIP-1186 proof of the Inbox account and its anchor slot set, in slot order.
    pub inbox: AccountWitness,
}

/// The committee witness carried at an epoch's first height (spec §4.1, §6.4).
///
/// RLP: `[record, registry, entries]`. The registry proofs verify against the parent's anchor
/// `stateRoot`.
#[derive(Clone, Debug, PartialEq, Eq, RlpEncodable, RlpDecodable)]
pub struct CommitteeWitness {
    /// The committee record the block claims for the starting epoch.
    pub record: CommitteeRecord,
    /// EIP-1186 proof of the staking-registry account and its snapshot slots.
    pub registry: AccountWitness,
    /// The registry entries of the snapshot checkpoint, in index order.
    pub entries: Vec<RegistryEntry>,
}

/// The decoded block envelope: the execution block plus the optional L1 witnesses.
///
/// Wire format: `0x01 || rlp([block, anchor, committee])`, where each optional witness is an empty
/// RLP list when absent and a one-element RLP list holding the witness when present.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct EtnaEnvelope {
    /// The L2 execution block.
    pub block: ExecutionBlock,
    /// Present iff the block moves the anchor, is `H_0`, or is a switch height.
    pub anchor: Option<AnchorWitness>,
    /// Present iff the block is the first height of an epoch.
    pub committee: Option<CommitteeWitness>,
}

/// Why an envelope (or a CometBFT block's transaction list) failed to decode.
#[derive(Debug, thiserror::Error, Clone, Copy, PartialEq, Eq)]
pub enum EnvelopeError {
    /// The envelope is zero bytes long, so it has no version byte.
    #[error("empty envelope")]
    Empty,
    /// The leading version byte is not [`ENVELOPE_VERSION`].
    #[error("unsupported envelope version {0}, expected {ENVELOPE_VERSION}")]
    Version(u8),
    /// The RLP after the version byte is malformed or does not match the envelope shape.
    #[error("malformed envelope RLP: {0}")]
    Rlp(#[from] alloy_rlp::Error),
    /// Bytes remain after the outer envelope list; the value is how many.
    #[error("{0} trailing bytes after the envelope")]
    TrailingBytes(usize),
    /// An optional witness list (`anchor` or `committee`, named by the value) holds more than one
    /// element.
    #[error("optional envelope field `{0}` holds more than one element")]
    OptionalArity(&'static str),
    /// The CometBFT block does not carry exactly one transaction; the value is how many it has.
    #[error("block must carry exactly one transaction, found {0}")]
    TxCount(usize),
}

impl EtnaEnvelope {
    /// Encodes the envelope as `0x01 || rlp([block, anchor, committee])`.
    pub fn encode(&self) -> Bytes {
        let mut out = Vec::with_capacity(1 + Encodable::length(self));
        out.push(ENVELOPE_VERSION);
        Encodable::encode(self, &mut out);
        out.into()
    }

    /// Decodes a full envelope, rejecting an empty input, a version byte other than
    /// [`ENVELOPE_VERSION`], malformed RLP, an optional witness list with more than one element,
    /// and trailing bytes after the outer list.
    pub fn decode(bytes: &[u8]) -> Result<Self, EnvelopeError> {
        let (&version, mut body) = bytes.split_first().ok_or(EnvelopeError::Empty)?;
        if version != ENVELOPE_VERSION {
            return Err(EnvelopeError::Version(version));
        }
        let envelope = Self::decode_body(&mut body)?;
        if !body.is_empty() {
            return Err(EnvelopeError::TrailingBytes(body.len()));
        }
        Ok(envelope)
    }

    /// Length in bytes of the outer list's payload (the three encoded fields).
    fn payload_length(&self) -> usize {
        self.block.length() +
            optional_length(self.anchor.as_ref()) +
            optional_length(self.committee.as_ref())
    }

    /// Decodes the RLP body `[block, anchor, committee]`, advancing `buf` past the outer list.
    fn decode_body(buf: &mut &[u8]) -> Result<Self, EnvelopeError> {
        let mut payload = alloy_rlp::Header::decode_bytes(buf, true)?;
        let payload_length = payload.len();
        let envelope = Self {
            block: ExecutionBlock::decode(&mut payload)?,
            anchor: decode_optional(&mut payload, "anchor")?,
            committee: decode_optional(&mut payload, "committee")?,
        };
        if !payload.is_empty() {
            return Err(alloy_rlp::Error::ListLengthMismatch {
                expected: payload_length,
                got: payload_length - payload.len(),
            }
            .into());
        }
        Ok(envelope)
    }
}

impl Encodable for EtnaEnvelope {
    /// Writes the RLP body `[block, anchor, committee]` (without the version byte).
    fn encode(&self, out: &mut dyn BufMut) {
        alloy_rlp::Header { list: true, payload_length: self.payload_length() }.encode(out);
        self.block.encode(out);
        encode_optional(self.anchor.as_ref(), out);
        encode_optional(self.committee.as_ref(), out);
    }

    /// Length in bytes of the RLP body (without the version byte).
    fn length(&self) -> usize {
        let payload_length = self.payload_length();
        alloy_rlp::length_of_length(payload_length) + payload_length
    }
}

impl Decodable for EtnaEnvelope {
    /// Reads the RLP body `[block, anchor, committee]` (without the version byte), advancing `buf`
    /// past it. An optional witness list with more than one element is reported as
    /// [`alloy_rlp::Error::Custom`].
    fn decode(buf: &mut &[u8]) -> alloy_rlp::Result<Self> {
        Self::decode_body(buf).map_err(|err| match err {
            EnvelopeError::Rlp(err) => err,
            _ => alloy_rlp::Error::Custom("optional envelope field holds more than one element"),
        })
    }
}

/// Decodes the envelope of a CometBFT block from its transaction list, which must hold exactly
/// one item.
pub fn single_envelope(txs: &[Bytes]) -> Result<EtnaEnvelope, EnvelopeError> {
    match txs {
        [tx] => EtnaEnvelope::decode(tx),
        _ => Err(EnvelopeError::TxCount(txs.len())),
    }
}

/// Encoded length of an optional witness: an empty list for `None`, `[value]` for `Some`.
fn optional_length<T: Encodable>(value: Option<&T>) -> usize {
    let payload_length = value.map_or(0, Encodable::length);
    alloy_rlp::length_of_length(payload_length) + payload_length
}

/// Encodes an optional witness as an empty list (`None`) or a one-element list (`Some`).
fn encode_optional<T: Encodable>(value: Option<&T>, out: &mut dyn BufMut) {
    let payload_length = value.map_or(0, Encodable::length);
    alloy_rlp::Header { list: true, payload_length }.encode(out);
    if let Some(value) = value {
        value.encode(out);
    }
}

/// Decodes an optional witness list named `field`: empty means `None`, exactly one element means
/// `Some`, anything more is [`EnvelopeError::OptionalArity`].
fn decode_optional<T: Decodable>(
    buf: &mut &[u8],
    field: &'static str,
) -> Result<Option<T>, EnvelopeError> {
    let mut payload = alloy_rlp::Header::decode_bytes(buf, true)?;
    if payload.is_empty() {
        return Ok(None);
    }
    let value = T::decode(&mut payload)?;
    if !payload.is_empty() {
        return Err(EnvelopeError::OptionalArity(field));
    }
    Ok(Some(value))
}

#[cfg(test)]
mod tests {
    use super::*;
    use alloy_primitives::{Address, B64, B256, Bloom, U256, address, b256, bytes, hex};

    /// `keccak256(rlp([]))`, the root of an empty trie.
    const EMPTY_ROOT: B256 =
        b256!("56e81f171bcc55a6ff8345e692c0f86e5b48e01b996cadc001622fb5e363b421");
    /// EIP-7685 `sha256("")`, the requests hash of a block with no requests.
    const EMPTY_REQUESTS: B256 =
        b256!("e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855");

    fn header(number: u64) -> Header {
        Header {
            parent_hash: B256::repeat_byte(0x01),
            beneficiary: address!("00000000000000000000000000000000e7a10003"),
            state_root: B256::repeat_byte(0x02),
            transactions_root: B256::repeat_byte(0x03),
            receipts_root: B256::repeat_byte(0x04),
            logs_bloom: Bloom::repeat_byte(0x05),
            difficulty: U256::from(1_234_567u64),
            number,
            gas_limit: 45_000_000,
            gas_used: 42_000,
            timestamp: 1_760_000_000 + number,
            // 100 | generation u48 | anchor u48: 13 bytes.
            extra_data: bytes!("64000000000002000000000400"),
            mix_hash: B256::repeat_byte(0x06),
            nonce: B64::ZERO,
            base_fee_per_gas: Some(10_000_000),
            withdrawals_root: Some(EMPTY_ROOT),
            blob_gas_used: Some(0),
            excess_blob_gas: Some(0),
            parent_beacon_block_root: Some(B256::repeat_byte(0x07)),
            requests_hash: Some(EMPTY_REQUESTS),
            ..Header::default()
        }
    }

    fn txs() -> Vec<Bytes> {
        vec![bytes!("02f86c82028d8084b2d05e00"), bytes!("f86b808504a817c800825208")]
    }

    fn account_witness(seed: u8) -> AccountWitness {
        AccountWitness {
            address: Address::repeat_byte(seed),
            nonce: 1,
            balance: U256::from(seed),
            storage_root: B256::repeat_byte(seed),
            code_hash: B256::repeat_byte(seed.wrapping_add(1)),
            account_proof: vec![bytes!("f90211a0"), Bytes::from(vec![seed; 33])],
            storage: vec![crate::types::StorageProof {
                slot: B256::with_last_byte(seed),
                value: U256::from(3),
                proof: vec![Bytes::from(vec![seed; 40])],
            }],
        }
    }

    fn anchor() -> AnchorWitness {
        AnchorWitness { l1_header: header(9_000), inbox: account_witness(0xa1) }
    }

    fn committee() -> CommitteeWitness {
        CommitteeWitness {
            record: CommitteeRecord {
                target_epoch: 2,
                cutoff_l1_block: 8_990,
                checkpoint_index: 4,
                set_root: B256::repeat_byte(0x44),
                total_stake: U256::from(10).pow(U256::from(24)),
                total_power: 2_000_000,
                encoding_version: 1,
            },
            registry: account_witness(0xb2),
            entries: vec![
                RegistryEntry {
                    pubkey: B256::repeat_byte(0x10),
                    eff_stake: U256::from(10).pow(U256::from(21)),
                    active_from_l1: 100,
                    exit_effective_l1: u64::MAX,
                    last_heartbeat_at: 8_000,
                },
                RegistryEntry {
                    pubkey: B256::repeat_byte(0x20),
                    eff_stake: U256::from(5) * U256::from(10).pow(U256::from(20)),
                    active_from_l1: 200,
                    exit_effective_l1: 9_500,
                    last_heartbeat_at: 0,
                },
            ],
        }
    }

    fn envelope(
        anchor: Option<AnchorWitness>,
        committee: Option<CommitteeWitness>,
    ) -> EtnaEnvelope {
        EtnaEnvelope {
            block: ExecutionBlock { header: header(1_000), transactions: txs() },
            anchor,
            committee,
        }
    }

    /// RLP list wrapping already-encoded items.
    fn rlp_list(items: &[Vec<u8>]) -> Vec<u8> {
        let payload: Vec<u8> = items.concat();
        let mut out = Vec::new();
        alloy_rlp::Header { list: true, payload_length: payload.len() }.encode(&mut out);
        out.extend_from_slice(&payload);
        out
    }

    fn versioned(body: Vec<u8>) -> Vec<u8> {
        [vec![ENVELOPE_VERSION], body].concat()
    }

    #[test]
    fn round_trips_every_witness_combination() {
        for env in [
            envelope(None, None),
            envelope(Some(anchor()), None),
            envelope(None, Some(committee())),
            envelope(Some(anchor()), Some(committee())),
        ] {
            let encoded = env.encode();
            assert_eq!(EtnaEnvelope::decode(&encoded), Ok(env));
        }
    }

    #[test]
    fn encode_starts_with_version_byte() {
        let encoded = envelope(Some(anchor()), None).encode();
        assert_eq!(encoded[0], 0x01);
        assert_eq!(encoded.len(), 1 + alloy_rlp::encode(envelope(Some(anchor()), None)).len());
    }

    #[test]
    fn absent_witness_is_empty_list_and_present_is_one_element_list() {
        let env = envelope(Some(anchor()), None);
        let expected = versioned(rlp_list(&[
            alloy_rlp::encode(&env.block),
            rlp_list(&[alloy_rlp::encode(anchor())]),
            rlp_list(&[]),
        ]));
        assert_eq!(env.encode().to_vec(), expected);
    }

    #[test]
    fn decode_rejects_empty_input() {
        assert_eq!(EtnaEnvelope::decode(&[]), Err(EnvelopeError::Empty));
    }

    #[test]
    fn decode_rejects_wrong_version() {
        let mut encoded = envelope(None, None).encode().to_vec();
        for version in [0x00, 0x02, 0xff] {
            encoded[0] = version;
            assert_eq!(EtnaEnvelope::decode(&encoded), Err(EnvelopeError::Version(version)));
        }
    }

    #[test]
    fn decode_rejects_malformed_rlp() {
        let encoded = envelope(Some(anchor()), Some(committee())).encode();
        // Version byte only.
        assert!(matches!(EtnaEnvelope::decode(&[ENVELOPE_VERSION]), Err(EnvelopeError::Rlp(_))));
        // Truncated body.
        assert!(matches!(
            EtnaEnvelope::decode(&encoded[..encoded.len() - 1]),
            Err(EnvelopeError::Rlp(_))
        ));
        // A string where the outer list belongs.
        assert_eq!(
            EtnaEnvelope::decode(&[ENVELOPE_VERSION, 0x80]),
            Err(EnvelopeError::Rlp(alloy_rlp::Error::UnexpectedString))
        );
        // A string where an optional witness list belongs.
        let env = envelope(None, None);
        let body = rlp_list(&[alloy_rlp::encode(&env.block), vec![0x80], rlp_list(&[])]);
        assert_eq!(
            EtnaEnvelope::decode(&versioned(body)),
            Err(EnvelopeError::Rlp(alloy_rlp::Error::UnexpectedString))
        );
        // A fourth element in the outer list.
        let body =
            rlp_list(&[alloy_rlp::encode(&env.block), rlp_list(&[]), rlp_list(&[]), vec![0x01]]);
        assert!(matches!(EtnaEnvelope::decode(&versioned(body)), Err(EnvelopeError::Rlp(_))));
        // Only two elements in the outer list.
        let body = rlp_list(&[alloy_rlp::encode(&env.block), rlp_list(&[])]);
        assert!(matches!(EtnaEnvelope::decode(&versioned(body)), Err(EnvelopeError::Rlp(_))));
    }

    #[test]
    fn decode_rejects_trailing_bytes() {
        let mut encoded = envelope(None, Some(committee())).encode().to_vec();
        encoded.extend_from_slice(&[0xc0, 0x00]);
        assert_eq!(EtnaEnvelope::decode(&encoded), Err(EnvelopeError::TrailingBytes(2)));
    }

    #[test]
    fn decode_rejects_optional_list_with_more_than_one_element() {
        let block = alloy_rlp::encode(envelope(None, None).block);
        let two_anchors = rlp_list(&[alloy_rlp::encode(anchor()), alloy_rlp::encode(anchor())]);
        let body = rlp_list(&[block.clone(), two_anchors, rlp_list(&[])]);
        assert_eq!(
            EtnaEnvelope::decode(&versioned(body)),
            Err(EnvelopeError::OptionalArity("anchor"))
        );

        let two_committees =
            rlp_list(&[alloy_rlp::encode(committee()), alloy_rlp::encode(committee())]);
        let body = rlp_list(&[block, rlp_list(&[]), two_committees]);
        assert_eq!(
            EtnaEnvelope::decode(&versioned(body)),
            Err(EnvelopeError::OptionalArity("committee"))
        );
    }

    #[test]
    fn rlp_decodable_matches_versioned_decode() {
        let env = envelope(Some(anchor()), Some(committee()));
        let body = alloy_rlp::encode(&env);
        let mut buf = body.as_slice();
        assert_eq!(<EtnaEnvelope as Decodable>::decode(&mut buf), Ok(env));
        assert!(buf.is_empty());
    }

    #[test]
    fn single_envelope_requires_exactly_one_tx() {
        let env = envelope(Some(anchor()), None);
        let tx = env.encode();
        assert_eq!(single_envelope(&[]), Err(EnvelopeError::TxCount(0)));
        assert_eq!(single_envelope(std::slice::from_ref(&tx)), Ok(env));
        assert_eq!(single_envelope(&[tx.clone(), tx]), Err(EnvelopeError::TxCount(2)));
        assert_eq!(single_envelope(&[Bytes::new()]), Err(EnvelopeError::Empty));
    }

    /// This vector pins the envelope wire format: if it changes, the encoding changed, which is a
    /// consensus-breaking change for every node replaying committed blocks.
    #[test]
    fn golden_vector_minimal_envelope() {
        let env = EtnaEnvelope {
            block: ExecutionBlock { header: Header::default(), transactions: vec![] },
            anchor: None,
            committee: None,
        };
        let expected = hex!(
            "01"       // ENVELOPE_VERSION
            "f901f6"   // envelope list
            "f901f1"   // block list
            "f901ed"   // header list (Header::default(): 15 pre-London fields)
            "a00000000000000000000000000000000000000000000000000000000000000000" // parentHash
            "a01dcc4de8dec75d7aab85b567b6ccd41ad312451b948a7413f0a142fd40d49347" // ommersHash
            "940000000000000000000000000000000000000000" // beneficiary
            "a056e81f171bcc55a6ff8345e692c0f86e5b48e01b996cadc001622fb5e363b421" // stateRoot
            "a056e81f171bcc55a6ff8345e692c0f86e5b48e01b996cadc001622fb5e363b421" // transactionsRoot
            "a056e81f171bcc55a6ff8345e692c0f86e5b48e01b996cadc001622fb5e363b421" // receiptsRoot
            "b90100" // logsBloom header, 256 zero bytes follow
            "0000000000000000000000000000000000000000000000000000000000000000"
            "0000000000000000000000000000000000000000000000000000000000000000"
            "0000000000000000000000000000000000000000000000000000000000000000"
            "0000000000000000000000000000000000000000000000000000000000000000"
            "0000000000000000000000000000000000000000000000000000000000000000"
            "0000000000000000000000000000000000000000000000000000000000000000"
            "0000000000000000000000000000000000000000000000000000000000000000"
            "0000000000000000000000000000000000000000000000000000000000000000"
            "808080808080" // difficulty, number, gasLimit, gasUsed, timestamp, extraData
            "a00000000000000000000000000000000000000000000000000000000000000000" // mixHash
            "880000000000000000" // nonce
            "c0" // transactions: empty list
            "c0" // anchor: absent
            "c0" // committee: absent
        );
        assert_eq!(env.encode().to_vec(), expected.to_vec());
        assert_eq!(EtnaEnvelope::decode(&expected), Ok(env));
    }
}
