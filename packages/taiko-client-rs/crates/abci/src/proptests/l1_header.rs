//! The raw L1 header an anchor witness carries: its exact RLP bytes, read by position.

use alloy_primitives::{B256, Bytes, keccak256};
use alloy_rlp::{Encodable, PayloadView};
use proptest::{collection::vec, prelude::*};

use super::{
    assert_canonical,
    mutate::{mutate, mutation},
    strategies::{el_header, raw_with_fields, rlp_item, rlp_list},
};
use crate::l1::header::{MIN_FIELDS, RawL1Header};

/// Arbitrary bytes, a list of arbitrary RLP items (around the [`MIN_FIELDS`] a header has at
/// least), or a mutated alloy header with arbitrary items appended.
fn raw_header_bytes() -> impl Strategy<Value = Vec<u8>> {
    prop_oneof![
        vec(any::<u8>(), 0..=700),
        vec(rlp_item(1), 0..=24).prop_map(|items| rlp_list(&items)),
        (el_header(), vec(rlp_item(2), 0..=2), vec(mutation(), 1..=3)).prop_map(
            |(header, extra, mutations)| mutate(&raw_with_fields(&header, &extra), &mutations, 0)
        ),
    ]
}

proptest! {
    #![proptest_config(ProptestConfig { cases: 2048, ..ProptestConfig::default() })]

    /// The RLP of any alloy header, with any RLP items appended as a newer L1 fork would, is an
    /// L1 header: its accessors are the header's fields, its hash is `keccak256` of the bytes
    /// as given (the alloy header's hash when nothing is appended), and its RLP (one byte string
    /// of the raw header) decodes back to it.
    #[test]
    fn raw_l1_header_reads_any_alloy_header_with_appended_fields(
        header in el_header(),
        extra in vec(rlp_item(2), 0..=3),
    ) {
        let raw = Bytes::from(raw_with_fields(&header, &extra));
        let parsed = RawL1Header::from_raw(raw.clone())
            .map_err(|error| TestCaseError::fail(format!("not an L1 header: {error}")))?;
        prop_assert_eq!(parsed.raw(), &raw);
        prop_assert_eq!(parsed.hash(), keccak256(&raw));
        if extra.is_empty() {
            prop_assert_eq!(parsed.hash(), header.hash_slow());
            prop_assert_eq!(&RawL1Header::from(&header), &parsed);
        }
        prop_assert_eq!(parsed.parent_hash(), header.parent_hash);
        prop_assert_eq!(parsed.state_root(), header.state_root);
        prop_assert_eq!(parsed.number(), header.number);
        prop_assert_eq!(parsed.timestamp(), header.timestamp);

        let encoded = alloy_rlp::encode(&parsed);
        prop_assert_eq!(&encoded, &alloy_rlp::encode(&raw));
        prop_assert_eq!(encoded.len(), parsed.length());
        prop_assert_eq!(alloy_rlp::decode_exact::<RawL1Header>(&encoded), Ok(parsed));
    }
}

proptest! {
    #![proptest_config(ProptestConfig { cases: 4096, ..ProptestConfig::default() })]

    /// `from_raw` never panics; whatever it accepts is an L1 header's shape, kept verbatim,
    /// hashed as given, and carried as an RLP byte string that decodes back to it. Decoding the
    /// same bytes as an RLP string never panics either, and accepts only a canonical one.
    #[test]
    fn raw_l1_header_keeps_whatever_it_accepts_verbatim(bytes in raw_header_bytes()) {
        if let Ok(header) = RawL1Header::from_raw(Bytes::copy_from_slice(&bytes)) {
            assert_l1_header_shape(&bytes, &header)?;
            prop_assert_eq!(header.raw().as_ref(), bytes.as_slice());
            prop_assert_eq!(header.hash(), keccak256(&bytes));
            let encoded = alloy_rlp::encode(&header);
            prop_assert_eq!(alloy_rlp::decode_exact::<RawL1Header>(&encoded), Ok(header));
        }
        assert_canonical::<RawL1Header>(&bytes)?;
        assert_canonical::<RawL1Header>(&alloy_rlp::encode(bytes.as_slice()))?;
    }
}

/// Checks that accepted `bytes` have an L1 header's shape: one RLP list with nothing after it, of
/// at least [`MIN_FIELDS`] items, whose items at Ethereum's positions of
/// `parentHash` (0), `stateRoot` (3), `number` (8) and `timestamp` (11) decode to `header`'s
/// accessors.
fn assert_l1_header_shape(bytes: &[u8], header: &RawL1Header) -> Result<(), TestCaseError> {
    let mut rest = bytes;
    let Ok(PayloadView::List(items)) = alloy_rlp::Header::decode_raw(&mut rest) else {
        return Err(TestCaseError::fail("accepted bytes that are not one RLP list"));
    };
    prop_assert!(rest.is_empty(), "accepted {} bytes after the list", rest.len());
    prop_assert!(items.len() >= MIN_FIELDS, "accepted a list of {} items", items.len());
    prop_assert_eq!(alloy_rlp::decode_exact::<B256>(items[0]), Ok(header.parent_hash()));
    prop_assert_eq!(alloy_rlp::decode_exact::<B256>(items[3]), Ok(header.state_root()));
    prop_assert_eq!(alloy_rlp::decode_exact::<u64>(items[8]), Ok(header.number()));
    prop_assert_eq!(alloy_rlp::decode_exact::<u64>(items[11]), Ok(header.timestamp()));
    Ok(())
}
