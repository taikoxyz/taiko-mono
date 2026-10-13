//! Pure certificate, CometBFT body-commitment and Etna envelope validation.

use std::collections::BTreeSet;

use abci::{
    AnchorState, ChainParams, CommitteeState, EtnaEnvelope, ParentInfo, Schedule,
    committee::verify_committee_witness,
    l1::{layout::inbox, witness::verify_anchor_witness},
    rules::{self, GenerationCheck, HeaderInputs},
};
use alloy_primitives::B256;
use ed25519_dalek::{Signature, VerifyingKey};
use prost::Message;
use sha2::{Digest, Sha256};
use tendermint::{
    Hash, Vote,
    block::{Commit, CommitSig},
    vote::{CanonicalVote, Type},
};
use tendermint_proto::{
    Protobuf,
    v0_38::types::{CanonicalVote as RawVote, CommitSig as RawCommitSig, Evidence as RawEvidence},
};

use crate::{committee::AuthenticatedCommittee, types::CertifiedBlock};

/// A certificate or block is inconsistent with authenticated consensus context.
#[derive(Debug, thiserror::Error)]
pub enum ValidationError {
    /// The source certificate is malformed or cannot authenticate the claimed block.
    #[error("invalid CometBFT certificate: {0}")]
    Certificate(String),
    /// One committed body hash disagrees with its contents.
    #[error("CometBFT {0} commitment mismatch")]
    Commitment(&'static str),
    /// An Etna envelope is malformed or violates witness/schedule/header rules.
    #[error("invalid Etna block: {0}")]
    Etna(String),
}

/// Validated execution and witness facts of one certified block.
#[derive(Clone, Debug)]
pub struct BlockFacts {
    /// Exact decoded envelope, without rewriting its transaction bytes.
    pub envelope: EtnaEnvelope,
    /// The block's own anchor, independently of a later landing reference.
    pub anchor: AnchorState,
    /// A newly derived target committee only at its H-2 switch height.
    pub derived: Option<CommitteeState>,
    /// Parent facts to consume when validating the next execution header.
    pub parent: ParentInfo,
}

/// Authenticates canonical precommits with distinct signers and strict `> 2/3` power.
///
/// The timestamp, round, block id, height and chain id all enter Tendermint's canonical
/// length-delimited vote sign bytes. Nil votes are verified but contribute no block power.
/// Absent slots contribute no power. Signatures must follow the authenticated validator order.
pub fn verify_commit(
    commit: &Commit,
    header: &tendermint::block::Header,
    committee: &AuthenticatedCommittee,
    chain_id: &str,
) -> Result<(), ValidationError> {
    if header.chain_id.as_str() != chain_id || commit.height != header.height {
        return Err(ValidationError::Certificate("chain id or commit height mismatch".into()));
    }
    if commit.block_id.hash != header.hash() ||
        commit.block_id.part_set_header.total == 0 ||
        commit.block_id.part_set_header.hash == Hash::None
    {
        return Err(ValidationError::Certificate(
            "commit block id mismatch or empty part set".into(),
        ));
    }
    if commit.signatures.len() != committee.validators.validators().len() {
        return Err(ValidationError::Certificate(
            "signature slots differ from validator count".into(),
        ));
    }
    if header.validators_hash != committee.validators.hash() {
        return Err(ValidationError::Commitment("validator set"));
    }
    let mut signed_power = 0u128;
    let mut seen = BTreeSet::new();
    for (index, (sig, validator)) in
        commit.signatures.iter().zip(committee.validators.validators()).enumerate()
    {
        let (address, timestamp, signature, is_commit) = match sig {
            CommitSig::BlockIdFlagAbsent => continue,
            CommitSig::BlockIdFlagCommit { validator_address, timestamp, signature } => {
                (*validator_address, *timestamp, signature.as_ref(), true)
            }
            CommitSig::BlockIdFlagNil { validator_address, timestamp, signature } => {
                (*validator_address, *timestamp, signature.as_ref(), false)
            }
        };
        if !seen.insert(address) || address != validator.address {
            return Err(ValidationError::Certificate(
                "duplicate signer or incorrect validator slot".into(),
            ));
        }
        let signature =
            signature.ok_or_else(|| ValidationError::Certificate("missing signature".into()))?;
        let vote = Vote {
            vote_type: Type::Precommit,
            height: commit.height,
            round: commit.round,
            block_id: is_commit.then_some(commit.block_id),
            timestamp: Some(timestamp),
            validator_address: address,
            validator_index: u32::try_from(index)
                .map_err(|_| ValidationError::Certificate("validator index overflow".into()))?
                .try_into()
                .map_err(|e| ValidationError::Certificate(format!("validator index: {e}")))?,
            signature: None,
            extension: Vec::new(),
            extension_signature: None,
        };
        let chain_id =
            chain_id.parse().map_err(|e| ValidationError::Certificate(format!("chain id: {e}")))?;
        let sign_bytes =
            Protobuf::<RawVote>::encode_length_delimited_vec(CanonicalVote::new(vote, chain_id));
        let raw_key = validator.pub_key.to_bytes();
        let key_bytes: &[u8; 32] = raw_key
            .as_slice()
            .try_into()
            .map_err(|_| ValidationError::Certificate("non-Ed25519 public key".into()))?;
        let key = VerifyingKey::from_bytes(key_bytes)
            .map_err(|e| ValidationError::Certificate(format!("Ed25519 key: {e}")))?;
        let signature = Signature::from_slice(signature.as_bytes())
            .map_err(|e| ValidationError::Certificate(format!("Ed25519 signature: {e}")))?;
        key.verify_strict(&sign_bytes, &signature)
            .map_err(|e| ValidationError::Certificate(format!("Ed25519 verification: {e}")))?;
        if is_commit {
            signed_power += u128::from(validator.power());
        }
    }
    let total = u128::from(committee.state.record.total_power);
    if signed_power * 3 <= total * 2 {
        return Err(ValidationError::Certificate(format!(
            "insufficient commit power {signed_power}/{total}; require strictly more than 2/3"
        )));
    }
    Ok(())
}

/// Tendermint's simple Merkle root of byte slices, including the SHA-256 empty root.
fn merkle(items: &[Vec<u8>]) -> Hash {
    Hash::Sha256(tendermint::merkle::simple_hash_from_byte_vectors::<
        tendermint::crypto::default::Sha256,
    >(items))
}

/// CometBFT `Data.Hash`: the simple Merkle root of the transactions' SHA-256 hashes.
pub fn data_hash(txs: &[Vec<u8>]) -> Hash {
    merkle(&txs.iter().map(|tx| Sha256::digest(tx).to_vec()).collect::<Vec<_>>())
}

/// Commit hash binds the signature protobufs, as CometBFT `Commit.Hash` does.
pub fn commit_hash(commit: &Commit) -> Hash {
    merkle(
        &commit
            .signatures
            .iter()
            .cloned()
            .map(|s| RawCommitSig::from(s).encode_to_vec())
            .collect::<Vec<_>>(),
    )
}

/// Stock CometBFT's 64-KiB block-part Merkle commitment.
///
/// Tendermint's domain adapter maps the initial empty commit to `None`. Go always includes
/// that non-nullable empty message and the header's empty last block id in `Block.ToProto`,
/// so restore both for the signed part set.
pub fn block_parts(block: &tendermint::Block) -> tendermint::block::parts::Header {
    let mut raw = tendermint_proto::v0_38::types::Block::from(block.clone());
    if block.header.height.value() == 1 {
        if block.last_commit.is_none() {
            raw.last_commit = Some(tendermint_proto::v0_38::types::Commit::from(Commit::default()));
        }
        if let Some(header) = raw.header.as_mut() &&
            header.last_block_id.is_none()
        {
            header.last_block_id = Some(tendermint_proto::v0_38::types::BlockId {
                hash: Vec::new(),
                part_set_header: Some(Default::default()),
            });
        }
    }
    let bytes = raw.encode_to_vec();
    let parts = bytes.chunks(65_536).map(<[u8]>::to_vec).collect::<Vec<_>>();
    tendermint::block::parts::Header::new(
        u32::try_from(parts.len()).expect("bounded block has at most u32::MAX parts"),
        merkle(&parts),
    )
    .expect("nonempty protobuf block yields a nonempty SHA-256 part set")
}

/// Recomputes every CometBFT body commitment and checks its decoded EL height/parent link.
///
/// This is also necessary for an already-landed checkpoint: a genuine certificate signs the
/// header's roots, not an arbitrary body an RPC response happens to return beside it.
pub fn verify_body(
    pair: &CertifiedBlock,
    expected_height: u64,
    parent_el_hash: B256,
) -> Result<EtnaEnvelope, ValidationError> {
    let block = &pair.block;
    if block.header.height.value() != expected_height {
        return Err(ValidationError::Certificate("requested block height mismatch".into()));
    }
    if block.header.data_hash != Some(data_hash(&block.data)) {
        return Err(ValidationError::Commitment("data"));
    }
    let evidence = block
        .evidence
        .iter()
        .cloned()
        .map(|e| RawEvidence::from(e).encode_to_vec())
        .collect::<Vec<_>>();
    if block.header.evidence_hash != Some(merkle(&evidence)) {
        return Err(ValidationError::Commitment("evidence"));
    }
    if pair.commit.block_id.part_set_header != block_parts(block) {
        return Err(ValidationError::Commitment("block part set"));
    }
    match &block.last_commit {
        None if expected_height == 1 => {
            if block.header.last_commit_hash != Some(merkle(&[])) ||
                block.header.last_block_id.is_some()
            {
                return Err(ValidationError::Commitment("genesis last commit"));
            }
        }
        Some(last) if expected_height > 1 => {
            if expected_height.checked_sub(1) != Some(last.height.value()) ||
                block.header.last_block_id != Some(last.block_id) ||
                block.header.last_commit_hash != Some(commit_hash(last))
            {
                return Err(ValidationError::Commitment("last commit"));
            }
        }
        _ => return Err(ValidationError::Commitment("missing last commit")),
    }
    if block.header.app_hash.as_bytes() != parent_el_hash.as_slice() {
        return Err(ValidationError::Commitment("parent execution app hash"));
    }
    let transactions =
        block.data.iter().cloned().map(alloy_primitives::Bytes::from).collect::<Vec<_>>();
    let envelope =
        abci::single_envelope(&transactions).map_err(|e| ValidationError::Etna(e.to_string()))?;
    let header = &envelope.block.header;
    if header.number != expected_height || header.parent_hash != parent_el_hash {
        return Err(ValidationError::Etna("execution height / parent hash mismatch".into()));
    }
    Ok(envelope)
}

/// Verifies one body's commitments plus its BFT ancestry against the preceding certificate.
///
/// A previous pair may be absent only at height one. Certificate verification remains a
/// separate operation using the independently authenticated epoch committee.
pub fn verify_structure(
    pair: &CertifiedBlock,
    previous: Option<&CertifiedBlock>,
    expected_height: u64,
    parent_el_hash: B256,
) -> Result<EtnaEnvelope, ValidationError> {
    let envelope = verify_body(pair, expected_height, parent_el_hash)?;
    match (&pair.block.last_commit, previous) {
        (None, None) if expected_height == 1 => {}
        (Some(last), Some(previous)) if last.block_id == previous.commit.block_id => {}
        _ => {
            return Err(ValidationError::Commitment("missing or conflicting previous block/commit"))
        }
    }
    Ok(envelope)
}

/// Immutable authenticated context for existing ABCI pure envelope rules.
#[derive(Clone, Copy, Debug)]
pub struct EnvelopeContext<'a> {
    /// Whole seconds of the CometBFT block timestamp.
    pub bft_time_secs: u64,
    /// Execution facts of the authenticated parent.
    pub parent: &'a ParentInfo,
    /// Exact historic anchor consumed by that parent.
    pub parent_anchor: &'a AnchorState,
    /// Authenticated recovery generation.
    pub generation: u64,
    /// Validated epoch schedule from the Inbox genesis record.
    pub schedule: &'a Schedule,
    /// Shared chain constants.
    pub params: &'a ChainParams,
}

