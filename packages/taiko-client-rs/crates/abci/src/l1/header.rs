//! The raw L1 header an anchor or genesis witness carries (spec §4.1). No I/O.
//!
//! An L1 header travels as its exact RLP bytes, never as a decoded struct: its hash is
//! `keccak256(raw)`, and the node reads the few fields it uses by position from the RLP list
//! (`parentHash` at 0, `stateRoot` at 3, `number` at 8, `timestamp` at 11). Every field after
//! those is carried and hashed but otherwise ignored, so an L1 fork that appends header fields (a
//! block-access-list hash, a slot number, ...) changes neither the decoding nor the hash. A
//! decoded struct could not do that: a decoder that does not know the new fields rejects them,
//! and re-encoding a struct drops them, so the re-encoding no longer hashes to the block hash.

use alloy_consensus::Header;
use alloy_primitives::{B256, Bytes, keccak256};
use alloy_rlp::{BufMut, Decodable, Encodable, PayloadView};

/// Position of `parentHash` in an L1 header's RLP list.
pub const PARENT_HASH_INDEX: usize = 0;
/// Position of `stateRoot` in an L1 header's RLP list.
pub const STATE_ROOT_INDEX: usize = 3;
/// Position of `number` in an L1 header's RLP list.
pub const NUMBER_INDEX: usize = 8;
/// Position of `timestamp` in an L1 header's RLP list.
pub const TIMESTAMP_INDEX: usize = 11;
/// The fewest fields an L1 header has: the 15 of a pre-London header (`parentHash` through
/// `nonce`); every later fork only appends fields.
pub const MIN_FIELDS: usize = 15;

/// Why bytes are not an L1 header.
#[derive(Debug, thiserror::Error, Clone, Copy, PartialEq, Eq)]
pub enum L1HeaderError {
    /// The bytes are not one well-formed, canonical RLP list of well-formed items.
    #[error("malformed L1 header RLP: {0}")]
    Rlp(alloy_rlp::Error),
    /// Bytes follow the header's RLP list; the value is how many.
    #[error("{0} trailing bytes after the L1 header list")]
    TrailingBytes(usize),
    /// The list has fewer than [`MIN_FIELDS`] fields.
    #[error("L1 header has {got} fields, at least {MIN_FIELDS} expected")]
    TooFewFields {
        /// The number of fields in the list.
        got: usize,
    },
    /// A field the node reads does not decode as its type (a 32-byte hash or a `u64`).
    #[error("L1 header field {name} (position {index}) is malformed: {error}")]
    Field {
        /// The field's position in the list.
        index: usize,
        /// The field's name.
        name: &'static str,
        /// Why it does not decode.
        error: alloy_rlp::Error,
    },
}

impl L1HeaderError {
    /// The error as an [`alloy_rlp::Error`], for decoding a witness that carries the header: a
    /// static message per variant, as [`alloy_rlp::Error::Custom`] holds no runtime detail.
    const fn as_rlp_error(&self) -> alloy_rlp::Error {
        alloy_rlp::Error::Custom(match self {
            Self::Rlp(_) => "malformed raw L1 header RLP",
            Self::TrailingBytes(_) => "trailing bytes after the raw L1 header",
            Self::TooFewFields { .. } => "raw L1 header has too few fields",
            Self::Field { .. } => "raw L1 header has a malformed field",
        })
    }
}

/// An L1 header as its exact RLP bytes, with the fields the node reads decoded by position.
///
/// Built only from bytes that are one canonical RLP list of at least [`MIN_FIELDS`] well-formed
/// items with a 32-byte `parentHash` and `stateRoot` and a `u64` `number` and `timestamp`
/// ([`RawL1Header::from_raw`]); the accessors therefore cannot fail. RLP: a byte string holding
/// the raw header (so a witness decodes whatever fields the header has).
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct RawL1Header {
    /// The header's RLP list, exactly as the L1 node serves it.
    raw: Bytes,
    /// `keccak256(raw)`: the L1 block hash.
    hash: B256,
    /// `parentHash` (position 0).
    parent_hash: B256,
    /// `stateRoot` (position 3).
    state_root: B256,
    /// `number` (position 8).
    number: u64,
    /// `timestamp` (position 11), in seconds since the Unix epoch.
    timestamp: u64,
}

