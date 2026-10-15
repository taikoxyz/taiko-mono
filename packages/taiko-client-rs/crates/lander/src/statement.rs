//! Exact V7 ABI encoding: proxy/registry identities, parent-anchor configuration, ordered blobs,
//! the forced inclusion queue heads before and after the batch, the fee recipient and, last, the
//! hash of the batch's validator participation.

use crate::{
    contracts::IEtnaInbox::{EpochParticipation, LandInput},
    types::LandingSnapshot,
};
use alloy::sol_types::SolValue;
use alloy_primitives::{B256, U256, keccak256};

/// Byte length of the static nineteen-word public statement preimage.
pub const PREIMAGE_BYTES: usize = 19 * 32;

/// Hash Solidity's packed ordered bytes32 blob list, with no array offset or length words.
pub fn blob_hashes_hash(hashes: &[B256]) -> B256 {
    keccak256(hashes.iter().flat_map(|h| h.as_slice()).copied().collect::<Vec<_>>())
}

/// `keccak256(abi.encode(parts))`: Solidity's encoding of one dynamic `EpochParticipation[]`
/// argument, leading offset word included, so an empty list hashes the two words `32, 0`.
pub fn participation_hash(parts: &[EpochParticipation]) -> B256 {
    keccak256(parts.abi_encode())
}

/// The exact nineteen static ABI words authenticated by `hashLandStatement`: the eighteen V6
/// words (the fifteen V5 words, then the stored forced inclusion head, the batch's head after and
/// its fee recipient, `LandInput.feeRecipient` as an address word) under the V7 domain, then the
/// [`participation_hash`] of `parts`.
pub fn preimage(
    snapshot: &LandingSnapshot,
    input: &LandInput,
    parts: &[EpochParticipation],
    reference_hash: B256,
    blob_hashes: &[B256],
) -> [u8; PREIMAGE_BYTES] {
    let mut tag = [0u8; 32];
    tag[..b"TAIKO_ETNA_LAND_V7".len()].copy_from_slice(b"TAIKO_ETNA_LAND_V7");
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
        participation_hash(parts).0,
    ];
    let mut out = [0; PREIMAGE_BYTES];
    for (word, target) in words.iter().zip(out.chunks_exact_mut(32)) {
        target.copy_from_slice(word);
    }
    out
}

