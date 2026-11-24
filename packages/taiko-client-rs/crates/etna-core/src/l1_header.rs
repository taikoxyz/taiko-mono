//! Positional decoding and byte identity of a raw L1 header.
//!
//! The header is hashed exactly as supplied. Only the fields used by anchor
//! consumers are decoded, and other fields are carried opaquely. A caller
//! authenticates the header's chain membership and any state proofs separately.

use alloy_primitives::{B256, keccak256};
use alloy_rlp::{Decodable, PayloadView};

/// Position of `parentHash` in an L1 header's RLP list.
pub const PARENT_HASH_INDEX: usize = 0;
/// Position of `stateRoot` in an L1 header's RLP list.
pub const STATE_ROOT_INDEX: usize = 3;
/// Position of `number` in an L1 header's RLP list.
pub const NUMBER_INDEX: usize = 8;
/// Position of `timestamp` in an L1 header's RLP list.
pub const TIMESTAMP_INDEX: usize = 11;
/// Minimum positional fields needed through timestamp; later header fields remain opaque.
pub const MIN_FIELDS: usize = 12;
/// Maximum authenticated L1 header size, including its canonical RLP framing.
pub const MAX_HEADER_BYTES: usize = 4096;

/// Why bytes are not an L1 header.
#[derive(Debug, thiserror::Error, Clone, Copy, PartialEq, Eq)]
pub enum L1HeaderError {
    /// The original header exceeds the consensus byte bound.
    #[error("L1 header is {0} bytes, exceeding 4096")]
    Oversize(usize),
    /// The outer RLP list or one of its items has invalid framing.
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
    /// Maps to a static [`alloy_rlp::Error`] for decoding a witness carrying the raw header.
    pub const fn as_rlp_error(&self) -> alloy_rlp::Error {
        alloy_rlp::Error::Custom(match self {
            Self::Oversize(_) => "raw L1 header exceeds byte bound",
            Self::Rlp(_) => "malformed raw L1 header RLP",
            Self::TrailingBytes(_) => "trailing bytes after the raw L1 header",
            Self::TooFewFields { .. } => "raw L1 header has too few fields",
            Self::Field { .. } => "raw L1 header has a malformed field",
        })
    }
}

/// A borrowed L1 header and the fields anchor consumers use.
///
/// Construction checks framing for the outer RLP list and each item, and
/// decodes the four positional fields. The contents of all other items are
/// opaque. The original bytes retain any appended fields.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct L1HeaderView<'a> {
    /// Original RLP list.
    raw: &'a [u8],
    /// Keccak-256 of the original list.
    hash: B256,
    /// Parent block hash.
    parent_hash: B256,
    /// L1 state root.
    state_root: B256,
    /// L1 block number.
    number: u64,
    /// L1 block timestamp in seconds since the Unix epoch.
    timestamp: u64,
}

impl<'a> L1HeaderView<'a> {
    /// Borrows the raw RLP list and decodes the four positional fields.
    ///
    /// # Errors
    ///
    /// Returns an error for an oversized header, invalid RLP framing, trailing
    /// bytes, too few fields, or an invalid encoding of a required field.
    pub fn from_raw(raw: &'a [u8]) -> Result<Self, L1HeaderError> {
        if raw.len() > MAX_HEADER_BYTES {
            return Err(L1HeaderError::Oversize(raw.len()));
        }
        let mut buf = raw;
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
        Ok(Self { hash: keccak256(raw), raw, parent_hash, state_root, number, timestamp })
    }

