//! Public native Comet verification boundary regressions.
use alloy_primitives::{U256, hex};
use etna_core::{comet::validators::Validators, key::ConsensusKey, types::Member};

fn member(power: u64) -> Member {
    Member {
        pubkey: ConsensusKey::from_slice(&hex!(
            "0279be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798"
        ))
        .unwrap(),
        eff_stake: U256::ZERO,
        power,
    }
}

#[test]
fn public_validator_slots_reject_unchecked_power_and_duplicate_authority() {
    assert!(Validators::from_members(&[]).is_err());
    assert!(Validators::from_members(&[member(0)]).is_err());
    assert!(Validators::from_members(&[member(u64::MAX)]).is_err());
    assert!(Validators::from_members(&[member(1), member(1)]).is_err());
    let valid = Validators::from_members(&[member(1)]).unwrap();
    assert_eq!(valid.total_voting_power(), 1);
}

use alloy_primitives::{B256, keccak256};
use etna_core::comet::{
    codec::{checked_block_proto, decode_canonical_block, decode_canonical_commit},
    native::{Block, Commit, CommitSig, RawBlock, RawCommit, RawCommitSig},
    verify::{
        CertifiedBlockRef, block_parts, commit_hash, verify_body_at_origin, verify_native_commit,
        verify_structure_at_origin,
    },
};
use k256::ecdsa::SigningKey;
use prost::Message;
use tendermint::{
    Hash, Vote,
    vote::{CanonicalVote, Type},
};
use tendermint_proto::{Protobuf, v0_38::types::CanonicalVote as RawVote};

fn fixtures() -> Vec<serde_json::Value> {
    [
        include_str!("../testdata/cometbft-v0.40/vectors.json"),
        include_str!("../testdata/cometbft-v0.40/differential.json"),
    ]
    .into_iter()
    .flat_map(|s| {
        serde_json::from_str::<serde_json::Value>(s).unwrap()["vectors"].as_array().unwrap().clone()
    })
    .collect()
}
fn bytes(v: &serde_json::Value) -> Vec<u8> {
    alloy_primitives::hex::decode(v.as_str().unwrap()).unwrap()
}
fn fixture(v: &serde_json::Value) -> (Vec<u8>, Block, Commit, Validators, Vec<SigningKey>) {
    let raw = bytes(&v["block_proto"]);
    let (_, block) = decode_canonical_block(&raw).unwrap();
    let commit = if v["commit_proto"].is_string() {
        decode_canonical_commit(&bytes(&v["commit_proto"])).unwrap()
    } else {
        serde_json::from_value(v["commit_rpc"]["signed_header"]["commit"].clone()).unwrap()
    };
    let powers: Vec<u64> =
        v["powers"].as_str().unwrap_or("10,30").split(',').map(|s| s.parse().unwrap()).collect();
    let keys: Vec<_> = (1..=powers.len())
        .map(|i| SigningKey::from_slice(&[u8::try_from(i).unwrap(); 32]).unwrap())
        .collect();
    let members: Vec<_> = keys
        .iter()
        .zip(powers)
        .map(|(key, power)| Member {
            pubkey: ConsensusKey::from_slice(key.verifying_key().to_encoded_point(true).as_bytes())
                .unwrap(),
            power,
            eff_stake: U256::ZERO,
        })
        .collect();
    (raw, block, commit, Validators::from_members(&members).unwrap(), keys)
}
fn view<'a>(raw: &'a [u8], block: &'a Block, commit: &'a Commit) -> CertifiedBlockRef<'a> {
    CertifiedBlockRef { raw_block: raw, block, commit }
}
fn sign(
    commit: &Commit,
    block: &Block,
    validators: &Validators,
    keys: &[SigningKey],
    index: usize,
    nil: bool,
) -> CommitSig {
    let validator = &validators.validators()[index];
    let timestamp = block.header.time;
    let vote = Vote {
        vote_type: Type::Precommit,
        height: commit.height,
        round: commit.round,
        block_id: (!nil).then_some(commit.block_id),
        timestamp: Some(timestamp),
        validator_address: validator.address,
        validator_index: u32::try_from(index).unwrap().try_into().unwrap(),
        signature: None,
        extension: vec![],
        extension_signature: None,
    };
    let message = Protobuf::<RawVote>::encode_length_delimited_vec(CanonicalVote::new(
        vote,
        block.header.chain_id.clone(),
    ));
    let key = keys
        .iter()
        .find(|k| {
            k.verifying_key().to_encoded_point(true).as_bytes() == validator.pub_key.as_bytes()
        })
        .unwrap();
    let (sig, recovery) = key.sign_prehash_recoverable(keccak256(message).as_slice()).unwrap();
    let signature =
        Some([sig.to_bytes().as_slice(), &[recovery.to_byte()]].concat().try_into().unwrap());
    if nil {
        CommitSig::BlockIdFlagNil { validator_address: validator.address, timestamp, signature }
    } else {
        CommitSig::BlockIdFlagCommit { validator_address: validator.address, timestamp, signature }
    }
}
fn resign(commit: &mut Commit, block: &Block, validators: &Validators, keys: &[SigningKey]) {
    commit.height = block.header.height;
    commit.block_id.hash = etna_core::comet::verify::header_hash(&block.header);
    commit.signatures = (0..validators.validators().len())
        .map(|i| sign(commit, block, validators, keys, i, false))
        .collect();
}

