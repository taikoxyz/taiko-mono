//! Shasta extra data encoding helpers.

use alloy::primitives::Bytes;

/// Encode the extra data field for a Shasta block header.
///
/// The first byte contains the basefee sharing percentage, followed by a 6-byte
/// big-endian proposal id.
pub fn encode_extra_data(basefee_sharing_pctg: u8, proposal_id: u64) -> Bytes {
    let mut data = [0u8; 7];
    data[0] = basefee_sharing_pctg;
    let proposal_bytes = proposal_id.to_be_bytes();
    data[1..7].copy_from_slice(&proposal_bytes[2..8]);
    Bytes::from(data.to_vec())
}
