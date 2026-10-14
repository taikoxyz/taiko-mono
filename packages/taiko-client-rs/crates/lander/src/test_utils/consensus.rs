//! Genuine deterministic Ed25519 certificates used by consensus tests.

use abci::{
    ChainParams, CommitteeRecord, CommitteeState, EtnaEnvelope, ExecutionBlock, Member,
    committee::{mem08_key, mem08_root, record_hash},
};
use alloy_consensus::Header;
use alloy_primitives::{B256, U256};
use ed25519_dalek::{Signer, SigningKey};
use prost::Message;
use sha2::{Digest, Sha256};
use tendermint::{
    AppHash, Block, Hash, Time, Vote,
    block::{Commit, CommitSig, Id, header::Version},
    vote::{CanonicalVote, Type},
};
use tendermint_proto::{
    Protobuf,
    v0_38::types::{Block as RawBlock, CanonicalVote as RawVote},
};

use crate::{
    committee::{AuthenticatedCommittee, authenticate},
    types::CertifiedBlock,
    validate::{block_parts, commit_hash},
};

pub fn parameters() -> ChainParams {
    let mut params = ChainParams::builtin(167001).unwrap();
    params.vp_unit = U256::from(1);
    params.s_min = U256::from(1);
    params.d_max = 0;
    params.margin_v = 0;
    params
}

pub fn committee(
    powers: &[u64],
    epoch: u64,
) -> (ChainParams, AuthenticatedCommittee, Vec<SigningKey>) {
    let params = parameters();
    let keys = powers
        .iter()
        .enumerate()
        .map(|(i, _)| SigningKey::from_bytes(&[u8::try_from(i + 1).unwrap(); 32]))
        .collect::<Vec<_>>();
    let mut members = keys
        .iter()
        .zip(powers)
        .map(|(key, power)| Member {
            pubkey: B256::from(key.verifying_key().to_bytes()),
            eff_stake: U256::from(*power),
            power: *power,
        })
        .collect::<Vec<_>>();
    members.sort_by_key(|member| mem08_key(params.l2_chain_id, member.pubkey));
    let record = CommitteeRecord {
        target_epoch: epoch,
        cutoff_l1_block: 1,
        checkpoint_index: 0,
        set_root: mem08_root(params.l2_chain_id, epoch + 1, &members),
        total_stake: members.iter().map(|member| member.eff_stake).sum(),
        total_power: powers.iter().sum(),
        encoding_version: 1,
    };
    let hash = record_hash(params.l2_chain_id, &record);
    (
        params.clone(),
        authenticate(CommitteeState { record, members }, epoch, hash, &params).unwrap(),
        keys,
    )
}

pub fn merkle(items: &[Vec<u8>]) -> Hash {
    Hash::Sha256(tendermint::merkle::simple_hash_from_byte_vectors::<
        tendermint::crypto::default::Sha256,
    >(items))
}

/// Builds Go's protobuf shape for synthetic, evidence-free fixtures.
pub fn raw_block(block: &Block) -> RawBlock {
    assert!(block.evidence.as_ref().is_empty());
    let mut raw = RawBlock::from(block.clone());
    if block.header.height.value() == 1 {
        raw.last_commit = Some(Commit::default().into());
        raw.header.as_mut().unwrap().last_block_id =
            Some(tendermint_proto::v0_38::types::BlockId {
                hash: Vec::new(),
                part_set_header: Some(Default::default()),
            });
    }
    raw
}

pub fn pair(
    height: u64,
    parent: B256,
    committee: &AuthenticatedCommittee,
    keys: &[SigningKey],
    previous: Option<&CertifiedBlock>,
) -> CertifiedBlock {
    let envelope = EtnaEnvelope {
        block: ExecutionBlock {
            header: Header { number: height, parent_hash: parent, ..Default::default() },
            transactions: vec![],
        },
        anchor: None,
        committee: None,
        forced: None,
    };
    pair_with_envelope(envelope, committee, keys, previous)
}