/// Validates all existing ABCI pure rules using authenticated parent and chain context.
pub fn verify_envelope(
    envelope: EtnaEnvelope,
    context: EnvelopeContext<'_>,
) -> Result<BlockFacts, ValidationError> {
    let EnvelopeContext { bft_time_secs, parent, parent_anchor, generation, schedule, params } =
        context;
    let height = envelope.block.header.number;
    let (_, extra_generation, extra_anchor) =
        rules::decode_extra_data(&envelope.block.header.extra_data)
            .map_err(|e| ValidationError::Etna(e.to_string()))?;
    let switch = schedule.switch_target(height);
    let forced = height == 1;
    let anchor = match envelope.anchor.as_ref() {
        None if forced || extra_anchor != parent_anchor.number => {
            return Err(ValidationError::Etna("required anchor witness is missing".into()))
        }
        None => parent_anchor.clone(),
        Some(w) if !forced && w.l1_header.number() == parent_anchor.number => {
            return Err(ValidationError::Etna("unexpected unchanged anchor witness".into()))
        }
        Some(w) => verify_anchor_witness(w, params.inbox)
            .map_err(|e| ValidationError::Etna(e.to_string()))?,
    };
    rules::check_anchor_progress(parent_anchor.number, anchor.number, schedule, height)
        .map_err(|e| ValidationError::Etna(e.to_string()))?;
    let generation_check =
        rules::check_generation(generation, extra_generation, anchor.inbox.recovery_generation)
            .map_err(|e| ValidationError::Etna(e.to_string()))?;
    if generation_check != GenerationCheck::Ok || anchor.inbox.status != inbox::ETNA_ACTIVE {
        return Err(ValidationError::Etna("superseded generation or inactive Inbox".into()));
    }
    rules::check_back_pressure(height, anchor.inbox.last_checkpoint_height, params.unsettled_cap())
        .map_err(|e| ValidationError::Etna(e.to_string()))?;
    let derived = match (switch, envelope.committee.as_ref()) {
        (None, None) => None,
        (Some(target), Some(w)) => {
            let (record, members) =
                verify_committee_witness(parent_anchor, schedule, params, w, target)
                    .map_err(|e| ValidationError::Etna(e.to_string()))?;
            Some(CommitteeState { record, members })
        }
        _ => return Err(ValidationError::Etna("committee witness presence mismatch".into())),
    };
    let expected = rules::expected_header(&HeaderInputs {
        height,
        parent,
        anchor: &anchor,
        bft_time_secs,
        generation,
        params,
        min_base_fee: protocol::shasta::constants::min_base_fee_for_chain(params.l2_chain_id),
    })
    .map_err(|e| ValidationError::Etna(e.to_string()))?;
    rules::check_header(&envelope.block.header, &expected)
        .map_err(|e| ValidationError::Etna(e.to_string()))?;
    let header = &envelope.block.header;
    let next_parent = ParentInfo {
        number: height,
        hash: header.hash_slow(),
        timestamp: header.timestamp,
        gas_limit: header.gas_limit,
        gas_used: header.gas_used,
        base_fee: header
            .base_fee_per_gas
            .ok_or_else(|| ValidationError::Etna("missing base fee".into()))?,
        difficulty: header.difficulty,
        grandparent_timestamp: parent.timestamp,
    };
    Ok(BlockFacts { envelope, anchor, derived, parent: next_parent })
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::test_utils::consensus::{committee, nil_vote, pair};
    use tendermint::Time;

    #[test]
    fn real_canonical_ed25519_commits_require_strictly_more_than_two_thirds() {
        let (_, committee, keys) = committee(&[1, 1, 1], 0);
        let mut block = pair(1, B256::repeat_byte(9), &committee, &keys, None);
        verify_commit(&block.commit, &block.block.header, &committee, "taiko-etna-167001-g0")
            .unwrap();
        block.commit.signatures[2] = CommitSig::BlockIdFlagAbsent;
        assert!(
            verify_commit(&block.commit, &block.block.header, &committee, "taiko-etna-167001-g0")
                .is_err()
        );
    }

    #[test]
    fn weighted_quorum_absent_and_nil_votes_do_not_count() {
        let (_, committee, keys) = committee(&[3, 1], 0);
        let mut block = pair(1, B256::ZERO, &committee, &keys, None);
        block.commit.signatures[1] = CommitSig::BlockIdFlagAbsent;
        verify_commit(&block.commit, &block.block.header, &committee, "taiko-etna-167001-g0")
            .unwrap();
        let mut nil_block = pair(1, B256::ZERO, &committee, &keys, None);
        nil_block.commit.signatures[1] = nil_vote(&nil_block, &committee, &keys, 1);
        verify_commit(
            &nil_block.commit,
            &nil_block.block.header,
            &committee,
            "taiko-etna-167001-g0",
        )
        .unwrap();
        nil_block.commit.signatures[0] = nil_vote(&nil_block, &committee, &keys, 0);
        assert!(
            verify_commit(
                &nil_block.commit,
                &nil_block.block.header,
                &committee,
                "taiko-etna-167001-g0"
            )
            .is_err()
        );
        block.commit.signatures[0] = CommitSig::BlockIdFlagAbsent;
        assert!(
            verify_commit(&block.commit, &block.block.header, &committee, "taiko-etna-167001-g0")
                .is_err()
        );
    }

    #[test]
    fn rejects_duplicate_signers_invalid_signatures_and_changed_sign_bytes() {
        let (_, committee, keys) = committee(&[1, 1, 1], 0);
        let original = pair(1, B256::ZERO, &committee, &keys, None);
        let mut block = original.clone();
        block.commit.signatures[1] = block.commit.signatures[0].clone();
        assert!(
            verify_commit(&block.commit, &block.block.header, &committee, "taiko-etna-167001-g0")
                .is_err()
        );
        let mut block = original.clone();
        block.commit.round = 1u16.into();
        assert!(
            verify_commit(&block.commit, &block.block.header, &committee, "taiko-etna-167001-g0")
                .is_err()
        );
        let mut block = original.clone();
        block.commit.height = 2u32.into();
        assert!(
            verify_commit(&block.commit, &block.block.header, &committee, "taiko-etna-167001-g0")
                .is_err()
        );
        assert!(
            verify_commit(
                &original.commit,
                &original.block.header,
                &committee,
                "taiko-etna-167001-g1"
            )
            .is_err()
        );
        let mut block = original.clone();
        if let CommitSig::BlockIdFlagCommit { signature, .. } = &mut block.commit.signatures[0] {
            *signature = Some(vec![0; 64].try_into().unwrap());
        }
        assert!(
            verify_commit(&block.commit, &block.block.header, &committee, "taiko-etna-167001-g0")
                .is_err()
        );
        let mut block = original;
        if let CommitSig::BlockIdFlagCommit { timestamp, .. } = &mut block.commit.signatures[0] {
            *timestamp = Time::from_unix_timestamp(200, 0).unwrap();
        }
        assert!(
            verify_commit(&block.commit, &block.block.header, &committee, "taiko-etna-167001-g0")
                .is_err()
        );
    }

    #[test]
    fn committed_body_and_el_linkage_are_checked_independently() {
        let (_, committee, keys) = committee(&[1], 0);
        let original = pair(1, B256::repeat_byte(3), &committee, &keys, None);
        verify_structure(&original, None, 1, B256::repeat_byte(3)).unwrap();
        let mut block = original.clone();
        block.block.data[0].push(0);
        assert!(matches!(
            verify_structure(&block, None, 1, B256::repeat_byte(3)),
            Err(ValidationError::Commitment("data"))
        ));
        let mut block = original.clone();
        block.block.header.evidence_hash = None;
        assert!(matches!(
            verify_structure(&block, None, 1, B256::repeat_byte(3)),
            Err(ValidationError::Commitment("evidence"))
        ));
        assert!(verify_structure(&original, None, 1, B256::repeat_byte(4)).is_err());
        let mut block = original.clone();
        block.block.header.app_hash = vec![0; 32].try_into().unwrap();
        assert!(verify_structure(&block, None, 1, B256::repeat_byte(3)).is_err());
        let second = pair(2, B256::repeat_byte(5), &committee, &keys, Some(&original));
        verify_structure(&second, Some(&original), 2, B256::repeat_byte(5)).unwrap();
        let mut changed = second.clone();
        changed.block.last_commit.as_mut().unwrap().signatures[0] = CommitSig::BlockIdFlagAbsent;
        assert!(verify_structure(&changed, Some(&original), 2, B256::repeat_byte(5)).is_err());
        assert!(verify_structure(&second, None, 2, B256::repeat_byte(5)).is_err());
    }
    #[test]
    fn authenticates_initial_empty_commit_and_multi_part_blocks() {
        let (_, committee, keys) = committee(&[1], 0);
        let mut original = pair(1, B256::ZERO, &committee, &keys, None);
        assert_eq!(original.block.header.last_commit_hash, Some(merkle(&[])));
        verify_structure(&original, None, 1, B256::ZERO).unwrap();
        let mut wrong = original.clone();
        wrong.block.header.last_commit_hash = None;
        wrong.commit.block_id.part_set_header = block_parts(&wrong.block);
        assert!(verify_structure(&wrong, None, 1, B256::ZERO).is_err());
        original.commit.block_id.part_set_header =
            tendermint::block::parts::Header::new(1, Hash::Sha256([9; 32])).unwrap();
        assert!(matches!(
            verify_structure(&original, None, 1, B256::ZERO),
            Err(ValidationError::Commitment("block part set"))
        ));
        let mut big = pair(1, B256::ZERO, &committee, &keys, None);
        let mut envelope = abci::EtnaEnvelope::decode(&big.block.data[0]).unwrap();
        envelope.block.transactions.push(alloy_primitives::Bytes::from(vec![7; 70_000]));
        big.block.data[0] = envelope.encode().to_vec();
        big.block.header.data_hash = Some(merkle(
            &big.block.data.iter().map(|tx| Sha256::digest(tx).to_vec()).collect::<Vec<_>>(),
        ));
        big.commit.block_id.part_set_header = block_parts(&big.block);
        crate::test_utils::consensus::resign(&mut big, &committee, &keys);
        assert_eq!(big.commit.block_id.part_set_header.total, 2);
        verify_structure(&big, None, 1, B256::ZERO).unwrap();
        verify_commit(&big.commit, &big.block.header, &committee, "taiko-etna-167001-g0").unwrap();
    }
}
