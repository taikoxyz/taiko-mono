//! Calldata forced inclusion: the canonical transaction decoder, which reads bytes anyone may
//! submit to the Inbox, and the forced inclusion witness codec.

use alloy_eips::eip2718::Encodable2718;
use alloy_rlp::{Decodable, Encodable};
use proptest::{collection::vec, prelude::*};

use super::{
    assert_canonical,
    mutate::{mutate, mutation},
    strategies::{account_witness, forced_tx, rlp_item, signed_transaction, uint},
};
use crate::forced::{ForcedWitness, MAX_FORCED_TX_BYTES, decode_canonical};

/// Arbitrary bytes, a transaction type byte (0 to 5, the first and last undefined) before an
/// arbitrary RLP item, or a mutated encoding of an arbitrary signed transaction.
fn transaction_bytes() -> impl Strategy<Value = Vec<u8>> {
    prop_oneof![
        vec(any::<u8>(), 0..=600),
        (0u8..=5, rlp_item(3)).prop_map(|(ty, item)| [vec![ty], item].concat()),
        (signed_transaction(), vec(mutation(), 1..=3)).prop_map(|(tx, mutations)| {
            let encoded = tx.encoded_2718();
            // A typed transaction's RLP list follows its type byte.
            mutate(&encoded, &mutations, usize::from(!tx.is_legacy()))
        }),
    ]
}

proptest! {
    #![proptest_config(ProptestConfig { cases: 4096, ..ProptestConfig::default() })]

    /// `decode_canonical` never panics, and returns a transaction only for the bytes it encodes
    /// to.
    #[test]
    fn decode_canonical_returns_only_exact_encodings(bytes in transaction_bytes()) {
        if let Some(tx) = decode_canonical(&bytes) {
            prop_assert_eq!(tx.encoded_2718(), bytes);
        }
    }
}

proptest! {
    #![proptest_config(ProptestConfig { cases: 2048, ..ProptestConfig::default() })]

    /// Every signed transaction type (legacy with and without an EIP-155 chain id, EIP-2930,
    /// EIP-1559, EIP-4844 without a sidecar and EIP-7702) decodes from its EIP-2718 encoding, and
    /// no longer once a byte trails it or once a typed one is wrapped as an RLP string.
    #[test]
    fn every_transaction_type_round_trips_through_decode_canonical(
        tx in signed_transaction(),
        trailing in any::<u8>(),
    ) {
        let encoded = tx.encoded_2718();
        prop_assert_eq!(decode_canonical(&encoded), Some(tx.clone()));
        prop_assert_eq!(decode_canonical(&[encoded.as_slice(), &[trailing]].concat()), None);
        if !tx.is_legacy() {
            prop_assert_eq!(decode_canonical(&alloy_rlp::encode(encoded.as_slice())), None);
        }
    }

    /// The forced inclusion witness decodes a transaction of at most `MAX_FORCED_TX_BYTES` and
    /// refuses a longer one; mutated encodings never panic its decoder, and any it accepts is
    /// canonical with a transaction within the limit.
    #[test]
    fn forced_witness_bounds_its_transaction_and_round_trips(
        index in uint(),
        entry in account_witness(),
        tx in prop_oneof![forced_tx(MAX_FORCED_TX_BYTES), forced_tx(MAX_FORCED_TX_BYTES + 1)],
        mutations in vec(mutation(), 0..=3),
    ) {
        let witness = ForcedWitness { index, entry, tx };
        let encoded = alloy_rlp::encode(&witness);
        prop_assert_eq!(encoded.len(), witness.length());
        let decoded = alloy_rlp::decode_exact::<ForcedWitness>(&encoded);
        if witness.tx.len() <= MAX_FORCED_TX_BYTES {
            prop_assert_eq!(decoded, Ok(witness));
        } else {
            prop_assert_eq!(
                decoded,
                Err(alloy_rlp::Error::Custom("forced transaction exceeds byte limit"))
            );
        }
        let mutated = mutate(&encoded, &mutations, 0);
        assert_canonical::<ForcedWitness>(&mutated)?;
        if let Ok(decoded) = ForcedWitness::decode(&mut mutated.as_slice()) {
            prop_assert!(decoded.tx.len() <= MAX_FORCED_TX_BYTES);
        }
    }
}
