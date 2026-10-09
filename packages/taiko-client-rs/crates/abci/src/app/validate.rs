//! Deterministic block validation shared by `ProcessProposal` and `FinalizeBlock` (spec §5.4
//! steps 1–8 without the ¹ checks).
//!
//! [`validate_block`] judges a decoded envelope against the committed [`AppState`] alone: no L1,
//! no EL. [`check_candidate`] holds the witness steps (b)–(h) so `PrepareProposal` can run the
//! same checks on its witnesses before it asks the EL to build. [`Rejection`] also carries the
//! reasons of the node-local ¹ checks and of a failed build, so every handler reports one label
//! set.

use std::fmt;

use alloy_consensus::Header;
use alloy_primitives::B256;
use protocol::shasta::constants::min_base_fee_for_chain;

use crate::{
    committee::{CommitteeError, record_hash, verify_committee_witness},
    config::ChainParams,
    engine::EngineError,
    envelope::{AnchorWitness, CommitteeWitness, EnvelopeError, EtnaEnvelope, ExecutionBlock},
    l1::{L1Error, WitnessError, layout::inbox, verify_anchor_witness},
    rules::{self, ExpectedHeader, GenerationCheck, HeaderInputs, RuleViolation},
    schedule::Schedule,
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
    /// Whether the anchor's L1 block number differs from the parent's.
    pub anchor_changed: bool,
    /// At an epoch's first height `h_first(e)`: the committee of epoch `e + 1` derived from the
    /// committee witness, keyed by that target epoch.
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
/// chain keeps rounding. [`validate_block`] yields only the deterministic variants; the ¹
/// node-local ones (anchor finality, L1, engine, timeouts) and the handler-level ones
/// ([`Rejection::ChainSuperseded`], [`Rejection::PayloadInvalid`], [`Rejection::Registry`],
/// [`Rejection::Oversize`], [`Rejection::BuiltHeader`]) come from the handlers.
#[derive(Debug, thiserror::Error, PartialEq, Eq)]
pub enum Rejection {
    /// The block's transactions are not exactly one well-formed envelope.
    #[error("malformed envelope: {0}")]
    Envelope(#[from] EnvelopeError),
    /// A header field or a consensus predicate fails (spec §4.2, §5.4).
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
    /// The anchored Inbox is not in `ETNA_ACTIVE` (spec §5.4 step 6).
    #[error("inbox migrationState is {0}, expected ETNA_ACTIVE ({active})", active = inbox::ETNA_ACTIVE)]
    NotActive(u8),
    /// A switch height needs a committee the app does not hold.
    #[error("no committee known for epoch {0}")]
    CommitteeUnknown(u64),
    /// At a switch height, the anchored checkpoint does not yet cover the height that derived
    /// the next committee (D19).
    #[error("lastCheckpoint.height {last_checkpoint_height} is below {required} (D19)")]
    RecordNotLanded {
        /// The anchored `lastCheckpoint.height`.
        last_checkpoint_height: u64,
        /// `h_first(t - 1)`, the height that derived committee `t`.
        required: u64,
    },
    /// At a switch height, the anchored `committee[t]` is not the derived record's hash (D19).
    #[error("committee[{epoch}] on L1 is {proven:?}, expected the derived record hash {expected}")]
    RecordMismatch {
        /// The switching-to epoch `t`.
        epoch: u64,
        /// `record_hash` of the derived committee `t`.
        expected: B256,
        /// What the anchor witness proves for the committee mapping.
        proven: Option<(u64, B256)>,
    },
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
            Self::RecordNotLanded { .. } => "record_not_landed",
            Self::RecordMismatch { .. } => "record_mismatch",
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
    /// The committee derived at an epoch's first height, keyed by its target epoch.
    pub(crate) derived: Option<(u64, CommitteeState)>,
}

/// Validates `env` as the block at `height` on top of `state` (spec §5.4 steps 1–8 without the
/// ¹ checks); `bft_secs` is the block's BFT time in whole seconds.
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
        anchor_changed: facts.anchor.number != state.anchor.number,
        anchor: facts.anchor,
        derived: facts.derived,
        executed: false,
    })
}

/// The derived header fields of the block at `height` on top of `state` with `anchor` and BFT
/// time `bft_secs` (spec §4.2), with the chain's minimum base fee.
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