impl RawL1Header {
    /// Checks that `raw` is an L1 header and decodes the fields the node reads by position.
    ///
    /// Rejects anything but one canonical RLP list ([`L1HeaderError::Rlp`]) followed by no other
    /// bytes ([`L1HeaderError::TrailingBytes`]) with at least [`MIN_FIELDS`] items
    /// ([`L1HeaderError::TooFewFields`]) whose `parentHash` and `stateRoot` are 32-byte strings
    /// and whose `number` and `timestamp` are canonical `u64`s ([`L1HeaderError::Field`]). Fields
    /// past the ones it reads are only checked to be well-formed RLP items.
    pub fn from_raw(raw: Bytes) -> Result<Self, L1HeaderError> {
        let mut buf = raw.as_ref();
        let fields = match alloy_rlp::Header::decode_raw(&mut buf).map_err(L1HeaderError::Rlp)? {
            PayloadView::List(fields) => fields,
            PayloadView::String(_) => {
                return Err(L1HeaderError::Rlp(alloy_rlp::Error::UnexpectedString));
            }
        };
        if !buf.is_empty() {
            return Err(L1HeaderError::TrailingBytes(buf.len()));
        }
        if fields.len() < MIN_FIELDS {
            return Err(L1HeaderError::TooFewFields { got: fields.len() });
        }
        let parent_hash = field(&fields, PARENT_HASH_INDEX, "parentHash")?;
        let state_root = field(&fields, STATE_ROOT_INDEX, "stateRoot")?;
        let number = field(&fields, NUMBER_INDEX, "number")?;
        let timestamp = field(&fields, TIMESTAMP_INDEX, "timestamp")?;
        Ok(Self { hash: keccak256(&raw), raw, parent_hash, state_root, number, timestamp })
    }

    /// The header's RLP list, exactly as received.
    pub const fn raw(&self) -> &Bytes {
        &self.raw
    }

    /// The L1 block hash, `keccak256(raw)`.
    pub const fn hash(&self) -> B256 {
        self.hash
    }

    /// The parent block's hash.
    pub const fn parent_hash(&self) -> B256 {
        self.parent_hash
    }

    /// The L1 state root: the root every proof against this header verifies against.
    pub const fn state_root(&self) -> B256 {
        self.state_root
    }

    /// The L1 block number.
    pub const fn number(&self) -> u64 {
        self.number
    }

    /// The L1 block timestamp, in seconds since the Unix epoch.
    pub const fn timestamp(&self) -> u64 {
        self.timestamp
    }
}

impl From<&Header> for RawL1Header {
    /// The RLP encoding of an alloy header, which has every field up to the latest fork alloy
    /// knows (and so at least [`MIN_FIELDS`]).
    fn from(header: &Header) -> Self {
        Self::from_raw(alloy_rlp::encode(header).into())
            .expect("an alloy header encodes as a canonical list of at least 15 fields")
    }
}

impl Encodable for RawL1Header {
    /// Writes the raw header as one RLP byte string.
    fn encode(&self, out: &mut dyn BufMut) {
        self.raw.encode(out);
    }

    /// Length of the RLP byte string holding the raw header.
    fn length(&self) -> usize {
        self.raw.length()
    }
}

impl Decodable for RawL1Header {
    /// Reads one RLP byte string and checks it holds an L1 header ([`RawL1Header::from_raw`]); a
    /// malformed header is an [`alloy_rlp::Error::Custom`] naming the [`L1HeaderError`] kind.
    fn decode(buf: &mut &[u8]) -> alloy_rlp::Result<Self> {
        Self::from_raw(Bytes::decode(buf)?).map_err(|e| e.as_rlp_error())
    }
}

