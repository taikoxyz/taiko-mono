//! Exact V6 ABI encoding, including proxy/registry identities, parent-anchor configuration,
//! ordered blobs, the forced inclusion queue heads before and after the batch, and the fee
//! recipient.

use crate::{contracts::IEtnaInbox::LandInput, types::LandingSnapshot};
use alloy_primitives::{B256, U256, keccak256};

/// Byte length of the static eighteen-word public statement preimage.
pub const PREIMAGE_BYTES: usize = 18 * 32;

/// Hash Solidity's packed ordered bytes32 blob list, with no array offset or length words.
pub fn blob_hashes_hash(hashes: &[B256]) -> B256 {
    keccak256(hashes.iter().flat_map(|h| h.as_slice()).copied().collect::<Vec<_>>())
}

/// The exact eighteen static ABI words authenticated by `hashLandStatement`: the fifteen V5
/// words under the V6 domain, then the stored forced inclusion head, the batch's head after and
/// its fee recipient (`LandInput.feeRecipient`, an address word).
pub fn preimage(
    snapshot: &LandingSnapshot,
    input: &LandInput,
    reference_hash: B256,
    blob_hashes: &[B256],
) -> [u8; PREIMAGE_BYTES] {
    let mut tag = [0u8; 32];
    tag[..b"TAIKO_ETNA_LAND_V6".len()].copy_from_slice(b"TAIKO_ETNA_LAND_V6");
    let mut inbox = [0u8; 32];
    inbox[12..].copy_from_slice(snapshot.inbox.as_slice());
    let mut registry = [0u8; 32];
    registry[12..].copy_from_slice(snapshot.registry.as_slice());
    let mut fee_recipient = [0u8; 32];
    fee_recipient[12..].copy_from_slice(input.feeRecipient.as_slice());
    let words = [
        tag,
        snapshot.l1_chain_id.to_be_bytes::<32>(),
        U256::from(snapshot.l2_chain_id).to_be_bytes::<32>(),
        inbox,
        registry,
        U256::from(snapshot.generation).to_be_bytes::<32>(),
        U256::from(snapshot.checkpoint_height).to_be_bytes::<32>(),
        snapshot.checkpoint_hash.0,
        snapshot.committee_config_hash.0,
        U256::from(input.lastHeight).to_be_bytes::<32>(),
        input.lastBlockHash.0,
        input.lastStateRoot.0,
        U256::from(input.l1ReferenceBlockNumber).to_be_bytes::<32>(),
        reference_hash.0,
        blob_hashes_hash(blob_hashes).0,
        U256::from(snapshot.forced_inclusion_head).to_be_bytes::<32>(),
        U256::from(input.forcedInclusionHead).to_be_bytes::<32>(),
        fee_recipient,
    ];
    let mut out = [0; PREIMAGE_BYTES];
    for (word, target) in words.iter().zip(out.chunks_exact_mut(32)) {
        target.copy_from_slice(word);
    }
    out
}