/// Compute the V7 job identity from coherent state, immutable outputs, the batch's participation
/// and ordered blobs.
pub fn hash(
    snapshot: &LandingSnapshot,
    input: &LandInput,
    parts: &[EpochParticipation],
    reference_hash: B256,
    blob_hashes: &[B256],
) -> B256 {
    keccak256(preimage(snapshot, input, parts, reference_hash, blob_hashes))
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::{
        contracts::IEtnaInbox::CommitteeMember,
        test_utils::{protocol::request, vectors},
    };
    use alloy_primitives::{address, aliases::U48, b256};

    /// The shared `land_statement` inputs (`testdata/etna_vectors`; the V5 inputs plus forced
    /// inclusion heads 3 (stored) and 5 (input) and fee recipient `0x…aa`), whose configuration
    /// hash is the shared `committee_config` vector, and one participation part: epoch 16,
    /// committee hash `0x…55`, counts `[3, 0, 7]`.
    fn vector() -> (LandingSnapshot, LandInput, Vec<EpochParticipation>, B256, Vec<B256>) {
        let input = |name: &str| format!("/land_statement/inputs/{name}");
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
            feeRecipient: vectors::address_at(&input("fee_recipient")),
        };
        let parts = vec![EpochParticipation {
            epoch: 16,
            committeeHash: B256::from(U256::from(0x55)),
            signedCounts: vec![3, 0, 7],
        }];
        (
            snapshot,
            land,
            parts,
            vectors::b256_at(&input("l1_reference_block_hash")),
            vectors::b256s_at(&input("blob_hashes")),
        )
    }

    /// The vector the contracts pin (`test_hashLandStatement_MatchesTheV7Vector` in
    /// `EtnaInboxLand.t.sol`), computed independently there with `cast abi-encode` and
    /// `cast keccak` over the nineteen words and the participation array. Under the V6 domain
    /// its first eighteen words are the shared V6 vector.
    #[test]
    fn v7_vector_matches_solidity() {
        let (snapshot, input, parts, reference, hashes) = vector();
        assert_eq!(blob_hashes_hash(&hashes), vectors::b256_at("/land_statement/blob_hashes_hash"));
        assert_eq!(
            participation_hash(&parts),
            b256!("c62a675c336fef9bf36145cc651d75a91dfd94fdd252f5ae7fe36c66e0db4d21")
        );
        assert_eq!(
            participation_hash(&[]),
            b256!("569e75fc77c1a856f6daaf9e69d8a9566ca34aa47f9133711ce065a571af0cfd"),
            "keccak256(abi.encode(uint256(32), uint256(0)))"
        );
        let preimage = preimage(&snapshot, &input, &parts, reference, &hashes);
        assert_eq!(preimage.len(), 608);
        assert_eq!(
            hash(&snapshot, &input, &parts, reference, &hashes),
            b256!("5daa726c9fd7ef3d3e70eb787228cd9ebbf53ce00ba261714f7b0efd10c370ab")
        );
        assert_eq!(&preimage[..18], b"TAIKO_ETNA_LAND_V7");
        assert_eq!(preimage[15 * 32..16 * 32], U256::from(3).to_be_bytes::<32>());
        assert_eq!(preimage[16 * 32..17 * 32], U256::from(5).to_be_bytes::<32>());
        assert_eq!(preimage[17 * 32..17 * 32 + 12], [0; 12]);
        assert_eq!(preimage[17 * 32 + 12..18 * 32], input.feeRecipient.0);
        assert_eq!(preimage[18 * 32..], participation_hash(&parts).0, "the appended last word");
        // Under the V6 domain, the first eighteen words are the shared V6 vector.
        let mut v6 = preimage;
        v6[b"TAIKO_ETNA_LAND_V7".len() - 1] = b'6';
        assert_eq!(&v6[..18 * 32], vectors::bytes_at("/land_statement/preimage").as_ref());
        assert_eq!(keccak256(&v6[..18 * 32]), vectors::b256_at("/land_statement/hash"));
        // Under the V5 domain, the first fifteen words are the V5 encoding of the same inputs.
        let mut v5 = preimage;
        v5[b"TAIKO_ETNA_LAND_V7".len() - 1] = b'5';
        assert_eq!(
            keccak256(&v5[..15 * 32]),
            b256!("43533fd98016f831c0f94ce56cf0b8e1480a275e07a0fbf22ce0f23a5fb9c4d7")
        );
    }

    #[test]
    fn every_v7_word_mutation_changes_the_hash() {
        let (snapshot, input, parts, reference, hashes) = vector();
        let preimage = preimage(&snapshot, &input, &parts, reference, &hashes);
        assert_eq!(PREIMAGE_BYTES, 19 * 32);
        let expected = keccak256(preimage);
        for word in 0..19 {
            let mut changed = preimage;
            changed[word * 32 + 31] ^= 1;
            assert_ne!(keccak256(changed), expected, "word {word}");
        }
        let mut v6 = preimage;
        v6[b"TAIKO_ETNA_LAND_V7".len() - 1] = b'6';
        assert_ne!(keccak256(v6), expected, "old domain cannot share job identity");
    }

    #[test]
    fn every_statement_input_is_bound_and_blob_order_matters() {
        let (snapshot, input, parts, reference, hashes) = vector();
        let expected = hash(&snapshot, &input, &parts, reference, &hashes);
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
                hash(&changed, &input, &parts, reference, &hashes),
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
                hash(&snapshot, &changed, &parts, reference, &hashes),
                expected,
                "output field {field}"
            );
        }
        for field in 0..7 {
            let mut changed = parts.clone();
            match field {
                0 => changed[0].epoch += 1,
                1 => changed[0].committeeHash = B256::ZERO,
                2 => changed[0].signedCounts[1] = 1,
                3 => changed[0].signedCounts.push(0),
                4 => changed[0].signedCounts.reverse(),
                5 => changed.push(changed[0].clone()),
                6 => changed.clear(),
                _ => unreachable!(),
            }
            assert_ne!(
                hash(&snapshot, &input, &changed, reference, &hashes),
                expected,
                "participation field {field}"
            );
        }
        assert_ne!(hash(&snapshot, &input, &parts, B256::ZERO, &hashes), expected);
        let reversed = hashes.iter().rev().copied().collect::<Vec<_>>();
        assert_ne!(hash(&snapshot, &input, &parts, reference, &reversed), expected);
        let mut swapped = (snapshot.clone(), input.clone());
        swapped.0.forced_inclusion_head = input.forcedInclusionHead.to();
        swapped.1.forcedInclusionHead = U48::from(snapshot.forced_inclusion_head);
        assert_ne!(
            hash(&swapped.0, &swapped.1, &parts, reference, &hashes),
            expected,
            "head before and after are ordered"
        );
    }

    /// The selectors and one complete call are pinned with `cast sig` and
    /// `cast keccak $(cast calldata 'land(…)' …)` over the same values.
    #[test]
    fn land_selector_matches_the_v7_abi() {
        use crate::contracts::IEtnaInbox::{hashLandStatementCall, landCall};
        use alloy::sol_types::SolCall;
        assert_eq!(
            landCall::SIGNATURE,
            "land((uint64,bytes32,bytes32,uint64,uint48,address),(uint64,bytes32,uint32[])[],\
             (uint32,uint64,uint256)[][],bytes)"
        );
        assert_eq!(landCall::SELECTOR, keccak256(landCall::SIGNATURE)[..4]);
        assert_eq!(landCall::SELECTOR, [0xb0, 0x05, 0x70, 0x1e]);
        assert_eq!(
            hashLandStatementCall::SIGNATURE,
            "hashLandStatement(uint64,uint64,bytes32,uint48,\
             (uint64,bytes32,bytes32,uint64,uint48,address),(uint64,bytes32,uint32[])[],bytes32,\
             bytes32[])"
        );
        assert_eq!(hashLandStatementCall::SELECTOR, [0x8a, 0xde, 0xe3, 0x39]);

        let (_, input, parts, _, _) = vector();
        let settlements = vec![vec![
            CommitteeMember {
                bondId: 3,
                activeFromL1: 11,
                effStake: U256::from(5_000_000_000_000_000_000u64),
            },
            CommitteeMember { bondId: 0, activeFromL1: 1, effStake: U256::from(1) },
        ]];
        let call = landCall {
            _input: input.clone(),
            _participation: parts.clone(),
            _settlements: settlements.clone(),
            _proof: alloy_primitives::Bytes::from_static(&[0]),
        };
        let calldata = call.abi_encode();
        assert_eq!(calldata.len(), 4 + 29 * 32);
        assert_eq!(
            keccak256(&calldata),
            b256!("384c25b3c13291b0a12a7a0c103bca37c5aee54f6ec9fdad12ba352d16e64bff")
        );
        let decoded = landCall::abi_decode(&calldata).unwrap();
        assert_eq!(decoded._input, input);
        assert_eq!(decoded._participation, parts);
        assert_eq!(decoded._settlements, settlements);
        assert_eq!(decoded._proof.as_ref(), &[0]);
    }
}
