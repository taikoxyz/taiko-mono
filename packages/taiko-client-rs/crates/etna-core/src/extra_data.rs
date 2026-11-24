//! The block header's 13-byte `extraData` (appendix A of the Etna specification):
//! `0x64 ‖ uint48_be(generation) ‖ uint48_be(anchorNumber)`.
//!
//! The first byte is the base-fee sharing percentage, always
//! [`BASEFEE_SHARING_PCTG`](crate::extra_data::BASEFEE_SHARING_PCTG).
//! [`ExtraData::decode`](crate::extra_data::ExtraData::decode) returns every field as it finds it,
//! so callers compare the decoded value with the one the block must carry.

use crate::params::UINT48_MAX;

/// The length of an Etna `extraData` in bytes: `1 + 6 + 6`.
pub const EXTRA_DATA_LEN: usize = 13;

/// The base-fee sharing percentage every Etna block carries in `extraData[0]`: all base fees go
/// to the beneficiary.
pub const BASEFEE_SHARING_PCTG: u8 = 100;

/// The fields of an Etna `extraData`.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct ExtraData {
    /// `extraData[0]`, the base-fee sharing percentage.
    pub basefee_sharing_pctg: u8,
    /// The recovery generation, a `uint48`.
    pub generation: u64,
    /// The anchor L1 block number, a `uint48`.
    pub anchor: u64,
}

/// Why an `extraData` could not be encoded or decoded.
#[derive(Clone, Copy, Debug, PartialEq, Eq, thiserror::Error)]
pub enum ExtraDataError {
    /// The bytes are not [`EXTRA_DATA_LEN`] long; their length.
    #[error("extraData is {0} bytes, not {EXTRA_DATA_LEN}")]
    Length(usize),
    /// A `uint48` field holds a larger value.
    #[error("extraData {field} {value} exceeds uint48")]
    Overflow {
        /// The field, `generation` or `anchor`.
        field: &'static str,
        /// The value that does not fit.
        value: u64,
    },
}

impl ExtraData {
    /// The 13 bytes of these fields, refused when `generation` or `anchor` exceeds `uint48`.
    pub fn encode(&self) -> Result<[u8; EXTRA_DATA_LEN], ExtraDataError> {
        let mut bytes = [0u8; EXTRA_DATA_LEN];
        bytes[0] = self.basefee_sharing_pctg;
        bytes[1..7].copy_from_slice(&uint48_be("generation", self.generation)?);
        bytes[7..].copy_from_slice(&uint48_be("anchor", self.anchor)?);
        Ok(bytes)
    }

    /// The fields of `bytes`, refused unless it is exactly [`EXTRA_DATA_LEN`] bytes long. The
    /// first byte is returned verbatim; the caller compares it with [`BASEFEE_SHARING_PCTG`].
    pub fn decode(bytes: &[u8]) -> Result<Self, ExtraDataError> {
        let bytes: &[u8; EXTRA_DATA_LEN] =
            bytes.try_into().map_err(|_| ExtraDataError::Length(bytes.len()))?;
        let mut generation = [0u8; 8];
        generation[2..].copy_from_slice(&bytes[1..7]);
        let mut anchor = [0u8; 8];
        anchor[2..].copy_from_slice(&bytes[7..]);
        Ok(Self {
            basefee_sharing_pctg: bytes[0],
            generation: u64::from_be_bytes(generation),
            anchor: u64::from_be_bytes(anchor),
        })
    }
}

/// `value` as a 6-byte big-endian `uint48`, naming `field` when it does not fit.
fn uint48_be(field: &'static str, value: u64) -> Result<[u8; 6], ExtraDataError> {
    if value > UINT48_MAX {
        return Err(ExtraDataError::Overflow { field, value });
    }
    let mut bytes = [0u8; 6];
    bytes.copy_from_slice(&value.to_be_bytes()[2..]);
    Ok(bytes)
}

#[cfg(test)]
mod tests {
    use super::*;
    use alloy_primitives::hex;

    fn extra(generation: u64, anchor: u64) -> ExtraData {
        ExtraData { basefee_sharing_pctg: BASEFEE_SHARING_PCTG, generation, anchor }
    }

    #[test]
    fn zero_fields_encode_as_0x64_and_12_zero_bytes() {
        let bytes = extra(0, 0).encode().unwrap();
        assert_eq!(bytes.len(), EXTRA_DATA_LEN);
        assert_eq!(bytes[0], 0x64);
        assert_eq!(bytes[1..], [0u8; 12]);
        assert_eq!(ExtraData::decode(&bytes), Ok(extra(0, 0)));
    }

    #[test]
    fn generation_and_anchor_are_big_endian_uint48() {
        let data = extra(1, 258);
        let bytes = data.encode().unwrap();
        assert_eq!(bytes.as_slice(), hex!("64000000000001000000000102"));
        assert_eq!(ExtraData::decode(&bytes), Ok(data));
    }

    /// Every shared extraData vector encodes its generation and anchor number after the base fee
    /// sharing percentage, and decodes back to them.
    #[test]
    fn shared_vectors_encode_and_decode() {
        use crate::test_utils::vectors::{len_at, str_at, u64_at};
        for index in 0..len_at("/extra_data") {
            let path = |field: &str| format!("/extra_data/{index}/{field}");
            let data = extra(u64_at(&path("generation")), u64_at(&path("anchor_number")));
            let bytes = hex::decode(str_at(&path("extra_data"))).unwrap();
            assert_eq!(data.encode().unwrap().as_slice(), bytes, "extraData {index}");
            assert_eq!(ExtraData::decode(&bytes), Ok(data), "extraData {index}");
        }
    }

    #[test]
    fn decode_rejects_12_14_and_29_bytes() {
        let bytes = extra(1, 258).encode().unwrap();
        assert_eq!(ExtraData::decode(&bytes[..12]), Err(ExtraDataError::Length(12)));
        let mut longer = bytes.to_vec();
        longer.push(0);
        assert_eq!(ExtraData::decode(&longer), Err(ExtraDataError::Length(14)));
        longer.resize(29, 0);
        assert_eq!(ExtraData::decode(&longer), Err(ExtraDataError::Length(29)));
        assert_eq!(ExtraData::decode(&[]), Err(ExtraDataError::Length(0)));
    }

    #[test]
    fn decode_returns_the_first_byte_verbatim() {
        let mut bytes = extra(3, 9).encode().unwrap();
        bytes[0] = 0x65;
        let decoded = ExtraData::decode(&bytes).unwrap();
        assert_eq!(decoded, ExtraData { basefee_sharing_pctg: 0x65, ..extra(3, 9) });
        assert_ne!(decoded, extra(3, 9));
        assert_eq!(decoded.encode().unwrap(), bytes);
    }

    #[test]
    fn uint48_overflow_is_refused() {
        assert_eq!(
            extra(1 << 48, 0).encode(),
            Err(ExtraDataError::Overflow { field: "generation", value: 1 << 48 })
        );
        assert_eq!(
            extra(0, 1 << 48).encode(),
            Err(ExtraDataError::Overflow { field: "anchor", value: 1 << 48 })
        );
        let max = (1 << 48) - 1;
        let bytes = extra(max, max).encode().unwrap();
        assert_eq!(bytes[1..], [0xff; 12]);
        assert_eq!(ExtraData::decode(&bytes), Ok(extra(max, max)));
    }
}