/// Compute the V6 job identity from coherent state, immutable outputs and ordered blobs.
pub fn hash(
    snapshot: &LandingSnapshot,
    input: &LandInput,
    reference_hash: B256,
    blob_hashes: &[B256],
) -> B256 {
    keccak256(preimage(snapshot, input, reference_hash, blob_hashes))
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::test_utils::protocol::request;
    use alloy_primitives::{address, aliases::U48, b256};

    /// The V5 fixed-vector inputs plus forced inclusion heads 3 (stored) and 5 (input) and fee
    /// recipient `0x…aa`.
    fn vector() -> (LandingSnapshot, LandInput, B256, Vec<B256>) {
        let mut snapshot = request().batch.snapshot;
        snapshot.l1_chain_id = U256::from(1);
        snapshot.l2_chain_id = 167001;
        snapshot.inbox = address!("1111111111111111111111111111111111111111");
        snapshot.registry = address!("2222222222222222222222222222222222222222");
        snapshot.generation = 3;
        snapshot.checkpoint_height = 100;
        snapshot.checkpoint_hash = B256::from(U256::from(0x11));
        snapshot.committee_config_hash =
            b256!("483221e100b91b58a058b89723effa13d9a8b8527f8915ca8ad74cc44d5b7c0e");
        snapshot.forced_inclusion_head = 3;
        let input = LandInput {
            lastHeight: 164,
            lastBlockHash: B256::from(U256::from(0x22)),
            lastStateRoot: B256::from(U256::from(0x33)),
            l1ReferenceBlockNumber: 19_000_000,
            forcedInclusionHead: U48::from(5),
            feeRecipient: address!("00000000000000000000000000000000000000aa"),
        };
        (
            snapshot,
            input,
            B256::from(U256::from(0x44)),
            vec![B256::from(U256::from(0x01aa)), B256::from(U256::from(0x01bb))],
        )
    }

    /// The vector the contracts pin (`EtnaInboxLand.t.sol`), computed independently there with
    /// `cast abi-encode` and `cast keccak` over the eighteen words.
    #[test]
    fn matches_independent_v6_vector_and_exact_eighteen_words() {
        let (snapshot, input, reference, hashes) = vector();
        assert_eq!(
            blob_hashes_hash(&hashes),
            b256!("e7591a4eb3dcfdc958b08bf3db6054ebae1f9b1a82b8c685499c13314381ea64")
        );
        let preimage = preimage(&snapshot, &input, reference, &hashes);
        assert_eq!(preimage.len(), 576);
        assert_eq!(
            hash(&snapshot, &input, reference, &hashes),
            b256!("e4f69a2c2e4a504cafcb7a737cd9eb64b1f6523fafa82e606c568f410ba24ca6")
        );
        assert_eq!(preimage[15 * 32..16 * 32], U256::from(3).to_be_bytes::<32>());
        assert_eq!(preimage[16 * 32..17 * 32], U256::from(5).to_be_bytes::<32>());
        assert_eq!(preimage[17 * 32..17 * 32 + 12], [0; 12]);
        assert_eq!(preimage[17 * 32 + 12..], input.feeRecipient.0);
        // The recipient is appended: the first seventeen words are the former seventeen-word V6
        // encoding of the same inputs (independently `cast abi-encode`d).
        assert_eq!(
            keccak256(&preimage[..17 * 32]),
            b256!("1ddacd671b06fb32f3daa57d1abf0fae06ccdec5190c33ecf7a4e649d7b8762a")
        );
        // Under the V5 domain, the first fifteen words are the V5 encoding of the same inputs.
        let mut v5 = preimage;
        v5[b"TAIKO_ETNA_LAND_V6".len() - 1] = b'5';
        assert_eq!(
            keccak256(&v5[..15 * 32]),
            b256!("43533fd98016f831c0f94ce56cf0b8e1480a275e07a0fbf22ce0f23a5fb9c4d7")
        );
    }

    #[test]
    fn every_eighteen_word_and_v5_domain_mutation_changes_the_vector() {
        let (snapshot, input, reference, hashes) = vector();
        let preimage = preimage(&snapshot, &input, reference, &hashes);
        let expected = keccak256(preimage);
        for word in 0..18 {
            let mut changed = preimage;
            changed[word * 32 + 31] ^= 1;
            assert_ne!(keccak256(changed), expected, "word {word}");
        }
        let mut v5 = preimage;
        v5[b"TAIKO_ETNA_LAND_V6".len() - 1] = b'5';
        assert_ne!(keccak256(v5), expected, "old domain cannot share job identity");
    }

    #[test]
    fn every_statement_input_is_bound_and_blob_order_matters() {
        let (snapshot, input, reference, hashes) = vector();
        let expected = hash(&snapshot, &input, reference, &hashes);
        for field in 0..11 {
            let mut changed = snapshot.clone();
            match field {
                0 => changed.l1_chain_id += U256::from(1),
                1 => changed.l2_chain_id += 1,
                2 => changed.inbox = alloy_primitives::Address::ZERO,
                3 => changed.registry = alloy_primitives::Address::ZERO,
                4 => changed.generation += 1,
                5 => changed.checkpoint_height += 1,
                6 => changed.checkpoint_hash = B256::ZERO,
                7 => changed.committee_config_hash = B256::ZERO,
                8 => changed.l1_chain_id = U256::from(1) << 200,
                9 => changed.forced_inclusion_head += 1,
                10 => changed.forced_inclusion_head = (1 << 48) - 1,
                _ => unreachable!(),
            }
            assert_ne!(
                hash(&changed, &input, reference, &hashes),
                expected,
                "snapshot field {field}"
            );
        }
        for field in 0..8 {
            let mut changed = input.clone();
            match field {
                0 => changed.lastHeight += 1,
                1 => changed.lastBlockHash = B256::ZERO,
                2 => changed.lastStateRoot = B256::ZERO,
                3 => changed.l1ReferenceBlockNumber += 1,
                4 => changed.forcedInclusionHead += U48::from(1),
                5 => changed.forcedInclusionHead = U48::MAX,
                6 => changed.feeRecipient = alloy_primitives::Address::ZERO,
                7 => changed.feeRecipient = address!("00000000000000000000000000000000000000ab"),
                _ => unreachable!(),
            }
            assert_ne!(
                hash(&snapshot, &changed, reference, &hashes),
                expected,
                "output field {field}"
            );
        }
        assert_ne!(hash(&snapshot, &input, B256::ZERO, &hashes), expected);
        let reversed = hashes.iter().rev().copied().collect::<Vec<_>>();
        assert_ne!(hash(&snapshot, &input, reference, &reversed), expected);
        let mut swapped = (snapshot.clone(), input.clone());
        swapped.0.forced_inclusion_head = input.forcedInclusionHead.to();
        swapped.1.forcedInclusionHead = U48::from(snapshot.forced_inclusion_head);
        assert_ne!(
            hash(&swapped.0, &swapped.1, reference, &hashes),
            expected,
            "head before and after are ordered"
        );
    }

    #[test]
    fn land_selector_and_field_order_match_exact_solidity_signature() {
        use alloy::sol_types::SolCall;
        assert_eq!(
            crate::contracts::IEtnaInbox::landCall::SIGNATURE,
            "land((uint64,bytes32,bytes32,uint64,uint48,address),bytes)"
        );
        assert_eq!(
            crate::contracts::IEtnaInbox::landCall::SELECTOR,
            keccak256(crate::contracts::IEtnaInbox::landCall::SIGNATURE)[..4]
        );
        assert_eq!(crate::contracts::IEtnaInbox::landCall::SELECTOR, [0x25, 0xc4, 0x13, 0x48]);
        let (_, input, _, _) = vector();
        let call = crate::contracts::IEtnaInbox::landCall {
            _input: input.clone(),
            _proof: alloy_primitives::Bytes::from_static(&[0]),
        };
        let decoded =
            crate::contracts::IEtnaInbox::landCall::abi_decode(&call.abi_encode()).unwrap();
        assert_eq!(decoded._input, input);
        assert_eq!(decoded._proof.as_ref(), &[0]);
    }
}