/// Decodes the item at `index` of `fields` (one complete RLP item) as a `T` named `name`.
fn field<T: Decodable>(
    fields: &[&[u8]],
    index: usize,
    name: &'static str,
) -> Result<T, L1HeaderError> {
    let mut item = fields[index];
    T::decode(&mut item).map_err(|error| L1HeaderError::Field { index, name, error })
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::test_utils::raw_with_future_fields;
    use alloy_primitives::{Address, B64, Bloom, U256, b256, hex};

    /// A post-Prague header (21 fields) with distinct values in the positions the node reads.
    fn prague() -> Header {
        Header {
            parent_hash: B256::repeat_byte(0x01),
            beneficiary: Address::repeat_byte(0x02),
            state_root: B256::repeat_byte(0x03),
            transactions_root: B256::repeat_byte(0x04),
            receipts_root: B256::repeat_byte(0x05),
            logs_bloom: Bloom::repeat_byte(0x06),
            difficulty: U256::ZERO,
            number: 0x0123_4567,
            gas_limit: 36_000_000,
            gas_used: 21_000,
            timestamp: 0x68e7_7800,
            extra_data: Bytes::from_static(b"geth"),
            mix_hash: B256::repeat_byte(0x07),
            nonce: B64::ZERO,
            base_fee_per_gas: Some(7),
            withdrawals_root: Some(B256::repeat_byte(0x08)),
            blob_gas_used: Some(0),
            excess_blob_gas: Some(0),
            parent_beacon_block_root: Some(B256::repeat_byte(0x09)),
            requests_hash: Some(B256::repeat_byte(0x0a)),
            ..Header::default()
        }
    }

    /// RLP list of the given already-encoded items.
    fn list(items: &[Vec<u8>]) -> Vec<u8> {
        let payload = items.concat();
        let mut out = Vec::new();
        alloy_rlp::Header { list: true, payload_length: payload.len() }.encode(&mut out);
        out.extend(payload);
        out
    }

    /// The encoded fields of `header`'s RLP list, in order.
    fn fields(header: &Header) -> Vec<Vec<u8>> {
        let encoded = alloy_rlp::encode(header);
        let mut buf = encoded.as_slice();
        match alloy_rlp::Header::decode_raw(&mut buf).expect("an alloy header encodes") {
            alloy_rlp::PayloadView::List(items) => items.iter().map(|i| i.to_vec()).collect(),
            alloy_rlp::PayloadView::String(_) => unreachable!("a header is a list"),
        }
    }

    #[test]
    fn reads_the_positional_fields_of_an_alloy_header() {
        for header in [prague(), Header::default()] {
            let raw = RawL1Header::from(&header);
            assert_eq!(raw.raw().as_ref(), alloy_rlp::encode(&header).as_slice());
            assert_eq!(raw.hash(), header.hash_slow());
            assert_eq!(raw.parent_hash(), header.parent_hash);
            assert_eq!(raw.state_root(), header.state_root);
            assert_eq!(raw.number(), header.number);
            assert_eq!(raw.timestamp(), header.timestamp);
        }
    }

    /// A later fork's extra fields are carried, hashed and otherwise ignored: the header still
    /// decodes, and its hash is `keccak256` of the bytes as given, not of a re-encoding.
    #[test]
    fn a_header_with_two_extra_trailing_fields_decodes_and_hashes_as_given() {
        let base = prague();
        let raw = raw_with_future_fields(&base);
        let mut buf = raw.as_ref();
        let Ok(alloy_rlp::PayloadView::List(items)) = alloy_rlp::Header::decode_raw(&mut buf)
        else {
            panic!("a list");
        };
        assert_eq!(items.len(), fields(&base).len() + 2, "two fields appended");
        assert!(
            <Header as Decodable>::decode(&mut raw.as_ref()).is_err(),
            "alloy's header decoder rejects the extra fields"
        );

        let header = RawL1Header::from_raw(raw.clone()).expect("decodes by position");
        assert_eq!(header.raw(), &raw);
        assert_eq!(header.hash(), keccak256(&raw));
        assert_ne!(header.hash(), base.hash_slow(), "the extra fields are hashed");
        assert_eq!(header.parent_hash(), base.parent_hash);
        assert_eq!(header.state_root(), base.state_root);
        assert_eq!(header.number(), base.number);
        assert_eq!(header.timestamp(), base.timestamp);
    }

    /// The witness carries the raw header as one RLP byte string.
    #[test]
    fn rlp_carries_the_raw_header_as_a_byte_string() {
        let raw = raw_with_future_fields(&prague());
        let header = RawL1Header::from_raw(raw.clone()).unwrap();
        let encoded = alloy_rlp::encode(&header);
        assert_eq!(encoded, alloy_rlp::encode(&raw), "a byte string of the raw bytes");
        assert_eq!(encoded.len(), header.length());
        assert_eq!(encoded[0], 0xb9, "a long string header (the raw list is > 255 bytes)");

        let mut buf = encoded.as_slice();
        assert_eq!(RawL1Header::decode(&mut buf), Ok(header));
        assert!(buf.is_empty());
    }

    #[test]
    fn malformed_rlp_is_rejected() {
        let good = alloy_rlp::encode(prague());
        let cases: Vec<(&str, Vec<u8>)> = vec![
            ("empty", vec![]),
            ("a string, not a list", alloy_rlp::encode(Bytes::from(vec![0x11; 40]))),
            ("truncated", good[..good.len() - 1].to_vec()),
            ("a truncated field", list(&[vec![0xa0, 0x01]])),
            // A 4-byte payload must use the short list form `0xc4`.
            ("non-canonical list length", [vec![0xf8, 0x04], vec![0x80; 4]].concat()),
        ];
        for (case, bytes) in cases {
            let err = RawL1Header::from_raw(bytes.into()).unwrap_err();
            assert!(matches!(err, L1HeaderError::Rlp(_)), "{case}: {err:?}");
        }
    }

    #[test]
    fn trailing_bytes_after_the_list_are_rejected() {
        let mut bytes = alloy_rlp::encode(prague());
        bytes.extend([0x80, 0x80]);
        assert_eq!(RawL1Header::from_raw(bytes.into()), Err(L1HeaderError::TrailingBytes(2)));
    }

    #[test]
    fn fewer_than_the_pre_london_fields_are_rejected() {
        let mut items = fields(&Header::default());
        assert_eq!(items.len(), MIN_FIELDS, "a pre-London header has the minimum");
        items.pop();
        assert_eq!(
            RawL1Header::from_raw(list(&items).into()),
            Err(L1HeaderError::TooFewFields { got: MIN_FIELDS - 1 })
        );
        assert_eq!(
            RawL1Header::from_raw(list(&[]).into()),
            Err(L1HeaderError::TooFewFields { got: 0 })
        );
    }

    #[test]
    fn undecodable_positional_fields_are_rejected() {
        let replace = |index: usize, item: Vec<u8>| {
            let mut items = fields(&prague());
            items[index] = item;
            Bytes::from(list(&items))
        };
        let cases = [
            (PARENT_HASH_INDEX, "parentHash", list(&[]), alloy_rlp::Error::UnexpectedList),
            (STATE_ROOT_INDEX, "stateRoot", [vec![0x9f], vec![3; 31]].concat(), {
                alloy_rlp::Error::UnexpectedLength
            }),
            (NUMBER_INDEX, "number", hex!("820001").to_vec(), alloy_rlp::Error::LeadingZero),
            (TIMESTAMP_INDEX, "timestamp", [vec![0x89], vec![1; 9]].concat(), {
                alloy_rlp::Error::Overflow
            }),
        ];
        for (index, name, item, error) in cases {
            assert_eq!(
                RawL1Header::from_raw(replace(index, item)),
                Err(L1HeaderError::Field { index, name, error }),
                "{name}"
            );
        }
    }

    /// Decoding a witness rejects a malformed raw header the same way, as an RLP error.
    #[test]
    fn rlp_decoding_rejects_a_malformed_raw_header() {
        let mut short = fields(&Header::default());
        short.pop();
        let encoded = alloy_rlp::encode(Bytes::from(list(&short)));
        assert_eq!(
            RawL1Header::decode(&mut encoded.as_slice()),
            Err(alloy_rlp::Error::Custom("raw L1 header has too few fields"))
        );
        // A list where the byte string belongs.
        let encoded = alloy_rlp::encode(prague());
        assert_eq!(
            RawL1Header::decode(&mut encoded.as_slice()),
            Err(alloy_rlp::Error::UnexpectedList)
        );
    }

    /// The positions are Ethereum's: an empty post-Prague mainnet-shaped header pins them.
    #[test]
    fn field_positions_are_ethereums() {
        assert_eq!(
            (PARENT_HASH_INDEX, STATE_ROOT_INDEX, NUMBER_INDEX, TIMESTAMP_INDEX, MIN_FIELDS),
            (0, 3, 8, 11, 15)
        );
        let header = Header {
            parent_hash: b256!("0101010101010101010101010101010101010101010101010101010101010101"),
            ..prague()
        };
        let items = fields(&header);
        assert_eq!(items.len(), 21);
        assert_eq!(items[PARENT_HASH_INDEX], [vec![0xa0], vec![0x01; 32]].concat());
        assert_eq!(items[STATE_ROOT_INDEX], [vec![0xa0], vec![0x03; 32]].concat());
        assert_eq!(items[NUMBER_INDEX], hex!("8401234567"));
        assert_eq!(items[TIMESTAMP_INDEX], hex!("8468e77800"));
    }
}
