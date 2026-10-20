//! Pure certificate, CometBFT body-commitment and Etna envelope validation.

use std::collections::BTreeSet;

use abci::{
    AnchorState, ChainParams, CommitteeState, EtnaEnvelope, ParentInfo, Schedule,
    committee::verify_committee_witness,
    l1::{layout::inbox, witness::verify_anchor_witness},
    rules::{self, GenerationCheck, HeaderInputs},
};
use alloy_primitives::B256;
use ed25519_consensus::{Signature, VerificationKey};
use prost::Message;
use sha2::{Digest, Sha256};
use tendermint::{
    Hash, Vote,
    block::{Commit, CommitSig},
    vote::{CanonicalVote, Type},
};
use tendermint_proto::{
    Protobuf,
    v0_38::types::{
        Block as RawBlock, CanonicalVote as RawVote, CommitSig as RawCommitSig,
        evidence::Sum as RawEvidence,
    },
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
    /// Provisional pure-rule decision for the parent's queue cursor. `NeedsSkip` requires
    /// asynchronous Engine checking before the lander may authenticate cursor advancement;
    /// the current dummy proof does not independently establish guest execution.
    pub forced: abci::forced::ForcedDecision,
    /// Consensus-derived singleton attributes, authenticated before asynchronous checking.
    pub expected: rules::ExpectedHeader,
}

/// Authenticate canonical precommits with distinct signers and strict `> 2/3` signed power.
///
/// The timestamp, round, block id, height and chain id all enter Tendermint's canonical
/// length-delimited vote sign bytes. Nil votes are verified but contribute no block power.
/// Absent slots contribute no power. Signatures must follow the authenticated validator order.
/// Ed25519 acceptance follows CometBFT's ZIP215 consensus rules, including torsion components;
/// every future proof guest must use the same verifier.
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
        let key = VerificationKey::try_from(*key_bytes)
            .map_err(|e| ValidationError::Certificate(format!("Ed25519 key: {e}")))?;
        let signature = Signature::try_from(signature.as_bytes())
            .map_err(|e| ValidationError::Certificate(format!("Ed25519 signature: {e}")))?;
        key.verify(&signature, &sign_bytes)
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

