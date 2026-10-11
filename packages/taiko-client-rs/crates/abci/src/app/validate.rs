//! Deterministic block validation shared by `ProcessProposal` and `FinalizeBlock`: every check
//! of a proposal except the node-local ones, marked ¹ here (anchor finality in the node's own L1
//! view, EL execution), which affect liveness only.
//!
//! [`validate_block`] judges a decoded envelope against the committed [`AppState`] alone: no L1,
//! no EL, in its steps (a)–(i). [`check_candidate`] holds the witness steps (b)–(h);
//! `PrepareProposal` runs its two halves ([`check_candidate_anchor`], [`finish_candidate`]) on
//! its own witnesses before it asks the EL to build.
//! [`Rejection`] also carries the reasons of the ¹ checks, of the envelope decoding and of a
//! failed build, so every handler reports one label set.

use std::fmt;

use alloy_consensus::Header;
use alloy_primitives::B256;
use protocol::shasta::constants::min_base_fee_for_chain;

use crate::{
    committee::{CommitteeError, verify_committee_witness},
    config::ChainParams,
    engine::EngineError,
    envelope::{AnchorWitness, CommitteeWitness, EnvelopeError, EtnaEnvelope, ExecutionBlock},
    l1::{FetchError, L1Error, WitnessError, layout::inbox, verify_anchor_witness},
    rules::{self, ExpectedHeader, GenerationCheck, HeaderInputs, RuleViolation},
    store::{AppState, CommitteeState},
    types::AnchorState,
};

/// A block that passed [`validate_block`], with everything `FinalizeBlock` needs to commit it.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Validated {
    /// The execution block the envelope carries.
    pub block: ExecutionBlock,
    /// The block's anchor: proven by its witness, or the parent's when it carries none.
    pub anchor: AnchorState,
    /// At switch height `H(t)-2`: the freshly derived incoming committee, keyed by target epoch.
    pub derived: Option<(u64, CommitteeState)>,
    /// Whether the EL already executed the block and answered `VALID`.
    pub executed: bool,
}

/// Which optional witness of an envelope a [`Rejection`] concerns.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum WitnessKind {
    /// The L1 anchor witness.
    Anchor,
    /// The committee witness.
    Committee,
}

impl fmt::Display for WitnessKind {
    /// `anchor` or `committee`.
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.write_str(match self {
            Self::Anchor => "anchor",
            Self::Committee => "committee",
        })
    }
}