#[test]
fn offline_stock_go_vectors_preserve_wire_qc_body_and_foreign_evidence() {
    for v in fixtures() {
        let (raw, block, commit, validators, _) = fixture(&v);
        let name = v["name"].as_str().unwrap();
        let proto = checked_block_proto(&raw, &block).unwrap();
        assert_eq!(proto.encode_to_vec(), raw, "{name}");
        let restored =
            decode_canonical_commit(&RawCommit::from(commit.clone()).encode_to_vec()).unwrap();
        assert_eq!(restored, commit, "{name}");
        let qc = verify_native_commit(
            &commit,
            &block.header,
            &validators,
            block.header.chain_id.as_str(),
        );
        assert_eq!(
            qc.is_ok(),
            block.header.version.app == etna_core::comet::APP_VERSION,
            "{name}: {qc:?}"
        );
        assert_eq!(block_parts(&proto).unwrap(), commit.block_id.part_set_header, "{name}");
        assert_eq!(
            block.header.evidence_hash.unwrap().as_bytes(),
            bytes(&v["evidence_hash"]),
            "{name}"
        );
        let tx = verify_body_at_origin(
            view(&raw, &block, &commit),
            block.header.height.value(),
            B256::ZERO,
            0,
        )
        .unwrap_or_else(|e| panic!("{name}: {e}"));
        assert_eq!(tx, block.data[0], "{name}");
    }
}

#[test]
fn canonical_codecs_reject_unknown_fields_mutated_projection_and_absent_shape() {
    let (raw, mut block, commit, _, _) = fixture(&fixtures()[0]);
    block.data[0].push(1);
    assert!(checked_block_proto(&raw, &block).is_err());
    let mut noncanonical = raw;
    noncanonical.extend_from_slice(&[0xf8, 0x07, 1]);
    assert!(decode_canonical_block(&noncanonical).is_err());
    let mut noncanonical = RawCommit::from(commit.clone()).encode_to_vec();
    noncanonical.extend_from_slice(&[0xf8, 0x07, 1]);
    assert!(decode_canonical_commit(&noncanonical).is_err());
    let mut malformed = RawCommit::from(commit);
    malformed.signatures[0] = RawCommitSig { block_id_flag: 1, ..Default::default() };
    assert!(decode_canonical_commit(&malformed.encode_to_vec()).is_err());
}

