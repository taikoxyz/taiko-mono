//! The block header's 29-byte `extraData` (appendix A of the Etna specification):
//! `0x64 ‖ uint48_be(generation) ‖ uint48_be(anchorNumber) ‖ uint128_be(missBitmap)`.
//!
//! The first byte is the base-fee sharing percentage, always
//! [`BASEFEE_SHARING_PCTG`](crate::extra_data::BASEFEE_SHARING_PCTG). Bit `s` of `missBitmap`
//! belongs to seat `s` ([`seat_bit`](crate::extra_data::seat_bit)): seat 0 is the low bit of the
//! last byte and seat 127 the high bit of byte 13.
//! [`ExtraData::decode`](crate::extra_data::ExtraData::decode) returns every field as it finds it,
//! so callers compare the decoded value with the one the block must carry.

use crate::params::UINT48_MAX;

/// The length of an Etna `extraData` in bytes: `1 + 6 + 6 + 16`.
pub const EXTRA_DATA_LEN: usize = 29;

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
    /// The seats of the validators missing from the block's LastCommit, one bit per seat.
    pub miss_bitmap: u128,
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
    /// The 29 bytes of these fields, refused when `generation` or `anchor` exceeds `uint48`.
    pub fn encode(&self) -> Result<[u8; EXTRA_DATA_LEN], ExtraDataError> {
        let mut bytes = [0u8; EXTRA_DATA_LEN];
        bytes[0] = self.basefee_sharing_pctg;
        bytes[1..7].copy_from_slice(&uint48_be("generation", self.generation)?);
        bytes[7..13].copy_from_slice(&uint48_be("anchor", self.anchor)?);
        bytes[13..].copy_from_slice(&self.miss_bitmap.to_be_bytes());
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
        anchor[2..].copy_from_slice(&bytes[7..13]);
        let mut miss_bitmap = [0u8; 16];
        miss_bitmap.copy_from_slice(&bytes[13..]);
        Ok(Self {
            basefee_sharing_pctg: bytes[0],
            generation: u64::from_be_bytes(generation),
            anchor: u64::from_be_bytes(anchor),
            miss_bitmap: u128::from_be_bytes(miss_bitmap),
        })
    }
}

/// Whether `miss_bitmap` marks seat `seat` missing: bit `seat`, `(miss_bitmap >> seat) & 1`.
/// Seats from 128 up have no bit and give `false`.
pub fn seat_bit(miss_bitmap: u128, seat: u8) -> bool {
    miss_bitmap.checked_shr(u32::from(seat)).is_some_and(|bits| bits & 1 == 1)
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

    fn extra(generation: u64, anchor: u64, miss_bitmap: u128) -> ExtraData {
        ExtraData { basefee_sharing_pctg: BASEFEE_SHARING_PCTG, generation, anchor, miss_bitmap }
    }

    #[test]
    fn zero_fields_encode_as_0x64_and_28_zero_bytes() {
        let bytes = extra(0, 0, 0).encode().unwrap();
        assert_eq!(bytes.len(), EXTRA_DATA_LEN);
        assert_eq!(bytes[0], 0x64);
        assert_eq!(bytes[1..], [0u8; 28]);
        assert_eq!(ExtraData::decode(&bytes), Ok(extra(0, 0, 0)));
    }

    #[test]
    fn vector_with_high_and_low_bitmap_bits() {
        let data = extra(1, 258, (1 << 127) + 1);
        let bytes = data.encode().unwrap();
        assert_eq!(
            bytes,
            hex!("64" "000000000001" "000000000102" "80000000000000000000000000000001")
        );
        assert_eq!(ExtraData::decode(&bytes), Ok(data));
    }

    #[test]
    fn seat_zero_is_the_low_bit_of_the_last_byte() {
        let bytes = extra(0, 0, 5).encode().unwrap();
        assert_eq!(bytes[28], 0x05);
        assert_eq!(bytes[13..28], [0u8; 15]);
        let decoded = ExtraData::decode(&bytes).unwrap().miss_bitmap;
        assert!(seat_bit(decoded, 0));
        assert!(!seat_bit(decoded, 1));
        assert!(seat_bit(decoded, 2));
        assert!((3..=u8::MAX).all(|seat| !seat_bit(decoded, seat)));
    }

    #[test]
    fn seat_127_is_the_high_bit_of_byte_13() {
        let bytes = extra(0, 0, 1 << 127).encode().unwrap();
        assert_eq!(bytes[13], 0x80);
        assert_eq!(bytes[14..], [0u8; 15]);
        let decoded = ExtraData::decode(&bytes).unwrap().miss_bitmap;
        assert!(seat_bit(decoded, 127));
        assert!((0..127).all(|seat| !seat_bit(decoded, seat)));
        // Seats from 128 up have no bit, even in a full bitmap.
        assert!((128..=u8::MAX).all(|seat| !seat_bit(u128::MAX, seat)));
    }

    #[test]
    fn decode_rejects_13_and_30_bytes() {
        let bytes = extra(1, 258, 7).encode().unwrap();
        assert_eq!(ExtraData::decode(&bytes[..13]), Err(ExtraDataError::Length(13)));
        let mut longer = bytes.to_vec();
        longer.push(0);
        assert_eq!(ExtraData::decode(&longer), Err(ExtraDataError::Length(30)));
        assert_eq!(ExtraData::decode(&[]), Err(ExtraDataError::Length(0)));
    }

    #[test]
    fn decode_returns_the_first_byte_verbatim() {
        let mut bytes = extra(3, 9, 1).encode().unwrap();
        bytes[0] = 0x65;
        let decoded = ExtraData::decode(&bytes).unwrap();
        assert_eq!(decoded, ExtraData { basefee_sharing_pctg: 0x65, ..extra(3, 9, 1) });
        assert_ne!(decoded, extra(3, 9, 1));
        assert_eq!(decoded.encode().unwrap(), bytes);
    }

    #[test]
    fn uint48_overflow_is_refused() {
        assert_eq!(
            extra(1 << 48, 0, 0).encode(),
            Err(ExtraDataError::Overflow { field: "generation", value: 1 << 48 })
        );
        assert_eq!(
            extra(0, 1 << 48, 0).encode(),
            Err(ExtraDataError::Overflow { field: "anchor", value: 1 << 48 })
        );
        let max = (1 << 48) - 1;
        let bytes = extra(max, max, u128::MAX).encode().unwrap();
        assert_eq!(bytes[1..13], [0xff; 12]);
        assert_eq!(ExtraData::decode(&bytes), Ok(extra(max, max, u128::MAX)));
    }
}
