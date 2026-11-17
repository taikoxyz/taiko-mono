//! Pure certificate, CometBFT body-commitment and Etna envelope validation.

use std::collections::BTreeMap;

use crate::{
    committee::AuthenticatedCommittee,
    native::{Commit, RawBlock},
    types::CertifiedBlock,
};
use abci::{
    AnchorState, ChainParams, CommitteeState, EtnaEnvelope, GenesisRecord, ParentInfo,
    app::ChainContext, rules,
};
use alloy_primitives::B256;

/// A certificate or block is inconsistent with authenticated consensus context.
#[derive(Debug, thiserror::Error)]
pub enum ValidationError {
    /// The source certificate is malformed or cannot authenticate the claimed block.
    #[error("invalid CometBFT certificate: {0}")]
    Certificate(String),
    /// One committed body hash disagrees with its contents.
    #[error("CometBFT {0} commitment mismatch")]
    Commitment(&'static str),
    /// Authenticated content selects a ruleset this software cannot interpret yet.
    #[error("ruleset {rules} is unsupported; upgrade the lander to continue")]
    UnsupportedRuleset {
        /// Monotonically assigned protocol ruleset selected by the block's own anchor.
        rules: u64,
    },
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
/// Native stock secp256k1eth verification enforces low-S recoverable signatures and authorized
/// Ethereum addresses; every future proof guest must preserve these exact checks.
pub fn verify_commit(
    commit: &Commit,
    header: &tendermint::block::Header,
    committee: &AuthenticatedCommittee,
    chain_id: &str,
) -> Result<(), ValidationError> {
    if committee.state.record.total_power != committee.validators.total_voting_power() {
        return Err(ValidationError::Certificate(
            "committee record and native total power differ".into(),
        ));
    }
    verify_native_commit(commit, header, &committee.validators, chain_id)
}

/// Shared native certificate verification with lander's existing error boundary.
pub(crate) fn verify_native_commit(
    commit: &Commit,
    header: &tendermint::block::Header,
    validators: &crate::committee::Validators,
    chain_id: &str,
) -> Result<(), ValidationError> {
    etna_core::comet::verify::verify_native_commit(commit, header, validators, chain_id)
        .map_err(Into::into)
}

/// Shared stock transaction and signature-protobuf Merkle commitments.
pub use etna_core::comet::verify::{commit_hash, data_hash};

/// Legacy infallible helper for already size-bounded native blocks.
/// Untrusted verification uses the fallible shared implementation directly.
pub fn block_parts(block: &RawBlock) -> tendermint::block::parts::Header {
    etna_core::comet::verify::block_parts(block).expect("bounded nonempty native block")
}

/// Pure native failures retain the existing lander certificate/commitment/Etna distinction.
impl From<etna_core::comet::verify::BftError> for ValidationError {
    /// Maps deterministic failures without changing unsupported-rules or runtime policy.
    fn from(error: etna_core::comet::verify::BftError) -> Self {
        use etna_core::comet::verify::BftError;
        match error {
            BftError::Certificate(reason) => Self::Certificate(reason),
            BftError::Commitment(reason) => Self::Commitment(reason),
            BftError::TransactionCount(count) => {
                Self::Etna(abci::EnvelopeError::TxCount(count).to_string())
            }
            other => Self::Certificate(other.to_string()),
        }
    }
}

/// Borrows the shared native view without copying original protobuf bytes.
fn native_pair(pair: &CertifiedBlock) -> etna_core::comet::verify::CertifiedBlockRef<'_> {
    etna_core::comet::verify::CertifiedBlockRef {
        block: &pair.block,
        raw_block: &pair.raw_block,
        commit: &pair.commit,
    }
}

/// Decodes the native-committed Etna transaction and preserves host EL linkage checks.
fn decode_transaction(
    transaction: &[u8],
    expected_height: u64,
    parent_el_hash: B256,
) -> Result<EtnaEnvelope, ValidationError> {
    let envelope = abci::single_envelope(&[alloy_primitives::Bytes::copy_from_slice(transaction)])
        .map_err(|e| ValidationError::Etna(e.to_string()))?;
    if envelope.block.header.number != expected_height ||
        envelope.block.header.parent_hash != parent_el_hash
    {
        return Err(ValidationError::Etna("execution height / parent hash mismatch".into()));
    }
    Ok(envelope)
}

/// Generation-zero body verification retained for native host tests.
#[cfg(test)]
pub fn verify_body(
    pair: &CertifiedBlock,
    expected_height: u64,
    parent_el_hash: B256,
) -> Result<EtnaEnvelope, ValidationError> {
    verify_body_at_origin(pair, expected_height, parent_el_hash, 0)
}

/// Checks shared native commitments, then decodes the envelope and verifies its EL linkage.
pub fn verify_body_at_origin(
    pair: &CertifiedBlock,
    expected_height: u64,
    parent_el_hash: B256,
    origin_height: u64,
) -> Result<EtnaEnvelope, ValidationError> {
    let transaction = etna_core::comet::verify::verify_body_at_origin(
        native_pair(pair),
        expected_height,
        parent_el_hash,
        origin_height,
    )?;
    decode_transaction(transaction, expected_height, parent_el_hash)
}

/// Generation-zero ancestry and envelope facade, retaining its existing public signature.
pub fn verify_structure(
    pair: &CertifiedBlock,
    previous: Option<&CertifiedBlock>,
    expected_height: u64,
    parent_el_hash: B256,
) -> Result<EtnaEnvelope, ValidationError> {
    verify_structure_at_origin(pair, previous, expected_height, parent_el_hash, 0)
}

/// Checks shared native full-identity ancestry before host envelope and EL linkage validation.
pub fn verify_structure_at_origin(
    pair: &CertifiedBlock,
    previous: Option<&CertifiedBlock>,
    expected_height: u64,
    parent_el_hash: B256,
    origin_height: u64,
) -> Result<EtnaEnvelope, ValidationError> {
    let transaction = etna_core::comet::verify::verify_structure_at_origin(
        native_pair(pair),
        previous.map(native_pair),
        expected_height,
        parent_el_hash,
        origin_height,
    )?;
    decode_transaction(transaction, expected_height, parent_el_hash)
}

/// Authenticated context of one certified block for [`verify_envelope`].
#[derive(Clone, Copy)]
pub struct EnvelopeContext<'a> {
    /// Whole seconds of the CometBFT block timestamp.
    pub bft_time_secs: u64,
    /// Original proposer from the certified CometBFT block header.
    pub proposer: tendermint::account::Id,
    /// Authenticated committees by epoch, including the block's own epoch.
    pub committees: &'a BTreeMap<u64, AuthenticatedCommittee>,
    /// Execution facts of the authenticated parent.
    pub parent: &'a ParentInfo,
    /// Exact historic anchor consumed by that parent.
    pub parent_anchor: &'a AnchorState,
    /// Authenticated recovery generation.
    pub generation: u64,
    /// Fixed independently authenticated generation origin.
    pub recovery: Option<&'a abci::recovery::RecoveryOrigin>,
    /// Authenticated genesis record of the Inbox: schedule, `maxAnchorAge` and forced inclusion
    /// delay.
    pub genesis: &'a GenesisRecord,
    /// Shared chain constants.
    pub params: &'a ChainParams,
    /// The forced inclusion cursor after the parent: the queue entries the chain has consumed.
    pub forced_cursor: u64,
}

