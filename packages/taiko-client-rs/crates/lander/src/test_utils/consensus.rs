//! Genuine deterministic native secp256k1eth certificates used by consensus tests.

use abci::{
    AccountWitness, AnchorState, ChainParams, CommitteeRecord, CommitteeState, CommitteeWitness,
    EtnaEnvelope, ExecutionBlock, InboxFacts, Member, RegistryEntry,
    committee::{record_hash, set_key, set_root},
    key::ConsensusKey,
};
pub use alloy::signers::k256::ecdsa::SigningKey;
use alloy_consensus::Header;
use alloy_primitives::{B256, U256};
use prost::Message;
use sha2::{Digest, Sha256};
use tendermint::{
    AppHash, Hash, Time, Vote,
    block::{Id, header::Version},
    vote::{CanonicalVote, Type},
};
use tendermint_proto::{Protobuf, v0_38::types::CanonicalVote as RawVote};

use crate::{
    committee::{AuthenticatedCommittee, authenticate},
    native::{Block, Commit, CommitSig, RawBlock},
    types::CertifiedBlock,
    validate::{block_parts, commit_hash},
};

/// Locally chosen proposer beneficiary, independent of consensus signing identity.
pub const BATCH_RECIPIENT: alloy_primitives::Address = alloy_primitives::Address::repeat_byte(0x77);

pub fn parameters() -> ChainParams {
    let mut params = ChainParams::builtin(167001).unwrap();
    params.inbox = alloy_primitives::Address::repeat_byte(0x11);
    params.registry = alloy_primitives::Address::repeat_byte(0x22);
    params.vp_unit = U256::from(1_000_000_000);
    params.s_min = params.vp_unit;
    params.unsettled_limit = 65532;
    params
}

/// A committee of one member per power, keyed by domain-separated full-width indices, with
/// registry entries in index order (bond id = index), active from L1 block 1 and staking
/// their power, preserving the authenticated registry stake for epoch derivation.
pub fn committee(
    powers: &[u64],
    epoch: u64,
) -> (ChainParams, AuthenticatedCommittee, Vec<SigningKey>) {
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
    committee_with_keys(powers, epoch, keys, false)
}

/// Reproduce the fixed one-byte seeds of the checked-in stock-Go differential vectors.
/// This bounded fixture convention is separate from the general full-width member builder.
pub fn stock_go_committee(
    powers: &[u64],
    epoch: u64,
) -> (ChainParams, AuthenticatedCommittee, Vec<SigningKey>) {
    assert!(powers.len() <= usize::from(u8::MAX), "stock-Go fixture seed range");
    let keys = (1..=powers.len())
        .map(|index| SigningKey::from_slice(&[u8::try_from(index).unwrap(); 32]).unwrap())
        .collect();
    committee_with_keys(powers, epoch, keys, true)
}

/// Build the same authenticated member structure for either deterministic test-key convention.
fn committee_with_keys(
    powers: &[u64],
    epoch: u64,
    keys: Vec<SigningKey>,
    _stock_go: bool,
) -> (ChainParams, AuthenticatedCommittee, Vec<SigningKey>) {
    let mut params = parameters();
    params.n_max = params.n_max.max(powers.len());
    let mut members = keys
        .iter()
        .zip(powers)
        .map(|(key, power)| Member {
            pubkey: public_key(key),
            eff_stake: U256::from(*power) * params.vp_unit,
            power: *power,
        })
        .collect::<Vec<_>>();
    members.sort_by_key(|member| set_key(params.l2_chain_id, member.pubkey));
    let record = CommitteeRecord {
        target_epoch: epoch,
        cutoff_l1_block: 1,
        checkpoint_index: 0,
        set_root: set_root(params.l2_chain_id, epoch + 1, &members),
        total_power: powers.iter().sum(),
    };
    let hash = record_hash(params.l2_chain_id, &record);
    let entries = keys
        .iter()
        .zip(powers)
        .map(|(key, power)| RegistryEntry {
            ck_prefix: public_key(key).prefix(),
            ck_x: public_key(key).x(),
            eff_stake: U256::from(*power) * params.vp_unit,
            active_from_l1: 1,
            exit_effective_l1: u64::MAX,
        })
        .collect();
    let registry = AccountWitness {
        address: params.registry,
        nonce: 0,
        balance: U256::ZERO,
        storage_root: B256::ZERO,
        code_hash: B256::ZERO,
        account_proof: vec![],
        storage: vec![],
    };
    let anchor = AnchorState {
        number: 1,
        hash: B256::repeat_byte(1),
        state_root: B256::repeat_byte(2),
        timestamp: 1,
        inbox: InboxFacts {
            recovery_generation: 0,
            last_checkpoint_height: 0,
            last_checkpoint_hash: B256::ZERO,
            forced_inclusion_head: 0,
            forced_inclusion_tail: 0,
        },
    };
    let mut committee =
        authenticate(CommitteeState { record: record.clone(), members }, epoch, hash, &params)
            .unwrap();
    committee.provenance = Some(crate::types::CommitteeContext {
        anchor,
        derivation_parent: None,
        witness: CommitteeWitness { record, registry, entries },
    });
    (params, committee, keys)
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
        version: Version { block: 11, app: 1 },
        chain_id: "etna-rFfVfgyjbP1zElufI3Hsqar8zT_q-s2n_fB74bWyvP4".parse().unwrap(),
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
    let block = Block { header, data, last_commit: previous.map(|pair| pair.commit.clone()) };
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
            let key = keys.iter().find(|key| public_key(key) == validator.pub_key).unwrap();
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
                signature: Some(sign(key, &bytes)),
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
