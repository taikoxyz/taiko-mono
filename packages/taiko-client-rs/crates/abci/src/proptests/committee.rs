//! The committee witness a switch block carries, and its parts: the committee record, the
//! staking-registry account witness and the registry entries.

use proptest::{collection::vec, prelude::*};

use super::{
    assert_canonical, assert_round_trip,
    mutate::{mutate, mutation},
    strategies::{account_witness, committee_record, committee_witness, rlp_item},
};
use crate::{
    envelope::CommitteeWitness,
    types::{AccountWitness, CommitteeRecord, RegistryEntry},
};

/// Decodes `bytes` with each committee witness decoder and checks that any accepted input is
/// canonical.
fn assert_canonical_decoders(bytes: &[u8]) -> Result<(), TestCaseError> {
    assert_canonical::<CommitteeWitness>(bytes)?;
    assert_canonical::<CommitteeRecord>(bytes)?;
    assert_canonical::<RegistryEntry>(bytes)?;
    assert_canonical::<AccountWitness>(bytes)
}

proptest! {
    #![proptest_config(ProptestConfig { cases: 1024, ..ProptestConfig::default() })]

    /// A committee witness, its record, its registry account witness and each of its entries
    /// round-trip through RLP.
    #[test]
    fn committee_witness_and_its_parts_round_trip(witness in committee_witness()) {
        assert_round_trip(&witness)?;
        assert_round_trip(&witness.record)?;
        assert_round_trip(&witness.registry)?;
        for entry in &witness.entries {
            assert_round_trip(entry)?;
        }
    }
}

proptest! {
    #![proptest_config(ProptestConfig { cases: 4096, ..ProptestConfig::default() })]

    /// Mutated encodings of a committee witness, a record, an account witness or an entry never
    /// panic any of the four decoders, and any input one accepts is canonical.
    #[test]
    fn committee_witness_decoders_accept_only_canonical_mutants(
        witness in committee_witness(),
        record in committee_record(),
        account in account_witness(),
        part in 0..4u8,
        mutations in vec(mutation(), 1..=4),
    ) {
        let encoded = match part {
            0 => alloy_rlp::encode(&witness),
            1 => alloy_rlp::encode(&record),
            2 => alloy_rlp::encode(&account),
            _ => witness.entries.first().map(alloy_rlp::encode).unwrap_or_default(),
        };
        assert_canonical_decoders(&mutate(&encoded, &mutations, 0))?;
    }

    /// Arbitrary bytes and arbitrary RLP items never panic the committee witness decoders, and
    /// any input one accepts is canonical.
    #[test]
    fn committee_witness_decoders_accept_only_canonical_arbitrary_input(
        bytes in prop_oneof![vec(any::<u8>(), 0..=400), rlp_item(4)],
    ) {
        assert_canonical_decoders(&bytes)?;
    }
}
