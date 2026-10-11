//! Exact V3 ABI encoding, including proxy/registry identities and both nested commitments.

use crate::{
    contracts::IEtnaInbox::{CommitteeRecord, LandInput},
    types::LandingSnapshot,
};
use alloy::sol_types::SolValue;
use alloy_primitives::{B256, U256, keccak256};

/// Byte length of the static sixteen-word public statement preimage.
pub const PREIMAGE_BYTES: usize = 16 * 32;

/// Hash Solidity's `abi.encode(records)`, retaining the dynamic-array offset and length words.
pub fn records_hash(records: &[CommitteeRecord]) -> B256 {
    keccak256(records.to_vec().abi_encode())
}

/// Hash Solidity's packed ordered bytes32 blob list, with no array offset or length words.
pub fn blob_hashes_hash(hashes: &[B256]) -> B256 {
    keccak256(hashes.iter().flat_map(|h| h.as_slice()).copied().collect::<Vec<_>>())
}

/// The exact sixteen static ABI words authenticated by `hashLandStatement`.
pub fn preimage(
    snapshot: &LandingSnapshot,
    input: &LandInput,
    reference_hash: B256,
    blob_hashes: &[B256],
) -> [u8; PREIMAGE_BYTES] {
    let mut tag = [0u8; 32];
    tag[..b"TAIKO_ETNA_LAND_V3".len()].copy_from_slice(b"TAIKO_ETNA_LAND_V3");
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
        snapshot.start_committee_record_hash.0,
        U256::from(input.lastHeight).to_be_bytes::<32>(),
        input.lastBlockHash.0,
        input.lastStateRoot.0,
        U256::from(input.l1ReferenceBlockNumber).to_be_bytes::<32>(),
        reference_hash.0,
        records_hash(&input.records).0,
        blob_hashes_hash(blob_hashes).0,
    ];
    let mut out = [0; PREIMAGE_BYTES];
    for (word, target) in words.iter().zip(out.chunks_exact_mut(32)) {
        target.copy_from_slice(word);
    }
    out
}

/// Compute the V3 job identity from coherent state, immutable outputs and ordered blobs.
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
        snapshot.start_committee_record_hash = B256::from(U256::from(0x77));
        let input = LandInput {
            lastHeight: 164,
            lastBlockHash: B256::from(U256::from(0x22)),
            lastStateRoot: B256::from(U256::from(0x33)),
            l1ReferenceBlockNumber: 19_000_000,
            records: vec![
                CommitteeRecord { epoch: 1, recordHash: B256::from(U256::from(0x55)) },
                CommitteeRecord { epoch: 2, recordHash: B256::from(U256::from(0x66)) },
            ],
        };
        (
            snapshot,
            input,
            B256::from(U256::from(0x44)),
            vec![B256::from(U256::from(0x01aa)), B256::from(U256::from(0x01bb))],
        )
    }

    #[test]
    fn matches_pinned_solidity_v3_vector_and_exact_sixteen_words() {
        let (snapshot, input, reference, hashes) = vector();
        assert_eq!(
            records_hash(&input.records),
            b256!("0fc2fb3087e71a5875752ba977cada62484ec8f9e897200fc61fde95b414fff1")
        );
        assert_eq!(
            blob_hashes_hash(&hashes),
            b256!("e7591a4eb3dcfdc958b08bf3db6054ebae1f9b1a82b8c685499c13314381ea64")
        );
        assert_eq!(preimage(&snapshot, &input, reference, &hashes).len(), 512);
        assert_eq!(
            hash(&snapshot, &input, reference, &hashes),
            b256!("90607f5e39a9f1a365d93fbf59a9397c3243e004182898c0c8db284ae190a56b")
        );
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
                7 => changed.start_committee_record_hash = B256::ZERO,
                8 => changed.l1_chain_id = U256::from(1) << 200,
                _ => unreachable!(),
            }
            assert_ne!(
                hash(&changed, &input, reference, &hashes),
                expected,
                "snapshot field {field}"
            );
        }
        for field in 0..6 {
            let mut changed = input.clone();
            match field {
                0 => changed.lastHeight += 1,
                1 => changed.lastBlockHash = B256::ZERO,
                2 => changed.lastStateRoot = B256::ZERO,
                3 => changed.l1ReferenceBlockNumber += 1,
                4 => changed.records[0].epoch += 1,
                5 => changed.records[0].recordHash = B256::ZERO,
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
            "land((uint64,bytes32,bytes32,uint64,(uint64,bytes32)[]),bytes)"
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