/// Validates the envelope with the ABCI app's own block rules ([`abci::app::validate_block`])
/// on the authenticated parent and chain context.
///
/// The forced inclusion rule runs last, on the parent's cursor and the block's anchor: it
/// verifies the entry proof and checks the block's first transaction, or the carried skip
/// preimage, against the entry's calldata `txHash`, but executes nothing.
pub fn verify_envelope(
    envelope: EtnaEnvelope,
    context: EnvelopeContext<'_>,
) -> Result<BlockFacts, ValidationError> {
    let chain = ChainContext {
        recovery: context.recovery,
        genesis: context.genesis,
        generation: context.generation,
        parent: context.parent,
        anchor: context.parent_anchor,
        forced_cursor: context.forced_cursor,
        committees: context.committees,
    };
    let validated = abci::app::validate_block(
        &chain,
        context.params,
        &envelope,
        envelope.block.header.number,
        context.bft_time_secs,
        context.proposer,
    )
    .map_err(|e| match e {
        abci::app::Rejection::Rule(rules::RuleViolation::UnsupportedRuleset { rules }) => {
            ValidationError::UnsupportedRuleset { rules }
        }
        other => ValidationError::Etna(other.to_string()),
    })?;
    let header = &envelope.block.header;
    let next_parent = ParentInfo {
        number: header.number,
        hash: header.hash_slow(),
        timestamp: header.timestamp,
        gas_limit: header.gas_limit,
        gas_used: header.gas_used,
        base_fee: header
            .base_fee_per_gas
            .ok_or_else(|| ValidationError::Etna("missing base fee".into()))?,
        difficulty: header.difficulty,
        grandparent_timestamp: context.parent.timestamp,
    };
    Ok(BlockFacts {
        envelope,
        anchor: validated.anchor,
        derived: validated.derived.map(|(_, committee)| committee),
        parent: next_parent,
        forced: validated.decision,
        expected: validated.expected,
    })
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::{
        native::CommitSig,
        test_utils::consensus::{self, committee, nil_vote, pair, raw_block},
    };
    use tendermint::{Hash, Time};

    #[test]
    fn epoch_boundary_uses_outgoing_last_commit_and_incoming_current_commit() {
        let (_, outgoing, old_keys) = committee(&[30, 10], 0);
        let (_, incoming, new_keys) = committee(&[10, 30], 1);
        let previous = pair(1, B256::ZERO, &outgoing, &old_keys, None);
        let parent = abci::single_envelope(
            &previous
                .block
                .data
                .iter()
                .cloned()
                .map(alloy_primitives::Bytes::from)
                .collect::<Vec<_>>(),
        )
        .unwrap()
        .block
        .header
        .hash_slow();
        let current = pair(2, parent, &incoming, &new_keys, Some(&previous));
        verify_structure(&current, Some(&previous), 2, parent).unwrap();
        let last = current.block.last_commit.as_ref().unwrap();
        let chain = previous.block.header.chain_id.as_str();
        verify_commit(last, &previous.block.header, &outgoing, chain).unwrap();
        verify_commit(&current.commit, &current.block.header, &incoming, chain).unwrap();
        assert!(verify_commit(last, &previous.block.header, &incoming, chain).is_err());
        assert!(verify_commit(&current.commit, &current.block.header, &outgoing, chain).is_err());
    }

    #[test]
    fn v1_certificate_rejects_another_app_version_even_with_valid_native_signatures() {
        let (_, committee, keys) = consensus::committee(&[1, 1, 1], 0);
        let mut pair = consensus::pair(1, B256::ZERO, &committee, &keys, None);
        pair.block.header.version.app = 0;
        consensus::resign(&mut pair, &committee, &keys);
        assert!(
            verify_commit(
                &pair.commit,
                &pair.block.header,
                &committee,
                pair.block.header.chain_id.as_str()
            )
            .is_err()
        );
    }

    #[test]
    fn real_canonical_native_commits_require_strictly_more_than_two_thirds() {
        let (_, committee, keys) = committee(&[1, 1, 1], 0);
        let mut block = pair(1, B256::repeat_byte(9), &committee, &keys, None);
        verify_commit(
            &block.commit,
            &block.block.header,
            &committee,
            "etna-rFfVfgyjbP1zElufI3Hsqar8zT_q-s2n_fB74bWyvP4",
        )
        .unwrap();
        block.commit.signatures[2] = CommitSig::BlockIdFlagAbsent;
        assert!(
            verify_commit(
                &block.commit,
                &block.block.header,
                &committee,
                "etna-rFfVfgyjbP1zElufI3Hsqar8zT_q-s2n_fB74bWyvP4"
            )
            .is_err()
        );
    }

    #[test]
    fn native_rejects_invalid_scalars_and_recovery_ids() {
        let (_, committee, keys) = committee(&[1], 0);
        let original = pair(1, B256::ZERO, &committee, &keys, None);
        for mutation in 0..3 {
            let mut changed = original.clone();
            if let CommitSig::BlockIdFlagCommit { signature, .. } =
                &mut changed.commit.signatures[0]
            {
                let mut bytes = signature.as_ref().unwrap().as_bytes().to_vec();
                match mutation {
                    0 => bytes[64] = 2,
                    1 => bytes[..32].fill(0),
                    2 => {
                        let order = alloy_primitives::U256::from_be_slice(
                            &alloy_primitives::hex::decode(
                                "fffffffffffffffffffffffffffffffebaaedce6af48a03bbfd25e8cd0364141",
                            )
                            .unwrap(),
                        );
                        let high_s = order - alloy_primitives::U256::from_be_slice(&bytes[32..64]);
                        bytes[32..64].copy_from_slice(&high_s.to_be_bytes::<32>());
                        bytes[64] ^= 1;
                    }
                    _ => unreachable!(),
                }
                *signature = Some(bytes.try_into().unwrap());
            }
            assert!(
                verify_commit(
                    &changed.commit,
                    &changed.block.header,
                    &committee,
                    "etna-rFfVfgyjbP1zElufI3Hsqar8zT_q-s2n_fB74bWyvP4"
                )
                .is_err()
            );
        }
    }

    #[test]
    fn weighted_quorum_absent_and_nil_votes_do_not_count() {
        let (_, committee, keys) = committee(&[3, 1], 0);
        let mut block = pair(1, B256::ZERO, &committee, &keys, None);
        verify_commit(
            &block.commit,
            &block.block.header,
            &committee,
            "etna-rFfVfgyjbP1zElufI3Hsqar8zT_q-s2n_fB74bWyvP4",
        )
        .unwrap();
        block.commit.signatures[1] = CommitSig::BlockIdFlagAbsent;
        verify_commit(
            &block.commit,
            &block.block.header,
            &committee,
            "etna-rFfVfgyjbP1zElufI3Hsqar8zT_q-s2n_fB74bWyvP4",
        )
        .unwrap();
        let mut nil_block = pair(1, B256::ZERO, &committee, &keys, None);
        nil_block.commit.signatures[1] = nil_vote(&nil_block, &committee, &keys, 1);
        verify_commit(
            &nil_block.commit,
            &nil_block.block.header,
            &committee,
            "etna-rFfVfgyjbP1zElufI3Hsqar8zT_q-s2n_fB74bWyvP4",
        )
        .unwrap();
        nil_block.commit.signatures[0] = nil_vote(&nil_block, &committee, &keys, 0);
        assert!(
            verify_commit(
                &nil_block.commit,
                &nil_block.block.header,
                &committee,
                "etna-rFfVfgyjbP1zElufI3Hsqar8zT_q-s2n_fB74bWyvP4"
            )
            .is_err()
        );
        block.commit.signatures[0] = CommitSig::BlockIdFlagAbsent;
        assert!(
            verify_commit(
                &block.commit,
                &block.block.header,
                &committee,
                "etna-rFfVfgyjbP1zElufI3Hsqar8zT_q-s2n_fB74bWyvP4"
            )
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
            verify_commit(
                &block.commit,
                &block.block.header,
                &committee,
                "etna-rFfVfgyjbP1zElufI3Hsqar8zT_q-s2n_fB74bWyvP4"
            )
            .is_err()
        );
        let mut block = original.clone();
        block.commit.round = 1u16.into();
        assert!(
            verify_commit(
                &block.commit,
                &block.block.header,
                &committee,
                "etna-rFfVfgyjbP1zElufI3Hsqar8zT_q-s2n_fB74bWyvP4"
            )
            .is_err()
        );
        let mut block = original.clone();
        block.commit.height = 2u32.into();
        assert!(
            verify_commit(
                &block.commit,
                &block.block.header,
                &committee,
                "etna-rFfVfgyjbP1zElufI3Hsqar8zT_q-s2n_fB74bWyvP4"
            )
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
            *signature = Some(vec![0; 65].try_into().unwrap());
        }
        assert!(
            verify_commit(
                &block.commit,
                &block.block.header,
                &committee,
                "etna-rFfVfgyjbP1zElufI3Hsqar8zT_q-s2n_fB74bWyvP4"
            )
            .is_err()
        );
        let mut block = original;
        if let CommitSig::BlockIdFlagCommit { timestamp, .. } = &mut block.commit.signatures[0] {
            *timestamp = Time::from_unix_timestamp(200, 0).unwrap();
        }
        assert!(
            verify_commit(
                &block.commit,
                &block.block.header,
                &committee,
                "etna-rFfVfgyjbP1zElufI3Hsqar8zT_q-s2n_fB74bWyvP4"
            )
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
        let envelope = EtnaEnvelope::decode(&fixture.blocks[&1].block.data[0]).unwrap();
        let genesis =
            |max_anchor_age| GenesisRecord { max_anchor_age, ..fixture.snapshot.genesis.clone() };
        let (fresh, stale) = (genesis(91), genesis(90));
        let context = |genesis| EnvelopeContext {
            recovery: None,
            bft_time_secs: 101,
            proposer: fixture.blocks[&1].block.header.proposer_address,
            committees: &fixture.committees,
            parent: &parent,
            parent_anchor: &fixture.anchors[&0],
            generation: 0,
            genesis,
            params: &fixture.params,
            forced_cursor: 0,
        };

        let facts = verify_envelope(envelope.clone(), context(&fresh)).unwrap();
        assert_eq!(facts.envelope.block.header.timestamp - facts.anchor.timestamp, 91);
        let error = verify_envelope(envelope, context(&stale)).unwrap_err();
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
        let envelope = EtnaEnvelope::decode(&fixture.blocks[&1].block.data[0]).unwrap();
        let original = fixture.blocks[&1].block.header.proposer_address;
        let genesis = GenesisRecord { max_anchor_age: 7200, ..fixture.snapshot.genesis.clone() };
        let context = |proposer| EnvelopeContext {
            recovery: None,
            bft_time_secs: 101,
            proposer,
            committees: &fixture.committees,
            parent: &parent,
            parent_anchor: &fixture.anchors[&0],
            generation: 0,
            genesis: &genesis,
            params: &fixture.params,
            forced_cursor: 0,
        };
        let facts = verify_envelope(envelope.clone(), context(original)).unwrap();
        assert_eq!(facts.expected.beneficiary, envelope.block.header.beneficiary);
        assert_eq!(facts.expected.extra_data[0], 100);
        let mut changed = envelope.clone();
        changed.block.header.beneficiary = alloy_primitives::Address::repeat_byte(0x88);
        assert_eq!(
            verify_envelope(changed, context(original)).unwrap().expected.beneficiary,
            alloy_primitives::Address::repeat_byte(0x88)
        );
        let unknown = tendermint::account::Id::new([0xff; 20]);
        assert!(
            matches!(verify_envelope(envelope, context(unknown)), Err(ValidationError::Etna(m)) if m.contains("unknown certified proposer"))
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
        assert_eq!(original.block.header.last_commit_hash, Some(data_hash(&[])));
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
        big.block.header.data_hash = Some(data_hash(&big.block.data));
        crate::test_utils::consensus::resign(&mut big, &committee, &keys);
        assert_eq!(big.commit.block_id.part_set_header.total, 2);
        verify_structure(&big, None, 1, B256::ZERO).unwrap();
        verify_commit(
            &big.commit,
            &big.block.header,
            &committee,
            "etna-rFfVfgyjbP1zElufI3Hsqar8zT_q-s2n_fB74bWyvP4",
        )
        .unwrap();
    }
}