/// Why a proposal is rejected (`ProcessProposal`) or not built (`PrepareProposal`).
///
/// Every variant is a liveness matter for the node that observes it: the block is refused, the
/// chain keeps rounding. [`validate_block`] yields only the deterministic variants on a decoded
/// envelope; the ¹ node-local ones (anchor finality, L1, engine, EL sync state, timeouts) and the
/// handler-level ones ([`Rejection::Envelope`], [`Rejection::EmptyProposal`],
/// [`Rejection::ChainSuperseded`], [`Rejection::PayloadInvalid`], [`Rejection::Registry`],
/// [`Rejection::Oversize`], [`Rejection::BuiltHeader`]) come from the handlers.
#[derive(Debug, thiserror::Error, PartialEq, Eq)]
pub enum Rejection {
    /// The block's transactions are not exactly one well-formed envelope.
    #[error("malformed envelope: {0}")]
    Envelope(#[from] EnvelopeError),
    /// `ProcessProposal`: the block carries no transaction at all, which is how a proposer in a
    /// liveness halt proposes nothing.
    #[error("empty proposal: the proposer built no block")]
    EmptyProposal,
    /// A header field or a consensus predicate fails ([`RuleViolation`]).
    #[error(transparent)]
    Rule(#[from] RuleViolation),
    /// The anchor witness does not verify.
    #[error("anchor witness rejected: {0}")]
    Witness(#[from] WitnessError),
    /// The committee witness does not verify, or no committee can be derived from it.
    #[error("committee witness rejected: {0}")]
    Committee(#[from] CommitteeError),
    /// The Inbox records a later recovery generation than the chain's: the chain is superseded.
    #[error("inbox recoveryGeneration {inbox} supersedes the chain generation {chain}")]
    Superseded {
        /// The running chain's generation.
        chain: u64,
        /// The Inbox's `recoveryGeneration` proven at the anchor.
        inbox: u64,
    },
    /// An earlier proposal proved a later recovery generation, so every proposal is refused.
    #[error("the chain is superseded by a later recovery generation")]
    ChainSuperseded,
    /// A witness the height requires is absent.
    #[error("the block lacks its required {0} witness")]
    MissingWitness(WitnessKind),
    /// A witness the height must not carry is present.
    #[error("the block carries an unexpected {0} witness")]
    UnexpectedWitness(WitnessKind),
    /// The anchored Inbox is not in `ETNA_ACTIVE`.
    #[error("inbox status is {0}, expected ETNA_ACTIVE ({active})", active = inbox::ETNA_ACTIVE)]
    NotActive(u8),
    /// A switch height needs a committee the app does not hold.
    #[error("no committee known for epoch {0}")]
    CommitteeUnknown(u64),
    /// ¹ The anchor L1 header is not final and canonical in the own L1 view.
    #[error("anchor L1 block {number} is not final and canonical in the own L1 view")]
    AnchorNotFinal {
        /// The anchor's L1 block number.
        number: u64,
    },
    /// ¹ An own-L1 read failed.
    #[error(transparent)]
    L1(#[from] L1Error),
    /// ¹ An Engine API call failed.
    #[error(transparent)]
    Engine(#[from] EngineError),
    /// The EL executed the block and answered `INVALID` with this reason.
    #[error("execution engine rejected the block: {0}")]
    PayloadInvalid(String),
    /// ¹ The EL cannot execute the block yet (`SYNCING`/`ACCEPTED`).
    #[error("execution engine is syncing")]
    PayloadSyncing,
    /// ¹ An external call exceeded its deadline.
    #[error("{0} timed out")]
    Timeout(&'static str),
    /// The registry storage read while discovering a snapshot is unusable.
    #[error("registry discovery failed: {0}")]
    Registry(String),
    /// `PrepareProposal`: the envelope exceeds CometBFT's `max_tx_bytes`.
    #[error("envelope of {len} bytes exceeds max_tx_bytes {max}")]
    Oversize {
        /// The encoded envelope length, in bytes.
        len: usize,
        /// The request's `max_tx_bytes`.
        max: i64,
    },
    /// `PrepareProposal`: the EL built a header that breaks the derived fields.
    #[error("built block breaks the derived header: {0}")]
    BuiltHeader(RuleViolation),
}

impl Rejection {
    /// A stable snake_case label of the reason, for `/status` and the rejection metric. Rule
    /// violations use [`RuleViolation::label`].
    pub fn label(&self) -> &'static str {
        match self {
            Self::Envelope(_) => "envelope",
            Self::EmptyProposal => "empty_proposal",
            Self::Rule(rule) => rule.label(),
            Self::Witness(_) => "anchor_witness",
            Self::Committee(_) => "committee_witness",
            Self::Superseded { .. } | Self::ChainSuperseded => "superseded",
            Self::MissingWitness(WitnessKind::Anchor) => "missing_anchor_witness",
            Self::MissingWitness(WitnessKind::Committee) => "missing_committee_witness",
            Self::UnexpectedWitness(WitnessKind::Anchor) => "unexpected_anchor_witness",
            Self::UnexpectedWitness(WitnessKind::Committee) => "unexpected_committee_witness",
            Self::NotActive(_) => "inbox_not_active",
            Self::CommitteeUnknown(_) => "committee_unknown",
            Self::AnchorNotFinal { .. } => "anchor_not_final",
            Self::L1(_) => "l1_error",
            Self::Engine(_) => "engine_error",
            Self::PayloadInvalid(_) => "payload_invalid",
            Self::PayloadSyncing => "payload_syncing",
            Self::Timeout(_) => "timeout",
            Self::Registry(_) => "registry_discovery",
            Self::Oversize { .. } => "envelope_too_large",
            Self::BuiltHeader(_) => "built_header_mismatch",
        }
    }

    /// Whether the refusal reports a local build fault at ERROR; expected liveness waits and
    /// malformed proposals log at WARN.
    pub fn logs_at_error(&self) -> bool {
        matches!(self, Self::Oversize { .. } | Self::BuiltHeader(_))
    }
}

impl From<FetchError> for Rejection {
    /// Maps a failed committee-witness discovery onto the proposal reasons: L1 errors, timeouts,
    /// unusable registry words and derivation failures keep their own labels.
    fn from(e: FetchError) -> Self {
        match e {
            FetchError::L1(e) => Self::L1(e),
            FetchError::Timeout(what) => Self::Timeout(what),
            FetchError::Registry(reason) => Self::Registry(reason),
            FetchError::Committee(e) => Self::Committee(e),
        }
    }
}

/// The witnesses of a block candidate and what its `extraData` claims; the input of
/// [`check_candidate`].
#[derive(Clone, Copy, Debug)]
pub(crate) struct Candidate<'a> {
    /// The anchor witness, if the candidate carries one.
    pub(crate) anchor: Option<&'a AnchorWitness>,
    /// The committee witness, if the candidate carries one.
    pub(crate) committee: Option<&'a CommitteeWitness>,
    /// The generation in the candidate's `extraData`.
    pub(crate) extra_generation: u64,
    /// The anchor L1 block number in the candidate's `extraData`.
    pub(crate) extra_anchor: u64,
}

/// What [`check_candidate`] proves about a candidate's L1 view.
#[derive(Clone, Debug, PartialEq, Eq)]
pub(crate) struct CandidateFacts {
    /// The candidate's anchor (proven, or inherited from the parent).
    pub(crate) anchor: AnchorState,
    /// The committee derived at a switch height, keyed by its target epoch.
    pub(crate) derived: Option<(u64, CommitteeState)>,
}

/// Validates `env` as the block at `height` on top of `state` (every check but the ¹ ones);
/// `bft_secs` is the block's BFT time in whole seconds.
///
/// In order: (a) `height == state.last_height + 1`, the header's number and parent hash;
/// (b)–(h) [`check_candidate`] with the generation and anchor number decoded from the header's
/// `extraData`; (i) every derived header field ([`rules::expected_header`],
/// [`rules::check_header`]). Reports the first failure.
pub(crate) fn validate_block(
    state: &AppState,
    params: &ChainParams,
    env: &EtnaEnvelope,
    height: u64,
    bft_secs: u64,
) -> Result<Validated, Rejection> {
    let header = &env.block.header;
    if state.last_height.checked_add(1) != Some(height) {
        return Err(RuleViolation::HeightMismatch { height, parent: state.last_height }.into());
    }
    check_link(header, height, state.parent.hash)?;

    let (_, extra_generation, extra_anchor) = rules::decode_extra_data(&header.extra_data)?;
    let facts = check_candidate(
        state,
        params,
        height,
        &Candidate {
            anchor: env.anchor.as_ref(),
            committee: env.committee.as_ref(),
            extra_generation,
            extra_anchor,
        },
    )?;

    let expected = expected_header(state, params, height, &facts.anchor, bft_secs)?;
    rules::check_header(header, &expected)?;
    Ok(Validated {
        block: env.block.clone(),
        anchor: facts.anchor,
        derived: facts.derived,
        executed: false,
    })
}

/// The derived header fields of the block at `height` on top of `state` with `anchor` and BFT
/// time `bft_secs` ([`rules::expected_header`]), with the chain's minimum base fee.
pub(crate) fn expected_header(
    state: &AppState,
    params: &ChainParams,
    height: u64,
    anchor: &AnchorState,
    bft_secs: u64,
) -> Result<ExpectedHeader, RuleViolation> {
    rules::expected_header(&HeaderInputs {
        height,
        parent: &state.parent,
        anchor,
        bft_time_secs: bft_secs,
        generation: state.generation,
        params,
        min_base_fee: min_base_fee_for_chain(params.l2_chain_id),
    })
}

/// Steps (b)–(h) of [`validate_block`] on a candidate's witnesses and `extraData` claims:
/// [`check_candidate_anchor`], then [`finish_candidate`].
fn check_candidate(
    state: &AppState,
    params: &ChainParams,
    height: u64,
    c: &Candidate<'_>,
) -> Result<CandidateFacts, Rejection> {
    let anchor = check_candidate_anchor(state, params, height, c)?;
    finish_candidate(state, params, height, c.committee, anchor)
}

/// Authenticates a supplied anchor or inherits the parent's anchor, then checks anchor progress,
/// generation, active status and the unchanged back-pressure cap before registry discovery.
/// Anchor witnesses are forced only on anchor moves and H0, independently of switch heights.
pub(crate) fn check_candidate_anchor(
    state: &AppState,
    params: &ChainParams,
    height: u64,
    c: &Candidate<'_>,
) -> Result<AnchorState, Rejection> {
    let schedule = &state.schedule();

    let anchor = candidate_anchor(state, params, height, c)?;
    rules::check_anchor_progress(state.anchor.number, anchor.number, schedule, height)?;

    let inbox_generation = anchor.inbox.recovery_generation;
    if rules::check_generation(state.generation, c.extra_generation, inbox_generation)? ==
        GenerationCheck::Superseded
    {
        return Err(Rejection::Superseded { chain: state.generation, inbox: inbox_generation });
    }
    if anchor.inbox.status != inbox::ETNA_ACTIVE {
        return Err(Rejection::NotActive(anchor.inbox.status));
    }
    rules::check_back_pressure(
        height,
        anchor.inbox.last_checkpoint_height,
        params.unsettled_cap(),
    )?;
    Ok(anchor)
}

/// Derives the incoming committee at switch height `H(t)-2` and requires the outgoing local
/// committee to exist. No L1 committee publication or checkpoint coverage of a prior derivation
/// is required; back-pressure was already checked on the anchor.
pub(crate) fn finish_candidate(
    state: &AppState,
    params: &ChainParams,
    height: u64,
    committee: Option<&CommitteeWitness>,
    anchor: AnchorState,
) -> Result<CandidateFacts, Rejection> {
    let derived = candidate_committee(state, params, height, committee)?;
    if let Some(t) = state.schedule().switch_target(height) &&
        !state.committees.contains_key(&(t - 1))
    {
        return Err(Rejection::CommitteeUnknown(t - 1));
    }
    Ok(CandidateFacts { anchor, derived })
}

/// Step (a): the header's number is `height` and its parent hash is the committed `parent`.
fn check_link(header: &Header, height: u64, parent: B256) -> Result<(), RuleViolation> {
    if header.number != height {
        return Err(RuleViolation::header_field("number", &height, &header.number));
    }
    if header.parent_hash != parent {
        return Err(RuleViolation::header_field("parent_hash", &parent, &header.parent_hash));
    }
    Ok(())
}

/// Step (b): the candidate's anchor, proven by its witness or inherited from the parent.
fn candidate_anchor(
    state: &AppState,
    params: &ChainParams,
    height: u64,
    c: &Candidate<'_>,
) -> Result<AnchorState, Rejection> {
    let forced = height == state.schedule().h0();
    match c.anchor {
        None if forced || c.extra_anchor != state.anchor.number => {
            Err(Rejection::MissingWitness(WitnessKind::Anchor))
        }
        None => Ok(state.anchor.clone()),
        Some(w) if !forced && w.l1_header.number() == state.anchor.number => {
            Err(Rejection::UnexpectedWitness(WitnessKind::Anchor))
        }
        Some(w) => Ok(verify_anchor_witness(w, params.inbox)?),
    }
}

/// Derives committee `t` only at its switch height `H(t)-2`, using the committed parent's
/// authenticated anchor. Non-switch heights forbid runtime committee witnesses.
fn candidate_committee(
    state: &AppState,
    params: &ChainParams,
    height: u64,
    w: Option<&CommitteeWitness>,
) -> Result<Option<(u64, CommitteeState)>, Rejection> {
    match (state.schedule().switch_target(height), w) {
        (None, None) => Ok(None),
        (None, Some(_)) => Err(Rejection::UnexpectedWitness(WitnessKind::Committee)),
        (Some(_), None) => Err(Rejection::MissingWitness(WitnessKind::Committee)),
        (Some(target), Some(w)) => {
            let (record, members) =
                verify_committee_witness(&state.anchor, &state.schedule(), params, w, target)?;
            Ok(Some((target, CommitteeState { record, members })))
        }
    }
}
