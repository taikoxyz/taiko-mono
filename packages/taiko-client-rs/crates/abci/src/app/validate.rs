//! Deterministic block validation shared by `ProcessProposal` and `FinalizeBlock`: every check
//! of a proposal except the node-local ones, marked ¹ here (anchor finality in the node's own L1
//! view, EL execution), which affect liveness only.
//!
//! [`validate_block`] judges a decoded envelope against the committed [`AppState`] alone: no L1,
//! no EL, in its steps (a)–(j). [`check_candidate`] holds the witness steps (b)–(h);
//! `PrepareProposal` runs its two halves ([`check_candidate_anchor`], [`finish_candidate`]) on
//! its own witnesses before it asks the EL to build.
//! [`check_landing_capacity`] is the landing capacity guard `ProcessProposal` and
//! `PrepareProposal` run on the encoded envelope (liveness only, never in `FinalizeBlock`).
//! [`forced_rebuild_attributes`] and [`check_forced_rebuild`] are the EL rebuild of a forced
//! inclusion block, which `ProcessProposal` and a cold `FinalizeBlock` run after
//! [`validate_block`].
//! [`Rejection`] also carries the reasons of the ¹ checks, of the envelope decoding, of the
//! landing capacity guard, of a failed build, of an unavailable forced inclusion blob and of a
//! forced inclusion rebuild, so every handler reports one label set.

use std::fmt;

use alethia_reth_primitives::payload::attributes::TaikoPayloadAttributes;
use alloy_consensus::Header;
use alloy_primitives::B256;
use protocol::shasta::constants::min_base_fee_for_chain;