#[test]
fn native_qc_checks_full_parts_validator_hash_and_late_nil_signatures() {
    let (raw, block, mut commit, validators, keys) = fixture(&fixtures()[0]);
    resign(&mut commit, &block, &validators, &keys);
    for total in [false, true] {
        let mut changed = commit.clone();
        if total {
            changed.block_id.part_set_header.total += 1;
        } else {
            changed.block_id.part_set_header.hash = Hash::Sha256([8; 32]);
        }
        assert!(
            verify_native_commit(
                &changed,
                &block.header,
                &validators,
                block.header.chain_id.as_str()
            )
            .is_err()
        );
        assert!(verify_body_at_origin(view(&raw, &block, &changed), 1, B256::ZERO, 0).is_err());
    }
    let mut header = block.header.clone();
    header.validators_hash = Hash::Sha256([9; 32]);
    let mut changed_block = block.clone();
    changed_block.header = header;
    let mut changed = commit.clone();
    resign(&mut changed, &changed_block, &validators, &keys);
    assert!(
        verify_native_commit(
            &changed,
            &changed_block.header,
            &validators,
            block.header.chain_id.as_str()
        )
        .is_err()
    );
    commit.signatures[1] = sign(&commit, &block, &validators, &keys, 1, true);
    verify_native_commit(&commit, &block.header, &validators, block.header.chain_id.as_str())
        .unwrap();
    if let CommitSig::BlockIdFlagNil { signature, .. } = &mut commit.signatures[1] {
        *signature = Some(vec![0; 65].try_into().unwrap());
    }
    assert!(
        verify_native_commit(&commit, &block.header, &validators, block.header.chain_id.as_str())
            .is_err()
    );
}

fn rebind_block(
    raw: &mut RawBlock,
    block: &Block,
    commit: &mut Commit,
    validators: &Validators,
    keys: &[SigningKey],
) -> Vec<u8> {
    raw.header = Some(block.header.clone().into());
    raw.last_commit = Some(block.last_commit.clone().unwrap_or_default().into());
    commit.block_id.part_set_header = block_parts(raw).unwrap();
    resign(commit, block, validators, keys);
    raw.encode_to_vec()
}

#[test]
fn empty_ancestry_is_authorized_only_at_checked_nonzero_origin_plus_one() {
    let (raw, mut block, mut commit, validators, keys) = fixture(&fixtures()[0]);
    let mut proto = RawBlock::decode(raw.as_slice()).unwrap();
    block.header.height = 42u32.into();
    let raw = rebind_block(&mut proto, &block, &mut commit, &validators, &keys);
    let first = view(&raw, &block, &commit);
    assert_eq!(verify_body_at_origin(first, 42, B256::ZERO, 41).unwrap(), block.data[0]);
    assert!(verify_structure_at_origin(first, None, 42, B256::ZERO, 41).is_ok());
    for wrong_origin in [0, 42, u64::MAX] {
        assert!(verify_body_at_origin(first, 42, B256::ZERO, wrong_origin).is_err());
        assert!(verify_structure_at_origin(first, None, 42, B256::ZERO, wrong_origin).is_err());
    }

    block.header.last_block_id = Some(commit.block_id);
    let raw = rebind_block(&mut proto, &block, &mut commit, &validators, &keys);
    let first = view(&raw, &block, &commit);
    assert!(verify_body_at_origin(first, 42, B256::ZERO, 41).is_err());
    assert!(verify_structure_at_origin(first, None, 42, B256::ZERO, 41).is_err());
}

#[test]
fn nonempty_ancestry_requires_a_successor_after_generation_start() {
    let (raw, mut previous_block, mut previous_commit, validators, keys) = fixture(&fixtures()[0]);
    let mut proto = RawBlock::decode(raw.as_slice()).unwrap();
    previous_block.header.height = 42u32.into();
    let previous_raw =
        rebind_block(&mut proto, &previous_block, &mut previous_commit, &validators, &keys);
    let previous = view(&previous_raw, &previous_block, &previous_commit);

    let mut block = previous_block.clone();
    block.header.height = 43u32.into();
    block.header.last_block_id = Some(previous_commit.block_id);
    block.header.last_commit_hash = Some(commit_hash(&previous_commit));
    block.last_commit = Some(previous_commit.clone());
    let mut commit = previous_commit.clone();
    let raw = rebind_block(&mut proto, &block, &mut commit, &validators, &keys);
    let successor = view(&raw, &block, &commit);

    assert!(verify_body_at_origin(successor, 43, B256::ZERO, 41).is_ok());
    assert!(verify_structure_at_origin(successor, Some(previous), 43, B256::ZERO, 41).is_ok());
    assert!(verify_structure_at_origin(successor, None, 43, B256::ZERO, 41).is_err());

    let mut mismatched = previous_commit.clone();
    mismatched.block_id.part_set_header.total += 1;
    let wrong_previous = view(&previous_raw, &previous_block, &mismatched);
    assert!(
        verify_structure_at_origin(successor, Some(wrong_previous), 43, B256::ZERO, 41).is_err()
    );

    for wrong_origin in [42, 43, u64::MAX] {
        let body = verify_body_at_origin(successor, 43, B256::ZERO, wrong_origin);
        let structure =
            verify_structure_at_origin(successor, Some(previous), 43, B256::ZERO, wrong_origin);
        assert!(
            body.is_err() && structure.is_err(),
            "origin {wrong_origin} accepted nonempty ancestry: body={}, structure={}",
            body.is_ok(),
            structure.is_ok(),
        );
    }
}