pub fn pair_with_envelope(
    envelope: EtnaEnvelope,
    committee: &AuthenticatedCommittee,
    keys: &[SigningKey],
    previous: Option<&CertifiedBlock>,
) -> CertifiedBlock {
    let height = envelope.block.header.number;
    let parent = envelope.block.header.parent_hash;
    let data = vec![envelope.encode().to_vec()];
    let header = tendermint::block::Header {
        version: Version { block: 11, app: 0 },
        chain_id: "taiko-etna-167001-g0".parse().unwrap(),
        height: height.try_into().unwrap(),
        time: Time::from_unix_timestamp(100 + i64::try_from(height).unwrap(), 0).unwrap(),
        last_block_id: previous.map(|pair| pair.commit.block_id),
        last_commit_hash: Some(
            previous.map(|pair| commit_hash(&pair.commit)).unwrap_or_else(|| merkle(&[])),
        ),
        data_hash: Some(merkle(
            &data.iter().map(|tx| Sha256::digest(tx).to_vec()).collect::<Vec<_>>(),
        )),
        validators_hash: committee.validators.hash(),
        next_validators_hash: committee.validators.hash(),
        consensus_hash: Hash::Sha256([2; 32]),
        app_hash: AppHash::try_from(parent.to_vec()).unwrap(),
        last_results_hash: None,
        evidence_hash: Some(merkle(&[])),
        proposer_address: committee.validators.validators()[0].address,
    };
    let block =
        Block::new(header, data, Default::default(), previous.map(|pair| pair.commit.clone()));
    let raw = raw_block(&block);
    let parts = block_parts(&raw);
    let commit = Commit {
        height: block.header.height,
        round: 0u16.into(),
        block_id: Id { hash: block.header.hash(), part_set_header: parts },
        signatures: vec![],
    };
    let mut pair = CertifiedBlock::from_raw(raw, commit).unwrap();
    resign(&mut pair, committee, keys);
    pair
}

pub fn resign(pair: &mut CertifiedBlock, committee: &AuthenticatedCommittee, keys: &[SigningKey]) {
    let raw = raw_block(&pair.block);
    pair.raw_block = raw.encode_to_vec().into();
    pair.commit.block_id.part_set_header = block_parts(&raw);
    pair.commit.block_id.hash = pair.block.header.hash();
    pair.commit.signatures = committee
        .validators
        .validators()
        .iter()
        .enumerate()
        .map(|(index, validator)| {
            let key = keys
                .iter()
                .find(|key| {
                    key.verifying_key().as_bytes().as_slice() == validator.pub_key.to_bytes()
                })
                .unwrap();
            let timestamp = pair.block.header.time;
            let vote = Vote {
                vote_type: Type::Precommit,
                height: pair.commit.height,
                round: pair.commit.round,
                block_id: Some(pair.commit.block_id),
                timestamp: Some(timestamp),
                validator_address: validator.address,
                validator_index: u32::try_from(index).unwrap().try_into().unwrap(),
                signature: None,
                extension: vec![],
                extension_signature: None,
            };
            let bytes = Protobuf::<RawVote>::encode_length_delimited_vec(CanonicalVote::new(
                vote,
                pair.block.header.chain_id.clone(),
            ));
            CommitSig::BlockIdFlagCommit {
                validator_address: validator.address,
                timestamp,
                signature: Some(key.sign(&bytes).to_bytes().to_vec().try_into().unwrap()),
            }
        })
        .collect();
}

pub fn nil_vote(
    pair: &CertifiedBlock,
    committee: &AuthenticatedCommittee,
    keys: &[SigningKey],
    index: usize,
) -> CommitSig {
    let validator = &committee.validators.validators()[index];
    let key = keys
        .iter()
        .find(|key| key.verifying_key().as_bytes().as_slice() == validator.pub_key.to_bytes())
        .unwrap();
    let timestamp = pair.block.header.time;
    let vote = Vote {
        vote_type: Type::Precommit,
        height: pair.commit.height,
        round: pair.commit.round,
        block_id: None,
        timestamp: Some(timestamp),
        validator_address: validator.address,
        validator_index: u32::try_from(index).unwrap().try_into().unwrap(),
        signature: None,
        extension: vec![],
        extension_signature: None,
    };
    let bytes = Protobuf::<RawVote>::encode_length_delimited_vec(CanonicalVote::new(
        vote,
        pair.block.header.chain_id.clone(),
    ));
    CommitSig::BlockIdFlagNil {
        validator_address: validator.address,
        timestamp,
        signature: Some(key.sign(&bytes).to_bytes().to_vec().try_into().unwrap()),
    }
}
