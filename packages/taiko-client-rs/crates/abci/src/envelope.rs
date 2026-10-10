//! The CometBFT block envelope.
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
//! The inner structs are RLP lists of their fields in declaration order. The anchor's L1 header
//! is one RLP byte string holding the header's exact RLP ([`RawL1Header`]), so a header carrying
//! fields of an L1 fork newer than this client still decodes and hashes as on L1.

use alloy_consensus::Header;
use alloy_primitives::Bytes;
use alloy_rlp::{BufMut, Decodable, Encodable, RlpDecodable, RlpEncodable};

use crate::{
    l1::header::RawL1Header,
    types::{AccountWitness, CommitteeRecord, RegistryEntry},
};

/// Leading version byte of every envelope.
pub const ENVELOPE_VERSION: u8 = 1;

/// Name of the optional `anchor` field, as carried by [`EnvelopeError::OptionalArity`].
const ANCHOR_FIELD: &str = "anchor";
/// Name of the optional `committee` field, as carried by [`EnvelopeError::OptionalArity`].
const COMMITTEE_FIELD: &str = "committee";

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
/// `stateRoot`.
///
/// RLP: `[l1_header, inbox]`, where `l1_header` is a byte string holding the raw header RLP.
#[derive(Clone, Debug, PartialEq, Eq, RlpEncodable, RlpDecodable)]
pub struct AnchorWitness {
    /// The anchor L1 header, raw; its hash (`keccak256` of the raw bytes) is the anchor hash and
    /// its `stateRoot` the proof root.
    pub l1_header: RawL1Header,
    /// EIP-1186 proof of the Inbox account and its anchor slot set, in slot order.
    pub inbox: AccountWitness,
}