#[test]
fn part_sets_use_exact_65536_byte_boundary_and_empty_input_is_typed_error() {
    assert!(block_parts(&RawBlock::default()).is_err());
    for (length, count) in [(65535, 1), (65536, 1), (65537, 2)] {
        let mut raw = RawBlock {
            data: Some(tendermint_proto::v0_38::types::Data { txs: vec![vec![1; length - 8]] }),
            ..Default::default()
        };
        while raw.encoded_len() != length {
            let size = raw.data.as_ref().unwrap().txs[0].len();
            let next = if raw.encoded_len() < length { size + 1 } else { size - 1 };
            raw.data.as_mut().unwrap().txs[0].resize(next, 1);
        }
        let header = block_parts(&raw).unwrap();
        assert_eq!(header.total, count);
        let chunks = raw.encode_to_vec().chunks(65536).map(<[u8]>::to_vec).collect::<Vec<_>>();
        assert_eq!(
            header.hash,
            Hash::Sha256(tendermint::merkle::simple_hash_from_byte_vectors::<sha2::Sha256>(
                &chunks
            ))
        );
    }
}

#[test]
fn native_quorum_is_strictly_power_weighted_and_nil_votes_never_add_power() {
    let (_, mut block, mut commit, _, keys) = fixture(&fixtures()[0]);
    let make = |power, key: &SigningKey| Member {
        pubkey: ConsensusKey::from_slice(key.verifying_key().to_encoded_point(true).as_bytes())
            .unwrap(),
        power,
        eff_stake: U256::ZERO,
    };
    let validators = Validators::from_members(&[make(20, &keys[0]), make(10, &keys[1])]).unwrap();
    block.header.validators_hash = validators.hash();
    resign(&mut commit, &block, &validators, &keys);
    verify_native_commit(&commit, &block.header, &validators, block.header.chain_id.as_str())
        .unwrap();
    commit.signatures[1] = CommitSig::BlockIdFlagAbsent;
    assert!(
        verify_native_commit(&commit, &block.header, &validators, block.header.chain_id.as_str())
            .is_err(),
        "exactly 2/3 must fail"
    );
    commit.signatures[1] = sign(&commit, &block, &validators, &keys, 1, true);
    assert!(
        verify_native_commit(&commit, &block.header, &validators, block.header.chain_id.as_str())
            .is_err(),
        "nil adds zero block power"
    );
    let max = etna_core::committee::MAX_TOTAL_POWER;
    assert!(Validators::from_members(&[make(max, &keys[0]), make(1, &keys[1])]).is_err());
    assert!(Validators::from_members(&[make(max + 1, &keys[0])]).is_err());
}

#[test]
fn body_enforces_single_transaction_before_any_envelope_interpretation() {
    let (raw, mut block, mut commit, _, _) = fixture(&fixtures()[0]);
    let original = RawBlock::decode(raw.as_slice()).unwrap();
    for txs in [vec![], vec![vec![1], vec![2]]] {
        let mut proto = original.clone();
        block.data = txs.clone();
        block.header.data_hash = Some(etna_core::comet::verify::data_hash(&txs));
        proto.header = Some(block.header.clone().into());
        proto.data = Some(tendermint_proto::v0_38::types::Data { txs });
        let raw = proto.encode_to_vec();
        commit.block_id.part_set_header = block_parts(&proto).unwrap();
        assert!(matches!(
            verify_body_at_origin(view(&raw, &block, &commit), 1, B256::ZERO, 0),
            Err(etna_core::comet::verify::BftError::TransactionCount(_))
        ));
    }
}
