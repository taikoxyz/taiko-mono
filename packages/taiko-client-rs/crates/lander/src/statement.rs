//! Exact V8 ABI encoding binding chain state, forced fees and L2 base fee rewards.

use crate::{contracts::IEtnaInbox::LandInput, types::LandingSnapshot};
use alloy_primitives::{B256, U256, keccak256};

/// Byte length of the static twenty-word public statement preimage.
pub const PREIMAGE_BYTES: usize = 20 * 32;

/// Hash Solidity's packed ordered bytes32 blob list, with no array offset or length words.
pub fn blob_hashes_hash(hashes: &[B256]) -> B256 {
    keccak256(hashes.iter().flat_map(|h| h.as_slice()).copied().collect::<Vec<_>>())
}

/// Encode the twenty static ABI words authenticated by the Inbox V8 statement.
pub fn preimage(
    snapshot: &LandingSnapshot,
    input: &LandInput,
    reference_hash: B256,
    blob_hashes: &[B256],
) -> [u8; PREIMAGE_BYTES] {
    let mut tag = [0u8; 32];
    tag[..b"TAIKO_ETNA_LAND_V8".len()].copy_from_slice(b"TAIKO_ETNA_LAND_V8");
    let mut inbox = [0u8; 32];
    inbox[12..].copy_from_slice(snapshot.inbox.as_slice());
    let mut registry = [0u8; 32];
    registry[12..].copy_from_slice(snapshot.registry.as_slice());
    let mut fee_recipient = [0u8; 32];
    fee_recipient[12..].copy_from_slice(input.feeRecipient.as_slice());
    let mut reward_recipient = [0u8; 32];
    reward_recipient[12..].copy_from_slice(input.l2RewardRecipient.as_slice());
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
        reward_recipient,
        input.baseFeeAmount.to_be_bytes::<32>(),
    ];
    let mut out = [0; PREIMAGE_BYTES];
    for (word, target) in words.iter().zip(out.chunks_exact_mut(32)) {
        target.copy_from_slice(word);
    }
    out
}

