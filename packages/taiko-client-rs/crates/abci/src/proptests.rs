//! Property tests of the decoders a proposer controls and of their encoders: the block envelope,
//! the committee witness RLP, calldata forced inclusion transactions and witnesses, and the raw
//! L1 header.
//!
//! Decoding never panics, whatever the bytes. Every value round-trips through its encoding, and
//! every input a decoder accepts is the canonical encoding of what it decodes to (re-encoding
//! reproduces it exactly): a decoder accepting two encodings of one value would let one block
//! travel under several CometBFT transaction hashes. Each property runs a fixed number of cases,
//! sized so that it takes at most a few seconds in a debug build.

use std::fmt::Debug;

use alloy_rlp::{Decodable, Encodable};
use proptest::prelude::*;

/// Committee witness, record, registry entry and account witness RLP.
mod committee;
/// The block envelope and `single_envelope`.
mod envelope;
/// Canonical forced transactions and the forced inclusion witness.
mod forced;
/// The raw L1 header.
mod l1_header;
/// Byte-level and RLP-aware mutations of valid encodings.
mod mutate;
/// Generators of the values the properties encode and decode.
mod strategies;

/// Checks that `value` encodes to exactly [`Encodable::length`] bytes, which decode back to it
/// with nothing left over.
fn assert_round_trip<T>(value: &T) -> Result<(), TestCaseError>
where
    T: Encodable + Decodable + PartialEq + Debug,
{
    let encoded = alloy_rlp::encode(value);
    prop_assert_eq!(encoded.len(), value.length());
    let decoded = alloy_rlp::decode_exact::<T>(&encoded);
    prop_assert_eq!(decoded.as_ref(), Ok(value));
    Ok(())
}

/// Decodes a `T` from the front of `bytes` (which must not panic) and, if that succeeds, checks
/// that the bytes it consumed are exactly the canonical encoding of the decoded value.
fn assert_canonical<T>(bytes: &[u8]) -> Result<(), TestCaseError>
where
    T: Encodable + Decodable + Debug,
{
    let mut rest = bytes;
    if let Ok(value) = T::decode(&mut rest) {
        let consumed = &bytes[..bytes.len() - rest.len()];
        let reencoded = alloy_rlp::encode(&value);
        prop_assert_eq!(reencoded.as_slice(), consumed, "decoded {:?}", value);
    }
    Ok(())
}
