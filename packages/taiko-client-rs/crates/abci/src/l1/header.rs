//! The owned raw L1 header an anchor or genesis witness carries. No I/O.
//!
//! The shared [`L1HeaderView`] checks framing and reads the positional fields.
//! The witness carries the exact received bytes, including appended fields.

use alloy_consensus::Header;
use alloy_primitives::{B256, Bytes};
use alloy_rlp::{BufMut, Decodable, Encodable};
use etna_core::l1_header::L1HeaderView;

pub use etna_core::l1_header::{
    L1HeaderError, MAX_HEADER_BYTES, MIN_FIELDS, NUMBER_INDEX, PARENT_HASH_INDEX, STATE_ROOT_INDEX,
    TIMESTAMP_INDEX,
};

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
    /// and whose `number` and `timestamp` are canonical `u64`s ([`L1HeaderError::Field`]). The
    /// other items' RLP framing is checked and their contents are opaque.
    pub fn from_raw(raw: Bytes) -> Result<Self, L1HeaderError> {
        let view = L1HeaderView::from_raw(raw.as_ref())?;
        Ok(Self {
            hash: view.hash(),
            parent_hash: view.parent_hash(),
            state_root: view.state_root(),
            number: view.number(),
            timestamp: view.timestamp(),
            raw,
        })
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

#[cfg(test)]
mod tests {
    use super::*;
    use crate::test_utils::raw_with_future_fields;
    use alloy_primitives::{Address, B64, Bloom, U64, U256, b256, hex, keccak256};

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
        assert_eq!(items.len(), fields(&base).len() + 3, "three fields appended");
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
        items.truncate(MIN_FIELDS);
        assert!(RawL1Header::from_raw(list(&items).into()).is_ok());
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
        short.truncate(11);
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

    /// A real Ethereum mainnet header, pinned in `testdata/mainnet_header_26155639.json`: block
    /// `0x18f1a77` as `eth_getBlockByNumber` served it, `raw` being the RLP list of its 21 header
    /// fields.
    #[derive(serde::Deserialize)]
    #[serde(rename_all = "camelCase")]
    struct MainnetHeader {
        number: U64,
        hash: B256,
        parent_hash: B256,
        state_root: B256,
        timestamp: U64,
        raw: Bytes,
    }

    /// The node reads a real mainnet header at Ethereum's positions: the raw bytes hash to the
    /// reported block hash, and parent hash, state root, number and timestamp are the reported
    /// ones.
    #[test]
    fn decodes_a_real_mainnet_header() {
        let fixture: MainnetHeader =
            serde_json::from_str(include_str!("testdata/mainnet_header_26155639.json"))
                .expect("the fixture parses");
        assert_eq!(fixture.number, U64::from(0x018f_1a77));
        assert_eq!(keccak256(&fixture.raw), fixture.hash, "the fixture is the block's header");

        let header = RawL1Header::from_raw(fixture.raw.clone()).expect("a mainnet header decodes");
        assert_eq!(header.hash(), fixture.hash);
        assert_eq!(header.parent_hash(), fixture.parent_hash);
        assert_eq!(header.state_root(), fixture.state_root);
        assert_eq!(header.number(), fixture.number.to::<u64>());
        assert_eq!(header.timestamp(), fixture.timestamp.to::<u64>());

        let mut buf = fixture.raw.as_ref();
        let Ok(alloy_rlp::PayloadView::List(items)) = alloy_rlp::Header::decode_raw(&mut buf)
        else {
            panic!("a list");
        };
        assert_eq!(items.len(), 21, "a post-Prague header");
        let decoded =
            <Header as Decodable>::decode(&mut fixture.raw.as_ref()).expect("alloy decodes it");
        assert_eq!(RawL1Header::from(&decoded), header, "alloy re-encodes the same bytes");
    }

    /// The positions are Ethereum's: an empty post-Prague mainnet-shaped header pins them.
    #[test]
    fn field_positions_are_ethereums() {
        assert_eq!(
            (PARENT_HASH_INDEX, STATE_ROOT_INDEX, NUMBER_INDEX, TIMESTAMP_INDEX, MIN_FIELDS),
            (0, 3, 8, 11, 12)
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

#[cfg(test)]
mod v1_bound_tests {
    use super::*;
    #[test]
    fn v1_l1_header_rejects_oversize_raw_input() {
        let header = Header { extra_data: Bytes::from(vec![0; 4096]), ..Default::default() };
        assert!(RawL1Header::from_raw(alloy_rlp::encode(header).into()).is_err());
    }
}
