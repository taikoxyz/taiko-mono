//! Exact V4 ABI encoding, including proxy/registry identities, fixed configuration and ordered
//! blobs.

use crate::{contracts::IEtnaInbox::LandInput, types::LandingSnapshot};
use alloy_primitives::{B256, U256, keccak256};

/// Byte length of the static fifteen-word public statement preimage.
pub const PREIMAGE_BYTES: usize = 15 * 32;

/// Hash Solidity's packed ordered bytes32 blob list, with no array offset or length words.
pub fn blob_hashes_hash(hashes: &[B256]) -> B256 {
    keccak256(hashes.iter().flat_map(|h| h.as_slice()).copied().collect::<Vec<_>>())
}

/// The exact fifteen static ABI words authenticated by `hashLandStatement`.
pub fn preimage(
    snapshot: &LandingSnapshot,
    input: &LandInput,
    reference_hash: B256,
    blob_hashes: &[B256],
) -> [u8; PREIMAGE_BYTES] {
    let mut tag = [0u8; 32];
    tag[..b"TAIKO_ETNA_LAND_V4".len()].copy_from_slice(b"TAIKO_ETNA_LAND_V4");
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
        U256::from(snapshot.checkpoint_height).to_be_bytes::<32>(),
        snapshot.checkpoint_hash.0,
        snapshot.committee_config_hash.0,
        U256::from(input.lastHeight).to_be_bytes::<32>(),
        input.lastBlockHash.0,
        input.lastStateRoot.0,
        U256::from(input.l1ReferenceBlockNumber).to_be_bytes::<32>(),
        reference_hash.0,
        blob_hashes_hash(blob_hashes).0,
    ];
    let mut out = [0; PREIMAGE_BYTES];
    for (word, target) in words.iter().zip(out.chunks_exact_mut(32)) {
        target.copy_from_slice(word);
    }
    out
}

/// Compute the V4 job identity from coherent state, immutable outputs and ordered blobs.
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
    use alloy_primitives::{address, b256};

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
            b256!("af72a8cac328b7a82ec9c449fb39aecc89a196de580f512cc40f0e1d8a6ad2fa");
        let input = LandInput {
            lastHeight: 164,
            lastBlockHash: B256::from(U256::from(0x22)),
            lastStateRoot: B256::from(U256::from(0x33)),
            l1ReferenceBlockNumber: 19_000_000,
        };
        (
            snapshot,
            input,
            B256::from(U256::from(0x44)),
            vec![B256::from(U256::from(0x01aa)), B256::from(U256::from(0x01bb))],
        )
    }

    #[test]
    fn matches_pinned_solidity_v4_vector_and_exact_fifteen_words() {
        let (snapshot, input, reference, hashes) = vector();
        assert_eq!(
            blob_hashes_hash(&hashes),
            b256!("e7591a4eb3dcfdc958b08bf3db6054ebae1f9b1a82b8c685499c13314381ea64")
        );
        assert_eq!(preimage(&snapshot, &input, reference, &hashes).len(), 480);
        assert_eq!(
            hash(&snapshot, &input, reference, &hashes),
            b256!("c25b74e918f50098001818a711b7604376e98978fa8cdace46af3803cdd100c2")
        );
    }

    #[test]
    fn every_fifteen_word_and_v3_domain_mutation_changes_the_vector() {
        let (snapshot, input, reference, hashes) = vector();
        let preimage = preimage(&snapshot, &input, reference, &hashes);
        let expected = keccak256(preimage);
        for word in 0..15 {
            let mut changed = preimage;
            changed[word * 32 + 31] ^= 1;
            assert_ne!(keccak256(changed), expected, "word {word}");
        }
        let mut v3 = preimage;
        v3[b"TAIKO_ETNA_LAND_V4".len() - 1] = b'3';
        assert_ne!(keccak256(v3), expected, "old domain cannot share job identity");
    }

    #[test]
    fn every_statement_input_is_bound_and_blob_order_matters() {
        let (snapshot, input, reference, hashes) = vector();
        let expected = hash(&snapshot, &input, reference, &hashes);
        for field in 0..9 {
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
                _ => unreachable!(),
            }
            assert_ne!(
                hash(&changed, &input, reference, &hashes),
                expected,
                "snapshot field {field}"
            );
        }
        for field in 0..4 {
            let mut changed = input.clone();
            match field {
                0 => changed.lastHeight += 1,
                1 => changed.lastBlockHash = B256::ZERO,
                2 => changed.lastStateRoot = B256::ZERO,
                3 => changed.l1ReferenceBlockNumber += 1,
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
    }

    #[test]
    fn land_selector_and_field_order_match_exact_solidity_signature() {
        use alloy::sol_types::SolCall;
        assert_eq!(
            crate::contracts::IEtnaInbox::landCall::SIGNATURE,
            "land((uint64,bytes32,bytes32,uint64),bytes)"
        );
        assert_eq!(
            crate::contracts::IEtnaInbox::landCall::SELECTOR,
            keccak256(crate::contracts::IEtnaInbox::landCall::SIGNATURE)[..4]
        );
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