use crate::{
    committee::{CommitteeError, verify_committee_witness},
    compression::{HEADER_ALLOWANCE, MAX_BLOCK_LANDING_BYTES, zlib_compress},
    config::ChainParams,
    engine::EngineError,
    envelope::{AnchorWitness, CommitteeWitness, EnvelopeError, EtnaEnvelope, ExecutionBlock},
    forced::{self, ForcedConsumption, ForcedEntry, ForcedError},
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
    /// For a forced inclusion block: the consumed entry (the committed cursor) and the EL
    /// transaction list its block is built from; `None` for an ordinary block.
    pub forced: Option<ForcedConsumption>,
    /// For an ordinary block that proves the pending entry at the cursor (a peek): that entry,
    /// a node-local hint to fetch its blob before it falls due; no consensus rule reads it.
    pub pending_forced: Option<ForcedEntry>,
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
/// Every variant but [`Rejection::AnchorOffChain`] (a `FinalizeBlock` safety halt) is a liveness
/// matter for the node that observes it: the block is refused, the chain keeps rounding.
/// [`validate_block`] yields only the deterministic variants on a decoded envelope; the ¹
/// node-local ones (anchor finality, L1, engine, EL sync state, timeouts) and the handler-level
/// ones ([`Rejection::Envelope`], [`Rejection::EmptyProposal`], [`Rejection::ChainSuperseded`],
/// [`Rejection::PayloadInvalid`], [`Rejection::Registry`], [`Rejection::CommitteeCache`],
/// [`Rejection::Oversize`],
/// [`Rejection::BuiltHeader`], [`Rejection::LandingCapacity`], [`Rejection::BlobUnavailable`],
/// [`Rejection::ForcedRebuildMismatch`]) come from the handlers.
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
    /// `FinalizeBlock` of a block this node never judged: the anchor L1 header cannot be on the
    /// own L1 chain (a forged history, or an own L1 on another network). Unlike the ¹ variants,
    /// a safety halt.
    #[error("anchor L1 block {number} ({hash}) is not on the own L1 chain: {detail}")]
    AnchorOffChain {
        /// The anchor's L1 block number.
        number: u64,
        /// The anchor header's hash.
        hash: B256,
        /// Why: the own L1's block at that number, or the impossible number or timestamp.
        detail: String,
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
    /// The complete verified switch witness could not be durably retained for restart.
    #[error("committee witness cache failed: {0}")]
    CommitteeCache(String),
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
    /// The block breaks the forced inclusion rule ([`forced::check`]).
    #[error("forced inclusion rule violated: {0}")]
    Forced(#[from] ForcedError),
    /// `PrepareProposal`: the blob of the due forced inclusion entry the block must consume
    /// cannot be fetched (or is not the entry's blob), so nothing is proposed: never an
    /// ordinary block in its place.
    #[error("forced inclusion blob unavailable: {0}")]
    BlobUnavailable(String),
    /// A forced inclusion block is not the block the EL rebuilds on the committed parent from
    /// its entry's transaction list: their hashes differ.
    #[error("forced inclusion block {got} differs from the block {expected} rebuilt from its list")]
    ForcedRebuildMismatch {
        /// The hash of the block the EL rebuilt.
        expected: B256,
        /// The hash of the proposed (or decided) block.
        got: B256,
    },
    /// The block cannot land on its own: its envelope compressed as landing payload V3 would
    /// publish it, plus [`HEADER_ALLOWANCE`], exceeds [`MAX_BLOCK_LANDING_BYTES`].
    #[error("block needs {bytes} compressed landing bytes, above the {max} one landing carries")]
    LandingCapacity {
        /// The compressed envelope length plus [`HEADER_ALLOWANCE`], in bytes.
        bytes: usize,
        /// [`MAX_BLOCK_LANDING_BYTES`].
        max: usize,
    },
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
            Self::AnchorOffChain { .. } => "anchor_off_chain",
            Self::L1(_) => "l1_error",
            Self::Engine(_) => "engine_error",
            Self::PayloadInvalid(_) => "payload_invalid",
            Self::PayloadSyncing => "payload_syncing",
            Self::Timeout(_) => "timeout",
            Self::Registry(_) => "registry_discovery",
            Self::CommitteeCache(_) => "committee_cache_error",
            Self::Oversize { .. } => "envelope_too_large",
            Self::BuiltHeader(_) => "built_header_mismatch",
            Self::Forced(_) => "forced_inclusion",
            Self::BlobUnavailable(_) => "blob_unavailable",
            Self::ForcedRebuildMismatch { .. } => "forced_rebuild_mismatch",
            Self::LandingCapacity { .. } => "landing_capacity",
        }
    }

    /// Whether the refusal reports a local build fault at ERROR; expected liveness waits and
    /// malformed proposals log at WARN.
    pub fn logs_at_error(&self) -> bool {
        matches!(self, Self::Oversize { .. } | Self::BuiltHeader(_) | Self::CommitteeCache(_))
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

/// The landing capacity guard: the block of the encoded `envelope` must fit one landing on its
/// own, i.e. the envelope compressed as landing payload V3 would publish it, plus
/// [`HEADER_ALLOWANCE`] for the published header, is at most [`MAX_BLOCK_LANDING_BYTES`].
///
/// The bound holds for any envelope content: the lander's single-block fallback deflates the
/// envelope after a full flush ([`zlib_compress_split`](crate::compression::zlib_compress_split)),
/// exactly as measured here, and the allowance covers the published prefix and that framing.
///
/// A liveness guard, not a validity rule: `ProcessProposal` and `PrepareProposal` run it,
/// `FinalizeBlock` and the guest never do, so a decided block always commits.
pub(crate) fn check_landing_capacity(envelope: &[u8]) -> Result<(), Rejection> {
    let bytes = zlib_compress(envelope).len() + HEADER_ALLOWANCE;
    if bytes > MAX_BLOCK_LANDING_BYTES {
        return Err(Rejection::LandingCapacity { bytes, max: MAX_BLOCK_LANDING_BYTES });
    }
    Ok(())
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
/// `extraData`; (i) the derived header ([`rules::expected_header`]), whose timestamp must keep
/// the anchor within the genesis `maxAnchorAge` ([`rules::check_anchor_freshness`]) and whose
/// every field the header must carry ([`rules::check_header`]); (j) the forced inclusion rule
/// ([`forced::check`]) on the committed cursor, the block's anchor (its own witness's or the
/// parent's), the genesis delay and the envelope's forced witness. Reports the first failure.
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
    rules::check_anchor_freshness(
        expected.timestamp,
        facts.anchor.timestamp,
        state.genesis.max_anchor_age,
    )?;
    rules::check_header(header, &expected)?;
    let forced = forced::check(
        state.forced_cursor,
        &facts.anchor,
        state.genesis.forced_inclusion_delay,
        params.inbox,
        env.forced.as_ref(),
    )?;
    // `check` already verified a peek's entry proof; this only recovers the proven entry.
    let pending_forced = match (&forced, &env.forced) {
        (None, Some(witness)) => forced::verify_entry(
            facts.anchor.state_root,
            &witness.entry,
            params.inbox,
            witness.index,
        )
        .ok(),
        _ => None,
    };
    Ok(Validated {
        block: env.block.clone(),
        anchor: facts.anchor,
        derived: facts.derived,
        forced,
        pending_forced,
        executed: false,
    })
}

/// The payload attributes the EL rebuilds the forced inclusion block of `v` from, as the block
/// at `height` on top of `state` with BFT time `bft_secs`: the derived header's
/// ([`rules::payload_attributes`]) with the consumed entry's transaction list. `None` for an
/// ordinary block.
///
/// A forced inclusion block's EL block is derived, not chosen: the EL builds it on the committed
/// parent from these attributes alone, so every node rebuilds it and requires the proposed block
/// to be the same ([`check_forced_rebuild`]). The list comes from the blob the envelope carries,
/// so the rebuild needs no L1 or beacon access.
pub(crate) fn forced_rebuild_attributes(
    state: &AppState,
    params: &ChainParams,
    height: u64,
    bft_secs: u64,
    v: &Validated,
) -> Result<Option<TaikoPayloadAttributes>, RuleViolation> {
    let Some(forced) = &v.forced else {
        return Ok(None);
    };
    let expected = expected_header(state, params, height, &v.anchor, bft_secs)?;
    Ok(Some(rules::payload_attributes(&expected, v.anchor.hash, Some(forced.tx_list.clone()))))
}

/// Requires the forced inclusion `block` to be the block the EL `rebuilt` from its attributes
/// ([`forced_rebuild_attributes`]): equal header hashes, else
/// [`Rejection::ForcedRebuildMismatch`]. The hash binds the transactions root; that the carried
/// transactions match it is the EL's `newPayload` check.
pub(crate) fn check_forced_rebuild(
    block: &ExecutionBlock,
    rebuilt: &ExecutionBlock,
) -> Result<(), Rejection> {
    let (expected, got) = (rebuilt.header.hash_slow(), block.header.hash_slow());
    if expected != got {
        return Err(Rejection::ForcedRebuildMismatch { expected, got });
    }
    Ok(())
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
