//! The block envelope: `0x06 || rlp([block, anchor, committee, forced])`, the one transaction of
//! every CometBFT block, chosen by the proposer.

use alloy_primitives::Bytes;
use alloy_rlp::{Decodable, Encodable};
use proptest::{collection::vec, prelude::*};

use super::{
    mutate::{mutate, mutation},
    strategies::{bytes, envelope, envelope_shaped_bytes, rlp_item},
};
use crate::envelope::{ENVELOPE_VERSION, EnvelopeError, EtnaEnvelope, single_envelope};

/// Decodes `bytes` as an envelope (which must not panic), on its own and as a CometBFT block's
/// only transaction, and checks that an accepted input is the canonical encoding of what it
/// decodes to, also when only its RLP body is decoded.
fn assert_canonical_envelope(bytes: &[u8]) -> Result<(), TestCaseError> {
    let decoded = EtnaEnvelope::decode(bytes);
    prop_assert_eq!(&single_envelope(&[Bytes::copy_from_slice(bytes)]), &decoded);
    if let Ok(envelope) = &decoded {
        let reencoded = envelope.encode();
        prop_assert_eq!(reencoded.as_ref(), bytes);
    }
    let body = bytes.get(1..).unwrap_or_default();
    let mut rest = body;
    if let Ok(envelope) = <EtnaEnvelope as Decodable>::decode(&mut rest) {
        let consumed = &body[..body.len() - rest.len()];
        let reencoded = alloy_rlp::encode(&envelope);
        prop_assert_eq!(reencoded.as_slice(), consumed);
    }
    Ok(())
}

/// Arbitrary bytes, the version byte before arbitrary bytes or an arbitrary RLP item, or an
/// envelope-shaped body whose witness lists hold arbitrary items.
fn arbitrary_envelope_bytes() -> impl Strategy<Value = Vec<u8>> {
    prop_oneof![
        vec(any::<u8>(), 0..=600),
        vec(any::<u8>(), 0..=600).prop_map(|bytes| [vec![ENVELOPE_VERSION], bytes].concat()),
        rlp_item(4).prop_map(|item| [vec![ENVELOPE_VERSION], item].concat()),
        envelope_shaped_bytes(),
    ]
}

proptest! {
    #![proptest_config(ProptestConfig { cases: 1024, ..ProptestConfig::default() })]

    /// Any envelope (any execution header, transactions and witnesses, including an anchor whose
    /// raw L1 header carries fields alloy's header does not know, and a forced transaction of up
    /// to 8192 bytes) decodes from its encoding, directly, as a block's only transaction and as an
    /// RLP body.
    #[test]
    fn envelope_round_trips_through_its_encoding(envelope in envelope()) {
        let encoded = envelope.encode();
        prop_assert_eq!(encoded[0], ENVELOPE_VERSION);
        prop_assert_eq!(encoded.len(), 1 + Encodable::length(&envelope));
        prop_assert_eq!(EtnaEnvelope::decode(&encoded), Ok(envelope.clone()));
        prop_assert_eq!(single_envelope(std::slice::from_ref(&encoded)), Ok(envelope.clone()));
        prop_assert_eq!(alloy_rlp::decode_exact::<EtnaEnvelope>(&encoded[1..]), Ok(envelope));
    }

    /// A CometBFT block whose transaction list does not hold exactly one item has no envelope.
    #[test]
    fn single_envelope_requires_exactly_one_transaction(txs in vec(bytes(32), 0..=4)) {
        match txs.as_slice() {
            [tx] => prop_assert_eq!(single_envelope(&txs), EtnaEnvelope::decode(tx)),
            _ => prop_assert_eq!(single_envelope(&txs), Err(EnvelopeError::TxCount(txs.len()))),
        }
    }
}

proptest! {
    #![proptest_config(ProptestConfig { cases: 4096, ..ProptestConfig::default() })]

    /// Mutated encodings of valid envelopes (bit flips, truncations, insertions, removals,
    /// duplicated ranges, a wrong version byte, non-canonical RLP headers, padded strings and
    /// extra list elements) never panic the decoder, and any it accepts is canonical.
    #[test]
    fn decoding_a_mutated_envelope_accepts_only_canonical_bytes(
        envelope in envelope(),
        mutations in vec(mutation(), 1..=4),
    ) {
        let encoded = envelope.encode();
        let mutated = mutate(&encoded, &mutations, 1);
        assert_canonical_envelope(&mutated)?;
        if mutated == encoded.as_ref() {
            prop_assert_eq!(EtnaEnvelope::decode(&mutated), Ok(envelope));
        }
    }
}

proptest! {
    #![proptest_config(ProptestConfig { cases: 8192, ..ProptestConfig::default() })]

    /// Arbitrary bytes never panic the decoder, and any it accepts is canonical.
    #[test]
    fn decoding_arbitrary_bytes_accepts_only_canonical_envelopes(
        bytes in arbitrary_envelope_bytes(),
    ) {
        assert_canonical_envelope(&bytes)?;
    }
}