    /// The header's RLP list, exactly as received.
    pub const fn raw(&self) -> &'a [u8] {
        self.raw
    }

    /// The L1 block hash, `keccak256(raw)`.
    pub const fn hash(&self) -> B256 {
        self.hash
    }

    /// The parent block's hash.
    pub const fn parent_hash(&self) -> B256 {
        self.parent_hash
    }

    /// The L1 state root recorded in this header.
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
    use alloc::{vec, vec::Vec};
    use alloy_rlp::Error;

    /// Positional fields through timestamp with opaque intervening items.
    fn fields() -> [Vec<u8>; 12] {
        let mut fields = core::array::from_fn(|_| vec![0x80]);
        fields[0] = [vec![0xa0], vec![0x11; 32]].concat();
        fields[1] = vec![0xc2, 0x01, 0x02];
        fields[3] = [vec![0xa0], vec![0x33; 32]].concat();
        fields[8] = vec![0x82, 0x01, 0x23];
        fields[11] = vec![0x84, 0x65, 0x43, 0x21, 0x00];
        fields
    }

    /// Frames already encoded RLP items as one list.
    fn list(fields: &[Vec<u8>]) -> Vec<u8> {
        let mut raw = Vec::new();
        alloy_rlp::Header { list: true, payload_length: fields.iter().map(Vec::len).sum() }
            .encode(&mut raw);
        for field in fields {
            raw.extend_from_slice(field);
        }
        raw
    }

    #[test]
    fn borrows_and_hashes_original_header_with_appended_fields() {
        let mut fields = fields().to_vec();
        let base = list(&fields);
        fields.push(vec![0xc3, 0x01, 0xc1, 0x02]);
        fields.push(vec![0x83, 0x00, 0xff, 0x00]);

        let raw = list(&fields);
        let header = L1HeaderView::from_raw(&raw).unwrap();
        assert!(core::ptr::eq(header.raw(), raw.as_slice()));
        assert_eq!(header.hash(), keccak256(&raw));
        assert_ne!(header.hash(), keccak256(&base));
        assert_eq!(header.parent_hash(), B256::repeat_byte(0x11));
        assert_eq!(header.state_root(), B256::repeat_byte(0x33));
        assert_eq!(header.number(), 0x0123);
        assert_eq!(header.timestamp(), 0x6543_2100);
    }

    #[test]
    fn accepts_exactly_twelve_fields_with_u64_extremes() {
        let mut fields = fields();
        fields[8] = vec![0x80];
        fields[11] = [vec![0x88], vec![0xff; 8]].concat();

        let raw = list(&fields);
        let header = L1HeaderView::from_raw(&raw).unwrap();
        assert_eq!(header.number(), 0);
        assert_eq!(header.timestamp(), u64::MAX);
        assert_eq!(
            L1HeaderView::from_raw(&list(&fields[..11])),
            Err(L1HeaderError::TooFewFields { got: 11 })
        );
    }

    #[test]
    fn rejects_invalid_positional_field_encodings() {
        for (index, name, replacement, error) in [
            (0, "parentHash", vec![0xc0], Error::UnexpectedList),
            (3, "stateRoot", [vec![0x9f], vec![0x55; 31]].concat(), Error::UnexpectedLength),
            (8, "number", vec![0x82, 0x00, 0x01], Error::LeadingZero),
            (11, "timestamp", [vec![0x89], vec![0x01; 9]].concat(), Error::Overflow),
        ] {
            let mut fields = fields();
            fields[index] = replacement;
            assert_eq!(
                L1HeaderView::from_raw(&list(&fields)),
                Err(L1HeaderError::Field { index, name, error })
            );
        }
    }

    #[test]
    fn rejects_invalid_list_framing_and_trailing_bytes() {
        let raw = list(&fields());
        for malformed in
            [&[][..], &[0x80][..], &[0xf8, 0x01, 0x80], &[0xc2, 0x81, 0x01], &raw[..raw.len() - 1]]
        {
            let error = L1HeaderView::from_raw(malformed).unwrap_err();
            assert!(matches!(error, L1HeaderError::Rlp(_)), "{error:?}");
        }

        let extra = [raw, vec![0xc0, 0x80]].concat();
        assert_eq!(L1HeaderView::from_raw(&extra), Err(L1HeaderError::TrailingBytes(2)));
    }

    #[test]
    fn enforces_the_inclusive_raw_header_bound() {
        let fields = fields();
        let fixed_payload = fields.iter().map(Vec::len).sum::<usize>();
        for total in [4096, 4097] {
            let mut fields = fields.to_vec();
            // Both the outer list and the appended byte string have three-byte prefixes.
            let opaque = vec![0x77; total - fixed_payload - 6];
            fields.push(alloy_rlp::encode(opaque.as_slice()));
            let raw = list(&fields);
            assert_eq!(raw.len(), total);

            let result = L1HeaderView::from_raw(&raw);
            if total == 4096 {
                assert!(result.is_ok());
            } else {
                assert_eq!(result, Err(L1HeaderError::Oversize(4097)));
            }
        }
    }
}