/// Compute the V8 job identity from coherent state, immutable outputs and ordered blobs.
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
    use crate::test_utils::{protocol::request, vectors};
    use alloy_primitives::{Address, aliases::U48};

    pub(super) fn vector() -> (LandingSnapshot, LandInput, B256, Vec<B256>) {
        let input = |name: &str| format!("/land_statement/inputs/{name}");
        assert_eq!(vectors::str_at(&input("tag")), "TAIKO_ETNA_LAND_V8");
        let mut snapshot = request().batch.snapshot;
        snapshot.l1_chain_id = vectors::u256_at(&input("l1_chain_id"));
        snapshot.l2_chain_id = vectors::u64_at(&input("l2_chain_id"));
        snapshot.inbox = vectors::address_at(&input("inbox"));
        snapshot.registry = vectors::address_at(&input("registry"));
        snapshot.generation = vectors::u64_at(&input("generation"));
        snapshot.checkpoint_height = vectors::u64_at(&input("parent_height"));
        snapshot.checkpoint_hash = vectors::b256_at(&input("parent_hash"));
        snapshot.committee_config_hash = vectors::b256_at(&input("committee_config_hash"));
        assert_eq!(snapshot.committee_config_hash, vectors::b256_at("/committee_config/hash"));
        snapshot.forced_inclusion_head = vectors::u64_at(&input("forced_inclusion_head_before"));
        let land = LandInput {
            lastHeight: vectors::u64_at(&input("last_height")),
            lastBlockHash: vectors::b256_at(&input("last_block_hash")),
            lastStateRoot: vectors::b256_at(&input("last_state_root")),
            l1ReferenceBlockNumber: vectors::u64_at(&input("l1_reference_block_number")),
            forcedInclusionHead: U48::from(vectors::u64_at(&input("forced_inclusion_head_after"))),
            l2RewardRecipient: vectors::address_at(&input("l2_reward_recipient")),
            baseFeeAmount: vectors::u256_at(&input("base_fee_amount")),
            feeRecipient: vectors::address_at(&input("fee_recipient")),
        };
        (
            snapshot,
            land,
            vectors::b256_at(&input("l1_reference_block_hash")),
            vectors::b256s_at(&input("blob_hashes")),
        )
    }

    #[test]
    fn v8_vector_matches_independent_cast_encoding() {
        let (snapshot, input, reference, blobs) = vector();
        let encoded = preimage(&snapshot, &input, reference, &blobs);
        assert_eq!(encoded.len(), 640);
        assert_eq!(encoded.as_slice(), vectors::bytes_at("/land_statement/preimage").as_ref());
        assert_eq!(
            hash(&snapshot, &input, reference, &blobs),
            vectors::b256_at("/land_statement/hash")
        );
        assert_eq!(blob_hashes_hash(&blobs), vectors::b256_at("/land_statement/blob_hashes_hash"));
        let mut zero = input.clone();
        zero.baseFeeAmount = U256::ZERO;
        assert_eq!(
            hash(&snapshot, &zero, reference, &blobs),
            vectors::b256_at("/zero_fee/land_statement/hash")
        );
        assert_eq!(&encoded[18 * 32..18 * 32 + 12], &[0; 12]);
        assert_eq!(&encoded[18 * 32 + 12..19 * 32], input.l2RewardRecipient.as_slice());
        assert_eq!(encoded[19 * 32..], input.baseFeeAmount.to_be_bytes::<32>());
    }

    #[test]
    fn every_v8_word_and_reward_bit_is_bound() {
        let (snapshot, input, reference, blobs) = vector();
        let encoded = preimage(&snapshot, &input, reference, &blobs);
        let expected = keccak256(encoded);
        for word in 0..20 {
            let mut changed = encoded;
            changed[word * 32 + 31] ^= 1;
            assert_ne!(keccak256(changed), expected, "word {word}");
        }
        for bit in 0..256 {
            let mut changed = input.clone();
            changed.baseFeeAmount ^= U256::from(1) << bit;
            assert_ne!(hash(&snapshot, &changed, reference, &blobs), expected, "amount bit {bit}");
        }
        let mut old = encoded;
        old[17] = b'7';
        assert_ne!(keccak256(old), expected);
    }

    #[test]
    fn every_statement_input_is_bound_and_blob_order_matters() {
        let (snapshot, input, reference, blobs) = vector();
        let expected = hash(&snapshot, &input, reference, &blobs);
        for field in 0..10 {
            let mut changed = snapshot.clone();
            match field {
                0 => changed.l1_chain_id += U256::from(1),
                1 => changed.l2_chain_id += 1,
                2 => changed.inbox = Address::ZERO,
                3 => changed.registry = Address::ZERO,
                4 => changed.generation += 1,
                5 => changed.checkpoint_height += 1,
                6 => changed.checkpoint_hash = B256::ZERO,
                7 => changed.committee_config_hash = B256::ZERO,
                8 => changed.l1_chain_id = U256::from(1) << 200,
                9 => changed.forced_inclusion_head += 1,
                _ => unreachable!(),
            }
            assert_ne!(
                hash(&changed, &input, reference, &blobs),
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
                5 => changed.feeRecipient = Address::ZERO,
                6 => changed.l2RewardRecipient = Address::ZERO,
                7 => changed.baseFeeAmount += U256::from(1),
                _ => unreachable!(),
            }
            assert_ne!(
                hash(&snapshot, &changed, reference, &blobs),
                expected,
                "input field {field}"
            );
        }
        assert_ne!(hash(&snapshot, &input, B256::ZERO, &blobs), expected);
        assert_ne!(
            hash(&snapshot, &input, reference, &blobs.iter().rev().copied().collect::<Vec<_>>()),
            expected
        );
    }

    #[test]
    fn land_selector_matches_generated_v8_abi() {
        use crate::contracts::IEtnaInbox::landCall;
        use alloy::sol_types::SolCall;
        assert_eq!(
            landCall::SIGNATURE,
            "land((uint64,bytes32,bytes32,uint64,uint48,address,address,uint256),bytes)"
        );
        assert_eq!(landCall::SELECTOR, vectors::bytes_at("/land_selector").as_ref());
        let (_, input, _, _) = vector();
        let call =
            landCall { _input: input.clone(), _proof: alloy_primitives::Bytes::from_static(&[0]) };
        let calldata = call.abi_encode();
        assert_eq!(calldata.len(), 4 + 11 * 32);
        let decoded = landCall::abi_decode(&calldata).unwrap();
        assert_eq!(decoded._input, input);
        assert_eq!(decoded._proof.as_ref(), &[0]);
    }
}
