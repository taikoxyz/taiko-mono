//! Exact V1 ABI encoding binding chain state, the deployment's configuration hash and cut leaves.

use crate::{contracts::IEtnaInbox::LandInput, types::LandingSnapshot};
use alloy_primitives::{B256, U256, keccak256};

/// Byte length of the static nineteen-word public statement preimage.
pub(crate) const PREIMAGE_BYTES: usize = 19 * 32;

/// Hash Solidity's packed ordered bytes32 blob list, with no array offset or length words.
pub fn blob_hashes_hash(hashes: &[B256]) -> B256 {
    keccak256(hashes.iter().flat_map(|h| h.as_slice()).copied().collect::<Vec<_>>())
}

/// Commit one height's execution/consensus identity and consumed FI cursor (appendix A's
/// `cutLeaf`: four words).
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

/// V1 ordered commitment to the leaves of every height strictly inside the immutable proof
/// interval (p, h) (ENC-A-30..32); an empty list (h = p + 1) hashes as keccak256("").
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

/// Encode the nineteen static ABI words authenticated by the Inbox V1 statement, in order: the
/// tag, l1ChainId, l2ChainId, inbox, generation, parentHeight, parentHash, parentCometHash,
/// configHash, lastHeight, lastBlockHash, lastCometHash, lastStateRoot, l1ReferenceBlockNumber,
/// l1ReferenceBlockHash, the packed blob hashes' hash, the forced inclusion heads before and
/// after, and cutHash. The parent words are the checkpoint record's values as stored, even at a
/// generation's origin. They are taken at proof origin p: `snapshot` is the one the batch was
/// built on, so its `checkpoint_*` fields are p's, not the latest checkpoint c's at execution.
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
    let words = [
        tag,
        snapshot.l1_chain_id.to_be_bytes::<32>(),
        U256::from(snapshot.l2_chain_id).to_be_bytes::<32>(),
        inbox,
        U256::from(snapshot.generation).to_be_bytes::<32>(),
        input.parentHeight.to_be_bytes::<32>(),
        snapshot.checkpoint_hash.0,
        snapshot.checkpoint_comet_hash.0,
        snapshot.config_hash.0,
        input.lastHeight.to_be_bytes::<32>(),
        input.lastBlockHash.0,
        input.lastCometHash.0,
        input.lastStateRoot.0,
        input.l1ReferenceBlockNumber.to_be_bytes::<32>(),
        reference_hash.0,
        blob_hashes_hash(blob_hashes).0,
        U256::from(snapshot.forced_inclusion_head).to_be_bytes::<32>(),
        input.forcedInclusionHead.to_be_bytes::<32>(),
        cut_hash(snapshot.generation, input.parentHeight, input.lastHeight, leaves).0,
    ];
    let mut out = [0; PREIMAGE_BYTES];
    for (word, target) in words.iter().zip(out.as_chunks_mut::<32>().0.iter_mut()) {
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
    use alloy_primitives::b256;

    /// The configuration hash of the devnet's built-in L2 chain id, `EtnaStaking` proxy and U,
    /// the one the pinned statements bind.
    const DEVNET_CONFIG_HASH: B256 =
        b256!("ce98efd6a337c78d7b268a407f9cd0dbfeee0e8724f07bc924087437497b4650");

    /// The hashes of the pinned statements, in vector order, under the nineteen-word encoding.
    const STATEMENT_HASHES: [B256; 2] = [
        b256!("8a0f8fe6072214c4f2aa16338aca44d834982d61d8255b37c91d88cf2b9a5ec9"),
        b256!("d33539cefca32052bc3bb80d1650b7f4727e09307a50b3f76e8d086c50eacbcb"),
    ];

    /// The pinned statement `index`: its snapshot, seven-field input, reference hash and blob
    /// hashes, bound to [`DEVNET_CONFIG_HASH`].
    fn vector(index: usize) -> (LandingSnapshot, LandInput, B256, Vec<B256>) {
        let path = |key: &str| format!("/land_statements/{index}/inputs/{key}");
        let mut snapshot = request().batch.snapshot;
        snapshot.l1_chain_id = vectors::u256_at(&path("l1_chain_id"));
        snapshot.l2_chain_id = vectors::u64_at(&path("l2_chain_id"));
        snapshot.inbox = vectors::address_at(&path("inbox"));
        snapshot.generation = vectors::u64_at(&path("generation"));
        snapshot.checkpoint_height = vectors::u64_at(&path("parent_height"));
        snapshot.checkpoint_hash = vectors::b256_at(&path("parent_hash"));
        snapshot.checkpoint_comet_hash = vectors::b256_at(&path("parent_comet_hash"));
        snapshot.config_hash = DEVNET_CONFIG_HASH;
        snapshot.forced_inclusion_head = vectors::u64_at(&path("forced_inclusion_head_before"));
        let input = LandInput {
            parentHeight: vectors::u256_at(&path("parent_height")),
            lastHeight: vectors::u256_at(&path("last_height")),
            lastBlockHash: vectors::b256_at(&path("last_block_hash")),
            lastCometHash: vectors::b256_at(&path("last_comet_hash")),
            lastStateRoot: vectors::b256_at(&path("last_state_root")),
            l1ReferenceBlockNumber: vectors::u256_at(&path("l1_reference_block_number")),
            forcedInclusionHead: vectors::u256_at(&path("forced_inclusion_head_after")),
        };
        (
            snapshot,
            input,
            vectors::b256_at(&path("l1_reference_block_hash")),
            vectors::b256s_at(&path("blob_hashes")),
        )
    }

    /// The leaves of every height strictly inside the statement's (p, h), from the shared cut
    /// table, whose entry `x` is height `x`'s.
    fn leaves(index: usize) -> Vec<B256> {
        let path = |key: &str| format!("/land_statements/{index}/inputs/{key}");
        (vectors::u64_at(&path("parent_height")) + 1..vectors::u64_at(&path("last_height")))
            .map(|height| {
                assert_eq!(vectors::u64_at(&format!("/cuts/table/{height}/height")), height);
                vectors::b256_at(&format!("/cuts/table/{height}/leaf"))
            })
            .collect()
    }

    /// The statement preimage is 19 static ABI words, 608 bytes: the tag, l1ChainId, l2ChainId,
    /// inbox, generation, parentHeight, parentHash, parentCometHash, configHash, lastHeight,
    /// lastBlockHash, lastCometHash, lastStateRoot, l1ReferenceBlockNumber,
    /// l1ReferenceBlockHash, the packed blob hashes' hash, the forced inclusion heads before and
    /// after, and cutHash, in that order, with no staking word. Each pinned statement's cut hash
    /// covers one leaf per height strictly inside (p, h).
    #[test]
    fn statement_is_19_words() {
        assert_eq!(PREIMAGE_BYTES, 608);
        assert_eq!(
            DEVNET_CONFIG_HASH,
            <abci::ChainParams as abci::ChainParamsExt>::builtin(167001).unwrap().config_hash(),
            "the devnet's built-in chain id, staking proxy and U"
        );
        assert_eq!(vectors::len_at("/land_statements"), STATEMENT_HASHES.len());
        for (index, expected_hash) in STATEMENT_HASHES.into_iter().enumerate() {
            let path = |key: &str| format!("/land_statements/{index}/inputs/{key}");
            let (snapshot, input, reference, blobs) = vector(index);
            let leaves = leaves(index);
            assert_eq!(
                leaves.len() as u64,
                vectors::u64_at(&path("last_height")) - vectors::u64_at(&path("parent_height")) - 1
            );
            let cut = cut_hash(snapshot.generation, input.parentHeight, input.lastHeight, &leaves);
            assert_eq!(cut, vectors::b256_at(&path("cut_hash")));
            let number = |key: &str| vectors::u256_at(&path(key)).to_be_bytes::<32>();
            let hash_word = |key: &str| vectors::b256_at(&path(key)).0;
            let mut tag = [0u8; 32];
            tag[..b"TAIKO_ETNA_LAND_V1".len()].copy_from_slice(b"TAIKO_ETNA_LAND_V1");
            let expected = [
                tag,
                number("l1_chain_id"),
                number("l2_chain_id"),
                vectors::address_at(&path("inbox")).into_word().0,
                number("generation"),
                number("parent_height"),
                hash_word("parent_hash"),
                hash_word("parent_comet_hash"),
                DEVNET_CONFIG_HASH.0,
                number("last_height"),
                hash_word("last_block_hash"),
                hash_word("last_comet_hash"),
                hash_word("last_state_root"),
                number("l1_reference_block_number"),
                hash_word("l1_reference_block_hash"),
                vectors::b256_at(&format!("/land_statements/{index}/blob_hashes_hash")).0,
                number("forced_inclusion_head_before"),
                number("forced_inclusion_head_after"),
                cut.0,
            ]
            .concat();
            assert_eq!(expected.len(), 19 * 32);
            let encoded = preimage(&snapshot, &input, reference, &blobs, &leaves);
            assert_eq!(encoded.len(), 19 * 32);
            assert_eq!(encoded.as_slice(), expected.as_slice(), "statement {index}");
            assert_eq!(hash(&snapshot, &input, reference, &blobs, &leaves), expected_hash);
            assert_eq!(keccak256(&expected), expected_hash);
            assert_eq!(
                blob_hashes_hash(&blobs),
                vectors::b256_at(&format!("/land_statements/{index}/blob_hashes_hash"))
            );
        }
    }

    /// Review focus 1, ENC-A-31/32: a landing of one block (h = p+1) has no leaves, its cut hash
    /// hashes the empty list as keccak256(""), and the lander builds and binds it.
    #[tokio::test]
    async fn single_block_batch_has_no_leaves() {
        use crate::{
            batch::{BatchBuilder, BatchBuilderConfig, BatchSource},
            test_utils::consensus_mpt::{Fixture, MAX_BATCH_BLOCKS},
            types::{Limits, SidecarMode},
        };
        use std::sync::Arc;
        // The shared single-block vector (p = 17, h = 18).
        let single = (0..vectors::len_at("/cuts/cut_hashes"))
            .find(|index| {
                let at =
                    |field: &str| vectors::u64_at(&format!("/cuts/cut_hashes/{index}/{field}"));
                at("last_height") == at("parent_height") + 1
            })
            .expect("a single-block cut hash vector");
        let path = |field: &str| format!("/cuts/cut_hashes/{single}/{field}");
        assert!(vectors::b256s_at(&path("leaves")).is_empty());
        assert_eq!(vectors::b256_at(&path("leaves_hash")), keccak256([]));
        assert_eq!(
            cut_hash(
                vectors::u64_at(&path("generation")),
                vectors::u256_at(&path("parent_height")),
                vectors::u256_at(&path("last_height")),
                &[]
            ),
            vectors::b256_at(&path("cut_hash"))
        );
        // The lander lands exactly one decided block above a checkpoint off the old grid.
        let fixture = Arc::new(Fixture::new(7, 8));
        let builder = BatchBuilder::new(
            fixture.clone(),
            fixture.clone(),
            BatchBuilderConfig {
                params: fixture.params.clone(),
                limits: Limits {
                    max_blocks: 8,
                    max_blobs: 2,
                    max_payload_bytes: 240_000,
                    max_message_bytes: 200_000,
                    max_decompressed_bytes: 2_000_000,
                },
                mode: SidecarMode::Eip4844,
                engine: Arc::new(test_harness::unavailable_engine::UnavailableEngine),
                engine_timeout: std::time::Duration::from_secs(1),
                max_batch_blocks: MAX_BATCH_BLOCKS,
            },
        )
        .unwrap();
        let batch =
            builder.prepare(fixture.snapshot.clone()).await.unwrap().expect("one block").batch;
        assert_eq!(batch.input.parentHeight, U256::from(7));
        assert_eq!(batch.input.lastHeight, U256::from(8));
        assert_eq!(batch.blocks.len(), 1);
        assert!(batch.leaves.is_empty());
        let mut tag = [0u8; 32];
        tag[..b"ETNA_LAND_CUTS_V1".len()].copy_from_slice(b"ETNA_LAND_CUTS_V1");
        let expected = keccak256(
            [
                tag,
                U256::from(batch.snapshot.generation).to_be_bytes::<32>(),
                U256::from(7).to_be_bytes::<32>(),
                U256::from(8).to_be_bytes::<32>(),
                keccak256([]).0,
            ]
            .concat(),
        );
        let reference =
            abci::RawL1Header::from_raw(batch.reference_headers[0].clone()).unwrap().hash();
        let encoded = preimage(
            &batch.snapshot,
            &batch.input,
            reference,
            &batch.blobs.versioned_hashes,
            &batch.leaves,
        );
        assert_eq!(&encoded[PREIMAGE_BYTES - 32..], expected.as_slice());
        assert_eq!(keccak256(encoded), batch.statement_hash);
        batch.verify_restored().unwrap();
    }

    /// Review focus 2, ENC-A-34: a competing landing that moves c to p+1, a height never on the
    /// old grid, is checked against leaf index c-p-1 = 0, the leaf of p+1 the lander built from
    /// that block's EL hash, Comet hash and forced inclusion cursor.
    #[tokio::test]
    async fn leaf_index_after_competitor_at_p_plus_1() {
        use crate::{
            batch::{BatchBuilder, BatchBuilderConfig, BatchSource},
            test_utils::consensus_mpt::{Fixture, MAX_BATCH_BLOCKS},
            types::{Limits, SidecarMode},
        };
        use std::sync::Arc;
        let fixture = Arc::new(Fixture::new(0, 12));
        let builder = BatchBuilder::new(
            fixture.clone(),
            fixture.clone(),
            BatchBuilderConfig {
                params: fixture.params.clone(),
                limits: Limits {
                    max_blocks: 12,
                    max_blobs: 2,
                    max_payload_bytes: 240_000,
                    max_message_bytes: 200_000,
                    max_decompressed_bytes: 2_000_000,
                },
                mode: SidecarMode::Eip4844,
                engine: Arc::new(test_harness::unavailable_engine::UnavailableEngine),
                engine_timeout: std::time::Duration::from_secs(1),
                max_batch_blocks: MAX_BATCH_BLOCKS,
            },
        )
        .unwrap();
        let batch = builder.prepare(fixture.snapshot.clone()).await.unwrap().unwrap().batch;
        let (p, h) = (0u64, 12u64);
        assert_eq!(batch.input.parentHeight, U256::from(p));
        assert_eq!(batch.input.lastHeight, U256::from(h));
        assert_eq!(batch.leaves.len() as u64, h - p - 1);
        let c = p + 1;
        // keccak256(abi.encode(x, blockHash(x), cometHash(x), forcedHead(x))), four words; no
        // forced inclusion entry exists, so every cursor is 0.
        let leaf = |x: u64| {
            keccak256(
                [
                    U256::from(x).to_be_bytes::<32>(),
                    fixture.headers[&x].hash_slow().0,
                    fixture.blocks[&x].block.header.hash().as_bytes().try_into().unwrap(),
                    [0; 32],
                ]
                .concat(),
            )
        };
        assert_eq!(batch.leaves[(c - p - 1) as usize], leaf(c));
        for (index, x) in (p + 1..h).enumerate() {
            assert_eq!(batch.leaves[index], leaf(x), "leaf of height {x}");
        }
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
                    vectors::u64_at(&path("forced_head")),
                ),
                vectors::b256_at(&path("leaf"))
            );
            assert_eq!(vectors::bytes_at(&path("preimage")).len(), 4 * 32);
        }
    }
    #[test]
    fn cut_hashes_match_independent_empty_long_and_nonzero_start_vectors() {
        for index in 0..vectors::len_at("/cuts/cut_hashes") {
            let path = |field: &str| format!("/cuts/cut_hashes/{index}/{field}");
            let leaves = vectors::b256s_at(&path("leaves"));
            assert_eq!(blob_hashes_hash(&leaves), vectors::b256_at(&path("leaves_hash")));
            assert_eq!(
                cut_hash(
                    vectors::u64_at(&path("generation")),
                    vectors::u256_at(&path("parent_height")),
                    vectors::u256_at(&path("last_height")),
                    &leaves
                ),
                vectors::b256_at(&path("cut_hash")),
                "{}",
                vectors::str_at(&path("name")),
            );
        }
    }

    /// Every one of the 19 words after the tag takes its value from its own input, so changing
    /// any one input changes exactly its word and the hash, and reordering the blobs changes the
    /// hash.
    #[test]
    fn every_static_word_and_blob_order_is_bound() {
        let (snapshot, input, reference, blobs) = vector(1);
        let encoded = preimage(&snapshot, &input, reference, &blobs, &leaves(1));
        for word in 1..19 {
            let mut snapshot = snapshot.clone();
            let mut input = input.clone();
            let mut reference = reference;
            let mut blobs = blobs.clone();
            let mut cuts = leaves(1);
            match word {
                1 => snapshot.l1_chain_id ^= U256::from(1) << 200,
                2 => snapshot.l2_chain_id ^= 1,
                3 => snapshot.inbox[0] ^= 1,
                4 => snapshot.generation ^= 1,
                5 => input.parentHeight ^= U256::from(1),
                6 => snapshot.checkpoint_hash[0] ^= 1,
                7 => snapshot.checkpoint_comet_hash[0] ^= 1,
                8 => snapshot.config_hash[0] ^= 1,
                9 => input.lastHeight ^= U256::from(1),
                10 => input.lastBlockHash[0] ^= 1,
                11 => input.lastCometHash[0] ^= 1,
                12 => input.lastStateRoot[0] ^= 1,
                13 => input.l1ReferenceBlockNumber ^= U256::from(1),
                14 => reference[0] ^= 1,
                15 => blobs[0][0] ^= 1,
                16 => snapshot.forced_inclusion_head ^= 1,
                17 => input.forcedInclusionHead ^= U256::from(1),
                18 => cuts[0][0] ^= 1,
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

    /// `land(LandInput, bytes32[], bytes)` takes the seven named fields and no others: the
    /// calldata is the selector, the seven input words in field order, the two offsets, then the
    /// leaves and the proof, and it decodes back to the same call.
    #[test]
    fn seven_field_abi_matches_complete_calldata() {
        use crate::contracts::IEtnaInbox::landCall;
        use alloy::sol_types::SolValue;
        assert_eq!(vectors::str_at("/land_abi/statement"), "nonzero");
        let (_, input, _, _) = vector(1);
        let leaves = vectors::b256s_at("/land_abi/leaves");
        let proof = vectors::bytes_at("/land_abi/proof");
        assert_eq!(
            landCall::SIGNATURE,
            "land((uint256,uint256,bytes32,bytes32,bytes32,uint256,uint256),bytes32[],bytes)"
        );
        assert_eq!(landCall::SELECTOR, [0x51, 0x85, 0xfd, 0x7a]);
        let fields = [
            input.parentHeight.to_be_bytes::<32>(),
            input.lastHeight.to_be_bytes::<32>(),
            input.lastBlockHash.0,
            input.lastCometHash.0,
            input.lastStateRoot.0,
            input.l1ReferenceBlockNumber.to_be_bytes::<32>(),
            input.forcedInclusionHead.to_be_bytes::<32>(),
        ];
        assert_eq!(input.abi_encode(), fields.concat());
        assert_eq!(input.abi_encode().len(), 7 * 32);
        let word = |value: usize| U256::from(value).to_be_bytes::<32>();
        let leaves_offset = 9 * 32;
        let proof_offset = leaves_offset + 32 * (1 + leaves.len());
        let mut expected = landCall::SELECTOR.to_vec();
        expected.extend(fields.concat());
        expected.extend(word(leaves_offset));
        expected.extend(word(proof_offset));
        expected.extend(word(leaves.len()));
        expected.extend(leaves.iter().flat_map(|leaf| leaf.0));
        expected.extend(word(proof.len()));
        expected.extend(proof.iter());
        expected.resize(4 + (expected.len() - 4).div_ceil(32) * 32, 0);
        let call = landCall { _input: input, _leaves: leaves, _proof: proof };
        assert_eq!(call.abi_encode(), expected);
        assert_eq!(landCall::abi_decode(&expected).unwrap(), call);
    }
}
