//! Genuine deterministic native secp256k1eth certificates used by consensus tests.

use abci::{
    ChainParams, ChainParamsExt, EtnaEnvelope, ExecutionBlock, fallback::FallbackKeys,
    key::ConsensusKey,
};
pub use alloy::signers::k256::ecdsa::SigningKey;
use alloy_consensus::Header;
use alloy_primitives::B256;
use prost::Message;
use sha2::{Digest, Sha256};
use tendermint::{
    AppHash, Hash, Time, Vote,
    block::{Id, header::Version},
    vote::{CanonicalVote, Type},
};
use tendermint_proto::{Protobuf, v0_38::types::CanonicalVote as RawVote};

use crate::{
    committee::Validators,
    native::{Block, Commit, CommitSig, RawBlock},
    types::CertifiedBlock,
    validate::{block_parts, commit_hash},
};

/// Locally chosen proposer beneficiary, independent of consensus signing identity.
pub const BATCH_RECIPIENT: alloy_primitives::Address = alloy_primitives::Address::repeat_byte(0x77);

pub fn parameters() -> ChainParams {
    let mut params = ChainParams::builtin(167001).unwrap();
    params.inbox = alloy_primitives::Address::repeat_byte(0x11);
    params.unsettled_limit = 65532;
    params
}

/// A fixture's signing set: its keys with their powers, and the validator set they sign as.
#[derive(Clone, Debug)]
pub struct FixtureCommittee {
    /// The keys with their powers, in key order.
    pub members: Vec<(ConsensusKey, u64)>,
    /// The members' CometBFT validator set.
    pub validators: Validators,
}

impl FixtureCommittee {
    /// The keys `members` with their powers and the validator set they sign as.
    pub fn new(members: Vec<(ConsensusKey, u64)>) -> Self {
        let validators = Validators::from_powers(&members).unwrap();
        Self { members, validators }
    }

    /// The set of the fallback key list `keys`: each key at power 1, as a generation's origin
    /// keys sign its first blocks.
    pub fn fallback(keys: &FallbackKeys) -> Self {
        Self::new(keys.validator_set())
    }
}

/// The fallback key list of the public keys of `keys`, in ascending order.
pub fn fallback_keys(keys: &[SigningKey]) -> FallbackKeys {
    let mut keys: Vec<_> = keys.iter().map(public_key).collect();
    keys.sort();
    FallbackKeys::new(keys).unwrap()
}

/// A signing set of one member per power, keyed by domain-separated full-width indices.
pub fn committee(powers: &[u64]) -> (ChainParams, FixtureCommittee, Vec<SigningKey>) {
    let keys = powers
        .iter()
        .enumerate()
        .map(|(i, _)| {
            let index = u64::try_from(i).unwrap();
            let seed = Sha256::new()
                .chain_update(b"etna-lander-test-member")
                .chain_update(index.to_be_bytes())
                .finalize();
            SigningKey::from_bytes(&seed).unwrap()
        })
        .collect::<Vec<_>>();
    committee_with_keys(powers, keys)
}

/// Reproduce the fixed one-byte seeds of the checked-in stock-Go differential vectors.
/// This bounded fixture convention is separate from the general full-width member builder.
pub fn stock_go_committee(powers: &[u64]) -> (ChainParams, FixtureCommittee, Vec<SigningKey>) {
    assert!(powers.len() <= usize::from(u8::MAX), "stock-Go fixture seed range");
    let keys = (1..=powers.len())
        .map(|index| SigningKey::from_slice(&[u8::try_from(index).unwrap(); 32]).unwrap())
        .collect();
    committee_with_keys(powers, keys)
}

/// Build the same signing set for either deterministic test-key convention: the key of each
/// power, in key order.
fn committee_with_keys(
    powers: &[u64],
    keys: Vec<SigningKey>,
) -> (ChainParams, FixtureCommittee, Vec<SigningKey>) {
    let mut members =
        keys.iter().zip(powers).map(|(key, power)| (public_key(key), *power)).collect::<Vec<_>>();
    members.sort_by_key(|(key, _)| *key);
    (parameters(), FixtureCommittee::new(members), keys)
}