/// Steps (b)–(h) of [`validate_block`] on a candidate's witnesses and `extraData` claims.
///
/// (b) the anchor witness is required iff the anchor number changes (per the witness, or per
/// `extraData` when absent), `height == H_0` or `height` is a switch height; a present witness
/// must verify for `anchor_slots(switch_target(height))`, an absent one inherits the parent's
/// anchor; (c) anchor progress; (d) the generation triple, an Inbox ahead of the chain being
/// [`Rejection::Superseded`]; (e) `migrationState == ETNA_ACTIVE`; (f) back-pressure; (g) the
/// committee witness is required iff `height = h_first(e)` and must prove committee `e + 1`
/// against the parent's anchor; (h) at a switch height to epoch `t`, D19.
pub(crate) fn check_candidate(
    state: &AppState,
    params: &ChainParams,
    height: u64,
    c: &Candidate<'_>,
) -> Result<CandidateFacts, Rejection> {
    let schedule = &state.schedule;
    let switch = schedule.switch_target(height);

    let anchor = candidate_anchor(state, params, height, switch, c)?;
    rules::check_anchor_progress(state.anchor.number, anchor.number, schedule, height)?;

    let inbox_generation = anchor.inbox.recovery_generation;
    if rules::check_generation(state.generation, c.extra_generation, inbox_generation)? ==
        GenerationCheck::Superseded
    {
        return Err(Rejection::Superseded { chain: state.generation, inbox: inbox_generation });
    }
    if anchor.inbox.migration_state != inbox::ETNA_ACTIVE {
        return Err(Rejection::NotActive(anchor.inbox.migration_state));
    }
    rules::check_back_pressure(
        height,
        anchor.inbox.last_checkpoint_height,
        params.unsettled_cap(),
    )?;

    let derived = candidate_committee(state, params, height, c.committee)?;
    if let Some(t) = switch {
        check_switch(state, params, schedule, t, &anchor)?;
    }
    Ok(CandidateFacts { anchor, derived })
}

/// Step (a): the header's number is `height` and its parent hash is the committed `parent`.
fn check_link(header: &Header, height: u64, parent: B256) -> Result<(), RuleViolation> {
    let field =
        |field, expected: &dyn fmt::Debug, got: &dyn fmt::Debug| RuleViolation::HeaderField {
            field,
            expected: format!("{expected:?}"),
            got: format!("{got:?}"),
        };
    if header.number != height {
        return Err(field("number", &height, &header.number));
    }
    if header.parent_hash != parent {
        return Err(field("parent_hash", &parent, &header.parent_hash));
    }
    Ok(())
}

/// Step (b): the candidate's anchor, proven by its witness or inherited from the parent.
fn candidate_anchor(
    state: &AppState,
    params: &ChainParams,
    height: u64,
    switch: Option<u64>,
    c: &Candidate<'_>,
) -> Result<AnchorState, Rejection> {
    let forced = height == state.schedule.h0() || switch.is_some();
    match c.anchor {
        None if forced || c.extra_anchor != state.anchor.number => {
            Err(Rejection::MissingWitness(WitnessKind::Anchor))
        }
        None => Ok(state.anchor.clone()),
        Some(w) if !forced && w.l1_header.number == state.anchor.number => {
            Err(Rejection::UnexpectedWitness(WitnessKind::Anchor))
        }
        Some(w) => Ok(verify_anchor_witness(w, params.inbox, switch)?),
    }
}

/// Step (g): the committee of epoch `e + 1` at `height = h_first(e)`, proven against the
/// parent's anchor; no witness at any other height.
fn candidate_committee(
    state: &AppState,
    params: &ChainParams,
    height: u64,
    w: Option<&CommitteeWitness>,
) -> Result<Option<(u64, CommitteeState)>, Rejection> {
    match (state.schedule.epoch_starting_at(height), w) {
        (None, None) => Ok(None),
        (None, Some(_)) => Err(Rejection::UnexpectedWitness(WitnessKind::Committee)),
        (Some(_), None) => Err(Rejection::MissingWitness(WitnessKind::Committee)),
        (Some(e), Some(w)) => {
            let target = e.checked_add(1).expect("an epoch below u64::MAX starts at a u64 height");
            let (record, members) = verify_committee_witness(
                state.anchor.state_root,
                params,
                w,
                state.anchor.number,
                target,
            )?;
            Ok(Some((target, CommitteeState { record, members })))
        }
    }
}

/// Step (h), D19: at the switch height to epoch `t`, the app holds committees `t − 1` and `t`,
/// the anchored checkpoint covers `h_first(t − 1)` (the height that derived `t`), and the
/// anchored `committee[t]` is the derived record's hash.
fn check_switch(
    state: &AppState,
    params: &ChainParams,
    schedule: &Schedule,
    t: u64,
    anchor: &AnchorState,
) -> Result<(), Rejection> {
    // `switch_target` only yields epochs >= 1.
    let prev = t - 1;
    if !state.committees.contains_key(&prev) {
        return Err(Rejection::CommitteeUnknown(prev));
    }
    let next = state.committees.get(&t).ok_or(Rejection::CommitteeUnknown(t))?;
    let required = schedule.h_first(prev);
    let last_checkpoint_height = anchor.inbox.last_checkpoint_height;
    if last_checkpoint_height < required {
        return Err(Rejection::RecordNotLanded { last_checkpoint_height, required });
    }
    let expected = record_hash(params.l2_chain_id, &next.record);
    if anchor.inbox.committee != Some((t, expected)) {
        return Err(Rejection::RecordMismatch {
            epoch: t,
            expected,
            proven: anchor.inbox.committee,
        });
    }
    Ok(())
}