/// Stock CometBFT's 64-KiB part commitment over the original block protobuf.
///
/// Never reconstruct this witness through the Tendermint domain adapter: that adapter changes
/// evidence powers, nil vote block ids and nested light-client validator set encodings.
pub fn block_parts(block: &RawBlock) -> tendermint::block::parts::Header {
    let bytes = block.encode_to_vec();
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
    if block.header.evidence_hash.is_none() {
        return Err(ValidationError::Commitment("evidence"));
    }
    let raw = pair.block_proto().map_err(|e| ValidationError::Certificate(e.to_string()))?;
    let evidence = raw
        .evidence
        .as_ref()
        .into_iter()
        .flat_map(|list| &list.evidence)
        .map(|e| {
            // EvidenceList.Hash uses each concrete evidence's Bytes(), not the Evidence oneof.
            match e.sum.as_ref() {
                Some(RawEvidence::DuplicateVoteEvidence(e)) => Ok(e.encode_to_vec()),
                Some(RawEvidence::LightClientAttackEvidence(e)) => Ok(e.encode_to_vec()),
                None => Err(ValidationError::Certificate("missing evidence subtype".into())),
            }
        })
        .collect::<Result<Vec<_>, _>>()?;
    if block.header.evidence_hash != Some(merkle(&evidence)) {
        return Err(ValidationError::Commitment("evidence"));
    }
    if pair.commit.block_id.part_set_header != block_parts(&raw) {
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
    /// Original proposer from the certified CometBFT block header.
    pub proposer: tendermint::account::Id,
    /// Authenticated committee for this block's epoch, including its first height.
    pub members: &'a [abci::types::Member],
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
    /// Genesis `maxAnchorAge`, in seconds: how much older than a block its anchor may be.
    pub max_anchor_age: u64,
    /// The forced inclusion cursor after the parent: the queue entries the chain has consumed.
    pub forced_cursor: u64,
    /// Genesis forced inclusion delay `D`, in seconds.
    pub forced_inclusion_delay: u64,
}

/// Validates all existing ABCI pure rules using authenticated parent and chain context.
///
/// The forced inclusion rule ([`abci::forced::check`]) runs last, on the parent's cursor and the
/// block's anchor: it verifies the entry proof and, for a forced inclusion block, the carried
/// blob's versioned hash and manifest, but executes nothing.
pub fn verify_envelope(
    envelope: EtnaEnvelope,
    context: EnvelopeContext<'_>,
) -> Result<BlockFacts, ValidationError> {
    let EnvelopeContext {
        bft_time_secs,
        proposer,
        members,
        parent,
        parent_anchor,
        generation,
        schedule,
        params,
        max_anchor_age,
        forced_cursor,
        forced_inclusion_delay,
    } = context;
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
    rules::check_anchor_progress(parent_anchor.number, anchor.number, schedule.l1_0)
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
            let (record, members) = verify_committee_witness(parent_anchor, params, w, target)
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
        reward_recipient: rules::proposer_recipient(members, proposer)
            .ok_or_else(|| ValidationError::Etna("unknown certified proposer".into()))?,
    })
    .map_err(|e| ValidationError::Etna(e.to_string()))?;
    rules::check_anchor_freshness(expected.timestamp, anchor.timestamp, max_anchor_age)
        .map_err(|e| ValidationError::Etna(e.to_string()))?;
    rules::check_header(&envelope.block.header, &expected)
        .map_err(|e| ValidationError::Etna(e.to_string()))?;
    let forced_index = abci::forced::check(
        abci::forced::ForcedContext {
            cursor: forced_cursor,
            anchor: &anchor,
            delay: forced_inclusion_delay,
            inbox: params.inbox,
        },
        envelope.forced.as_ref(),
        envelope.block.transactions.first().map(|tx| tx.as_ref()),
    )
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
    Ok(BlockFacts {
        envelope,
        anchor,
        derived,
        parent: next_parent,
        forced: forced_index,
        expected,
    })
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::test_utils::consensus::{committee, nil_vote, pair, raw_block};
    use curve25519_dalek::{
        constants::{ED25519_BASEPOINT_POINT, EIGHT_TORSION},
        scalar::Scalar,
    };
    use sha2::Sha512;
    use tendermint::Time;

    #[test]
    fn accepts_cometbft_zip215_torsion_nonce_with_an_ordinary_powered_key() {
        let (_, committee, keys) = committee(&[1], 0);
        let mut pair = pair(1, B256::ZERO, &committee, &keys, None);
        let validator = &committee.validators.validators()[0];
        let vote = Vote {
            vote_type: Type::Precommit,
            height: pair.commit.height,
            round: pair.commit.round,
            block_id: Some(pair.commit.block_id),
            timestamp: Some(pair.block.header.time),
            validator_address: validator.address,
            validator_index: 0u32.try_into().unwrap(),
            signature: None,
            extension: vec![],
            extension_signature: None,
        };
        let bytes = Protobuf::<RawVote>::encode_length_delimited_vec(CanonicalVote::new(
            vote,
            pair.block.header.chain_id.clone(),
        ));
        let mut secret = Sha512::digest(keys[0].to_bytes());
        secret[0] &= 248;
        secret[31] &= 63;
        secret[31] |= 64;
        let scalar = Scalar::from_bytes_mod_order(secret[..32].try_into().unwrap());
        let nonce = Scalar::from(7u64);
        let point = ED25519_BASEPOINT_POINT * nonce + EIGHT_TORSION[1];
        assert!(!point.is_torsion_free());
        assert!(!point.is_small_order());
        let r = point.compress().to_bytes();
        let challenge = Sha512::new()
            .chain_update(r)
            .chain_update(keys[0].verifying_key().to_bytes())
            .chain_update(&bytes)
            .finalize();
        let challenge = Scalar::from_bytes_mod_order_wide(&challenge.into());
        let s = nonce + challenge * scalar;
        let signature = [r.as_slice(), s.as_bytes()].concat();
        if let CommitSig::BlockIdFlagCommit { signature: slot, .. } = &mut pair.commit.signatures[0]
        {
            *slot = Some(signature.try_into().unwrap());
        }
        verify_commit(&pair.commit, &pair.block.header, &committee, "taiko-etna-167001-g0")
            .unwrap();
    }

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
    fn zip215_rejects_noncanonical_scalars_and_noncurve_nonce_points() {
        let (_, committee, keys) = committee(&[1], 0);
        let original = pair(1, B256::ZERO, &committee, &keys, None);
        for scalar in [false, true] {
            let mut changed = original.clone();
            if let CommitSig::BlockIdFlagCommit { signature, .. } =
                &mut changed.commit.signatures[0]
            {
                let mut bytes = signature.as_ref().unwrap().as_bytes().to_vec();
                if scalar {
                    bytes[32..].fill(255);
                } else {
                    let invalid = [2; 32];
                    assert!(
                        curve25519_dalek::edwards::CompressedEdwardsY(invalid)
                            .decompress()
                            .is_none()
                    );
                    bytes[..32].copy_from_slice(&invalid);
                }
                *signature = Some(bytes.try_into().unwrap());
            }
            assert!(
                verify_commit(
                    &changed.commit,
                    &changed.block.header,
                    &committee,
                    "taiko-etna-167001-g0"
                )
                .is_err()
            );
        }
    }

    #[test]
    fn weighted_quorum_absent_and_nil_votes_do_not_count() {
        let (_, committee, keys) = committee(&[3, 1], 0);
        let mut block = pair(1, B256::ZERO, &committee, &keys, None);
        verify_commit(&block.commit, &block.block.header, &committee, "taiko-etna-167001-g0")
            .unwrap();
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

    /// Anchor freshness, inclusive: block 1 of the fixture is at 101 s and its anchor (L1 block
    /// 10) at 10 s, an anchor age of 91 s.
    #[test]
    fn stale_anchor_block_is_rejected() {
        let fixture = crate::test_utils::consensus_mpt::Fixture::new(0, 1);
        let genesis = &fixture.headers[&0];
        let parent = ParentInfo {
            number: 0,
            hash: genesis.hash_slow(),
            timestamp: genesis.timestamp,
            gas_limit: genesis.gas_limit,
            gas_used: genesis.gas_used,
            base_fee: genesis.base_fee_per_gas.unwrap(),
            difficulty: genesis.difficulty,
            grandparent_timestamp: 0,
        };
        let schedule = Schedule::from_genesis(&fixture.snapshot.genesis);
        let envelope = EtnaEnvelope::decode(&fixture.blocks[&1].block.data[0]).unwrap();
        let context = |max_anchor_age| EnvelopeContext {
            bft_time_secs: 101,
            proposer: fixture.blocks[&1].block.header.proposer_address,
            members: &fixture.committees[&schedule.epoch_of(1)].state.members,
            parent: &parent,
            parent_anchor: &fixture.anchors[&0],
            generation: 0,
            schedule: &schedule,
            params: &fixture.params,
            max_anchor_age,
            forced_cursor: 0,
            forced_inclusion_delay: fixture.snapshot.genesis.forced_inclusion_delay,
        };

        let facts = verify_envelope(envelope.clone(), context(91)).unwrap();
        assert_eq!(facts.envelope.block.header.timestamp - facts.anchor.timestamp, 91);
        let error = verify_envelope(envelope, context(90)).unwrap_err();
        let violation = rules::RuleViolation::AnchorTooOld { age: 91, max: 90 };
        assert!(
            matches!(&error, ValidationError::Etna(m) if *m == violation.to_string()),
            "{error}"
        );
    }

    /// Shared validation uses the certified header proposer and authenticated epoch payout.
    #[test]
    fn validate_certified_proposer_payout_and_unknown_proposer() {
        let fixture = crate::test_utils::consensus_mpt::Fixture::new(0, 1);
        let genesis = &fixture.headers[&0];
        let parent = ParentInfo {
            number: 0,
            hash: genesis.hash_slow(),
            timestamp: genesis.timestamp,
            gas_limit: genesis.gas_limit,
            gas_used: genesis.gas_used,
            base_fee: genesis.base_fee_per_gas.unwrap(),
            difficulty: genesis.difficulty,
            grandparent_timestamp: 0,
        };
        let schedule = Schedule::from_genesis(&fixture.snapshot.genesis);
        let envelope = EtnaEnvelope::decode(&fixture.blocks[&1].block.data[0]).unwrap();
        let original = fixture.blocks[&1].block.header.proposer_address;
        let members = &fixture.committees[&schedule.epoch_of(1)].state.members;
        let context = |proposer| EnvelopeContext {
            bft_time_secs: 101,
            proposer,
            members,
            parent: &parent,
            parent_anchor: &fixture.anchors[&0],
            generation: 0,
            schedule: &schedule,
            params: &fixture.params,
            max_anchor_age: 7200,
            forced_cursor: 0,
            forced_inclusion_delay: fixture.snapshot.genesis.forced_inclusion_delay,
        };
        let facts = verify_envelope(envelope.clone(), context(original)).unwrap();
        assert_eq!(
            facts.expected.beneficiary,
            rules::proposer_recipient(members, original).unwrap()
        );
        assert_eq!(facts.expected.extra_data[0], 0);
        let mut wrong = envelope.clone();
        wrong.block.header.beneficiary = fixture.params.fee_vault;
        assert!(
            matches!(verify_envelope(wrong, context(original)), Err(ValidationError::Etna(m)) if m.contains("beneficiary"))
        );
        let mut changed = members.clone();
        let key = changed
            .iter_mut()
            .find(|member| {
                rules::proposer_recipient(std::slice::from_ref(member), original).is_some()
            })
            .unwrap();
        key.reward_recipient = alloy_primitives::Address::repeat_byte(0x88);
        assert!(
            verify_envelope(
                envelope.clone(),
                EnvelopeContext { members: &changed, ..context(original) }
            )
            .is_err()
        );
        let mut updated = envelope.clone();
        updated.block.header.beneficiary = alloy_primitives::Address::repeat_byte(0x88);
        verify_envelope(updated, EnvelopeContext { members: &changed, ..context(original) })
            .unwrap();
        let unknown = tendermint::account::Id::new([0xff; 20]);
        assert!(
            matches!(verify_envelope(envelope, context(unknown)), Err(ValidationError::Etna(m)) if m.contains("unknown certified proposer"))
        );
    }

    #[test]
    fn asymmetric_members_keep_batch_payout_distinct_from_certified_proposer() {
        let fixture = crate::test_utils::consensus_mpt::Fixture::new(24, 25);
        let schedule = Schedule::from_genesis(&fixture.snapshot.genesis);
        let committee = &fixture.committees[&schedule.epoch_of(25)];
        let members = &committee.state.members;
        assert_eq!(members.len(), 2);
        assert_ne!(members[0].reward_recipient, members[1].reward_recipient);
        let batch_recipient = crate::test_utils::consensus::BATCH_RECIPIENT;
        assert!(members.iter().all(|m| m.reward_recipient != batch_recipient));
        // Deliberately certify the member that is not first in set-key order, in a later round.
        let original = committee
            .validators
            .validators()
            .iter()
            .find(|v| {
                rules::proposer_recipient(members, v.address) == Some(members[1].reward_recipient)
            })
            .unwrap()
            .address;
        let mut certified = fixture.blocks[&25].clone();
        certified.block.header.proposer_address = original;
        certified.commit.round = 2u16.into();
        let mut envelope = EtnaEnvelope::decode(&certified.block.data[0]).unwrap();
        envelope.block.header.beneficiary = members[1].reward_recipient;
        certified.block.data[0] = envelope.encode().to_vec();
        let keys = vec![
            ed25519_dalek::SigningKey::from_bytes(&[1; 32]),
            ed25519_dalek::SigningKey::from_bytes(&[2; 32]),
        ];
        crate::test_utils::consensus::resign(&mut certified, committee, &keys);
        verify_commit(
            &certified.commit,
            &certified.block.header,
            committee,
            "taiko-etna-167001-g0",
        )
        .unwrap();
        let previous = &fixture.headers[&24];
        let parent = ParentInfo {
            number: 24,
            hash: previous.hash_slow(),
            timestamp: previous.timestamp,
            gas_limit: previous.gas_limit,
            gas_used: previous.gas_used,
            base_fee: previous.base_fee_per_gas.unwrap(),
            difficulty: previous.difficulty,
            grandparent_timestamp: fixture.headers[&23].timestamp,
        };
        let context = || EnvelopeContext {
            bft_time_secs: 125,
            proposer: certified.block.header.proposer_address,
            members,
            parent: &parent,
            parent_anchor: &fixture.anchors[&24],
            generation: 0,
            schedule: &schedule,
            params: &fixture.params,
            max_anchor_age: 7200,
            forced_cursor: 0,
            forced_inclusion_delay: fixture.snapshot.genesis.forced_inclusion_delay,
        };
        assert_eq!(
            verify_envelope(envelope.clone(), context()).unwrap().expected.beneficiary,
            members[1].reward_recipient
        );
        for wrong in [members[0].reward_recipient, batch_recipient] {
            let mut changed = envelope.clone();
            changed.block.header.beneficiary = wrong;
            assert!(
                matches!(verify_envelope(changed, context()), Err(ValidationError::Etna(m)) if m.contains("beneficiary"))
            );
        }
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
        wrong.commit.block_id.part_set_header = block_parts(&raw_block(&wrong.block));
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
        crate::test_utils::consensus::resign(&mut big, &committee, &keys);
        assert_eq!(big.commit.block_id.part_set_header.total, 2);
        verify_structure(&big, None, 1, B256::ZERO).unwrap();
        verify_commit(&big.commit, &big.block.header, &committee, "taiko-etna-167001-g0").unwrap();
    }
}