/// Canonical native identity corresponding to a deterministic fixture signer.
pub fn public_key(key: &SigningKey) -> ConsensusKey {
    ConsensusKey::from_slice(key.verifying_key().to_encoded_point(true).as_bytes()).unwrap()
}
/// Stock low-S recoverable signature; no Ethereum personal-message prefix is applied.
pub fn sign(key: &SigningKey, bytes: &[u8]) -> crate::native::Signature {
    let (signature, recovery) =
        key.sign_prehash_recoverable(alloy_primitives::keccak256(bytes).as_slice()).unwrap();
    let mut bytes = signature.to_bytes().to_vec();
    bytes.push(recovery.to_byte());
    bytes.try_into().unwrap()
}

pub fn merkle(items: &[Vec<u8>]) -> Hash {
    Hash::Sha256(tendermint::merkle::simple_hash_from_byte_vectors::<
        tendermint::crypto::default::Sha256,
    >(items))
}

/// Builds Go's protobuf shape for synthetic, evidence-free fixtures.
pub fn raw_block(block: &Block) -> RawBlock {
    let mut raw = RawBlock {
        header: Some(block.header.clone().into()),
        data: Some(tendermint_proto::v0_38::types::Data { txs: block.data.clone() }),
        evidence: Some(crate::native::EvidenceList { evidence: vec![] }),
        last_commit: block.last_commit.clone().map(Into::into),
    };
    if block.last_commit.is_none() {
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
    committee: &FixtureCommittee,
    keys: &[SigningKey],
    previous: Option<&CertifiedBlock>,
) -> CertifiedBlock {
    let envelope = EtnaEnvelope {
        block: ExecutionBlock {
            header: Header {
                number: height,
                parent_hash: parent,
                beneficiary: BATCH_RECIPIENT,
                base_fee_per_gas: Some(7),
                gas_used: 21_000,
                ommers_hash: alloy_consensus::EMPTY_OMMER_ROOT_HASH,
                withdrawals_root: Some(alloy_consensus::EMPTY_ROOT_HASH),
                blob_gas_used: Some(0),
                excess_blob_gas: Some(0),
                parent_beacon_block_root: Some(B256::repeat_byte(9)),
                requests_hash: Some(alloy_eips::eip7685::EMPTY_REQUESTS_HASH),
                ..Default::default()
            },
            transactions: vec![],
        },
        anchor: None,
        forced: None,
    };
    pair_with_envelope(envelope, committee, keys, previous)
}

pub fn pair_with_envelope(
    envelope: EtnaEnvelope,
    committee: &FixtureCommittee,
    keys: &[SigningKey],
    previous: Option<&CertifiedBlock>,
) -> CertifiedBlock {
    let height = envelope.block.header.number;
    let time = Time::from_unix_timestamp(100 + i64::try_from(height).unwrap(), 0).unwrap();
    timed_pair(envelope, committee, keys, previous.map(|p| &p.commit), time, time, None)
}

/// Construct one stock-format native block, with a separately specified precommit time.
pub fn timed_pair(
    envelope: EtnaEnvelope,
    committee: &FixtureCommittee,
    keys: &[SigningKey],
    previous: Option<&Commit>,
    time: Time,
    vote_time: Time,
    last_results_hash: Option<Hash>,
) -> CertifiedBlock {
    let height = envelope.block.header.number;
    let parent = envelope.block.header.parent_hash;
    let data = vec![envelope.encode().to_vec()];
    let header = tendermint::block::Header {
        version: Version { block: 11, app: 1 },
        chain_id: "etna-rFfVfgyjbP1zElufI3Hsqar8zT_q-s2n_fB74bWyvP4".parse().unwrap(),
        height: height.try_into().unwrap(),
        time,
        last_block_id: previous.map(|commit| commit.block_id),
        last_commit_hash: Some(previous.map(commit_hash).unwrap_or_else(|| merkle(&[]))),
        data_hash: Some(merkle(
            &data.iter().map(|tx| Sha256::digest(tx).to_vec()).collect::<Vec<_>>(),
        )),
        validators_hash: committee.validators.hash(),
        next_validators_hash: committee.validators.hash(),
        consensus_hash: Hash::Sha256(abci::genesis::GenesisConsensusParams::etna_hash().0),
        // appHash of the parent's EL hash (CONS-3.1-8), never the bare hash. These blocks carry
        // no validator-state replica, so its hash is a zero placeholder; fixtures that need the
        // real one replace it.
        app_hash: AppHash::try_from(abci::valstate::app_hash(parent, B256::ZERO).to_vec()).unwrap(),
        last_results_hash,
        evidence_hash: Some(merkle(&[])),
        proposer_address: committee.validators.validators()[0].address,
    };
    let block = Block { header, data, last_commit: previous.cloned() };
    let raw = raw_block(&block);
    let parts = block_parts(&raw);
    let commit = Commit {
        height: block.header.height,
        round: 0u16.into(),
        block_id: Id { hash: block.header.hash(), part_set_header: parts },
        signatures: vec![],
    };
    let mut pair = CertifiedBlock::from_raw(raw, commit).unwrap();
    resign_at(&mut pair, committee, keys, vote_time);
    pair
}

pub fn resign(pair: &mut CertifiedBlock, committee: &FixtureCommittee, keys: &[SigningKey]) {
    resign_at(pair, committee, keys, pair.block.header.time)
}

pub fn resign_at(
    pair: &mut CertifiedBlock,
    committee: &FixtureCommittee,
    keys: &[SigningKey],
    timestamp: Time,
) {
    let raw = raw_block(&pair.block);
    pair.raw_block = raw.encode_to_vec().into();
    pair.commit.block_id.part_set_header = block_parts(&raw);
    pair.commit.block_id.hash = pair.block.header.hash();
    sign_commit(&mut pair.commit, &pair.block.header.chain_id, committee, keys, timestamp);
}

/// Sign a source certificate, including a retained boundary's modeled predecessor.
pub fn sign_commit(
    commit: &mut Commit,
    chain: &tendermint::chain::Id,
    committee: &FixtureCommittee,
    keys: &[SigningKey],
    timestamp: Time,
) {
    let public_keys = keys.iter().map(public_key).collect::<Vec<_>>();
    commit.signatures = committee
        .validators
        .validators()
        .iter()
        .enumerate()
        .map(|(index, validator)| {
            let key = &keys[public_keys.iter().position(|key| *key == validator.pub_key).unwrap()];
            let vote = Vote {
                vote_type: Type::Precommit,
                height: commit.height,
                round: commit.round,
                block_id: Some(commit.block_id),
                timestamp: Some(timestamp),
                validator_address: validator.address,
                validator_index: u32::try_from(index).unwrap().try_into().unwrap(),
                signature: None,
                extension: vec![],
                extension_signature: None,
            };
            let bytes = Protobuf::<RawVote>::encode_length_delimited_vec(CanonicalVote::new(
                vote,
                chain.clone(),
            ));
            CommitSig::BlockIdFlagCommit {
                validator_address: validator.address,
                timestamp,
                signature: Some(sign(key, &bytes)),
            }
        })
        .collect();
}

pub fn nil_vote(
    pair: &CertifiedBlock,
    committee: &FixtureCommittee,
    keys: &[SigningKey],
    index: usize,
) -> CommitSig {
    let validator = &committee.validators.validators()[index];
    let key = keys.iter().find(|key| public_key(key) == validator.pub_key).unwrap();
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
        signature: Some(sign(key, &bytes)),
    }
}