/// The committee witness carried at an epoch's first height.
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
            anchor: decode_optional(&mut payload, ANCHOR_FIELD)?,
            committee: decode_optional(&mut payload, COMMITTEE_FIELD)?,
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
    /// [`alloy_rlp::Error::Custom`] naming the field.
    fn decode(buf: &mut &[u8]) -> alloy_rlp::Result<Self> {
        Self::decode_body(buf).map_err(|err| match err {
            EnvelopeError::Rlp(err) => err,
            EnvelopeError::OptionalArity(field) => {
                alloy_rlp::Error::Custom(optional_arity_message(field))
            }
            // `decode_body` never returns these: they concern the version byte, the bytes after
            // the body and the CometBFT transaction list, none of which it reads. They are still
            // mapped (not panicked on) so a future change cannot turn bad input into a crash.
            EnvelopeError::Empty |
            EnvelopeError::Version(_) |
            EnvelopeError::TrailingBytes(_) |
            EnvelopeError::TxCount(_) => alloy_rlp::Error::Custom("unexpected envelope error"),
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

/// The [`EnvelopeError::OptionalArity`] message for `field` as a `&'static str`, the only payload
/// [`alloy_rlp::Error::Custom`] can carry.
fn optional_arity_message(field: &'static str) -> &'static str {
    match field {
        ANCHOR_FIELD => "optional envelope field `anchor` holds more than one element",
        COMMITTEE_FIELD => "optional envelope field `committee` holds more than one element",
        _ => "optional envelope field holds more than one element",
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
    use alloy_primitives::{Address, B64, B256, Bloom, U256, address, b256, bytes, hex, keccak256};

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
        AnchorWitness { l1_header: RawL1Header::from(&header(9_000)), inbox: account_witness(0xa1) }
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
                    last_heartbeat_seq: 7,
                },
                RegistryEntry {
                    pubkey: B256::repeat_byte(0x20),
                    eff_stake: U256::from(5) * U256::from(10).pow(U256::from(20)),
                    active_from_l1: 200,
                    exit_effective_l1: 9_500,
                    last_heartbeat_at: 0,
                    last_heartbeat_seq: 0,
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

    /// An anchor witness whose L1 header bytes are not a header is a malformed envelope.
    #[test]
    fn decode_rejects_a_malformed_raw_l1_header() {
        let env = envelope(None, None);
        let inbox = alloy_rlp::encode(account_witness(0xa1));
        // A 14-field list: one field short of a pre-London header.
        let short = rlp_list(&vec![vec![0x80]; 14]);
        let anchor = rlp_list(&[alloy_rlp::encode(Bytes::from(short)), inbox]);
        let body = rlp_list(&[alloy_rlp::encode(&env.block), rlp_list(&[anchor]), rlp_list(&[])]);
        assert_eq!(
            EtnaEnvelope::decode(&versioned(body)),
            Err(EnvelopeError::Rlp(alloy_rlp::Error::Custom("raw L1 header has too few fields")))
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

    #[test]
    fn rlp_decodable_names_the_optional_field_with_more_than_one_element() {
        let block = alloy_rlp::encode(envelope(None, None).block);
        let two_anchors = rlp_list(&[alloy_rlp::encode(anchor()), alloy_rlp::encode(anchor())]);
        let body = rlp_list(&[block.clone(), two_anchors, rlp_list(&[])]);
        assert_eq!(
            <EtnaEnvelope as Decodable>::decode(&mut body.as_slice()),
            Err(alloy_rlp::Error::Custom(
                "optional envelope field `anchor` holds more than one element"
            ))
        );

        let two_committees =
            rlp_list(&[alloy_rlp::encode(committee()), alloy_rlp::encode(committee())]);
        let body = rlp_list(&[block, rlp_list(&[]), two_committees]);
        assert_eq!(
            <EtnaEnvelope as Decodable>::decode(&mut body.as_slice()),
            Err(alloy_rlp::Error::Custom(
                "optional envelope field `committee` holds more than one element"
            ))
        );
    }

    /// Non-canonical RLP must be rejected: otherwise one envelope would have several encodings,
    /// so one block could be carried by CometBFT transactions with different hashes.
    #[test]
    fn decode_rejects_non_canonical_rlp() {
        let header = alloy_rlp::encode(Header::default());
        let with_txs = |txs: &[u8]| {
            versioned(rlp_list(&[
                rlp_list(&[header.clone(), txs.to_vec()]),
                rlp_list(&[]),
                rlp_list(&[]),
            ]))
        };
        let expected = |txs: Vec<Bytes>| {
            Ok(EtnaEnvelope {
                block: ExecutionBlock { header: Header::default(), transactions: txs },
                anchor: None,
                committee: None,
            })
        };

        // A one-byte tx `0x05` is its own encoding; the string form `0x81 0x05` is non-canonical.
        assert_eq!(EtnaEnvelope::decode(&with_txs(&hex!("c105"))), expected(vec![bytes!("05")]));
        assert_eq!(
            EtnaEnvelope::decode(&with_txs(&hex!("c28105"))),
            Err(EnvelopeError::Rlp(alloy_rlp::Error::NonCanonicalSingleByte))
        );

        // A 4-byte tx list must use the short list form `0xc4`, not the long form `0xf8 0x04`.
        assert_eq!(
            EtnaEnvelope::decode(&with_txs(&hex!("c483aabbcc"))),
            expected(vec![bytes!("aabbcc")])
        );
        assert_eq!(
            EtnaEnvelope::decode(&with_txs(&hex!("f80483aabbcc"))),
            Err(EnvelopeError::Rlp(alloy_rlp::Error::NonCanonicalSize))
        );
    }

    /// This vector pins the consensus wire format of an envelope carrying both witnesses: the
    /// field order of `ExecutionBlock`, `AnchorWitness`, `CommitteeWitness`, `AccountWitness`,
    /// `StorageProof`, `CommitteeRecord` and `RegistryEntry`, the post-Prague header fields, the
    /// anchor's L1 header as one byte string of its raw RLP (here with two fields alloy's header
    /// does not know), and the one-element list wrapping a present witness. If it changes, the
    /// encoding changed, which is a consensus-breaking change for every node replaying
    /// committed blocks.
    ///
    /// The expected bytes are assembled from per-field RLP written out by hand (only list headers
    /// are computed), so they do not depend on the encoder under test. Same-typed sibling fields
    /// hold distinct values, so swapping any two of them changes the bytes.
    #[test]
    fn golden_vector_envelope_with_witnesses() {
        /// RLP list of the given already-encoded items.
        fn list(items: &[&[u8]]) -> Vec<u8> {
            rlp_list(&items.iter().map(|item| item.to_vec()).collect::<Vec<_>>())
        }
        /// RLP of a 32-byte word whose bytes are all `byte`.
        fn word(byte: u8) -> Vec<u8> {
            [vec![0xa0], vec![byte; 32]].concat()
        }
        /// RLP byte string of `bytes` (longer than 255 bytes): `0xb9 || len (2 bytes) || bytes`.
        fn string(bytes: &[u8]) -> Vec<u8> {
            let len = u16::try_from(bytes.len()).expect("a header is shorter than 64 KiB");
            assert!(len > 255, "the long-string form with a 2-byte length");
            [vec![0xb9], len.to_be_bytes().to_vec(), bytes.to_vec()].concat()
        }

        let header = |number: u64| Header {
            parent_hash: B256::repeat_byte(0x01),
            beneficiary: address!("00000000000000000000000000000000e7a10003"),
            state_root: B256::repeat_byte(0x02),
            transactions_root: B256::repeat_byte(0x03),
            receipts_root: B256::repeat_byte(0x04),
            logs_bloom: Bloom::repeat_byte(0x05),
            difficulty: U256::from(0x0102),
            number,
            gas_limit: 0x0200_0000,
            gas_used: 0x5208,
            timestamp: 0x68e7_7800,
            extra_data: bytes!("6401"),
            mix_hash: B256::repeat_byte(0x06),
            nonce: B64::ZERO,
            base_fee_per_gas: Some(0x0098_9680),
            withdrawals_root: Some(EMPTY_ROOT),
            blob_gas_used: Some(0x0002_0000),
            excess_blob_gas: Some(0x0004_0000),
            parent_beacon_block_root: Some(B256::repeat_byte(0x07)),
            requests_hash: Some(EMPTY_REQUESTS),
            ..Header::default()
        };
        let header_rlp = |number: &[u8], extra: &[&[u8]]| {
            let fields: &[&[u8]] = &[
                &word(0x01), // parentHash
                // ommersHash
                &hex!("a01dcc4de8dec75d7aab85b567b6ccd41ad312451b948a7413f0a142fd40d49347"),
                &hex!("9400000000000000000000000000000000e7a10003"), // beneficiary
                &word(0x02),                                         // stateRoot
                &word(0x03),                                         // transactionsRoot
                &word(0x04),                                         // receiptsRoot
                &[hex!("b90100").as_slice(), &[0x05; 256]].concat(), // logsBloom
                &hex!("820102"),                                     // difficulty
                number,                                              // number
                &hex!("8402000000"),                                 // gasLimit
                &hex!("825208"),                                     // gasUsed
                &hex!("8468e77800"),                                 // timestamp
                &hex!("826401"),                                     // extraData
                &word(0x06),                                         // mixHash
                &hex!("880000000000000000"),                         // nonce
                &hex!("83989680"),                                   // baseFeePerGas
                // withdrawalsRoot
                &hex!("a056e81f171bcc55a6ff8345e692c0f86e5b48e01b996cadc001622fb5e363b421"),
                &hex!("83020000"), // blobGasUsed
                &hex!("83040000"), // excessBlobGas
                &word(0x07),       // parentBeaconBlockRoot
                // requestsHash
                &hex!("a0e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"),
            ];
            list(&[fields, extra].concat())
        };
        // The anchor's L1 header: the same 21 fields (number 0x2400) plus two fields of an L1
        // fork newer than alloy's header (a 32-byte hash and a slot number), carried opaquely.
        let l1_header = header_rlp(&hex!("822400"), &[&word(0xba), &hex!("8401020304")]);

        let env = EtnaEnvelope {
            block: ExecutionBlock {
                header: header(0x0400),
                transactions: vec![bytes!("02f86c82028d8084b2d05e00")],
            },
            anchor: Some(AnchorWitness {
                l1_header: RawL1Header::from_raw(l1_header.clone().into())
                    .expect("an L1 header with two extra fields"),
                inbox: AccountWitness {
                    address: address!("00000000000000000000000000000000e7a10001"),
                    nonce: 1,
                    balance: U256::from(0x0de0_b6b3_a764_0000u64),
                    storage_root: B256::repeat_byte(0x11),
                    code_hash: B256::repeat_byte(0x12),
                    account_proof: vec![bytes!("e2a0aabb")],
                    storage: vec![crate::types::StorageProof {
                        slot: B256::with_last_byte(0x0e),
                        value: U256::from(3),
                        proof: vec![bytes!("e3a120cc")],
                    }],
                },
            }),
            committee: Some(CommitteeWitness {
                record: CommitteeRecord {
                    target_epoch: 2,
                    cutoff_l1_block: 0x23f0,
                    checkpoint_index: 5,
                    set_root: B256::repeat_byte(0x44),
                    total_stake: U256::from(10).pow(U256::from(24)),
                    total_power: 0x0f_4240,
                    encoding_version: 1,
                },
                registry: AccountWitness {
                    address: address!("00000000000000000000000000000000e7a10002"),
                    nonce: 2,
                    balance: U256::from(0x05f5_e100),
                    storage_root: B256::repeat_byte(0x21),
                    code_hash: B256::repeat_byte(0x22),
                    account_proof: vec![bytes!("e2a0ddee")],
                    storage: vec![crate::types::StorageProof {
                        slot: B256::with_last_byte(0x01),
                        value: U256::ZERO,
                        proof: vec![bytes!("e3a120ff")],
                    }],
                },
                entries: vec![RegistryEntry {
                    pubkey: B256::repeat_byte(0x10),
                    eff_stake: U256::from(10).pow(U256::from(21)),
                    active_from_l1: 0x64,
                    exit_effective_l1: u64::MAX,
                    last_heartbeat_at: 0x1f40,
                    last_heartbeat_seq: 0x0102,
                }],
            }),
        };

        let block = list(&[
            &header_rlp(&hex!("820400"), &[]), // header (number 0x0400)
            &list(&[&hex!("8c02f86c82028d8084b2d05e00")]), // transactions: one opaque tx
        ]);
        let inbox = list(&[
            &hex!("9400000000000000000000000000000000e7a10001"), // address
            &hex!("01"),                                         // nonce
            &hex!("880de0b6b3a7640000"),                         // balance: 1 ether
            &word(0x11),                                         // storage_root
            &word(0x12),                                         // code_hash
            &list(&[&hex!("84e2a0aabb")]),                       // account_proof: one node
            &list(&[&list(&[
                // storage: one StorageProof
                &[vec![0xa0], vec![0; 31], vec![0x0e]].concat(), // slot 14 (B256 keeps zeros)
                &hex!("03"),                                     // value
                &list(&[&hex!("84e3a120cc")]),                   // proof: one node
            ])]),
        ]);
        let anchor = list(&[
            &string(&l1_header), // l1_header: the raw header as one byte string
            &inbox,              // inbox
        ]);
        let record = list(&[
            &hex!("02"),                     // target_epoch
            &hex!("8223f0"),                 // cutoff_l1_block
            &hex!("05"),                     // checkpoint_index
            &word(0x44),                     // set_root
            &hex!("8ad3c21bcecceda1000000"), // total_stake: 10^24
            &hex!("830f4240"),               // total_power
            &hex!("01"),                     // encoding_version
        ]);
        let registry = list(&[
            &hex!("9400000000000000000000000000000000e7a10002"), // address
            &hex!("02"),                                         // nonce
            &hex!("8405f5e100"),                                 // balance
            &word(0x21),                                         // storage_root
            &word(0x22),                                         // code_hash
            &list(&[&hex!("84e2a0ddee")]),                       // account_proof: one node
            &list(&[&list(&[
                // storage: one StorageProof (an exclusion proof)
                &[vec![0xa0], vec![0; 31], vec![0x01]].concat(), // slot 1
                &hex!("80"),                                     // value: zero
                &list(&[&hex!("84e3a120ff")]),                   // proof: one node
            ])]),
        ]);
        let entry = list(&[
            &word(0x10),                   // pubkey
            &hex!("893635c9adc5dea00000"), // eff_stake: 10^21
            &hex!("64"),                   // active_from_l1
            &hex!("88ffffffffffffffff"),   // exit_effective_l1: u64::MAX
            &hex!("821f40"),               // last_heartbeat_at
            &hex!("820102"),               // last_heartbeat_seq
        ]);
        let committee = list(&[
            &record,          // record
            &registry,        // registry
            &list(&[&entry]), // entries: one RegistryEntry
        ]);
        let expected = versioned(list(&[
            &block,
            &list(&[&anchor]),    // anchor: present, a one-element list
            &list(&[&committee]), // committee: present, a one-element list
        ]));

        assert_eq!(hex::encode(env.encode()), hex::encode(&expected));
        assert_eq!(EtnaEnvelope::decode(&expected), Ok(env));

        // The fields the node reads from the anchor's raw L1 header, at Ethereum's positions.
        let decoded = EtnaEnvelope::decode(&expected).expect("decodes");
        let l1 = &decoded.anchor.as_ref().expect("an anchor witness").l1_header;
        assert_eq!(l1.raw().as_ref(), l1_header.as_slice());
        assert_eq!(l1.hash(), keccak256(&l1_header));
        assert_eq!(l1.parent_hash(), B256::repeat_byte(0x01));
        assert_eq!(l1.state_root(), B256::repeat_byte(0x02));
        assert_eq!(l1.number(), 0x2400);
        assert_eq!(l1.timestamp(), 0x68e7_7800);
    }
}
