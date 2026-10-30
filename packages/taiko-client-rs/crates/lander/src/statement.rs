//! Exact V1 ABI encoding binding chain state, cut leaves and the active committee snapshot.

use crate::{contracts::IEtnaInbox::LandInput, types::LandingSnapshot};
use alloy_primitives::{B256, U256, keccak256};

/// Byte length of the static twenty-one-word public statement preimage.
pub const PREIMAGE_BYTES: usize = 21 * 32;

/// Hash Solidity's packed ordered bytes32 blob list, with no array offset or length words.
pub fn blob_hashes_hash(hashes: &[B256]) -> B256 {
    keccak256(hashes.iter().flat_map(|h| h.as_slice()).copied().collect::<Vec<_>>())
}

/// Commit one grid endpoint's execution/consensus identity and consumed FI cursor.
pub fn cut_leaf(height: u64, el_hash: B256, comet_hash: B256, cursor: u64) -> B256 {
    keccak256(
        [
            U256::from(height).to_be_bytes::<32>(),
            el_hash.0,
            comet_hash.0,
            U256::from(cursor).to_be_bytes::<32>(),
        ]
        .concat(),
    )
}

/// V1 ordered interior-leaf commitment for the immutable original proof interval.
pub fn cut_hash(generation: u64, parent: U256, last: U256, leaves: &[B256]) -> B256 {
    let mut tag = [0u8; 32];
    tag[..b"ETNA_LAND_CUTS_V1".len()].copy_from_slice(b"ETNA_LAND_CUTS_V1");
    keccak256(
        [
            tag,
            U256::from(generation).to_be_bytes::<32>(),
            parent.to_be_bytes::<32>(),
            last.to_be_bytes::<32>(),
            blob_hashes_hash(leaves).0,
        ]
        .concat(),
    )
}

/// Encode the twenty-one static ABI words authenticated by the Inbox V1 statement.
pub fn preimage(
    snapshot: &LandingSnapshot,
    input: &LandInput,
    reference_hash: B256,
    blob_hashes: &[B256],
    leaves: &[B256],
) -> [u8; PREIMAGE_BYTES] {
    let mut tag = [0u8; 32];
    tag[..b"TAIKO_ETNA_LAND_V1".len()].copy_from_slice(b"TAIKO_ETNA_LAND_V1");
    let mut inbox = [0u8; 32];
    inbox[12..].copy_from_slice(snapshot.inbox.as_slice());
    let mut registry = [0u8; 32];
    registry[12..].copy_from_slice(snapshot.registry.as_slice());
    let words = [
        tag,
        snapshot.l1_chain_id.to_be_bytes::<32>(),
        U256::from(snapshot.l2_chain_id).to_be_bytes::<32>(),
        inbox,
        registry,
        U256::from(snapshot.generation).to_be_bytes::<32>(),
        input.parentHeight.to_be_bytes::<32>(),
        snapshot.checkpoint_hash.0,
        snapshot.checkpoint_comet_hash.0,
        snapshot.committee_config_hash.0,
        input.lastHeight.to_be_bytes::<32>(),
        input.lastBlockHash.0,
        input.lastCometHash.0,
        input.lastStateRoot.0,
        input.l1ReferenceBlockNumber.to_be_bytes::<32>(),
        reference_hash.0,
        blob_hashes_hash(blob_hashes).0,
        U256::from(snapshot.forced_inclusion_head).to_be_bytes::<32>(),
        input.forcedInclusionHead.to_be_bytes::<32>(),
        input.activeCommitteeSnapshot.to_be_bytes::<32>(),
        cut_hash(snapshot.generation, input.parentHeight, input.lastHeight, leaves).0,
    ];
    let mut out = [0; PREIMAGE_BYTES];
    for (word, target) in words.iter().zip(out.chunks_exact_mut(32)) {
        target.copy_from_slice(word);
    }
    out
}

/// Compute the V1 job identity from coherent state, immutable outputs and ordered blobs.
pub fn hash(
    snapshot: &LandingSnapshot,
    input: &LandInput,
    reference_hash: B256,
    blob_hashes: &[B256],
    leaves: &[B256],
) -> B256 {
    keccak256(preimage(snapshot, input, reference_hash, blob_hashes, leaves))
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::test_utils::{protocol::request, vectors};
    use alloy::sol_types::SolCall;

    fn vector(index: usize) -> (LandingSnapshot, LandInput, B256, Vec<B256>) {
        let path = |key: &str| format!("/land_statements/{index}/inputs/{key}");
        let mut snapshot = request().batch.snapshot;
        snapshot.l1_chain_id = vectors::u256_at(&path("l1_chain_id"));
        snapshot.l2_chain_id = vectors::u64_at(&path("l2_chain_id"));
        snapshot.inbox = vectors::address_at(&path("inbox"));
        snapshot.registry = vectors::address_at(&path("registry"));
        snapshot.generation = vectors::u64_at(&path("generation"));
        snapshot.checkpoint_height = vectors::u64_at(&path("parent_height"));
        snapshot.checkpoint_hash = vectors::b256_at(&path("parent_hash"));
        snapshot.checkpoint_comet_hash = vectors::b256_at(&path("parent_comet_hash"));
        snapshot.committee_config_hash = vectors::b256_at(&path("committee_config_hash"));
        snapshot.forced_inclusion_head = vectors::u64_at(&path("forced_inclusion_head_before"));
        let input = LandInput {
            parentHeight: vectors::u256_at(&path("parent_height")),
            lastHeight: vectors::u256_at(&path("last_height")),
            lastBlockHash: vectors::b256_at(&path("last_block_hash")),
            lastCometHash: vectors::b256_at(&path("last_comet_hash")),
            lastStateRoot: vectors::b256_at(&path("last_state_root")),
            l1ReferenceBlockNumber: vectors::u256_at(&path("l1_reference_block_number")),
            forcedInclusionHead: vectors::u256_at(&path("forced_inclusion_head_after")),
            activeCommitteeSnapshot: vectors::u256_at(&path("active_committee_snapshot")),
        };
        (
            snapshot,
            input,
            vectors::b256_at(&path("l1_reference_block_hash")),
            vectors::b256s_at(&path("blob_hashes")),
        )
    }

    fn leaves(index: usize) -> Vec<B256> {
        let heights: &[usize] = if index == 0 { &[6, 12] } else { &[12] };
        heights
            .iter()
            .map(|height| vectors::b256_at(&format!("/cuts/table/{height}/leaf")))
            .collect()
    }
    #[test]
    fn cut_leaves_match_all_independent_four_word_vectors() {
        for index in 0..vectors::len_at("/cuts/table") {
            let path = |key: &str| format!("/cuts/table/{index}/{key}");
            assert_eq!(
                cut_leaf(
                    vectors::u64_at(&path("height")),
                    vectors::b256_at(&path("block_hash")),
                    vectors::b256_at(&path("comet_hash")),
                    vectors::u64_at(&path("forced_head"))
                ),
                vectors::b256_at(&path("leaf"))
            );
        }
    }
    #[test]
    fn v1_statement_matches_all_pinned_672_byte_preimages() {
        for index in 0..vectors::len_at("/land_statements") {
            let (snapshot, input, reference, blobs) = vector(index);
            let encoded = preimage(&snapshot, &input, reference, &blobs, &leaves(index));
            assert_eq!(encoded.len(), 672);
            assert_eq!(
                encoded.as_slice(),
                vectors::bytes_at(&format!("/land_statements/{index}/preimage")).as_ref()
            );
            assert_eq!(
                hash(&snapshot, &input, reference, &blobs, &leaves(index)),
                vectors::b256_at(&format!("/land_statements/{index}/hash"))
            );
            assert_eq!(
                blob_hashes_hash(&blobs),
                vectors::b256_at(&format!("/land_statements/{index}/blob_hashes_hash"))
            );
        }
    }

    #[test]
    fn every_static_word_and_blob_order_is_bound() {
        let (snapshot, input, reference, blobs) = vector(1);
        let encoded = preimage(&snapshot, &input, reference, &blobs, &leaves(1));
        for word in 1..21 {
            let mut snapshot = snapshot.clone();
            let mut input = input.clone();
            let mut reference = reference;
            let mut blobs = blobs.clone();
            let mut cuts = leaves(1);
            match word {
                1 => snapshot.l1_chain_id ^= U256::from(1) << 200,
                2 => snapshot.l2_chain_id ^= 1,
                3 => snapshot.inbox[0] ^= 1,
                4 => snapshot.registry[0] ^= 1,
                5 => snapshot.generation ^= 1,
                6 => input.parentHeight ^= U256::from(1),
                7 => snapshot.checkpoint_hash[0] ^= 1,
                8 => snapshot.checkpoint_comet_hash[0] ^= 1,
                9 => snapshot.committee_config_hash[0] ^= 1,
                10 => input.lastHeight ^= U256::from(1),
                11 => input.lastBlockHash[0] ^= 1,
                12 => input.lastCometHash[0] ^= 1,
                13 => input.lastStateRoot[0] ^= 1,
                14 => input.l1ReferenceBlockNumber ^= U256::from(1),
                15 => reference[0] ^= 1,
                16 => blobs[0][0] ^= 1,
                17 => snapshot.forced_inclusion_head ^= 1,
                18 => input.forcedInclusionHead ^= U256::from(1),
                19 => input.activeCommitteeSnapshot ^= U256::from(1),
                20 => cuts[0][0] ^= 1,
                _ => unreachable!(),
            }
            let changed = preimage(&snapshot, &input, reference, &blobs, &cuts);
            assert_ne!(
                &changed[word * 32..(word + 1) * 32],
                &encoded[word * 32..(word + 1) * 32],
                "input word {word}"
            );
            assert_ne!(
                hash(&snapshot, &input, reference, &blobs, &cuts),
                keccak256(encoded),
                "input word {word}"
            );
        }
        assert_ne!(
            hash(&snapshot, &input, reference, &blobs, &leaves(1)),
            hash(
                &snapshot,
                &input,
                reference,
                &blobs.into_iter().rev().collect::<Vec<_>>(),
                &leaves(1)
            )
        );
    }

    #[test]
    fn v1_eight_field_abi_matches_complete_pinned_calldata() {
        use crate::contracts::IEtnaInbox::landCall;
        let (_, input, _, _) = vector(1);
        let call = landCall {
            _input: input,
            _leaves: vectors::b256s_at("/land_abi/leaves"),
            _proof: vectors::bytes_at("/land_abi/proof"),
        };
        assert_eq!(landCall::SIGNATURE, vectors::str_at("/land_abi/signature"));
        assert_eq!(call.abi_encode(), vectors::bytes_at("/land_abi/calldata"));
        assert_eq!(landCall::abi_decode(&call.abi_encode()).unwrap(), call);
    }
}
